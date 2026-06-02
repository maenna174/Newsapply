#!/usr/bin/env node

import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

const defaultStatement = '本期新闻按公共重要性、来源多样性和主题配额生成，不基于个人阅读行为排序。';
const categoryOrder = [
  'domestic',
  'international',
  'finance',
  'technology',
  'health',
  'education',
  'society',
  'sports',
  'perspective'
];
const categoryLimits = {
  domestic: 2,
  international: 2,
  finance: 1,
  technology: 1,
  health: 1,
  education: 1,
  society: 2,
  sports: 1,
  perspective: 1
};

function usage() {
  console.log(`Usage:
  node scripts/make-edition-from-candidates.mjs data/candidates.2026-06-02.json --pick 3,7,11,14,18,21,25,29,31,34
  node scripts/make-edition-from-candidates.mjs data/candidates.2026-06-02.json --auto-draft

Options:
  --out <file>          Output file. Default: data/daily-edition.<date>.json
  --pick <ids>          Comma separated candidateId list. Order becomes positions 1-10.
  --auto-draft          Create a draft using fixed public quotas. Review before publishing.
  --status <status>     draft or published. Default: draft
`);
}

function getArg(name, fallback = null) {
  const index = process.argv.indexOf(name);
  if (index === -1) {
    return fallback;
  }
  return process.argv[index + 1] ?? fallback;
}

function chinaDateTime() {
  const now = new Date();
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Shanghai',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false
  }).formatToParts(now).reduce((acc, part) => {
    acc[part.type] = part.value;
    return acc;
  }, {});
  return `${parts.year}-${parts.month}-${parts.day}T${parts.hour}:${parts.minute}:${parts.second}+08:00`;
}

function normalizeText(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function parsePick(value) {
  if (!value) {
    return [];
  }
  return value.split(',')
    .map((part) => Number(part.trim()))
    .filter((value) => Number.isInteger(value));
}

function pickByIds(candidates, ids) {
  const byId = new Map(candidates.map((candidate) => [candidate.candidateId, candidate]));
  return ids.map((id) => byId.get(id)).filter(Boolean);
}

function autoDraft(candidates) {
  const picked = [];
  const sourceCounts = new Map();
  const topicCounts = new Map();
  const categoryCounts = new Map();
  const seen = new Set();

  function canPick(candidate, options = { enforceCategoryLimit: true, enforceSourceLimit: true, enforceTopicLimit: true }) {
    const sourceCount = sourceCounts.get(candidate.source.name) ?? 0;
    const topicCount = topicCounts.get(candidate.topicKey) ?? 0;
    const categoryCount = categoryCounts.get(candidate.category) ?? 0;
    const categoryLimit = categoryLimits[candidate.category] ?? 1;
    return !seen.has(candidate.url) &&
      (!options.enforceSourceLimit || sourceCount < 3) &&
      (!options.enforceTopicLimit || topicCount < 2) &&
      (!options.enforceCategoryLimit || categoryCount < categoryLimit);
  }

  function add(candidate) {
    picked.push(candidate);
    seen.add(candidate.url);
    sourceCounts.set(candidate.source.name, (sourceCounts.get(candidate.source.name) ?? 0) + 1);
    topicCounts.set(candidate.topicKey, (topicCounts.get(candidate.topicKey) ?? 0) + 1);
    categoryCounts.set(candidate.category, (categoryCounts.get(candidate.category) ?? 0) + 1);
  }

  for (const category of categoryOrder) {
    const candidate = candidates.find((item) => item.category === category && canPick(item));
    if (candidate && picked.length < 10) {
      add(candidate);
    }
  }

  for (const candidate of candidates) {
    if (picked.length >= 10) {
      break;
    }
    if (canPick(candidate, { enforceCategoryLimit: false, enforceSourceLimit: true, enforceTopicLimit: true })) {
      add(candidate);
    }
  }

  for (const candidate of candidates) {
    if (picked.length >= 10) {
      break;
    }
    if (canPick(candidate, { enforceCategoryLimit: false, enforceSourceLimit: true, enforceTopicLimit: false })) {
      add(candidate);
    }
  }

  for (const candidate of candidates) {
    if (picked.length >= 10) {
      break;
    }
    if (canPick(candidate, { enforceCategoryLimit: false, enforceSourceLimit: false, enforceTopicLimit: false })) {
      add(candidate);
    }
  }

  return picked;
}

function toEditionItem(candidate, position) {
  return {
    position,
    selectionReason: normalizeText(candidate.selectionHint) || '按公共重要性、来源多样性和主题配额入选。',
    article: {
      title: normalizeText(candidate.title),
      summary: normalizeText(candidate.summary),
      url: normalizeText(candidate.url),
      category: normalizeText(candidate.category),
      topicKey: normalizeText(candidate.topicKey),
      publishedAt: normalizeText(candidate.publishedAt),
      source: {
        name: normalizeText(candidate.source.name),
        homepageUrl: normalizeText(candidate.source.homepageUrl),
        feedUrl: normalizeText(candidate.source.feedUrl),
        crawlType: normalizeText(candidate.source.crawlType) || 'rss',
        reliabilityNote: normalizeText(candidate.source.reliabilityNote),
        licenseNote: normalizeText(candidate.source.licenseNote)
      }
    }
  };
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

  const candidateFile = resolve(process.cwd(), file);
  const payload = JSON.parse(readFileSync(candidateFile, 'utf8'));
  const candidates = payload.candidates ?? [];
  const pickIds = parsePick(getArg('--pick'));
  const useAutoDraft = process.argv.includes('--auto-draft');
  const date = payload.date;
  const status = getArg('--status', 'draft');
  const outFile = resolve(process.cwd(), getArg('--out', `data/daily-edition.${date}.json`));

  let picked = [];
  if (pickIds.length > 0) {
    picked = pickByIds(candidates, pickIds);
  } else if (useAutoDraft) {
    picked = autoDraft(candidates);
  } else {
    console.error('Provide --pick or --auto-draft.');
    process.exit(1);
  }

  if (picked.length !== 10) {
    console.error(`Need exactly 10 candidates, got ${picked.length}.`);
    console.error('Use candidateId values from the candidate file, for example: --pick 1,2,3,4,5,6,7,8,9,10');
    process.exit(1);
  }

  const edition = {
    edition: {
      date,
      region: 'cn',
      language: 'zh-CN',
      status,
      publishedAt: status === 'published' ? chinaDateTime() : null,
      statement: defaultStatement
    },
    items: picked.map((candidate, index) => toEditionItem(candidate, index + 1))
  };

  mkdirSync(dirname(outFile), { recursive: true });
  writeFileSync(outFile, `${JSON.stringify(edition, null, 2)}\n`);
  console.log(`Wrote ${picked.length} items to ${outFile}`);
  console.log('Review the file, then run publish-edition.mjs --dry-run before publishing.');
}

main();
