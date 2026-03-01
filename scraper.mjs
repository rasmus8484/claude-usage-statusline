#!/usr/bin/env node

// Claude Session Limit Scraper
// Fetches usage data from Anthropic's OAuth usage API and caches it locally.

import { readFileSync, writeFileSync, mkdirSync } from "fs";
import { join } from "path";
import { homedir } from "os";

const CLAUDE_DIR = join(homedir(), ".claude");
const CREDENTIALS_PATH = join(CLAUDE_DIR, ".credentials.json");
const OUTPUT_PATH = join(CLAUDE_DIR, "usage.json");
const API_URL = "https://api.anthropic.com/api/oauth/usage";

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

async function fetchUsage(token) {
  const res = await fetch(API_URL, {
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
      "User-Agent": "claude-code/2.0.32",
      Authorization: `Bearer ${token}`,
      "anthropic-beta": "oauth-2025-04-20",
    },
  });

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`API returned ${res.status}: ${body}`);
  }

  return res.json();
}

function formatOutput(data) {
  return {
    fetched_at: new Date().toISOString(),
    five_hour: data.five_hour ?? null,
    seven_day: data.seven_day ?? null,
    seven_day_opus: data.seven_day_opus ?? null,
    extra_usage: data.extra_usage ?? null,
  };
}

async function main() {
  const token = getAccessToken();
  const data = await fetchUsage(token);
  const output = formatOutput(data);

  mkdirSync(CLAUDE_DIR, { recursive: true });
  writeFileSync(OUTPUT_PATH, JSON.stringify(output, null, 2) + "\n");

  // Print summary to stdout
  const h5 = output.five_hour?.utilization ?? "??";
  const d7 = output.seven_day?.utilization ?? "??";
  const reset5 = output.five_hour?.resets_at;
  const resetStr = reset5 ? ` (resets ${new Date(reset5).toLocaleTimeString()})` : "";
  console.log(`5h: ${h5}%${resetStr}  |  7d: ${d7}%`);
  console.log(`Saved to ${OUTPUT_PATH}`);
}

main().catch((err) => {
  console.error(`Scraper error: ${err.message}`);
  process.exit(1);
});
