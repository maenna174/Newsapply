insert into sources (name, homepage_url, feed_url, crawl_type, reliability_note, license_note)
values
  ('人民网', 'https://www.people.com.cn/', 'https://politics.people.com.cn/ywkx/GB/368825/index.html', 'rss', '国内公共事务来源', '商业化前确认授权'),
  ('中国新闻网', 'https://www.chinanews.com.cn/', 'https://www.chinanews.com.cn/rss/', 'rss', '中文综合新闻来源', '商业化前确认授权'),
  ('新华社', 'https://www.news.cn/', null, 'site', '权威通稿来源', '优先走供稿授权'),
  ('BBC News', 'https://www.bbc.com/news', 'https://feeds.bbci.co.uk/news/rss.xml', 'rss', '国际新闻来源', '遵循来源条款'),
  ('WHO', 'https://www.who.int/news-room', null, 'site', '公共卫生专业来源', '遵循来源条款')
on conflict do nothing;
