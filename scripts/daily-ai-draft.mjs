#!/usr/bin/env node

import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const DEFAULT_ADMIN_URL = 'http://127.0.0.1:3000/functions/v1/admin';
const DEFAULT_LIMIT = 50;

function usage() {
  console.log(`Usage:
  node scripts/daily-ai-draft.mjs
  node scripts/daily-ai-draft.mjs --date 2026-06-10
  node scripts/daily-ai-draft.mjs --skip-fetch --candidates data/candidates.2026-06-10.json

Environment:
  DAILYTEN_ADMIN_TOKEN     required
  DAILYTEN_ADMIN_URL       optional, default: ${DEFAULT_ADMIN_URL}

Options:
  --date <YYYY-MM-DD>      Edition date. Default: today in Asia/Shanghai
  --limit <n>              Candidate count to keep. Default: ${DEFAULT_LIMIT}
  --candidates <file>      Candidate JSON path. Default: data/candidates.<date>.json
  --out <file>             Draft JSON path. Default: data/daily-edition.<date>.ai-draft.json
  --skip-fetch             Reuse an existing candidate file
  --no-save                Do not save the generated draft into the admin database
`);
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

function run(command, args) {
  const result = spawnSync(command, args, {
    cwd: process.cwd(),
    encoding: 'utf8',
    stdio: 'inherit'
  });
  if ((result.status ?? 1) !== 0) {
    throw new Error(`${command} ${args.join(' ')} failed`);
  }
}

async function adminFetch(path, body) {
  const token = process.env.DAILYTEN_ADMIN_TOKEN || process.env.ADMIN_TOKEN;
  if (!token) throw new Error('Missing DAILYTEN_ADMIN_TOKEN.');
  const baseUrl = (process.env.DAILYTEN_ADMIN_URL || DEFAULT_ADMIN_URL).replace(/\/+$/, '');
  const response = await fetch(`${baseUrl}${path}`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: 'application/json',
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(body)
  });
  const text = await response.text();
  const payload = text ? JSON.parse(text) : {};
  if (!response.ok) {
    const details = Array.isArray(payload.errors) ? `: ${payload.errors.join('; ')}` : '';
    const error = new Error(`${payload.message || payload.error || `HTTP ${response.status}`}${details}`);
    error.payload = payload;
    throw error;
  }
  return payload;
}

async function main() {
  loadDotEnv(resolve(process.cwd(), '.env'));
  loadDotEnv(resolve(process.cwd(), '.env.local'));
  loadDotEnv('/etc/newsapply/newsapply.env');

  if (process.argv.includes('--help') || process.argv.includes('-h')) {
    usage();
    return;
  }

  const date = getArg('--date', chinaDate());
  const limit = Number(getArg('--limit', DEFAULT_LIMIT));
  const candidateFile = resolve(process.cwd(), getArg('--candidates', `data/candidates.${date}.json`));
  const outFile = resolve(process.cwd(), getArg('--out', `data/daily-edition.${date}.ai-draft.json`));

  if (!process.argv.includes('--skip-fetch')) {
    run('node', [
      'scripts/fetch-candidates.mjs',
      '--date', date,
      '--out', candidateFile,
      '--limit', String(limit)
    ]);
  }

  const candidates = JSON.parse(readFileSync(candidateFile, 'utf8'));
  if (!Array.isArray(candidates.candidates) || candidates.candidates.length < 10) {
    throw new Error(`Candidate file needs at least 10 items, got ${candidates.candidates?.length || 0}.`);
  }

  const draftResult = await adminFetch('/ai/draft', candidates);
  const draft = draftResult.draft;
  if (!draft || !Array.isArray(draft.items)) {
    throw new Error('AI draft response did not include draft.items.');
  }

  mkdirSync(dirname(outFile), { recursive: true });
  writeFileSync(outFile, `${JSON.stringify(draft, null, 2)}\n`);
  console.log(`Wrote AI draft to ${outFile}`);

  const dryRun = await adminFetch('/editions/publish?dryRun=true', draft);
  console.log(`Dry run ok: ${dryRun.items} items`);

  if (!process.argv.includes('--no-save')) {
    const saved = await adminFetch('/editions', draft);
    console.log(`Saved draft edition: ${saved.edition?.edition_date || date} / ${saved.edition?.status || 'draft'}`);
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
