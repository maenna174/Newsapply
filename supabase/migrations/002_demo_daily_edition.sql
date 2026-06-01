insert into sources (name, homepage_url, feed_url, crawl_type, reliability_note, license_note)
values
  ('人民网', 'https://www.people.com.cn/', 'https://politics.people.com.cn/ywkx/GB/368825/index.html', 'rss', '国内公共事务来源', '商业化前确认授权'),
  ('中国新闻网', 'https://www.chinanews.com.cn/', 'https://www.chinanews.com.cn/rss/', 'rss', '中文综合新闻来源', '商业化前确认授权'),
  ('新华社', 'https://www.news.cn/', null, 'site', '权威通稿来源', '优先走供稿授权'),
  ('BBC News', 'https://www.bbc.com/news', 'https://feeds.bbci.co.uk/news/rss.xml', 'rss', '国际新闻来源', '遵循来源条款'),
  ('WHO', 'https://www.who.int/news-room', null, 'site', '公共卫生专业来源', '遵循来源条款'),
  ('联合国新闻', 'https://news.un.org/zh', null, 'site', '国际组织新闻来源', '遵循来源条款'),
  ('Reuters', 'https://www.reuters.com/', null, 'licensed', '国际财经新闻来源', '商业化优先采购授权'),
  ('NASA', 'https://www.nasa.gov/', 'https://www.nasa.gov/?p=539799', 'rss', '科学与航天来源', '遵循来源条款'),
  ('BBC Sport', 'https://www.bbc.com/sport', null, 'rss', '体育新闻来源', '遵循来源条款'),
  ('编辑部', 'https://example.com/editorial', null, 'manual', '编辑补充视角', '自有内容')
on conflict do nothing;

with demo_articles as (
  insert into articles (source_id, title, summary, url, category, topic_key, published_at, status)
  values
    ((select id from sources where name = '人民网' limit 1), '多部门发布新一轮公共服务数字化安排', '相关部门提出继续完善线上办事、适老化服务和跨地区协同，让基础公共服务更容易被普通用户触达。', 'https://example.com/news/n001', 'domestic', 'public-service-digital', now() - interval '20 minutes', 'published'),
    ((select id from sources where name = '联合国新闻' limit 1), '国际组织呼吁加强极端天气早期预警', '近期多地极端天气风险升高，国际组织建议提高预警覆盖率，并加强城市基础设施韧性。', 'https://example.com/news/n002', 'international', 'weather-warning', now() - interval '35 minutes', 'published'),
    ((select id from sources where name = 'Reuters' limit 1), '主要经济体公布最新通胀与就业观察', '多国最新经济数据释放出不同信号，食品、能源和服务价格仍是影响居民感受的重要变量。', 'https://example.com/news/n003', 'finance', 'inflation-jobs', now() - interval '50 minutes', 'published'),
    ((select id from sources where name = 'NASA' limit 1), '科研机构公布新一代地球观测任务进展', '新的观测任务将提升对海洋、冰川和森林变化的跟踪能力，为气候研究提供长期数据。', 'https://example.com/news/n004', 'technology', 'earth-observation', now() - interval '65 minutes', 'published'),
    ((select id from sources where name = '中国新闻网' limit 1), '多地推进基层医疗服务能力建设', '社区医疗机构将增加慢病管理、远程咨询和康复服务，缓解大医院门诊压力。', 'https://example.com/news/n005', 'health', 'community-health', now() - interval '80 minutes', 'published'),
    ((select id from sources where name = '新华社' limit 1), '教育部门提示毕业季求职风险', '相关提醒聚焦虚假招聘、培训贷和个人信息泄露，建议毕业生核验招聘主体和合同条款。', 'https://example.com/news/n006', 'education', 'job-risk', now() - interval '95 minutes', 'published'),
    ((select id from sources where name = '中国新闻网' limit 1), '城市交通更新计划关注慢行系统', '多个城市计划优化步行和骑行空间，缓解短途出行拥堵，并改善老城区道路体验。', 'https://example.com/news/n007', 'society', 'city-transport', now() - interval '110 minutes', 'published'),
    ((select id from sources where name = 'WHO' limit 1), '世界卫生组织更新季节性健康提示', '提示强调高温天气、饮水安全和基础疫苗接种的重要性，建议重点关注老人和儿童。', 'https://example.com/news/n008', 'health', 'seasonal-health', now() - interval '125 minutes', 'published'),
    ((select id from sources where name = 'BBC Sport' limit 1), '国际赛事进入关键阶段，赛程密集考验队伍轮换', '多支队伍将在短时间内连续比赛，体能管理和阵容深度成为影响结果的重要因素。', 'https://example.com/news/n009', 'sports', 'sport-schedule', now() - interval '140 minutes', 'published'),
    ((select id from sources where name = '编辑部' limit 1), '本期补充视角：长期议题不应被突发新闻完全挤出', '气候、公共卫生、教育公平等长期议题未必每天登上头条，但仍需要在公共信息菜单中保留位置。', 'https://example.com/news/n010', 'perspective', 'long-term-issues', now() - interval '155 minutes', 'published')
  on conflict (url) do update
    set title = excluded.title,
        summary = excluded.summary,
        category = excluded.category,
        topic_key = excluded.topic_key,
        published_at = excluded.published_at,
        status = excluded.status
  returning id, url
),
edition as (
  insert into daily_editions (edition_date, region, language, status, published_at)
  values ((now() at time zone 'Asia/Shanghai')::date, 'cn', 'zh-CN', 'published', now())
  on conflict (edition_date, region, language) do update
    set status = 'published',
        published_at = coalesce(daily_editions.published_at, now()),
        updated_at = now()
  returning id
)
insert into daily_edition_items (edition_id, article_id, position, selection_reason)
select
  (select id from edition),
  articles.id,
  article_positions.position,
  article_positions.selection_reason
from (
  values
    ('https://example.com/news/n001', 1, '涉及公共服务，且与民生和数字治理直接相关。'),
    ('https://example.com/news/n002', 2, '补充全球公共安全视角，避免只关注单一区域事件。'),
    ('https://example.com/news/n003', 3, '财经信息影响面广，适合进入每日公共简报。'),
    ('https://example.com/news/n004', 4, '科学类新闻用于平衡时政和社会议题，拓宽信息面。'),
    ('https://example.com/news/n005', 5, '健康议题与日常生活关联高，且具有公共服务属性。'),
    ('https://example.com/news/n006', 6, '面向年轻群体的实用公共信息，具备风险提醒价值。'),
    ('https://example.com/news/n007', 7, '城市生活议题覆盖面广，补充本地公共事务维度。'),
    ('https://example.com/news/n008', 8, '来自专业机构，有助于降低健康信息噪音。'),
    ('https://example.com/news/n009', 9, '保留轻量体育内容，避免每日新闻全部沉重化。'),
    ('https://example.com/news/n010', 10, '作为编辑补充视角，抵消单日热点对注意力的挤压。')
) as article_positions(url, position, selection_reason)
join articles on articles.url = article_positions.url
on conflict (edition_id, position) do update
  set article_id = excluded.article_id,
      selection_reason = excluded.selection_reason;
