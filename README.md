# Newsapply

第一版新闻 App：每天 10 条公共新闻，不做个性化推荐。

## 目录

```text
apps/web       Web 预览页，可部署到 Vercel
apps/harmony   HarmonyOS NEXT / ArkTS 客户端骨架
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
