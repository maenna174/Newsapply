#!/usr/bin/env node

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const DEFAULT_API_URL = 'https://api.deepseek.com/chat/completions';
const DEFAULT_MODEL = 'deepseek-v4-flash';
const DEFAULT_STATEMENT = '本期新闻由 AI 按公共重要性、来源多样性和主题配额生成初稿，并经人工审核后发布；不基于个人阅读行为排序。';

function usage() {
  console.log(`Usage:
  node scripts/ai-draft-edition.mjs data/candidates.2026-06-03.json
  node scripts/ai-draft-edition.mjs data/candidates.2026-06-03.json --out data/daily-edition.2026-06-03.ai-draft.json
  node scripts/ai-draft-edition.mjs data/candidates.2026-06-03.json --mock

Environment:
  AI_API_KEY       required unless --mock
  AI_API_URL       optional, default: ${DEFAULT_API_URL}
  AI_MODEL         optional, default: ${DEFAULT_MODEL}
`);
}

function getArg(name, fallback = null) {
  const index = process.argv.indexOf(name);
  if (index === -1) {
    return fallback;
  }
  return process.argv[index + 1] ?? fallback;
}

function loadDotEnv(filePath) {
  try {
    const text = readFileSync(filePath, 'utf8');
    for (const line of text.split(/\r?\n/)) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('#') || !trimmed.includes('=')) {
        continue;
      }
      const index = trimmed.indexOf('=');
      const key = trimmed.slice(0, index).trim();
      const value = trimmed.slice(index + 1).trim().replace(/^['"]|['"]$/g, '');
      if (key && process.env[key] === undefined) {
        process.env[key] = value;
      }
    }
  } catch (_) {
    // Local .env is optional.
  }
}

function chinaDateTime() {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Shanghai',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false
  }).formatToParts(new Date()).reduce((acc, part) => {
    acc[part.type] = part.value;
    return acc;
  }, {});
  return `${parts.year}-${parts.month}-${parts.day}T${parts.hour}:${parts.minute}:${parts.second}+08:00`;
}

function normalizeText(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function compactCandidate(candidate) {
  return {
    candidateId: candidate.candidateId,
    title: candidate.title,
    summary: candidate.summary,
    url: candidate.url,
    category: candidate.category,
    topicKey: candidate.topicKey,
    publishedAt: candidate.publishedAt,
    source: {
      name: candidate.source?.name,
      homepageUrl: candidate.source?.homepageUrl,
      feedUrl: candidate.source?.feedUrl,
      crawlType: candidate.source?.crawlType,
      reliabilityNote: candidate.source?.reliabilityNote,
      licenseNote: candidate.source?.licenseNote
    }
  };
}

function systemPrompt() {
  return `你是“今日十条”的公共新闻编辑助理。

目标：从候选新闻中生成 10 条每日公共新闻草稿。

硬性原则：
- 不使用任何用户画像、兴趣、点击、停留、收藏、搜索历史。
- 不做个性化推荐，只做公共编辑筛选。
- 只从候选新闻中选择，不编造新闻，不改写 URL，不新增来源。
- 同一来源最多 3 条，同一主题最多 2 条。
- 尽量覆盖国内/国际/财经/科技/健康/教育/社会/体育/长期议题。
- 避免标题党、八卦化、重复事件、摘要过短或来源不清的条目。
- 输出必须是 JSON，不要 Markdown，不要解释文字。

选择维度：
1. 公共影响范围
2. 来源可靠性
3. 主题多样性
4. 时效性
5. 长期议题价值
6. 重复事件去重

输出 JSON 格式：
{
  "picks": [
    {
      "candidateId": 1,
      "selectionReason": "为什么这条具备公共信息价值",
      "summaryRewrite": "中性、事实导向、60 到 180 字中文摘要；英文新闻也用中文摘要"
    }
  ],
  "reviewNotes": ["需要人工注意的事项"]
}`;
}

function userPrompt(payload) {
  const candidates = (payload.candidates ?? [])
    .slice(0, 120)
    .map(compactCandidate);

  return JSON.stringify({
    editionDate: payload.date,
    rules: payload.rules,
    candidates
  });
}

async function callAi(payload) {
  const apiKey = process.env.AI_API_KEY;
  if (!apiKey) {
    throw new Error('Missing AI_API_KEY. Add it to .env or run with --mock.');
  }

  const apiUrl = process.env.AI_API_URL || DEFAULT_API_URL;
  const model = process.env.AI_MODEL || DEFAULT_MODEL;
  const response = await fetch(apiUrl, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      model,
      messages: [
        { role: 'system', content: systemPrompt() },
        { role: 'user', content: userPrompt(payload) }
      ],
      response_format: { type: 'json_object' },
      temperature: 0.2,
      thinking: { type: 'disabled' }
    })
  });

  if (!response.ok) {
    throw new Error(`AI API ${response.status}: ${await response.text()}`);
  }

  const data = await response.json();
  const content = data.choices?.[0]?.message?.content;
  if (!content) {
    throw new Error('AI API returned empty content');
  }
  return JSON.parse(content);
}

function mockAi(payload) {
  const seenSources = new Map();
  const seenTopics = new Map();
  const picks = [];
  const candidates = payload.candidates ?? [];

  for (const candidate of candidates) {
    if (picks.length >= 10) {
      break;
    }
    const source = candidate.source?.name ?? '未知来源';
    const topic = candidate.topicKey ?? candidate.title;
    const sourceCount = seenSources.get(source) ?? 0;
    const topicCount = seenTopics.get(topic) ?? 0;
    if (sourceCount >= 3 || topicCount >= 2) {
      continue;
    }
    picks.push({
      candidateId: candidate.candidateId,
      selectionReason: candidate.selectionHint || '按公共重要性、来源多样性和主题配额入选。',
      summaryRewrite: candidate.summary
    });
    seenSources.set(source, sourceCount + 1);
    seenTopics.set(topic, topicCount + 1);
  }

  return {
    picks,
    reviewNotes: ['mock 模式只用于本地链路测试，正式请使用 AI_API_KEY。']
  };
}

function buildEdition(payload, aiResult) {
  const candidateById = new Map((payload.candidates ?? []).map((candidate) => [Number(candidate.candidateId), candidate]));
  const items = [];
  const used = new Set();
  const reviewNotes = [...(aiResult.reviewNotes ?? [])];

  for (const pick of aiResult.picks ?? []) {
    const candidateId = Number(pick.candidateId);
    const candidate = candidateById.get(candidateId);
    if (!candidate || used.has(candidateId)) {
      continue;
    }
    used.add(candidateId);
    items.push({
      position: items.length + 1,
      selectionReason: normalizeText(pick.selectionReason) || '按公共重要性、来源多样性和主题配额入选。',
      article: {
        title: normalizeText(candidate.title),
        summary: normalizeText(pick.summaryRewrite) || normalizeText(candidate.summary),
        url: normalizeText(candidate.url),
        category: normalizeText(candidate.category),
        topicKey: normalizeText(candidate.topicKey),
        publishedAt: normalizeText(candidate.publishedAt),
        source: {
          name: normalizeText(candidate.source?.name),
          homepageUrl: normalizeText(candidate.source?.homepageUrl),
          feedUrl: normalizeText(candidate.source?.feedUrl),
          crawlType: normalizeText(candidate.source?.crawlType) || 'rss',
          reliabilityNote: normalizeText(candidate.source?.reliabilityNote),
          licenseNote: normalizeText(candidate.source?.licenseNote)
        }
      }
    });
  }

  if (items.length < 10) {
    for (const candidate of payload.candidates ?? []) {
      if (items.length >= 10) {
        break;
      }
      const candidateId = Number(candidate.candidateId);
      if (used.has(candidateId)) {
        continue;
      }
      used.add(candidateId);
      items.push({
        position: items.length + 1,
        selectionReason: candidate.selectionHint || 'AI 返回不足 10 条，按候选池顺序补足，需人工复核。',
        article: {
          title: normalizeText(candidate.title),
          summary: normalizeText(candidate.summary),
          url: normalizeText(candidate.url),
          category: normalizeText(candidate.category),
          topicKey: normalizeText(candidate.topicKey),
          publishedAt: normalizeText(candidate.publishedAt),
          source: {
            name: normalizeText(candidate.source?.name),
            homepageUrl: normalizeText(candidate.source?.homepageUrl),
            feedUrl: normalizeText(candidate.source?.feedUrl),
            crawlType: normalizeText(candidate.source?.crawlType) || 'rss',
            reliabilityNote: normalizeText(candidate.source?.reliabilityNote),
            licenseNote: normalizeText(candidate.source?.licenseNote)
          }
        }
      });
    }
    reviewNotes.push('AI 返回不足 10 条，脚本已从候选池自动补足，请重点复核补足条目。');
  }

  if (items.length !== 10) {
    throw new Error(`AI selected ${items.length} valid items. Need exactly 10.`);
  }

  return {
    edition: {
      date: payload.date,
      region: 'cn',
      language: 'zh-CN',
      status: 'draft',
      publishedAt: null,
      statement: DEFAULT_STATEMENT
    },
    items,
    aiReviewNotes: reviewNotes,
    generatedBy: {
      type: 'ai-editor-assistant',
      model: process.env.AI_MODEL || DEFAULT_MODEL,
      generatedAt: chinaDateTime(),
      personalized: false
    }
  };
}

function runDryRun(filePath) {
  const result = spawnSync('node', ['scripts/publish-edition.mjs', filePath, '--dry-run'], {
    cwd: process.cwd(),
    encoding: 'utf8'
  });
  if (result.stdout) {
    process.stdout.write(result.stdout);
  }
  if (result.stderr) {
    process.stderr.write(result.stderr);
  }
  return result.status ?? 1;
}

async function main() {
  loadDotEnv(resolve(process.cwd(), '.env'));
  loadDotEnv(resolve(process.cwd(), '.env.local'));

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
  const outFile = resolve(process.cwd(), getArg('--out', `data/daily-edition.${payload.date}.ai-draft.json`));
  const aiResult = process.argv.includes('--mock')
    ? mockAi(payload)
    : await callAi(payload);
  const edition = buildEdition(payload, aiResult);

  mkdirSync(dirname(outFile), { recursive: true });
  writeFileSync(outFile, `${JSON.stringify(edition, null, 2)}\n`);
  console.log(`Wrote AI draft to ${outFile}`);
  console.log(`Review notes: ${(edition.aiReviewNotes ?? []).join(' | ') || 'none'}`);

  if (!process.argv.includes('--no-dry-run')) {
    const status = runDryRun(outFile);
    if (status !== 0) {
      process.exit(status);
    }
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
