#!/usr/bin/env node

// Claude Session Limit Scraper
// Fetches usage data by making a minimal Messages API call and reading
// rate limit headers. This avoids the /api/oauth/usage endpoint which
// is aggressively rate-limited (persistent 429s).

import { readFileSync, writeFileSync, mkdirSync } from "fs";
import { join } from "path";
import { homedir } from "os";
import { request } from "https";

const CLAUDE_DIR = join(homedir(), ".claude");
const CREDENTIALS_PATH = join(CLAUDE_DIR, ".credentials.json");
const OUTPUT_PATH = join(CLAUDE_DIR, "usage.json");
const API_URL = "https://api.anthropic.com/v1/messages";

function getAccessToken() {
  try {
    const creds = JSON.parse(readFileSync(CREDENTIALS_PATH, "utf-8"));
    const token = creds?.claudeAiOauth?.accessToken;
    if (!token) {
      throw new Error("No accessToken found in credentials");
    }
    return token;
  } catch (err) {
    console.error(`Failed to read credentials from ${CREDENTIALS_PATH}: ${err.message}`);
    process.exit(1);
  }
}

function fetchUsage(token) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify({
      model: "claude-haiku-4-5-20251001",
      max_tokens: 1,
      messages: [{ role: "user", content: "hi" }],
    });

    const url = new URL(API_URL);
    const options = {
      hostname: url.hostname,
      path: url.pathname,
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
        "anthropic-version": "2023-06-01",
        "anthropic-beta": "oauth-2025-04-20",
        "Content-Length": Buffer.byteLength(body),
      },
    };

    const req = request(options, (res) => {
      let data = "";
      res.on("data", (chunk) => (data += chunk));
      res.on("end", () => {
        if (res.statusCode === 401) {
          reject(new Error("OAuth token expired. Re-authenticate with: claude"));
          return;
        }

        // Extract rate limit headers
        const h = res.headers;
        const h5Util = parseFloat(h["anthropic-ratelimit-unified-5h-utilization"] || "0");
        const h5Reset = h["anthropic-ratelimit-unified-5h-reset"] || null;
        const h5Status = h["anthropic-ratelimit-unified-5h-status"] || "unknown";
        const d7Util = parseFloat(h["anthropic-ratelimit-unified-7d-utilization"] || "0");
        const d7Reset = h["anthropic-ratelimit-unified-7d-reset"] || null;
        const d7Status = h["anthropic-ratelimit-unified-7d-status"] || "unknown";

        // Convert epoch-seconds reset to ISO timestamp
        const toISO = (epoch) => {
          if (!epoch) return null;
          const n = parseInt(epoch, 10);
          return isNaN(n) ? null : new Date(n * 1000).toISOString();
        };

        resolve({
          five_hour: {
            utilization: Math.round(h5Util * 100),
            resets_at: toISO(h5Reset),
            status: h5Status,
          },
          seven_day: {
            utilization: Math.round(d7Util * 100),
            resets_at: toISO(d7Reset),
            status: d7Status,
          },
        });
      });
    });

    req.on("error", reject);
    req.write(body);
    req.end();
  });
}

async function main() {
  const token = getAccessToken();
  const data = await fetchUsage(token);

  const output = {
    fetched_at: new Date().toISOString(),
    five_hour: data.five_hour,
    seven_day: data.seven_day,
  };

  mkdirSync(CLAUDE_DIR, { recursive: true });
  writeFileSync(OUTPUT_PATH, JSON.stringify(output, null, 2) + "\n");

  const h5 = data.five_hour.utilization ?? "??";
  const d7 = data.seven_day.utilization ?? "??";
  const reset5 = data.five_hour.resets_at;
  const resetStr = reset5 ? ` (resets ${new Date(reset5).toLocaleTimeString()})` : "";
  console.log(`5h: ${h5}%${resetStr}  |  7d: ${d7}%`);
  console.log(`Saved to ${OUTPUT_PATH}`);
}

main().catch((err) => {
  console.error(`Scraper error: ${err.message}`);
  process.exit(1);
});
