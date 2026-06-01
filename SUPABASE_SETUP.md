# Supabase 使用步骤

## 你在本项目里用 Supabase 做什么

Supabase 在这个新闻 App 里负责：

- Postgres 数据库：存新闻源、新闻池、每日十条
- Edge Functions：提供 App 调用的公共 API
- 定时任务：后续每天生成一期新闻
- 权限控制：普通 App 只能读已发布版本，后台才能写

## 第 1 步：创建 Supabase 项目

1. 打开 https://supabase.com/
2. 登录后创建一个新项目
3. 选择离主要用户更近的 region
4. 保存这些信息：

```text
Project URL
Project Ref
anon / publishable key
service_role key
database password
```

`service_role key` 只能放在服务端或 Supabase secrets 里，不能放进 App。

## 第 2 步：安装或使用 Supabase CLI

本机目前没有全局 `supabase` 命令，但有 `npx`，可以直接用：

```bash
npx supabase --version
```

Supabase 官方文档要求通过 CLI 登录、链接项目、推送数据库迁移和部署 Edge Functions。

## 第 3 步：登录并链接远程项目

在项目根目录执行：

```bash
cd /Users/mac/news
npx supabase login
npx supabase link --project-ref <your-project-ref>
```

`project-ref` 可以在 Supabase Dashboard 的项目 URL 或 Project Settings 里找到。

## 第 4 步：推送数据库表结构

本项目已经有迁移文件：

```text
supabase/migrations/001_daily_news.sql
```

推送到远程 Supabase：

```bash
npx supabase db push
```

如果要顺便导入初始新闻源：

```bash
npx supabase db push --include-seed
```

seed 文件位置：

```text
supabase/seed.sql
```

## 第 5 步：部署每日新闻 API

本项目已经有 Edge Function：

```text
supabase/functions/editions/index.ts
```

部署：

```bash
npx supabase functions deploy editions
```

部署成功后，API 地址类似：

```text
https://<your-project-ref>.supabase.co/functions/v1/editions/today?region=cn&language=zh-CN
```

## 第 6 步：设置 Function secrets

Edge Function 需要读数据库。Supabase 默认会提供 `SUPABASE_URL`，但建议确认并设置服务端密钥：

```bash
npx supabase secrets set DAILYTEN_SUPABASE_SECRET_KEY=<your-service-role-key>
```

不要把 `service_role` 放到 HarmonyOS、iOS、Android 客户端。

## 第 7 步：插入一版测试数据

第一版可以先在 Supabase Dashboard 的 SQL Editor 里手动插入：

1. `sources`
2. `articles`
3. `daily_editions`
4. `daily_edition_items`

只要有一条 `daily_editions.status = 'published'`，App 就可以通过 `/editions/today` 读取。

## 第 8 步：HM 端调用

HM 端后续把 mock 数据换成：

```text
GET https://<your-project-ref>.supabase.co/functions/v1/editions/today?region=cn&language=zh-CN
```

返回结构见：

```text
API_DESIGN.md
```

## 注意事项

- App 使用 `anon / publishable key` 或直接访问公开 Edge Function
- 管理后台和定时任务才使用服务端密钥
- 新闻排序只来自 `daily_edition_items.position`
- API 不接收 `user_id`、兴趣标签、阅读历史
- 不要让客户端直接写 `articles` 或 `daily_editions`

## 官方文档

- Supabase CLI: https://supabase.com/docs/guides/cli
- Database Migrations: https://supabase.com/docs/guides/deployment/database-migrations
- Edge Functions: https://supabase.com/docs/guides/functions
- Deploy Edge Functions: https://supabase.com/docs/guides/functions/deploy
- Scheduled Functions: https://supabase.com/docs/guides/functions/schedule-functions
