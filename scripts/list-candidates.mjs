#!/usr/bin/env node

import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

function usage() {
  console.log(`Usage:
  node scripts/list-candidates.mjs data/candidates.2026-06-02.json
  node scripts/list-candidates.mjs data/candidates.2026-06-02.json --category international
`);
}

function getArg(name, fallback = null) {
  const index = process.argv.indexOf(name);
  if (index === -1) {
    return fallback;
  }
  return process.argv[index + 1] ?? fallback;
}

function formatTime(value) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return value;
  }
  return new Intl.DateTimeFormat('zh-CN', {
    timeZone: 'Asia/Shanghai',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit'
  }).format(date);
}

function truncate(value, length) {
  const text = String(value ?? '').replace(/\s+/g, ' ').trim();
  return text.length > length ? `${text.slice(0, length - 1)}...` : text;
}

function main() {
  if (process.argv.includes('--help') || process.argv.includes('-h')) {
    usage();
    return;
  }

  const file = process.argv.slice(2).find((arg) => !arg.startsWith('-'));
  if (!file) {
    usage();
    process.exit(1);
  }

  const category = getArg('--category');
  const payload = JSON.parse(readFileSync(resolve(process.cwd(), file), 'utf8'));
  const candidates = (payload.candidates ?? []).filter((candidate) => {
    return !category || candidate.category === category;
  });

  console.log(`Candidates for ${payload.date}: ${candidates.length}`);
  console.log('Pick 10 candidateId values, then pass them to make-edition-from-candidates.mjs --pick');
  console.log('');

  for (const candidate of candidates) {
    const id = String(candidate.candidateId).padStart(3, ' ');
    const categoryText = String(candidate.category).padEnd(13, ' ');
    const source = truncate(candidate.source?.name, 20).padEnd(20, ' ');
    const time = formatTime(candidate.publishedAt);
    console.log(`${id}  ${categoryText} ${source} ${time}  ${truncate(candidate.title, 86)}`);
  }
}

main();
