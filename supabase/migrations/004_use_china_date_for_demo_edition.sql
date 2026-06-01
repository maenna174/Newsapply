update daily_editions
set edition_date = (now() at time zone 'Asia/Shanghai')::date,
    updated_at = now()
where id = (
  select id
  from daily_editions
  where region = 'cn'
    and language = 'zh-CN'
    and status = 'published'
  order by published_at desc nulls last, generated_at desc
  limit 1
);
