#!/usr/bin/env node

import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

function chinaDate(now = new Date()) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Shanghai',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  }).format(now);
}

function getArg(name, fallback = null) {
  const index = process.argv.indexOf(name);
  if (index === -1) {
    return fallback;
  }
  return process.argv[index + 1] ?? fallback;
}

function run(command, args) {
  console.log(`\n$ ${command} ${args.join(' ')}`);
  const result = spawnSync(command, args, {
    cwd: process.cwd(),
    encoding: 'utf8',
    stdio: 'pipe'
  });

  if (result.stdout) {
    process.stdout.write(result.stdout);
  }
  if (result.stderr) {
    process.stderr.write(result.stderr);
  }

  return result.status ?? 1;
}

function countCandidates(filePath) {
  if (!existsSync(filePath)) {
    return 0;
  }
  const payload = JSON.parse(readFileSync(filePath, 'utf8'));
  return Array.isArray(payload.candidates) ? payload.candidates.length : 0;
}

function main() {
  const date = getArg('--date', chinaDate());
  const candidateFile = getArg('--candidates', `data/candidates.${date}.json`);
  const editionFile = getArg('--edition', `data/daily-edition.${date}.json`);

  const fetchStatus = run('node', [
    'scripts/fetch-candidates.mjs',
    '--date',
    date,
    '--out',
    candidateFile
  ]);

  if (fetchStatus !== 0) {
    console.error('Candidate fetch failed.');
    process.exit(fetchStatus);
  }

  const count = countCandidates(resolve(process.cwd(), candidateFile));
  if (count < 10) {
    console.error(`Only ${count} candidates were generated. Need at least 10 for an auto draft.`);
    process.exit(1);
  }

  const draftStatus = run('node', [
    'scripts/make-edition-from-candidates.mjs',
    candidateFile,
    '--auto-draft',
    '--out',
    editionFile
  ]);

  if (draftStatus !== 0) {
    console.error('Auto draft failed.');
    process.exit(draftStatus);
  }

  const dryRunStatus = run('node', [
    'scripts/publish-edition.mjs',
    editionFile,
    '--dry-run'
  ]);

  console.log('\nDaily auto draft summary');
  console.log(`Candidates: ${candidateFile} (${count})`);
  console.log(`Draft: ${editionFile}`);
  console.log('Open the review UI at http://127.0.0.1:4180 and import the candidate or draft file before publishing.');

  if (dryRunStatus !== 0) {
    console.log('Dry-run found issues. Review and edit the draft JSON before publishing.');
    process.exit(dryRunStatus);
  }
}

main();
