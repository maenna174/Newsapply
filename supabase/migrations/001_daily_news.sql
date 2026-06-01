create extension if not exists "pgcrypto";

create table if not exists sources (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  homepage_url text not null,
  feed_url text,
  crawl_url text,
  crawl_type text not null default 'rss',
  reliability_note text,
  license_note text,
  enabled boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists articles (
  id uuid primary key default gen_random_uuid(),
  source_id uuid not null references sources(id),
  title text not null,
  summary text not null,
  url text not null unique,
  canonical_url text,
  category text not null,
  topic_key text,
  published_at timestamptz not null,
  fetched_at timestamptz not null default now(),
  content_hash text,
  status text not null default 'candidate',
  created_at timestamptz not null default now()
);

create table if not exists daily_editions (
  id uuid primary key default gen_random_uuid(),
  edition_date date not null,
  region text not null default 'cn',
  language text not null default 'zh-CN',
  status text not null default 'draft',
  statement text not null default '本期新闻按公共重要性、来源多样性和主题配额生成，不基于个人阅读行为排序。',
  generated_at timestamptz not null default now(),
  published_at timestamptz,
  updated_at timestamptz not null default now(),
  unique (edition_date, region, language)
);

create table if not exists daily_edition_items (
  id uuid primary key default gen_random_uuid(),
  edition_id uuid not null references daily_editions(id) on delete cascade,
  article_id uuid not null references articles(id),
  position integer not null check (position >= 1 and position <= 10),
  selection_reason text not null,
  created_at timestamptz not null default now(),
  unique (edition_id, position),
  unique (edition_id, article_id)
);

create index if not exists idx_articles_category_published_at on articles(category, published_at desc);
create index if not exists idx_articles_topic_key on articles(topic_key);
create index if not exists idx_daily_editions_lookup on daily_editions(region, language, status, edition_date desc);
create index if not exists idx_daily_edition_items_order on daily_edition_items(edition_id, position);

alter table sources enable row level security;
alter table articles enable row level security;
alter table daily_editions enable row level security;
alter table daily_edition_items enable row level security;

create policy "public can read enabled sources"
  on sources for select
  using (enabled = true);

create policy "public can read published articles"
  on articles for select
  using (
    exists (
      select 1
      from daily_edition_items dei
      join daily_editions de on de.id = dei.edition_id
      where dei.article_id = articles.id
        and de.status = 'published'
    )
  );

create policy "public can read published editions"
  on daily_editions for select
  using (status = 'published');

create policy "public can read published edition items"
  on daily_edition_items for select
  using (
    exists (
      select 1
      from daily_editions de
      where de.id = daily_edition_items.edition_id
        and de.status = 'published'
    )
  );
