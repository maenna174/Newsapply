# 新闻 App 第一版技术栈

## 产品边界

第一版只做“每日 10 条公共新闻”，不做个性化推荐、不做猜你喜欢、不做无限信息流。所有用户在同一地区和语言版本下看到同一组新闻。

## 技术栈总览

| 模块 | 选型 | 用途 |
| --- | --- | --- |
| iOS / Android 端 | Expo + React Native + TypeScript | 同一套代码发布 iOS / Android，开发速度快 |
| HarmonyOS NEXT 端 | ArkTS + ArkUI + DevEco Studio | 纯血鸿蒙原生实现，适配 HM 生态 |
| iOS / Android 导航 | Expo Router | App 页面路由、详情页、设置页 |
| HarmonyOS NEXT 导航 | Navigation / Router | 鸿蒙端页面跳转和栈管理 |
| iOS / Android UI | React Native Paper 或 Tamagui | 快速搭建稳定的移动端界面 |
| HarmonyOS NEXT UI | ArkUI 声明式组件 | 使用系统原生组件和交互规范 |
| iOS / Android 状态管理 | TanStack Query | 请求缓存、刷新、离线容错 |
| HarmonyOS NEXT 状态管理 | ArkTS 状态装饰器 + 本地缓存封装 | 管理页面状态、今日新闻缓存、设置项 |
| 后端 | Supabase | Postgres 数据库、Auth 预留、Edge Functions |
| 数据库 | Supabase Postgres | 存新闻、每日版本、来源、入选理由 |
| 定时任务 | Supabase Scheduled Edge Functions | 每天生成一期“每日 10 条” |
| 内容抓取 | Edge Function / 独立 Node.js worker | 抓取 RSS/API，做去重和基础过滤 |
| 管理后台 | Next.js + TypeScript | 编辑审核、手动调整每日 10 条 |
| 部署 | Vercel + Supabase | 后台部署到 Vercel，数据和函数在 Supabase |
| 监控 | Sentry + Supabase Logs | 移动端错误、后端任务日志 |
| 分析 | PostHog 或 Plausible | 只看整体访问数据，不做用户画像 |

## 为什么这样选

### 1. Expo + React Native

第一版需要尽快验证体验，Expo 可以用一个 TypeScript 项目覆盖 iOS 和 Android。新闻 App 的主要页面是列表、详情、设置和收藏，React Native 足够合适。

### 2. ArkTS + ArkUI

如果要部署到纯血 HarmonyOS NEXT，鸿蒙端建议原生开发。ArkTS 是 HarmonyOS 应用开发的主力语言，ArkUI 是声明式 UI 框架，能直接使用鸿蒙系统能力、系统组件、权限模型和应用分发链路。

这意味着移动端会有两套 UI 工程：`mobile` 负责 iOS / Android，`harmony` 负责 HarmonyOS NEXT。但新闻数据、每日 10 条生成规则、管理后台和 API 都共用同一套后端，避免产品逻辑分裂。

### 3. Supabase

这个项目的数据结构清晰：新闻、来源、每日版本、每日 10 条。Supabase 的 Postgres 很适合做可审计的数据表，也方便后续加管理后台和权限控制。

### 4. Scheduled Edge Functions

每天固定时间生成一期内容，适合放到服务端定时任务里执行。任务逻辑不依赖用户行为，只根据公开规则挑选新闻。

### 5. Next.js 管理后台

第一版建议保留编辑审核能力。即使大部分流程自动化，也应该允许人工查看、替换、下架新闻，避免错误内容直接进入当天版本。

## 多端架构原则

客户端只负责展示和轻量缓存，不在本地做推荐排序。所有端都调用同一套公共 API：

```text
GET /editions/today?region=cn&language=zh-CN
GET /editions/:date?region=cn&language=zh-CN
GET /articles/:id
GET /sources
```

API 返回的新闻顺序由后端每日版本决定，iOS、Android、HarmonyOS NEXT 端都不能根据用户行为重排。

## 第一版 App 页面

1. 今日十条
2. 新闻详情
3. 来源说明
4. 非个性化说明
5. 设置：地区、语言、字号、深色模式

## 第一版后台页面

1. 新闻池
2. 今日候选
3. 每日 10 条编辑页
4. 来源管理
5. 发布记录

## 数据表设计

```sql
sources
- id
- name
- url
- type
- reliability_note
- enabled
- created_at

articles
- id
- source_id
- title
- summary
- url
- category
- topic_key
- published_at
- fetched_at
- status

daily_editions
- id
- edition_date
- region
- language
- status
- generated_at
- published_at

daily_edition_items
- id
- edition_id
- article_id
- position
- selection_reason
- created_at
```

## 非个性化规则

第一版推荐使用固定配额，而不是用户行为排序：

| 类别 | 数量 |
| --- | --- |
| 国内 / 本地公共事务 | 2 |
| 国际 | 2 |
| 财经 / 民生 | 1 |
| 科技 / 科学 | 1 |
| 社会 / 法治 | 1 |
| 文化 / 教育 / 健康 | 1 |
| 体育 / 生活方式 | 1 |
| 编辑补充视角 | 1 |

每条新闻需要保存 `selection_reason`，例如：

- 多家可靠来源报道
- 涉及重大公共利益
- 与今日主要议题形成补充视角
- 来自不同地区或不同主题，避免单一信息面

## 明确不做

- 不做个性化推荐
- 不做按点击率给用户重排
- 不做猜你喜欢
- 不做无限下滑信息流
- 不用用户阅读历史生成兴趣标签
- 不向第三方广告平台发送可识别阅读偏好

## 推荐目录结构

```text
news-app/
  apps/
    mobile/          # Expo App，覆盖 iOS / Android
    harmony/         # HarmonyOS NEXT App，ArkTS + ArkUI
    admin/           # Next.js 管理后台
  packages/
    shared/          # 共享类型、校验 schema、工具函数
    api-client/      # 公共 API 契约和请求封装
  supabase/
    migrations/      # 数据库迁移
    functions/       # 抓取、生成每日十条、发布任务
  docs/
    product.md
    non-personalization.md
```

## 第一阶段里程碑

1. 建立 Supabase 表结构
2. 接入 10-20 个新闻源
3. 实现抓取、去重、分类入库
4. 实现每日 10 条生成任务
5. 实现管理后台审核和发布
6. 实现 Expo 移动端读取和展示
7. 实现 HarmonyOS NEXT 端读取和展示
8. 上线非个性化说明页

## 官方文档参考

- Expo: https://docs.expo.dev/
- HarmonyOS ArkTS: https://developer.huawei.com/consumer/cn/arkts/devstart/
- HarmonyOS ArkUI: https://developer.huawei.com/consumer/cn/arkui/
- Supabase Scheduled Functions: https://supabase.com/docs/guides/functions/schedule-functions
- Next.js App Router: https://nextjs.org/docs/app
- Cloudflare Workers Cron Triggers: https://developers.cloudflare.com/workers/configuration/cron-triggers/
