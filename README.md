# Newsapply

第一版新闻 App：每天 10 条公共新闻，不做个性化推荐。

## 目录

```text
apps/web       Web 预览页，可部署到 Vercel
apps/harmony   HarmonyOS NEXT / ArkTS 客户端骨架
apps/editor    本地审核台，从候选池挑 10 条
apps/admin     本地管理后台，发布每日版本
supabase       数据库迁移和 Edge Function API
```

## Web 预览

```bash
cd apps/web
python3 -m http.server 4173
```

## Supabase API

```text
https://rrufsrfkmypxvwyggtwm.supabase.co/functions/v1/editions/today?region=cn&language=zh-CN
```

App 请求时使用：

```text
Accept: application/json
```

## 每日生产数据

第一版使用 RSS 候选池 + 人工审核的公共编辑流程，不做个性化推荐：

```bash
node scripts/fetch-candidates.mjs --date 2026-06-02
node scripts/list-candidates.mjs data/candidates.2026-06-02.json
node scripts/make-edition-from-candidates.mjs data/candidates.2026-06-02.json --pick 3,7,11,14,18,21,25,29,31,34
node scripts/publish-edition.mjs data/daily-edition.2026-06-02.json --dry-run
SUPABASE_URL=https://rrufsrfkmypxvwyggtwm.supabase.co DAILYTEN_SUPABASE_SECRET_KEY=<service-role-key> node scripts/publish-edition.mjs data/daily-edition.2026-06-02.json --publish
```

发布说明见：

```text
docs/PRODUCTION_DATA_FLOW.md
```

## 本地审核台

```bash
python3 -m http.server 4180 --directory apps/editor
```

打开：

```text
http://127.0.0.1:4180
```

## 本地管理后台

```bash
python3 -m http.server 4190 --bind 127.0.0.1 --directory apps/admin
```

打开：

```text
http://127.0.0.1:4190
```

说明见：

```text
docs/ADMIN_DASHBOARD.md
```

## 每日自动草稿

电脑保持开机时，可以让自动任务每天运行：

```bash
node scripts/daily-auto-draft.mjs
```

它只生成候选池和待审核草稿，不会自动发布到 Supabase。

## AI 编辑助理

```bash
node scripts/ai-draft-edition.mjs data/candidates.2026-06-03.json
```

默认使用 DeepSeek API。需要在 `.env` 设置：

```text
AI_API_KEY=<你的 DeepSeek API Key>
AI_API_URL=https://api.deepseek.com/chat/completions
AI_MODEL=deepseek-v4-flash
```

它只生成待审核草稿，不会自动发布。
