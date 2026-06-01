with edition as (
  select id
  from daily_editions
  where region = 'cn'
    and language = 'zh-CN'
    and status = 'published'
  order by edition_date desc
  limit 1
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
where (select id from edition) is not null
on conflict (edition_id, position) do update
  set article_id = excluded.article_id,
      selection_reason = excluded.selection_reason;
