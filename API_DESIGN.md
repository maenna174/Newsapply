# 后端 API 方案

## 目标

后端只提供“每日公共版本”的新闻数据，不提供个性化推荐接口。客户端不上传用户点击、停留、收藏、搜索历史，也不传 `user_id` 获取新闻排序。

## 第一版架构

```text
新闻源 / 爬虫 / RSS
  ↓
articles 新闻池
  ↓
每日十条生成任务
  ↓
daily_editions + daily_edition_items
  ↓
公共 API
  ↓
HarmonyOS / iOS / Android
```

## 客户端 API

### GET /v1/editions/today

如果使用 Supabase Edge Functions，实际部署入口通常是：

```text
https://<project-ref>.supabase.co/functions/v1/editions/today
```

获取当前已发布的每日十条。

Query:

```text
region=cn
language=zh-CN
```

Response:

```json
{
  "edition": {
    "date": "2026-05-31",
    "region": "cn",
    "language": "zh-CN",
    "publishedAt": "2026-05-31T08:00:00+08:00",
    "statement": "本期新闻按公共重要性、来源多样性和主题配额生成，不基于个人阅读行为排序。"
  },
  "items": [
    {
      "position": 1,
      "selectionReason": "涉及公共服务，且与民生和数字治理直接相关。",
      "article": {
        "id": "uuid",
        "title": "多部门发布新一轮公共服务数字化安排",
        "summary": "相关部门提出继续完善线上办事、适老化服务和跨地区协同。",
        "source": "人民网",
        "category": "domestic",
        "publishedAt": "2026-05-31T07:42:00+08:00",
        "url": "https://example.com/news/n001"
      }
    }
  ]
}
```

### GET /v1/editions/:date

获取指定日期的已发布版本。

Example:

```text
GET /v1/editions/2026-05-31?region=cn&language=zh-CN
```

Supabase Edge Functions 对应：

```text
GET /functions/v1/editions/2026-05-31?region=cn&language=zh-CN
```

### GET /v1/articles/:id

获取单条新闻摘要和原文链接。第一版不存储未经授权的全文。

### GET /v1/sources

获取启用的新闻源说明。

## 管理后台 API

管理后台接口需要鉴权，不暴露给普通客户端。

```text
POST /admin/sources
POST /admin/articles/fetch
POST /admin/editions/generate
PATCH /admin/editions/:id/items
POST /admin/editions/:id/publish
```

## 非个性化约束

API 层明确不支持：

- `user_id`
- `interest`
- `history`
- `recommendation_score`
- `similar_users`
- `personalized_rank`

允许的客户端参数只有：

- `region`
- `language`
- `date`

## 缓存策略

每日版本发布后基本不变，可以设置：

```text
Cache-Control: public, max-age=300, stale-while-revalidate=3600
```

如果当日版本被编辑下架或重新发布，服务端更新 `updated_at`，客户端下次刷新即可拿到新版本。

## NAS 的位置

NAS 可以存：

- 原始抓取文件
- 备份
- 日志
- 图片缓存

但 App 不直接访问 NAS。App 只访问公共 API，公共 API 再读云数据库或自托管数据库。
