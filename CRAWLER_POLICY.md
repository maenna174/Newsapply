# 新闻 App 爬虫接入规范

## 结论

可以使用爬虫，但第一版只建议爬取新闻元数据：

- 标题
- 摘要
- 原文链接
- 来源
- 发布时间
- 栏目 / 分类
- 封面图链接，需确认可用授权

不建议未经授权抓取、存储或展示全文内容、高清图片、视频、付费内容。

## 推荐优先级

1. 官方 API
2. 官方 RSS
3. 官方 sitemap
4. 被允许抓取的公开栏目页
5. 普通网页解析

普通网页解析放在最后，因为它最容易遇到版权、反爬、结构变更和服务条款问题。

## 必须遵守

### 1. 尊重 robots.txt

每个域名抓取前先读取并缓存 `robots.txt`。如果目标路径被禁止，不抓。

### 2. 控制频率

第一版建议：

- 同一域名每 30-120 秒最多请求一次
- 每个来源每天抓取 2-6 次即可
- 不做并发轰炸
- 请求失败后指数退避

新闻 App 每天只发布 10 条，不需要高频全站扫描。

### 3. 标明 User-Agent

使用清晰的 User-Agent，例如：

```text
DailyTenNewsBot/0.1 (+https://your-domain.example/bot; contact: editor@your-domain.example)
```

### 4. 只保存必要字段

数据库只保存推荐展示所需字段，不保存无关页面内容。

### 5. 保留来源和原文链接

每条新闻必须展示来源，并提供跳转原文链接。

### 6. 建立黑名单和停抓机制

如果来源要求停止抓取、robots.txt 变更、访问异常、收到投诉，应立即停抓。

## 不要做

- 绕过登录、验证码、付费墙
- 破解接口签名或反爬机制
- 使用大量代理 IP 模拟真实用户
- 抓取全文后改写成自己的内容
- 抓取用户评论、账号资料等个人信息
- 抓取禁止转载或明确禁止机器人访问的内容
- 用点击热度、用户行为反向影响抓取优先级

## 爬虫架构建议

```text
定时任务
  ↓
读取 source 配置
  ↓
检查 robots.txt / 抓取许可
  ↓
低频抓取 RSS/API/页面
  ↓
解析元数据
  ↓
去重与分类
  ↓
写入 articles
  ↓
每日十条生成任务从 articles 中挑选
```

## source 表建议增加字段

```sql
sources
- id
- name
- homepage_url
- feed_url
- crawl_url
- crawl_type
- robots_allowed
- crawl_interval_minutes
- last_crawled_at
- terms_note
- license_note
- contact_email
- enabled
```

## article 表建议增加字段

```sql
articles
- id
- source_id
- title
- summary
- url
- canonical_url
- category
- topic_key
- published_at
- fetched_at
- content_hash
- status
```

## 上线前检查清单

- 是否有官方 RSS/API 可替代爬虫
- 是否允许抓取目标路径
- 是否只保存元数据
- 是否保留来源和原文链接
- 是否设置合理抓取频率
- 是否有停抓机制
- 是否有投诉/纠错入口
- 是否没有抓取个人信息
- 是否没有绕过付费墙或登录限制

## 参考

- Robots Exclusion Protocol: https://www.rfc-editor.org/rfc/rfc9309
- 中华人民共和国著作权法: https://www.gov.cn/guoqing/2021-10/29/content_5647633.htm
- 信息网络传播权保护条例: https://www.cac.gov.cn/2013-02/08/c_126468776.htm
- 中华人民共和国个人信息保护法: https://www.npc.gov.cn/npc/c2/c30834/202108/t20210820_313088.html
- 网络反不正当竞争暂行规定: https://www.gov.cn/zhengce/202406/content_6959668.htm
