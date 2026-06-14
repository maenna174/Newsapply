#!/usr/bin/env node

import { spawnSync } from 'node:child_process';

const args = [
  'scripts/daily-ai-draft.mjs',
  '--sources', 'data/ai-rss-sources.json',
  '--region', 'ai',
  '--statement', 'AI 新闻专区每日自动汇总模型、应用、硬件、治理与安全动态；只按公共信息价值排序，不基于个人阅读行为推荐。',
  '--candidates', `data/ai-candidates.${todayInChina()}.json`,
  '--out', `data/daily-edition.${todayInChina()}.ai-news.json`,
  '--max-per-source', '4',
  '--publish',
  ...process.argv.slice(2)
];

function todayInChina() {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Shanghai',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  }).format(new Date());
}

const result = spawnSync('node', args, {
  cwd: process.cwd(),
  stdio: 'inherit',
  encoding: 'utf8'
});

process.exit(result.status ?? 1);
