import { createHash } from 'node:crypto';
import http from 'node:http';
import { Pool } from 'pg';

const PORT = Number(process.env.PORT || 3000);
const DATABASE_URL = process.env.DATABASE_URL || 'postgresql://dailyten:dailyten@127.0.0.1:5432/dailyten';
const ADMIN_TOKEN = process.env.DAILYTEN_ADMIN_TOKEN || process.env.ADMIN_TOKEN || '';
const AI_API_URL = process.env.AI_API_URL || 'https://api.deepseek.com/chat/completions';
const AI_MODEL = process.env.AI_MODEL || 'deepseek-v4-flash';
const AI_API_KEY = process.env.AI_API_KEY || '';
const DEFAULT_STATEMENT = '本期新闻由 AI 按公共重要性、来源多样性和主题配额生成初稿，并经人工审核后发布；不基于个人阅读行为排序。';

const pool = new Pool({ connectionString: DATABASE_URL, max: 6 });
const allowedCategories = new Set(['domestic', 'international', 'finance', 'technology', 'health', 'education', 'society', 'sports', 'perspective']);
const allowedStatuses = new Set(['draft', 'published']);

function send(res, status, body, headers = {}) {
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, content-type, accept',
    'Access-Control-Allow-Methods': 'GET, POST, PATCH, OPTIONS',
    ...headers
  });
  res.end(JSON.stringify(body));
}

function normalizeText(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function assertString(errors, value, path, minLength = 1) {
  if (typeof value !== 'string' || value.trim().length < minLength) {
    errors.push(`${path} must be a string with at least ${minLength} character(s)`);
  }
}

function assertUrl(errors, value, path) {
  assertString(errors, value, path);
  if (typeof value !== 'string') return;
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
  assertString(errors, value, path);
  if (typeof value === 'string' && Number.isNaN(Date.parse(value))) {
    errors.push(`${path} must be a valid date/time`);
  }
}

function contentHash(article) {
  return createHash('sha256').update([
    article.title,
    article.summary,
    article.url,
    article.publishedAt
  ].map(normalizeText).join('\n')).digest('hex');
}

async function readJson(req) {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  const text = Buffer.concat(chunks).toString('utf8');
  return text ? JSON.parse(text) : {};
}

function checkAuth(req) {
  return Boolean(ADMIN_TOKEN) && req.headers.authorization === `Bearer ${ADMIN_TOKEN}`;
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
    const path = `items[${index}]`;
    const article = item?.article;
    if (!Number.isInteger(item?.position) || item.position < 1 || item.position > 10) {
      errors.push(`${path}.position must be an integer between 1 and 10`);
    } else if (positions.has(item.position)) {
      errors.push(`${path}.position duplicates ${item.position}`);
    } else {
      positions.add(item.position);
    }
    assertString(errors, item?.selectionReason, `${path}.selectionReason`, 8);
    if (!article || typeof article !== 'object') {
      errors.push(`${path}.article must be an object`);
      return;
    }
    assertString(errors, article.title, `${path}.article.title`, 6);
    assertString(errors, article.summary, `${path}.article.summary`, 20);
    assertUrl(errors, article.url, `${path}.article.url`);
    assertDateTime(errors, article.publishedAt, `${path}.article.publishedAt`);
    assertString(errors, article.category, `${path}.article.category`);
    if (typeof article.category === 'string' && !allowedCategories.has(article.category)) {
      errors.push(`${path}.article.category is not allowed`);
    }
    if (typeof article.url === 'string') {
      if (urls.has(article.url)) errors.push(`${path}.article.url duplicates ${article.url}`);
      urls.add(article.url);
    }
    const source = article.source;
    if (!source || typeof source !== 'object') {
      errors.push(`${path}.article.source must be an object`);
      return;
    }
    assertString(errors, source.name, `${path}.article.source.name`, 2);
    assertUrl(errors, source.homepageUrl, `${path}.article.source.homepageUrl`);
  });
  return errors;
}

async function getToday(url) {
  const region = url.searchParams.get('region') || 'cn';
  const language = url.searchParams.get('language') || 'zh-CN';
  const date = url.searchParams.get('date');
  const params = [region, language];
  let where = 'region = $1 and language = $2 and status = $3';
  params.push('published');
  if (date) {
    params.push(date);
    where += ` and edition_date = $${params.length}`;
  }
  const editionResult = await pool.query(
    `select id, edition_date, region, language, published_at, statement
     from daily_editions
     where ${where}
     order by edition_date desc
     limit 1`,
    params
  );
  const edition = editionResult.rows[0];
  if (!edition) return { status: 404, body: { error: 'edition_not_found' } };
  const itemsResult = await pool.query(
    `select dei.position, dei.selection_reason,
            a.id, a.title, a.summary, a.url, a.category, a.published_at,
            s.name as source
     from daily_edition_items dei
     join articles a on a.id = dei.article_id
     join sources s on s.id = a.source_id
     where dei.edition_id = $1
     order by dei.position asc`,
    [edition.id]
  );
  return {
    status: 200,
    body: {
      edition: {
        date: edition.edition_date?.toISOString?.().slice(0, 10) || String(edition.edition_date),
        region: edition.region,
        language: edition.language,
        publishedAt: edition.published_at,
        statement: edition.statement
      },
      items: itemsResult.rows.map((row) => ({
        position: row.position,
        selectionReason: row.selection_reason,
        article: {
          id: row.id,
          title: row.title,
          summary: row.summary,
          source: row.source,
          category: row.category,
          publishedAt: row.published_at,
          url: row.url
        }
      }))
    }
  };
}

async function upsertEdition(payload) {
  const client = await pool.connect();
  try {
    await client.query('begin');
    const edition = payload.edition;
    const status = edition.status || 'published';
    const editionResult = await client.query(
      `insert into daily_editions (edition_date, region, language, status, statement, published_at, updated_at)
       values ($1, $2, $3, 'draft', $4, null, now())
       on conflict (edition_date, region, language)
       do update set status = 'draft', statement = excluded.statement, published_at = null, updated_at = now()
       returning id`,
      [edition.date, edition.region, edition.language, normalizeText(edition.statement)]
    );
    const editionId = editionResult.rows[0].id;
    await client.query('delete from daily_edition_items where edition_id = $1', [editionId]);
    for (const item of [...payload.items].sort((a, b) => a.position - b.position)) {
      const source = item.article.source;
      const sourceResult = await client.query(
        `insert into sources (name, homepage_url, feed_url, crawl_url, crawl_type, reliability_note, license_note, enabled)
         values ($1, $2, $3, $4, $5, $6, $7, true)
         on conflict (name)
         do update set homepage_url = excluded.homepage_url, feed_url = excluded.feed_url, crawl_url = excluded.crawl_url,
                       crawl_type = excluded.crawl_type, reliability_note = excluded.reliability_note, license_note = excluded.license_note
         returning id`,
        [
          normalizeText(source.name),
          normalizeText(source.homepageUrl),
          normalizeText(source.feedUrl) || null,
          normalizeText(source.crawlUrl) || null,
          normalizeText(source.crawlType) || 'manual',
          normalizeText(source.reliabilityNote) || null,
          normalizeText(source.licenseNote) || null
        ]
      );
      const article = item.article;
      const articleResult = await client.query(
        `insert into articles (source_id, title, summary, url, canonical_url, category, topic_key, published_at, content_hash, status)
         values ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'published')
         on conflict (url)
         do update set source_id = excluded.source_id, title = excluded.title, summary = excluded.summary,
                       canonical_url = excluded.canonical_url, category = excluded.category, topic_key = excluded.topic_key,
                       published_at = excluded.published_at, content_hash = excluded.content_hash, status = 'published'
         returning id`,
        [
          sourceResult.rows[0].id,
          normalizeText(article.title),
          normalizeText(article.summary),
          normalizeText(article.url),
          normalizeText(article.canonicalUrl) || null,
          normalizeText(article.category),
          normalizeText(article.topicKey) || null,
          new Date(normalizeText(article.publishedAt)).toISOString(),
          contentHash(article)
        ]
      );
      await client.query(
        `insert into daily_edition_items (edition_id, article_id, position, selection_reason)
         values ($1, $2, $3, $4)`,
        [editionId, articleResult.rows[0].id, item.position, normalizeText(item.selectionReason)]
      );
    }
    const finalResult = await client.query(
      `update daily_editions
       set status = $2, published_at = case when $2 = 'published' then coalesce($3::timestamptz, now()) else null end, updated_at = now()
       where id = $1
       returning id, edition_date, region, language, status, published_at, updated_at`,
      [editionId, status, edition.publishedAt || null]
    );
    await client.query('commit');
    return finalResult.rows[0];
  } catch (error) {
    await client.query('rollback');
    throw error;
  } finally {
    client.release();
  }
}

async function listEditions(url) {
  const limit = Math.min(Number(url.searchParams.get('limit') || 20), 50);
  const result = await pool.query(
    `select id, edition_date, region, language, status, published_at, updated_at, statement
     from daily_editions
     order by edition_date desc
     limit $1`,
    [limit]
  );
  return { editions: result.rows };
}

async function updateEditionStatus(body) {
  const date = normalizeText(body.date);
  const status = normalizeText(body.status) || 'published';
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || !allowedStatuses.has(status)) {
    return { status: 422, body: { error: 'validation_failed' } };
  }
  const result = await pool.query(
    `update daily_editions
     set status = $4, published_at = case when $4 = 'published' then now() else null end, updated_at = now()
     where edition_date = $1 and region = $2 and language = $3
     returning id, edition_date, region, language, status, published_at, updated_at`,
    [date, body.region || 'cn', body.language || 'zh-CN', status]
  );
  if (!result.rows[0]) return { status: 404, body: { error: 'edition_not_found' } };
  return { status: 200, body: { ok: true, edition: result.rows[0] } };
}

async function setting(key, fallback = '') {
  const result = await pool.query('select value from app_settings where setting_key = $1', [key]);
  return normalizeText(result.rows[0]?.value || fallback);
}

function normalizeAiUrl(value) {
  let normalized = normalizeText(value || AI_API_URL).replace(/\/+$/, '');
  if (!normalized) return 'https://api.deepseek.com/chat/completions';
  try {
    const url = new URL(normalized);
    if (url.hostname === 'api.deepseek.com' && url.pathname === '/v1') normalized = url.origin;
  } catch (_) {}
  return normalized.endsWith('/chat/completions') ? normalized : `${normalized}/chat/completions`;
}

async function aiConfig() {
  const apiKey = await setting('ai_api_key', AI_API_KEY);
  const apiUrl = normalizeAiUrl(await setting('ai_api_url', AI_API_URL));
  const model = await setting('ai_model', AI_MODEL);
  return {
    provider: apiUrl.includes('deepseek') ? 'deepseek' : 'openai-compatible',
    apiUrl,
    model,
    hasApiKey: Boolean(apiKey),
    keyPreview: apiKey ? `${apiKey.slice(0, 4)}...${apiKey.slice(-4)}` : null
  };
}

async function saveAiConfig(body) {
  const entries = [
    ['ai_api_url', normalizeAiUrl(body.apiUrl)],
    ['ai_model', normalizeText(body.model || AI_MODEL)]
  ];
  if (normalizeText(body.apiKey)) entries.push(['ai_api_key', normalizeText(body.apiKey)]);
  for (const [key, value] of entries) {
    await pool.query(
      `insert into app_settings (setting_key, value, is_secret, updated_at)
       values ($1, $2::jsonb, $3, now())
       on conflict (setting_key)
       do update set value = excluded.value, is_secret = excluded.is_secret, updated_at = now()`,
      [key, JSON.stringify(value), key === 'ai_api_key']
    );
  }
  return aiConfig();
}

async function callAiDraft(candidatePayload) {
  const apiKey = await setting('ai_api_key', AI_API_KEY);
  const apiUrl = normalizeAiUrl(await setting('ai_api_url', AI_API_URL));
  const model = await setting('ai_model', AI_MODEL);
  if (!apiKey) {
    const error = new Error('missing_ai_api_key');
    error.status = 503;
    throw error;
  }
  const candidates = (candidatePayload.candidates || []).slice(0, 120).map((candidate) => ({
    candidateId: candidate.candidateId,
    title: candidate.title,
    summary: candidate.summary,
    url: candidate.url,
    category: candidate.category,
    topicKey: candidate.topicKey,
    publishedAt: candidate.publishedAt,
    source: candidate.source
  }));
  const response = await fetch(apiUrl, {
    method: 'POST',
    headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model,
      messages: [
        {
          role: 'system',
          content: '你是“今日十条”的公共新闻编辑助理。只从候选新闻中选择 10 条，不使用任何用户画像，不编造新闻。输出 JSON：{"picks":[{"candidateId":1,"selectionReason":"...","summaryRewrite":"..."}],"reviewNotes":[]}'
        },
        { role: 'user', content: JSON.stringify({ editionDate: candidatePayload.date, rules: candidatePayload.rules, candidates }) }
      ],
      response_format: { type: 'json_object' },
      temperature: 0.2,
      max_tokens: 4000,
      stream: false,
      thinking: { type: 'disabled' }
    })
  });
  if (!response.ok) throw new Error(`AI API ${response.status}: ${await response.text()}`);
  const data = await response.json();
  return JSON.parse(data.choices?.[0]?.message?.content || '{}');
}

function candidateToItem(candidate, position, pick = {}) {
  return {
    position,
    selectionReason: normalizeText(pick.selectionReason) || candidate.selectionHint || '按公共重要性、来源多样性和主题配额入选。',
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
  };
}

async function aiDraft(payload) {
  if (!Array.isArray(payload.candidates) || payload.candidates.length < 10) {
    return { status: 422, body: { error: 'validation_failed', errors: ['candidates must contain at least 10 articles'] } };
  }
  const result = await callAiDraft(payload);
  const byId = new Map(payload.candidates.map((candidate) => [Number(candidate.candidateId), candidate]));
  const used = new Set();
  const items = [];
  for (const pick of Array.isArray(result.picks) ? result.picks : []) {
    const id = Number(pick.candidateId);
    const candidate = byId.get(id);
    if (!candidate || used.has(id) || items.length >= 10) continue;
    used.add(id);
    items.push(candidateToItem(candidate, items.length + 1, pick));
  }
  for (const candidate of payload.candidates) {
    if (items.length >= 10) break;
    const id = Number(candidate.candidateId);
    if (used.has(id)) continue;
    used.add(id);
    items.push(candidateToItem(candidate, items.length + 1));
  }
  const draft = {
    edition: { date: payload.date, region: 'cn', language: 'zh-CN', status: 'draft', publishedAt: null, statement: DEFAULT_STATEMENT },
    items,
    aiReviewNotes: Array.isArray(result.reviewNotes) ? result.reviewNotes : [],
    generatedBy: { type: 'ai-editor-assistant', generatedAt: new Date().toISOString(), personalized: false }
  };
  const errors = validateEdition(draft);
  if (errors.length > 0) return { status: 422, body: { error: 'ai_draft_validation_failed', errors, draft } };
  return { status: 200, body: { ok: true, draft, aiReviewNotes: draft.aiReviewNotes } };
}

async function route(req, res) {
  const url = new URL(req.url, `http://${req.headers.host}`);
  if (req.method === 'OPTIONS') return send(res, 200, { ok: true });
  if (req.method === 'GET' && url.pathname === '/health') return send(res, 200, { ok: true });
  if (req.method === 'GET' && (url.pathname === '/functions/v1/editions/today' || url.pathname === '/editions/today')) {
    const result = await getToday(url);
    return send(res, result.status, result.body, result.status === 200 ? { 'Cache-Control': 'public, max-age=60' } : {});
  }
  if (!url.pathname.startsWith('/functions/v1/admin') && !url.pathname.startsWith('/admin')) {
    return send(res, 404, { error: 'not_found' });
  }
  if (!checkAuth(req)) return send(res, 401, { error: 'unauthorized' });
  const adminPath = url.pathname.replace('/functions/v1/admin', '').replace('/admin', '') || '/health';
  if (req.method === 'GET' && adminPath === '/health') return send(res, 200, { ok: true });
  if (req.method === 'GET' && adminPath === '/editions') return send(res, 200, await listEditions(url));
  if (req.method === 'PATCH' && adminPath === '/editions/status') {
    const result = await updateEditionStatus(await readJson(req));
    return send(res, result.status, result.body);
  }
  if (req.method === 'POST' && (adminPath === '/editions' || adminPath === '/editions/publish')) {
    const payload = await readJson(req);
    const errors = validateEdition(payload);
    if (errors.length > 0) return send(res, 422, { error: 'validation_failed', errors });
    if (url.searchParams.get('dryRun') === 'true') return send(res, 200, { ok: true, dryRun: true, items: payload.items.length });
    return send(res, 200, { ok: true, edition: await upsertEdition(payload) });
  }
  if (req.method === 'GET' && adminPath === '/ai/config') return send(res, 200, { ok: true, config: await aiConfig() });
  if (req.method === 'POST' && adminPath === '/ai/config') return send(res, 200, { ok: true, config: await saveAiConfig(await readJson(req)) });
  if (req.method === 'POST' && adminPath === '/ai/test') return send(res, 200, { ok: true, config: await aiConfig() });
  if (req.method === 'POST' && adminPath === '/ai/draft') {
    const result = await aiDraft(await readJson(req));
    return send(res, result.status, result.body);
  }
  return send(res, 404, { error: 'not_found' });
}

const server = http.createServer((req, res) => {
  route(req, res).catch((error) => {
    send(res, error.status || 500, { error: 'internal_error', message: error.message || String(error) });
  });
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`dailyten server listening on 127.0.0.1:${PORT}`);
});
