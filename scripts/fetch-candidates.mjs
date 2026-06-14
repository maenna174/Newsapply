#!/usr/bin/env node

import { createHash } from 'node:crypto';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

const DEFAULT_SOURCE_FILE = 'data/rss-sources.json';
const DEFAULT_MAX_AGE_DAYS = 4;
const DEFAULT_LIMIT_PER_SOURCE = 12;
const DEFAULT_TOTAL_LIMIT = 50;
const DEFAULT_TIMEOUT_MS = 8000;
const USER_AGENT = 'DailyTenNewsBot/0.1 (+https://project-ys6f3-4kgmdyl0q-bleedwolf-s-projects.vercel.app; contact: editor@example.com)';

function usage() {
  console.log(`Usage:
  node scripts/fetch-candidates.mjs
  node scripts/fetch-candidates.mjs --date 2026-06-02 --out data/candidates.2026-06-02.json

Options:
  --sources <file>          RSS source config. Default: ${DEFAULT_SOURCE_FILE}
  --date <YYYY-MM-DD>       Edition date. Default: today in Asia/Shanghai
  --out <file>              Output candidate JSON. Default: data/candidates.<date>.json
  --limit <n>               Max total candidates. Default: ${DEFAULT_TOTAL_LIMIT}. Use 0 for no limit
  --limit-per-source <n>    Max items per source. Default: ${DEFAULT_LIMIT_PER_SOURCE}
  --max-per-source <n>      Max final candidates from the same source. Default: 0 means unlimited
  --max-age-days <n>        Keep recent items only. Default: ${DEFAULT_MAX_AGE_DAYS}
  --timeout-ms <n>          Network timeout per source. Default: ${DEFAULT_TIMEOUT_MS}
`);
}

function getArg(name, fallback = null) {
  const index = process.argv.indexOf(name);
  if (index === -1) {
    return fallback;
  }
  return process.argv[index + 1] ?? fallback;
}

function chinaDate(now = new Date()) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Shanghai',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  }).format(now);
}

function decodeEntities(value) {
  const named = {
    amp: '&',
    lt: '<',
    gt: '>',
    quot: '"',
    apos: "'",
    nbsp: ' '
  };
  return String(value ?? '')
    .replace(/<!\[CDATA\[(.*?)\]\]>/gs, '$1')
    .replace(/&#(\d+);/g, (_, code) => String.fromCharCode(Number(code)))
    .replace(/&#x([0-9a-f]+);/gi, (_, code) => String.fromCharCode(parseInt(code, 16)))
    .replace(/&([a-z]+);/gi, (_, name) => named[name] ?? `&${name};`);
}

function stripHtml(value) {
  return decodeEntities(value)
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function firstTag(xml, tag) {
  const match = xml.match(new RegExp(`<${tag}(?:\\s[^>]*)?>([\\s\\S]*?)<\\/${tag}>`, 'i'));
  return match ? decodeEntities(match[1]).trim() : '';
}

function firstLink(block) {
  const attr = block.match(/<link[^>]+href=["']([^"']+)["'][^>]*>/i);
  if (attr) {
    return decodeEntities(attr[1]).trim();
  }
  return firstTag(block, 'link');
}

function parseItems(xml, source) {
  const blocks = [
    ...xml.matchAll(/<item(?:\s[^>]*)?>([\s\S]*?)<\/item>/gi)
  ].map((match) => match[1]);

  if (blocks.length === 0) {
    blocks.push(...[...xml.matchAll(/<entry(?:\s[^>]*)?>([\s\S]*?)<\/entry>/gi)].map((match) => match[1]));
  }

  return blocks.map((block) => {
    const title = stripHtml(firstTag(block, 'title'));
    const rawSummary = firstTag(block, 'description') ||
      firstTag(block, 'summary') ||
      firstTag(block, 'content:encoded') ||
      firstTag(block, 'content');
    const summary = stripHtml(rawSummary).slice(0, 260);
    const url = firstLink(block) || firstTag(block, 'guid');
    const publishedRaw = firstTag(block, 'pubDate') ||
      firstTag(block, 'published') ||
      firstTag(block, 'updated') ||
      firstTag(block, 'dc:date');
    const publishedAt = parseDate(publishedRaw);

    return {
      id: stableId(source.name, title, url),
      title,
      summary: summary || title,
      url,
      category: source.category,
      topicKey: makeTopicKey(title),
      publishedAt,
      source: {
        name: source.name,
        homepageUrl: source.homepageUrl,
        feedUrl: source.feedUrl,
        crawlType: source.crawlType ?? 'rss',
        reliabilityNote: source.reliabilityNote ?? '',
        licenseNote: source.licenseNote ?? ''
      },
      selectionHint: selectionHint(source.category, source.name),
      priority: Number(source.priority ?? 50)
    };
  }).filter((item) => item.title && item.url && item.publishedAt && matchesSourceKeywords(item, source));
}

function matchesSourceKeywords(item, source) {
  const keywords = sourceKeywords(source);
  if (keywords.length === 0) {
    return true;
  }
  const text = `${item.title}\n${item.summary}`.toLowerCase();
  return keywords.some((keyword) => text.includes(String(keyword).toLowerCase()));
}

function sourceKeywords(source) {
  const keywords = Array.isArray(source.includeKeywords) ? [...source.includeKeywords] : [];
  if (source.keywordPreset === 'ai') {
    keywords.push(
      'ai',
      'artificial intelligence',
      '人工智能',
      '大模型',
      '生成式',
      '机器学习',
      'openai',
      'anthropic',
      'deepseek',
      'mistral',
      'gemini',
      'claude',
      'llm',
      'large language model',
      'agent',
      'agents',
      'chatbot',
      'model',
      'neural',
      'nvidia',
      'gpu',
      'robot'
    );
  }
  return Array.from(new Set(keywords));
}

function parseDate(value) {
  const time = Date.parse(stripHtml(value));
  if (Number.isNaN(time)) {
    return '';
  }
  return new Date(time).toISOString();
}

function makeTopicKey(title) {
  const text = stripHtml(title).toLowerCase();
  const tokens = text.match(/[\p{Script=Han}a-z0-9]+/gu) ?? [];
  return tokens.slice(0, 6).join('-').slice(0, 80) || 'news';
}

function stableId(...parts) {
  return createHash('sha1').update(parts.filter(Boolean).join('\n')).digest('hex').slice(0, 16);
}

function selectionHint(category, sourceName) {
  const hints = {
    domestic: '涉及国内公共事务，影响范围较广，适合进入每日公共简报。',
    international: '补充国际公共议题，避免每日版本只覆盖单一区域。',
    finance: '财经信息影响就业、物价或消费预期，具备公共参考价值。',
    technology: '科技或科学议题用于平衡每日信息结构，拓宽公共视野。',
    health: '健康议题与公众日常生活直接相关，来源需要可靠。',
    education: '教育或就业信息具备明确公共提醒价值。',
    society: '社会民生议题覆盖面广，补充公共生活维度。',
    sports: '体育内容用于降低每日版本的信息疲劳，保留轻量公共话题。',
    perspective: '长期议题不应被当天热点完全挤出。'
  };
  return `${hints[category] ?? '具备公共信息价值。'} 来源：${sourceName}。`;
}

async function fetchSource(source, limitPerSource, timeoutMs) {
  const response = await fetch(source.feedUrl, {
    signal: AbortSignal.timeout(timeoutMs),
    headers: {
      Accept: 'application/rss+xml, application/atom+xml, application/xml, text/xml, */*',
      'User-Agent': USER_AGENT
    }
  });

  if (!response.ok) {
    throw new Error(`${source.name}: HTTP ${response.status}`);
  }

  const xml = await response.text();
  return parseItems(xml, source).slice(0, limitPerSource);
}

function dedupe(items) {
  const seen = new Set();
  const result = [];
  for (const item of items) {
    const key = item.url.replace(/[?#].*$/, '');
    if (seen.has(key)) {
      continue;
    }
    seen.add(key);
    result.push(item);
  }
  return result;
}

function withinMaxAge(item, maxAgeDays) {
  const published = Date.parse(item.publishedAt);
  if (Number.isNaN(published)) {
    return false;
  }
  return Date.now() - published <= maxAgeDays * 24 * 60 * 60 * 1000;
}

async function main() {
  if (process.argv.includes('--help') || process.argv.includes('-h')) {
    usage();
    return;
  }

  const date = getArg('--date', chinaDate());
  const sourceFile = resolve(process.cwd(), getArg('--sources', DEFAULT_SOURCE_FILE));
  const outFile = resolve(process.cwd(), getArg('--out', `data/candidates.${date}.json`));
  const limitPerSource = Number(getArg('--limit-per-source', DEFAULT_LIMIT_PER_SOURCE));
  const maxPerSource = Number(getArg('--max-per-source', 0));
  const totalLimit = Number(getArg('--limit', DEFAULT_TOTAL_LIMIT));
  const maxAgeDays = Number(getArg('--max-age-days', DEFAULT_MAX_AGE_DAYS));
  const timeoutMs = Number(getArg('--timeout-ms', DEFAULT_TIMEOUT_MS));
  const sources = JSON.parse(readFileSync(sourceFile, 'utf8')).filter((source) => source.enabled !== false);

  const results = [];
  const errors = [];

  for (const source of sources) {
    try {
      const items = await fetchSource(source, limitPerSource, timeoutMs);
      results.push(...items);
      console.log(`${source.name}: ${items.length}`);
    } catch (error) {
      errors.push(error instanceof Error ? error.message : String(error));
      console.error(`Failed ${source.name}: ${errors[errors.length - 1]}`);
    }
  }

  const candidates = limitSourceCounts(dedupe(results)
    .filter((item) => withinMaxAge(item, maxAgeDays))
    .sort((a, b) => {
      const priority = b.priority - a.priority;
      if (priority !== 0) {
        return priority;
      }
      return Date.parse(b.publishedAt) - Date.parse(a.publishedAt);
    }), maxPerSource)
    .slice(0, totalLimit > 0 ? totalLimit : undefined)
    .map((item, index) => ({
      candidateId: index + 1,
      ...item
    }));

  const payload = {
    generatedAt: new Date().toISOString(),
    date,
    sourceFile: sourceFile.replace(`${process.cwd()}/`, ''),
    rules: {
      personalized: false,
      note: '候选池按公共来源优先级和发布时间整理，不使用用户画像、点击、停留、收藏或搜索历史。'
    },
    errors,
    candidates
  };

  mkdirSync(dirname(outFile), { recursive: true });
  writeFileSync(outFile, `${JSON.stringify(payload, null, 2)}\n`);
  console.log(`Wrote ${candidates.length} candidates to ${outFile}`);
}

function limitSourceCounts(items, maxPerSource) {
  if (!Number.isFinite(maxPerSource) || maxPerSource <= 0) {
    return items;
  }
  const counts = new Map();
  const result = [];
  for (const item of items) {
    const sourceName = item.source?.name || 'unknown';
    const count = counts.get(sourceName) || 0;
    if (count >= maxPerSource) {
      continue;
    }
    counts.set(sourceName, count + 1);
    result.push(item);
  }
  return result;
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
