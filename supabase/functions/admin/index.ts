import { corsHeaders } from '../_shared/cors.ts';

type JsonRecord = Record<string, unknown>;

interface EditionPayload {
  edition?: {
    date?: string;
    region?: string;
    language?: string;
    status?: string;
    publishedAt?: string | null;
    statement?: string;
  };
  items?: Array<{
    position?: number;
    selectionReason?: string;
    article?: {
      title?: string;
      summary?: string;
      url?: string;
      canonicalUrl?: string | null;
      category?: string;
      topicKey?: string | null;
      publishedAt?: string;
      source?: {
        name?: string;
        homepageUrl?: string;
        feedUrl?: string | null;
        crawlUrl?: string | null;
        crawlType?: string;
        reliabilityNote?: string | null;
        licenseNote?: string | null;
      };
    };
  }>;
}

interface CandidatePayload {
  date?: string;
  rules?: unknown;
  candidates?: Array<{
    candidateId?: number | string;
    title?: string;
    summary?: string;
    url?: string;
    category?: string;
    topicKey?: string | null;
    publishedAt?: string;
    selectionHint?: string;
    source?: {
      name?: string;
      homepageUrl?: string;
      feedUrl?: string | null;
      crawlType?: string;
      reliabilityNote?: string | null;
      licenseNote?: string | null;
    };
  }>;
}

interface AiPick {
  candidateId?: number | string;
  selectionReason?: string;
  summaryRewrite?: string;
}

interface AiDraftResult {
  picks?: AiPick[];
  reviewNotes?: string[];
}

interface AiRuntimeConfig {
  apiKey: string;
  apiUrl: string;
  model: string;
  source: 'database' | 'env' | 'default';
  keyPreview: string | null;
  updatedAt: string | null;
  storageReady: boolean;
}

interface AppSettingRow {
  setting_key: string;
  value: unknown;
  updated_at?: string;
}

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ??
  Deno.env.get('DAILYTEN_SUPABASE_SECRET_KEY') ??
  '';
const adminToken = Deno.env.get('DAILYTEN_ADMIN_TOKEN') ??
  Deno.env.get('ADMIN_TOKEN') ??
  '';
const envAiApiKey = Deno.env.get('AI_API_KEY') ?? '';
const envAiApiUrl = Deno.env.get('AI_API_URL') ?? 'https://api.deepseek.com/chat/completions';
const envAiModel = Deno.env.get('AI_MODEL') ?? 'deepseek-v4-flash';
const defaultAiStatement = '本期新闻由 AI 按公共重要性、来源多样性和主题配额生成初稿，并经人工审核后发布；不基于个人阅读行为排序。';

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

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store'
    }
  });
}

function normalizeText(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function chinaDateTime(): string {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Shanghai',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false
  }).formatToParts(new Date()).reduce<Record<string, string>>((acc, part) => {
    acc[part.type] = part.value;
    return acc;
  }, {});
  return `${parts.year}-${parts.month}-${parts.day}T${parts.hour}:${parts.minute}:${parts.second}+08:00`;
}

function assertString(errors: string[], value: unknown, path: string, minLength = 1): void {
  if (typeof value !== 'string' || value.trim().length < minLength) {
    errors.push(`${path} must be a string with at least ${minLength} character(s)`);
  }
}

function assertUrl(errors: string[], value: unknown, path: string): void {
  assertString(errors, value, path);
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

function assertDateTime(errors: string[], value: unknown, path: string): void {
  assertString(errors, value, path);
  if (typeof value === 'string' && Number.isNaN(Date.parse(value))) {
    errors.push(`${path} must be a valid date/time`);
  }
}

function validateEdition(payload: EditionPayload): string[] {
  const errors: string[] = [];
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

  const positions = new Set<number>();
  const urls = new Set<string>();
  items.forEach((item, index) => {
    const itemPath = `items[${index}]`;
    const article = item?.article;

    if (!Number.isInteger(item?.position) || Number(item.position) < 1 || Number(item.position) > 10) {
      errors.push(`${itemPath}.position must be an integer between 1 and 10`);
    } else if (positions.has(Number(item.position))) {
      errors.push(`${itemPath}.position duplicates ${item.position}`);
    } else {
      positions.add(Number(item.position));
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
      errors.push(`${itemPath}.article.category is not allowed`);
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

function settingValue(row: AppSettingRow | undefined): string {
  return typeof row?.value === 'string' ? row.value.trim() : '';
}

function maskSecret(value: string): string | null {
  const normalized = normalizeText(value);
  if (!normalized) {
    return null;
  }
  return normalized.length <= 8
    ? '********'
    : `${normalized.slice(0, 4)}...${normalized.slice(-4)}`;
}

function normalizeAiApiUrl(value: string): string {
  let normalized = normalizeText(value || envAiApiUrl).replace(/\/+$/, '');
  if (!normalized) {
    return 'https://api.deepseek.com/chat/completions';
  }
  try {
    const url = new URL(normalized);
    if (url.hostname === 'api.deepseek.com' && url.pathname === '/v1') {
      normalized = `${url.origin}`;
    }
  } catch (_) {
    return normalized;
  }
  if (normalized.endsWith('/chat/completions')) {
    return normalized;
  }
  return `${normalized}/chat/completions`;
}

async function getAiRuntimeConfig(): Promise<AiRuntimeConfig> {
  try {
    const rows = await postgrest<AppSettingRow[]>(
      'app_settings?setting_key=in.(ai_api_key,ai_api_url,ai_model)&select=setting_key,value,updated_at'
    );
    const byKey = new Map(rows.map((row) => [row.setting_key, row]));
    const dbApiKey = settingValue(byKey.get('ai_api_key'));
    const dbApiUrl = settingValue(byKey.get('ai_api_url'));
    const dbModel = settingValue(byKey.get('ai_model'));
    const keyRow = byKey.get('ai_api_key');
    const source = dbApiKey || dbApiUrl || dbModel
      ? 'database'
      : (envAiApiKey || envAiApiUrl || envAiModel ? 'env' : 'default');
    const apiKey = dbApiKey || envAiApiKey;
    return {
      apiKey,
      apiUrl: normalizeAiApiUrl(dbApiUrl || envAiApiUrl),
      model: dbModel || envAiModel,
      source,
      keyPreview: maskSecret(apiKey),
      updatedAt: keyRow?.updated_at ?? null,
      storageReady: true
    };
  } catch (_) {
    const apiKey = envAiApiKey;
    return {
      apiKey,
      apiUrl: normalizeAiApiUrl(envAiApiUrl),
      model: envAiModel,
      source: apiKey ? 'env' : 'default',
      keyPreview: maskSecret(apiKey),
      updatedAt: null,
      storageReady: false
    };
  }
}

function aiConfigResponse(config: AiRuntimeConfig): JsonRecord {
  return {
    provider: config.apiUrl.includes('deepseek') ? 'deepseek' : 'openai-compatible',
    apiUrl: config.apiUrl,
    model: config.model,
    hasApiKey: Boolean(config.apiKey),
    keyPreview: config.keyPreview,
    source: config.source,
    storageReady: config.storageReady,
    updatedAt: config.updatedAt,
    keyLocation: config.source === 'database'
      ? 'admin backend settings'
      : 'Supabase Edge Function Secret'
  };
}

async function upsertSetting(settingKey: string, value: string, isSecret = false): Promise<void> {
  await postgrest(
    'app_settings?on_conflict=setting_key',
    {
      method: 'POST',
      body: JSON.stringify({
        setting_key: settingKey,
        value,
        is_secret: isSecret,
        updated_at: new Date().toISOString()
      })
    },
    'resolution=merge-duplicates,return=minimal'
  );
}

async function saveAiConfig(request: Request): Promise<Response> {
  const body = await request.json() as JsonRecord;
  const apiUrl = normalizeText(body.apiUrl);
  const model = normalizeText(body.model);
  const apiKey = normalizeText(body.apiKey);
  const clearApiKey = body.clearApiKey === true;
  const errors: string[] = [];

  if (apiUrl) {
    assertUrl(errors, normalizeAiApiUrl(apiUrl), 'apiUrl');
  }
  if (model && model.length < 2) {
    errors.push('model must be at least 2 characters');
  }
  if (apiKey && apiKey.length < 12) {
    errors.push('apiKey is too short');
  }
  if (errors.length > 0) {
    return jsonResponse({ error: 'validation_failed', errors }, 422);
  }

  try {
    if (apiUrl) {
      await upsertSetting('ai_api_url', normalizeAiApiUrl(apiUrl));
    }
    if (model) {
      await upsertSetting('ai_model', model);
    }
    if (apiKey || clearApiKey) {
      await upsertSetting('ai_api_key', clearApiKey ? '' : apiKey, true);
    }
  } catch (error) {
    return jsonResponse({
      error: 'settings_storage_unavailable',
      message: error instanceof Error ? error.message : String(error)
    }, 500);
  }

  const config = await getAiRuntimeConfig();
  return jsonResponse({ ok: true, config: aiConfigResponse(config) });
}

function compactCandidate(candidate: NonNullable<CandidatePayload['candidates']>[number]): JsonRecord {
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

function aiSystemPrompt(): string {
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

function aiUserPrompt(payload: CandidatePayload): string {
  return JSON.stringify({
    editionDate: payload.date,
    rules: payload.rules,
    candidates: (payload.candidates ?? []).slice(0, 120).map(compactCandidate)
  });
}

function parseAiJson(content: string): AiDraftResult {
  const trimmed = content.trim()
    .replace(/^```json\s*/i, '')
    .replace(/^```\s*/i, '')
    .replace(/```$/i, '')
    .trim();
  return JSON.parse(trimmed) as AiDraftResult;
}

async function callAi(payload: CandidatePayload, config: AiRuntimeConfig): Promise<AiDraftResult> {
  if (!config.apiKey) {
    throw new Error('missing_ai_api_key');
  }

  const response = await fetch(config.apiUrl, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${config.apiKey}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      model: config.model,
      messages: [
        { role: 'system', content: aiSystemPrompt() },
        { role: 'user', content: aiUserPrompt(payload) }
      ],
      response_format: { type: 'json_object' },
      temperature: 0.2,
      max_tokens: 4000,
      stream: false,
      thinking: { type: 'disabled' }
    })
  });

  if (!response.ok) {
    throw new Error(`ai_api_${response.status}: ${await response.text()}`);
  }

  const data = await response.json();
  const content = data?.choices?.[0]?.message?.content;
  if (!content || typeof content !== 'string') {
    throw new Error('ai_api_empty_content');
  }
  return parseAiJson(content);
}

async function testAiConnection(): Promise<Response> {
  const config = await getAiRuntimeConfig();
  if (!config.apiKey) {
    return jsonResponse({ error: 'missing_ai_api_key', config: aiConfigResponse(config) }, 503);
  }

  const response = await fetch(config.apiUrl, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${config.apiKey}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      model: config.model,
      messages: [
        { role: 'system', content: 'Return JSON only.' },
        { role: 'user', content: 'Return exactly {"ok":true,"message":"connected"}.' }
      ],
      response_format: { type: 'json_object' },
      temperature: 0,
      max_tokens: 128,
      stream: false,
      thinking: { type: 'disabled' }
    })
  });

  if (!response.ok) {
    return jsonResponse({
      error: 'ai_connection_failed',
      status: response.status,
      message: await response.text(),
      config: aiConfigResponse(config)
    }, 502);
  }

  const data = await response.json();
  return jsonResponse({
    ok: true,
    config: aiConfigResponse(config),
    response: data?.choices?.[0]?.message?.content ?? null
  });
}

function buildAiEdition(payload: CandidatePayload, aiResult: AiDraftResult, config: AiRuntimeConfig): EditionPayload & JsonRecord {
  const candidates = payload.candidates ?? [];
  const candidateById = new Map(candidates.map((candidate) => [Number(candidate.candidateId), candidate]));
  const items: NonNullable<EditionPayload['items']> = [];
  const used = new Set<number>();
  const reviewNotes = Array.isArray(aiResult.reviewNotes)
    ? aiResult.reviewNotes.map(normalizeText).filter(Boolean)
    : [];

  const picks = Array.isArray(aiResult.picks) ? aiResult.picks : [];
  for (const pick of picks) {
    if (items.length >= 10) {
      break;
    }
    const candidateId = Number(pick.candidateId);
    const candidate = candidateById.get(candidateId);
    if (!candidate || used.has(candidateId)) {
      continue;
    }
    used.add(candidateId);
    items.push(candidateToEditionItem(candidate, items.length + 1, pick));
  }

  if (items.length < 10) {
    for (const candidate of candidates) {
      if (items.length >= 10) {
        break;
      }
      const candidateId = Number(candidate.candidateId);
      if (used.has(candidateId)) {
        continue;
      }
      used.add(candidateId);
      items.push(candidateToEditionItem(candidate, items.length + 1, {
        selectionReason: candidate.selectionHint || 'AI 返回不足 10 条，按候选池顺序补足，需人工复核。',
        summaryRewrite: candidate.summary
      }));
    }
    reviewNotes.push('AI 返回不足 10 条，已从候选池自动补足，请重点复核补足条目。');
  }

  return {
    edition: {
      date: normalizeText(payload.date),
      region: 'cn',
      language: 'zh-CN',
      status: 'draft',
      publishedAt: null,
      statement: defaultAiStatement
    },
    items,
    aiReviewNotes: reviewNotes,
    generatedBy: {
      type: 'ai-editor-assistant',
      model: config.model,
      generatedAt: chinaDateTime(),
      personalized: false
    }
  };
}

function candidateToEditionItem(
  candidate: NonNullable<CandidatePayload['candidates']>[number],
  position: number,
  pick: AiPick
): NonNullable<EditionPayload['items']>[number] {
  return {
    position,
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
  };
}

async function postgrest<T>(path: string, options: RequestInit = {}, prefer?: string): Promise<T> {
  const response = await fetch(`${supabaseUrl}/rest/v1/${path}`, {
    ...options,
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      Accept: 'application/json',
      ...(options.body ? { 'Content-Type': 'application/json' } : {}),
      ...(prefer ? { Prefer: prefer } : {}),
      ...(options.headers ?? {})
    }
  });

  if (!response.ok) {
    const message = await response.text();
    throw new Error(`PostgREST ${response.status}: ${message}`);
  }

  if (response.status === 204) {
    return null as T;
  }

  const text = await response.text();
  return (text ? JSON.parse(text) : null) as T;
}

async function upsertSource(source: NonNullable<NonNullable<NonNullable<EditionPayload['items']>[number]['article']>['source']>): Promise<string> {
  const name = normalizeText(source.name);
  const rows = await postgrest<Array<{ id: string }>>(`sources?name=eq.${encodeURIComponent(name)}&select=id&limit=1`);
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
    const updated = await postgrest<Array<{ id: string }>>(
      `sources?id=eq.${rows[0].id}&select=id`,
      { method: 'PATCH', body: JSON.stringify(body) },
      'return=representation'
    );
    return updated[0].id;
  }

  const inserted = await postgrest<Array<{ id: string }>>(
    'sources?select=id',
    { method: 'POST', body: JSON.stringify(body) },
    'return=representation'
  );
  return inserted[0].id;
}

async function upsertArticle(item: NonNullable<EditionPayload['items']>[number], sourceId: string): Promise<string> {
  const article = item.article!;
  const inserted = await postgrest<Array<{ id: string }>>(
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
        published_at: new Date(normalizeText(article.publishedAt)).toISOString(),
        content_hash: await sha256([
          article.title,
          article.summary,
          article.url,
          article.publishedAt
        ].map(normalizeText).join('\n')),
        status: 'published'
      })
    },
    'resolution=merge-duplicates,return=representation'
  );
  return inserted[0].id;
}

async function sha256(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(digest)).map((byte) => byte.toString(16).padStart(2, '0')).join('');
}

async function upsertEdition(payload: EditionPayload): Promise<JsonRecord> {
  const edition = payload.edition!;
  const status = edition.status ?? 'published';
  const draftRows = await postgrest<Array<{ id: string }>>(
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
      })
    },
    'resolution=merge-duplicates,return=representation'
  );
  const editionId = draftRows[0].id;

  await postgrest(`daily_edition_items?edition_id=eq.${editionId}`, { method: 'DELETE' });

  const sourceIdsByName = new Map<string, string>();
  const rows = [];
  for (const item of [...payload.items!].sort((a, b) => Number(a.position) - Number(b.position))) {
    const sourceName = normalizeText(item.article!.source!.name);
    if (!sourceIdsByName.has(sourceName)) {
      sourceIdsByName.set(sourceName, await upsertSource(item.article!.source!));
    }
    const articleId = await upsertArticle(item, sourceIdsByName.get(sourceName)!);
    rows.push({
      edition_id: editionId,
      article_id: articleId,
      position: item.position,
      selection_reason: normalizeText(item.selectionReason)
    });
  }

  await postgrest('daily_edition_items', {
    method: 'POST',
    body: JSON.stringify(rows)
  }, 'return=minimal');

  const finalRows = await postgrest<JsonRecord[]>(
    `daily_editions?id=eq.${editionId}&select=id,edition_date,region,language,status,published_at,updated_at`,
    {
      method: 'PATCH',
      body: JSON.stringify({
        status,
        published_at: status === 'published'
          ? (edition.publishedAt ? new Date(edition.publishedAt).toISOString() : new Date().toISOString())
          : null,
        updated_at: new Date().toISOString()
      })
    },
    'return=representation'
  );

  return finalRows[0];
}

function checkAuth(request: Request): boolean {
  if (!adminToken) {
    return false;
  }
  const header = request.headers.get('authorization') ?? '';
  return header === `Bearer ${adminToken}`;
}

async function listEditions(url: URL): Promise<Response> {
  const region = url.searchParams.get('region') ?? 'cn';
  const language = url.searchParams.get('language') ?? 'zh-CN';
  const status = url.searchParams.get('status');
  const limit = Math.min(Number(url.searchParams.get('limit') ?? 20), 50);
  const filters = [
    `region=eq.${encodeURIComponent(region)}`,
    `language=eq.${encodeURIComponent(language)}`,
    'select=id,edition_date,region,language,status,published_at,updated_at,statement',
    'order=edition_date.desc',
    `limit=${limit}`
  ];
  if (status) {
    filters.push(`status=eq.${encodeURIComponent(status)}`);
  }
  const editions = await postgrest(`daily_editions?${filters.join('&')}`);
  return jsonResponse({ editions });
}

async function updateEditionStatus(request: Request): Promise<Response> {
  const body = await request.json() as JsonRecord;
  const date = normalizeText(body.date);
  const region = normalizeText(body.region) || 'cn';
  const language = normalizeText(body.language) || 'zh-CN';
  const status = normalizeText(body.status) || 'published';
  const errors: string[] = [];

  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    errors.push('date must use YYYY-MM-DD');
  }
  if (!allowedStatuses.has(status)) {
    errors.push('status must be draft or published');
  }
  if (errors.length > 0) {
    return jsonResponse({ error: 'validation_failed', errors }, 422);
  }

  const rows = await postgrest<JsonRecord[]>(
    [
      'daily_editions?',
      `edition_date=eq.${encodeURIComponent(date)}`,
      `region=eq.${encodeURIComponent(region)}`,
      `language=eq.${encodeURIComponent(language)}`,
      'select=id,edition_date,region,language,status,published_at,updated_at'
    ].join('&'),
    {
      method: 'PATCH',
      body: JSON.stringify({
        status,
        published_at: status === 'published' ? new Date().toISOString() : null,
        updated_at: new Date().toISOString()
      })
    },
    'return=representation'
  );

  if (rows.length === 0) {
    return jsonResponse({ error: 'edition_not_found' }, 404);
  }

  return jsonResponse({ ok: true, edition: rows[0] });
}

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse({ error: 'missing_supabase_env' }, 500);
  }

  if (!adminToken) {
    return jsonResponse({ error: 'missing_admin_token' }, 500);
  }

  if (!checkAuth(request)) {
    return jsonResponse({ error: 'unauthorized' }, 401);
  }

  try {
    const url = new URL(request.url);
    const parts = url.pathname.split('/').filter(Boolean);
    const route = parts.slice(parts.indexOf('admin') + 1).join('/');

    if (request.method === 'GET' && (route === '' || route === 'health')) {
      return jsonResponse({ ok: true });
    }

    if (request.method === 'GET' && route === 'ai/config') {
      const config = await getAiRuntimeConfig();
      return jsonResponse({ ok: true, config: aiConfigResponse(config) });
    }

    if (request.method === 'POST' && route === 'ai/config') {
      return await saveAiConfig(request);
    }

    if (request.method === 'POST' && route === 'ai/test') {
      return await testAiConnection();
    }

    if (request.method === 'POST' && route === 'ai/draft') {
      const payload = await request.json() as CandidatePayload;
      if (!payload.date || !/^\d{4}-\d{2}-\d{2}$/.test(String(payload.date))) {
        return jsonResponse({ error: 'validation_failed', errors: ['date must use YYYY-MM-DD'] }, 422);
      }
      if (!Array.isArray(payload.candidates) || payload.candidates.length < 10) {
        return jsonResponse({ error: 'validation_failed', errors: ['candidates must contain at least 10 articles'] }, 422);
      }
      const config = await getAiRuntimeConfig();
      if (!config.apiKey) {
        return jsonResponse({ error: 'missing_ai_api_key', config: aiConfigResponse(config) }, 503);
      }

      const aiResult = await callAi(payload, config);
      const draft = buildAiEdition(payload, aiResult, config);
      const errors = validateEdition(draft);
      if (errors.length > 0) {
        return jsonResponse({
          error: 'ai_draft_validation_failed',
          errors,
          draft
        }, 422);
      }

      return jsonResponse({
        ok: true,
        draft,
        aiReviewNotes: draft.aiReviewNotes ?? [],
        generatedBy: draft.generatedBy
      });
    }

    if (request.method === 'GET' && route === 'editions') {
      return await listEditions(url);
    }

    if (request.method === 'PATCH' && route === 'editions/status') {
      return await updateEditionStatus(request);
    }

    if (request.method === 'POST' && (route === 'editions' || route === 'editions/publish')) {
      const payload = await request.json() as EditionPayload;
      const errors = validateEdition(payload);
      if (errors.length > 0) {
        return jsonResponse({ error: 'validation_failed', errors }, 422);
      }

      if (url.searchParams.get('dryRun') === 'true') {
        return jsonResponse({ ok: true, dryRun: true, items: payload.items?.length ?? 0 });
      }

      const edition = await upsertEdition(payload);
      return jsonResponse({ ok: true, edition });
    }

    return jsonResponse({ error: 'not_found' }, 404);
  } catch (error) {
    return jsonResponse({
      error: 'internal_error',
      message: error instanceof Error ? error.message : String(error)
    }, 500);
  }
});
