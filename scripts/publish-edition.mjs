#!/usr/bin/env node

import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const allowedCategories = new Set([
  'domestic',
  'international',
  'finance',
  'technology',
  'health',
  'education',
  'society',
  'sports',
  'perspective'
]);

const allowedStatuses = new Set(['draft', 'published']);

function usage() {
  console.log(`Usage:
  node scripts/publish-edition.mjs <edition.json> --dry-run
  node scripts/publish-edition.mjs <edition.json> --publish

Environment for --publish:
  SUPABASE_URL
  DAILYTEN_SUPABASE_SECRET_KEY or SUPABASE_SERVICE_ROLE_KEY
`);
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

function assertString(errors, value, path, minLength = 1) {
  if (typeof value !== 'string' || value.trim().length < minLength) {
    errors.push(`${path} must be a string with at least ${minLength} character(s)`);
  }
}

function assertUrl(errors, value, path) {
  assertString(errors, value, path, 1);
  if (typeof value !== 'string') {
    return;
  }
  try {
    const url = new URL(value);
    if (url.protocol !== 'http:' && url.protocol !== 'https:') {
      errors.push(`${path} must use http or https`);
    }
  } catch (_) {
    errors.push(`${path} must be a valid URL`);
  }
}

function assertDateTime(errors, value, path) {
  assertString(errors, value, path, 1);
  if (typeof value === 'string' && Number.isNaN(Date.parse(value))) {
    errors.push(`${path} must be a valid date/time`);
  }
}

function normalizeText(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function contentHash(article) {
  const raw = [
    article.title,
    article.summary,
    article.url,
    article.publishedAt
  ].map(normalizeText).join('\n');
  return createHash('sha256').update(raw).digest('hex');
}

function validateEdition(payload) {
  const errors = [];
  const edition = payload?.edition;
  const items = payload?.items;

  if (!edition || typeof edition !== 'object') {
    errors.push('edition must be an object');
  } else {
    assertString(errors, edition.date, 'edition.date', 10);
    if (typeof edition.date === 'string' && !/^\d{4}-\d{2}-\d{2}$/.test(edition.date)) {
      errors.push('edition.date must use YYYY-MM-DD');
    }
    assertString(errors, edition.region, 'edition.region');
    assertString(errors, edition.language, 'edition.language');
    assertString(errors, edition.statement, 'edition.statement', 12);
    if (edition.status !== undefined && !allowedStatuses.has(edition.status)) {
      errors.push('edition.status must be draft or published');
    }
    if (edition.publishedAt !== undefined && edition.publishedAt !== null) {
      assertDateTime(errors, edition.publishedAt, 'edition.publishedAt');
    }
  }

  if (!Array.isArray(items)) {
    errors.push('items must be an array');
    return errors;
  }

  if (items.length !== 10) {
    errors.push('items must contain exactly 10 articles');
  }

  const positions = new Set();
  const urls = new Set();

  items.forEach((item, index) => {
    const itemPath = `items[${index}]`;
    const article = item?.article;
    if (!Number.isInteger(item?.position) || item.position < 1 || item.position > 10) {
      errors.push(`${itemPath}.position must be an integer between 1 and 10`);
    } else if (positions.has(item.position)) {
      errors.push(`${itemPath}.position duplicates ${item.position}`);
    } else {
      positions.add(item.position);
    }

    assertString(errors, item?.selectionReason, `${itemPath}.selectionReason`, 8);

    if (!article || typeof article !== 'object') {
      errors.push(`${itemPath}.article must be an object`);
      return;
    }

    assertString(errors, article.title, `${itemPath}.article.title`, 6);
    assertString(errors, article.summary, `${itemPath}.article.summary`, 20);
    assertUrl(errors, article.url, `${itemPath}.article.url`);
    assertDateTime(errors, article.publishedAt, `${itemPath}.article.publishedAt`);
    assertString(errors, article.category, `${itemPath}.article.category`);

    if (typeof article.category === 'string' && !allowedCategories.has(article.category)) {
      errors.push(`${itemPath}.article.category is not in the allowed category list`);
    }

    if (typeof article.url === 'string') {
      if (urls.has(article.url)) {
        errors.push(`${itemPath}.article.url duplicates ${article.url}`);
      }
      urls.add(article.url);
    }

    const source = article.source;
    if (!source || typeof source !== 'object') {
      errors.push(`${itemPath}.article.source must be an object`);
      return;
    }

    assertString(errors, source.name, `${itemPath}.article.source.name`, 2);
    assertUrl(errors, source.homepageUrl, `${itemPath}.article.source.homepageUrl`);
    if (source.feedUrl) {
      assertUrl(errors, source.feedUrl, `${itemPath}.article.source.feedUrl`);
    }
    if (source.crawlUrl) {
      assertUrl(errors, source.crawlUrl, `${itemPath}.article.source.crawlUrl`);
    }
  });

  for (let position = 1; position <= 10; position++) {
    if (!positions.has(position)) {
      errors.push(`items is missing position ${position}`);
    }
  }

  return errors;
}

function getArgs() {
  const args = process.argv.slice(2);
  const file = args.find((arg) => !arg.startsWith('-'));
  return {
    file,
    publish: args.includes('--publish'),
    dryRun: args.includes('--dry-run') || !args.includes('--publish')
  };
}

function restClient() {
  const supabaseUrl = process.env.SUPABASE_URL;
  const serviceKey = process.env.DAILYTEN_SUPABASE_SECRET_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!supabaseUrl || !serviceKey) {
    throw new Error('Missing SUPABASE_URL or service role key in environment');
  }

  async function request(path, options = {}) {
    const response = await fetch(`${supabaseUrl}/rest/v1/${path}`, {
      ...options,
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
        Accept: 'application/json',
        ...(options.body ? { 'Content-Type': 'application/json' } : {}),
        ...(options.prefer ? { Prefer: options.prefer } : {}),
        ...(options.headers ?? {})
      }
    });

    if (!response.ok) {
      const message = await response.text();
      throw new Error(`PostgREST ${response.status} ${path}: ${message}`);
    }

    if (response.status === 204) {
      return null;
    }

    const text = await response.text();
    return text ? JSON.parse(text) : null;
  }

  return { request };
}

async function upsertSource(client, source) {
  const name = normalizeText(source.name);
  const rows = await client.request(`sources?name=eq.${encodeURIComponent(name)}&select=id&limit=1`);
  const body = {
    name,
    homepage_url: normalizeText(source.homepageUrl),
    feed_url: normalizeText(source.feedUrl) || null,
    crawl_url: normalizeText(source.crawlUrl) || null,
    crawl_type: normalizeText(source.crawlType) || 'manual',
    reliability_note: normalizeText(source.reliabilityNote) || null,
    license_note: normalizeText(source.licenseNote) || null,
    enabled: true
  };

  if (rows.length > 0) {
    const updated = await client.request(
      `sources?id=eq.${rows[0].id}&select=id`,
      {
        method: 'PATCH',
        body: JSON.stringify(body),
        prefer: 'return=representation'
      }
    );
    return updated[0].id;
  }

  const inserted = await client.request(
    'sources?select=id',
    {
      method: 'POST',
      body: JSON.stringify(body),
      prefer: 'return=representation'
    }
  );
  return inserted[0].id;
}

async function upsertArticle(client, item, sourceId) {
  const article = item.article;
  const inserted = await client.request(
    'articles?on_conflict=url&select=id',
    {
      method: 'POST',
      body: JSON.stringify({
        source_id: sourceId,
        title: normalizeText(article.title),
        summary: normalizeText(article.summary),
        url: normalizeText(article.url),
        canonical_url: normalizeText(article.canonicalUrl) || null,
        category: normalizeText(article.category),
        topic_key: normalizeText(article.topicKey) || null,
        published_at: new Date(article.publishedAt).toISOString(),
        content_hash: contentHash(article),
        status: 'published'
      }),
      prefer: 'resolution=merge-duplicates,return=representation'
    }
  );
  return inserted[0].id;
}

async function upsertEdition(client, payload) {
  const edition = payload.edition;
  const status = edition.status ?? 'published';
  const draftRows = await client.request(
    'daily_editions?on_conflict=edition_date,region,language&select=id',
    {
      method: 'POST',
      body: JSON.stringify({
        edition_date: edition.date,
        region: edition.region,
        language: edition.language,
        status: 'draft',
        statement: normalizeText(edition.statement),
        published_at: null,
        updated_at: new Date().toISOString()
      }),
      prefer: 'resolution=merge-duplicates,return=representation'
    }
  );
  const editionId = draftRows[0].id;

  await client.request(`daily_edition_items?edition_id=eq.${editionId}`, {
    method: 'DELETE'
  });

  const sourceIdsByName = new Map();
  const articleRows = [];
  for (const item of [...payload.items].sort((a, b) => a.position - b.position)) {
    const sourceName = normalizeText(item.article.source.name);
    if (!sourceIdsByName.has(sourceName)) {
      sourceIdsByName.set(sourceName, await upsertSource(client, item.article.source));
    }
    const articleId = await upsertArticle(client, item, sourceIdsByName.get(sourceName));
    articleRows.push({
      edition_id: editionId,
      article_id: articleId,
      position: item.position,
      selection_reason: normalizeText(item.selectionReason)
    });
  }

  await client.request('daily_edition_items', {
    method: 'POST',
    body: JSON.stringify(articleRows),
    prefer: 'return=minimal'
  });

  const finalRows = await client.request(`daily_editions?id=eq.${editionId}&select=id,status,published_at`, {
    method: 'PATCH',
    body: JSON.stringify({
      status,
      published_at: status === 'published'
        ? (edition.publishedAt ? new Date(edition.publishedAt).toISOString() : new Date().toISOString())
        : null,
      updated_at: new Date().toISOString()
    }),
    prefer: 'return=representation'
  });

  return finalRows[0];
}

async function main() {
  loadDotEnv(resolve(process.cwd(), '.env'));
  loadDotEnv(resolve(process.cwd(), '.env.local'));

  const args = getArgs();
  if (!args.file || process.argv.includes('--help') || process.argv.includes('-h')) {
    usage();
    process.exit(args.file ? 0 : 1);
  }

  const filePath = resolve(process.cwd(), args.file);
  const payload = JSON.parse(readFileSync(filePath, 'utf8'));
  const errors = validateEdition(payload);

  if (errors.length > 0) {
    console.error(`Validation failed for ${filePath}:`);
    for (const error of errors) {
      console.error(`- ${error}`);
    }
    process.exit(1);
  }

  const sortedItems = [...payload.items].sort((a, b) => a.position - b.position);
  console.log(`Edition ${payload.edition.date} ${payload.edition.region}/${payload.edition.language}`);
  console.log(`Items: ${sortedItems.length}`);
  for (const item of sortedItems) {
    console.log(`${String(item.position).padStart(2, '0')}. [${item.article.category}] ${item.article.title}`);
  }

  if (args.dryRun) {
    console.log('Dry run complete. Add --publish to write to Supabase.');
    return;
  }

  const result = await upsertEdition(restClient(), payload);
  console.log(`Published edition id=${result.id} status=${result.status}`);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
