#!/usr/bin/env node

import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const DEFAULT_ADMIN_URL = 'http://127.0.0.1:3000/functions/v1/admin';
const DEFAULT_REGION = 'cn';
const DEFAULT_LANGUAGE = 'zh-CN';

const SCRIPT_ONLY_FLAGS = new Set([
  '--allow-warnings',
  '--no-publish',
  '--help',
  '-h'
]);

function usage() {
  console.log(`Usage:
  node scripts/daily-auto-publish.mjs
  node scripts/daily-auto-publish.mjs --allow-warnings
  node scripts/daily-auto-publish.mjs --date 2026-06-26 --limit 50

Environment:
  DAILYTEN_ADMIN_TOKEN     required
  DAILYTEN_ADMIN_URL       optional, default: ${DEFAULT_ADMIN_URL}

Options:
  --allow-warnings         Publish when quality review has warnings but no errors
  --no-publish             Generate and review only, do not publish

All other options are passed through to scripts/daily-ai-draft.mjs, including:
  --date, --limit, --sources, --region, --language, --statement,
  --candidates, --out, --skip-fetch, --max-per-source
`);
}

function hasArg(name) {
  return process.argv.includes(name);
}

function getArg(name, fallback = null) {
  const index = process.argv.indexOf(name);
  if (index === -1) return fallback;
  return process.argv[index + 1] ?? fallback;
}

function loadDotEnv(filePath) {
  try {
    const text = readFileSync(filePath, 'utf8');
    for (const line of text.split(/\r?\n/)) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('#') || !trimmed.includes('=')) continue;
      const index = trimmed.indexOf('=');
      const key = trimmed.slice(0, index).trim();
      const value = trimmed.slice(index + 1).trim().replace(/^['"]|['"]$/g, '');
      if (key && process.env[key] === undefined) process.env[key] = value;
    }
  } catch (_) {
    // Optional environment file.
  }
}

function chinaDate(now = new Date()) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Shanghai',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  }).format(now);
}

function forwardedArgs() {
  const args = [];
  for (let index = 2; index < process.argv.length; index += 1) {
    const arg = process.argv[index];
    if (SCRIPT_ONLY_FLAGS.has(arg)) continue;
    if (arg === '--publish' || arg === '--no-save') continue;
    args.push(arg);
  }
  return args;
}

function runDraftPipeline() {
  const result = spawnSync('node', ['scripts/daily-ai-draft.mjs', ...forwardedArgs()], {
    cwd: process.cwd(),
    stdio: 'inherit',
    encoding: 'utf8'
  });
  if ((result.status ?? 1) !== 0) {
    throw new Error(`daily-ai-draft failed with status ${result.status ?? 1}`);
  }
}

async function adminFetch(path, { method = 'GET', body = undefined } = {}) {
  const token = process.env.DAILYTEN_ADMIN_TOKEN || process.env.ADMIN_TOKEN;
  if (!token) throw new Error('Missing DAILYTEN_ADMIN_TOKEN.');
  const baseUrl = (process.env.DAILYTEN_ADMIN_URL || DEFAULT_ADMIN_URL).replace(/\/+$/, '');
  const response = await fetch(`${baseUrl}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: 'application/json',
      ...(body === undefined ? {} : { 'Content-Type': 'application/json' })
    },
    body: body === undefined ? undefined : JSON.stringify(body)
  });
  const text = await response.text();
  const payload = text ? JSON.parse(text) : {};
  if (!response.ok) {
    const error = new Error(payload.message || payload.error || `HTTP ${response.status}`);
    error.status = response.status;
    error.payload = payload;
    throw error;
  }
  return payload;
}

function printIssues(quality) {
  const issues = Array.isArray(quality?.issues) ? quality.issues : [];
  for (const issue of issues.slice(0, 20)) {
    console.log(`[${issue.level}] ${issue.path}: ${issue.message}`);
  }
  if (issues.length > 20) {
    console.log(`... ${issues.length - 20} more issue(s)`);
  }
}

async function reviewAndPublish() {
  const date = getArg('--date', chinaDate());
  const region = getArg('--region', DEFAULT_REGION);
  const language = getArg('--language', DEFAULT_LANGUAGE);
  const query = new URLSearchParams({ date, region, language });
  const draft = await adminFetch(`/editions/detail?${query}`);
  if (draft.edition?.status !== 'draft') {
    throw new Error(`Expected ${date}/${region}/${language} to be draft, got ${draft.edition?.status || 'unknown'}.`);
  }

  const review = await adminFetch('/editions/quality', { method: 'POST', body: draft });
  console.log(`Quality review ok: ${review.quality.errors} error(s), ${review.quality.warnings} warning(s)`);
  printIssues(review.quality);

  if (review.errors?.length) {
    throw new Error(`Validation failed: ${review.errors.join('; ')}`);
  }
  if (!review.quality.ok) {
    throw new Error('Quality review has blocking errors; draft was not published.');
  }
  if (review.quality.warnings > 0 && !hasArg('--allow-warnings')) {
    throw new Error('Quality review has warnings; rerun with --allow-warnings to publish automatically.');
  }
  if (hasArg('--no-publish')) {
    console.log('Review passed; --no-publish set, draft remains unpublished.');
    return;
  }

  const published = await adminFetch('/editions/publish-draft', {
    method: 'POST',
    body: { date, region, language, allowWarnings: hasArg('--allow-warnings') }
  });
  console.log(`Published edition: ${published.edition.edition_date || date} / ${published.edition.status}`);
}

async function main() {
  loadDotEnv(resolve(process.cwd(), '.env'));
  loadDotEnv(resolve(process.cwd(), '.env.local'));
  loadDotEnv('/etc/newsapply/newsapply.env');

  if (hasArg('--help') || hasArg('-h')) {
    usage();
    return;
  }

  runDraftPipeline();
  await reviewAndPublish();
}

main().catch((error) => {
  const payload = error?.payload;
  if (payload?.quality) printIssues(payload.quality);
  if (Array.isArray(payload?.errors)) console.error(payload.errors.join('\n'));
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
