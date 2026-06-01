import { corsHeaders } from '../_shared/cors.ts';

interface EditionRow {
  id: string;
  edition_date: string;
  region: string;
  language: string;
  published_at: string | null;
  statement: string;
}

interface SourceRow {
  id: string;
  name: string;
}

interface ArticleRow {
  id: string;
  source_id: string;
  title: string;
  summary: string;
  url: string;
  category: string;
  published_at: string;
}

interface EditionItemRow {
  position: number;
  selection_reason: string;
  article_id: string;
}

interface DailyNewsPayload {
  edition: {
    date: string;
    region: string;
    language: string;
    publishedAt: string | null;
    statement: string;
  };
  items: Array<{
    position: number;
    selectionReason: string;
    article: {
      id: string;
      title: string;
      summary: string;
      source: string;
      category: string;
      publishedAt: string;
      url: string;
    };
  }>;
}

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ??
  Deno.env.get('DAILYTEN_SUPABASE_SECRET_KEY') ??
  '';

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': status === 200 ? 'public, max-age=300, stale-while-revalidate=3600' : 'no-store'
    }
  });
}

function htmlEscape(value: string | null | undefined): string {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function categoryLabel(category: string): string {
  const labels: Record<string, string> = {
    domestic: '国内',
    international: '国际',
    finance: '财经',
    technology: '科技',
    health: '健康',
    education: '教育',
    society: '社会',
    sports: '体育',
    perspective: '视角'
  };
  return labels[category] ?? category;
}

function wantsHtml(request: Request, url: URL): boolean {
  if (url.searchParams.get('format') === 'json') {
    return false;
  }
  const accept = request.headers.get('accept') ?? '';
  return url.searchParams.get('format') === 'html' &&
    accept.includes('text/html') &&
    !accept.includes('application/json');
}

function htmlResponse(payload: DailyNewsPayload): Response {
  const items = payload.items.map((item) => {
    const article = item.article;
    return `
      <article class="item">
        <div class="rank">${item.position}</div>
        <div class="content">
          <div class="meta">
            <span class="tag">${htmlEscape(categoryLabel(article.category))}</span>
            <span>${htmlEscape(article.source)}</span>
            <span>${htmlEscape(new Date(article.publishedAt).toLocaleTimeString('zh-CN', {
              hour: '2-digit',
              minute: '2-digit',
              timeZone: 'Asia/Shanghai'
            }))}</span>
          </div>
          <h2><a href="${htmlEscape(article.url)}" target="_blank" rel="noreferrer">${htmlEscape(article.title)}</a></h2>
          <p>${htmlEscape(article.summary)}</p>
          <div class="reason">入选理由：${htmlEscape(item.selectionReason)}</div>
        </div>
      </article>
    `;
  }).join('');

  const html = `<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>今日十条 - ${htmlEscape(payload.edition.date)}</title>
  <style>
    :root {
      color-scheme: light;
      --bg: #f6f7f2;
      --paper: #ffffff;
      --text: #202124;
      --muted: #687076;
      --line: #d9ded8;
      --green: #2e6f57;
      --green-soft: #e4eee9;
      --amber: #8a4d16;
      --amber-soft: #f3e7d5;
      --red: #b34b45;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      background: var(--bg);
      color: var(--text);
      font-family: -apple-system, BlinkMacSystemFont, "HarmonyOS Sans SC", "PingFang SC", "Microsoft YaHei", sans-serif;
      line-height: 1.55;
    }
    main {
      max-width: 920px;
      margin: 0 auto;
      padding: 42px 20px 56px;
    }
    header {
      display: grid;
      grid-template-columns: 1fr auto;
      gap: 20px;
      align-items: start;
      margin-bottom: 22px;
    }
    h1 {
      margin: 0;
      font-size: clamp(34px, 7vw, 64px);
      line-height: 1;
      letter-spacing: 0;
    }
    .sub {
      margin-top: 12px;
      color: var(--muted);
      font-size: 15px;
    }
    .badge {
      width: 72px;
      height: 72px;
      border-radius: 50%;
      background: var(--green);
      color: #fff;
      display: grid;
      place-items: center;
      font-size: 30px;
      font-weight: 800;
    }
    .statement {
      background: var(--paper);
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 16px 18px;
      color: #3d454d;
      margin-bottom: 18px;
    }
    .toolbar {
      display: flex;
      justify-content: space-between;
      gap: 12px;
      color: var(--muted);
      font-size: 14px;
      margin: 18px 0;
      flex-wrap: wrap;
    }
    .item {
      display: grid;
      grid-template-columns: 44px 1fr;
      gap: 14px;
      background: var(--paper);
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 18px;
      margin: 12px 0;
    }
    .rank {
      width: 36px;
      height: 36px;
      border-radius: 50%;
      background: var(--green);
      color: #fff;
      display: grid;
      place-items: center;
      font-weight: 800;
    }
    .item:nth-of-type(-n+3) .rank { background: var(--red); }
    .meta {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      align-items: center;
      color: var(--muted);
      font-size: 13px;
      margin-bottom: 6px;
    }
    .tag {
      color: var(--green);
      background: var(--green-soft);
      padding: 3px 8px;
      border-radius: 6px;
      font-weight: 700;
    }
    h2 {
      margin: 0 0 8px;
      font-size: clamp(18px, 3.2vw, 24px);
      line-height: 1.3;
      letter-spacing: 0;
    }
    a {
      color: inherit;
      text-decoration: none;
    }
    a:hover { color: var(--green); }
    p {
      margin: 0;
      color: #3d454d;
    }
    .reason {
      margin-top: 12px;
      padding: 10px 12px;
      border-radius: 8px;
      background: var(--amber-soft);
      color: var(--amber);
      font-size: 13px;
    }
    footer {
      margin-top: 24px;
      color: var(--muted);
      font-size: 13px;
      text-align: center;
    }
    @media (max-width: 620px) {
      main { padding-top: 28px; }
      header { grid-template-columns: 1fr; }
      .badge { width: 58px; height: 58px; font-size: 24px; }
      .item { grid-template-columns: 1fr; }
    }
  </style>
</head>
<body>
  <main>
    <header>
      <div>
        <h1>今日十条</h1>
        <div class="sub">${htmlEscape(payload.edition.date)} / ${htmlEscape(payload.edition.region)} / ${htmlEscape(payload.edition.language)}</div>
      </div>
      <div class="badge">10</div>
    </header>
    <section class="statement">${htmlEscape(payload.edition.statement)}</section>
    <div class="toolbar">
      <span>公共新闻简报</span>
      <span>不基于个人行为推荐</span>
    </div>
    ${items}
    <footer>新闻顺序由服务端每日版本决定，客户端不会根据点击、停留或收藏进行重排。</footer>
  </main>
</body>
</html>`;

  return new Response(html, {
    headers: {
      ...corsHeaders,
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'public, max-age=300, stale-while-revalidate=3600'
    }
  });
}

async function postgrest<T>(path: string): Promise<T> {
  const response = await fetch(`${supabaseUrl}/rest/v1/${path}`, {
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      Accept: 'application/json'
    }
  });

  if (!response.ok) {
    const message = await response.text();
    throw new Error(`PostgREST ${response.status}: ${message}`);
  }

  return await response.json() as T;
}

function getDateFromPath(url: URL): string | null {
  const parts = url.pathname.split('/').filter(Boolean);
  const last = parts[parts.length - 1] ?? '';
  if (/^\d{4}-\d{2}-\d{2}$/.test(last)) {
    return last;
  }
  return url.searchParams.get('date');
}

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (request.method !== 'GET') {
    return jsonResponse({ error: 'method_not_allowed' }, 405);
  }

  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse({ error: 'missing_supabase_env' }, 500);
  }

  try {
    const url = new URL(request.url);
    const region = url.searchParams.get('region') ?? 'cn';
    const language = url.searchParams.get('language') ?? 'zh-CN';
    const date = getDateFromPath(url);

    const editionFilter = [
      `region=eq.${encodeURIComponent(region)}`,
      `language=eq.${encodeURIComponent(language)}`,
      'status=eq.published',
      'select=id,edition_date,region,language,published_at,statement',
      'order=edition_date.desc',
      'limit=1'
    ];

    if (date) {
      editionFilter.push(`edition_date=eq.${date}`);
    }

    const editions = await postgrest<EditionRow[]>(`daily_editions?${editionFilter.join('&')}`);
    const edition = editions[0];

    if (!edition) {
      return jsonResponse({ error: 'edition_not_found' }, 404);
    }

    const itemQuery = [
      `edition_id=eq.${edition.id}`,
      'select=position,selection_reason,article_id',
      'order=position.asc'
    ].join('&');
    const items = await postgrest<EditionItemRow[]>(`daily_edition_items?${itemQuery}`);
    const articleIds = items.map((item) => item.article_id);

    if (articleIds.length === 0) {
      const payload: DailyNewsPayload = {
        edition: {
          date: edition.edition_date,
          region: edition.region,
          language: edition.language,
          publishedAt: edition.published_at,
          statement: edition.statement
        },
        items: []
      };

      return wantsHtml(request, url) ? htmlResponse(payload) : jsonResponse(payload);
    }

    const articles = await postgrest<ArticleRow[]>(
      `articles?id=in.(${articleIds.join(',')})&select=id,source_id,title,summary,url,category,published_at`
    );
    const sourceIds = Array.from(new Set(articles.map((article) => article.source_id)));
    const sources = await postgrest<SourceRow[]>(`sources?id=in.(${sourceIds.join(',')})&select=id,name`);
    const articleById = new Map<string, ArticleRow>();
    const sourceById = new Map<string, SourceRow>();

    for (const article of articles) {
      articleById.set(article.id, article);
    }
    for (const source of sources) {
      sourceById.set(source.id, source);
    }

    const payload: DailyNewsPayload = {
      edition: {
        date: edition.edition_date,
        region: edition.region,
        language: edition.language,
        publishedAt: edition.published_at,
        statement: edition.statement
      },
      items: items.map((item) => {
        const article = articleById.get(item.article_id);
        const source = article ? sourceById.get(article.source_id) : undefined;

        if (!article) {
          return null;
        }

        return {
          position: item.position,
          selectionReason: item.selection_reason,
          article: {
            id: article.id,
            title: article.title,
            summary: article.summary,
            source: source?.name ?? '未知来源',
            category: article.category,
            publishedAt: article.published_at,
            url: article.url
          }
        };
      }).filter((item): item is DailyNewsPayload['items'][number] => item !== null)
    };

    return wantsHtml(request, url) ? htmlResponse(payload) : jsonResponse(payload);
  } catch (error) {
    return jsonResponse({
      error: 'internal_error',
      message: error instanceof Error ? error.message : String(error)
    }, 500);
  }
});
