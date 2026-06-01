# 今日十条 Web 预览页

Supabase Edge Functions 托管版不适合直接返回 HTML 页面。官方限制会把 `text/html` 改成 `text/plain`，所以浏览器会显示源码。

这个目录是独立的静态网页，负责渲染界面；数据仍来自 Supabase API：

```text
https://rrufsrfkmypxvwyggtwm.supabase.co/functions/v1/editions/today?region=cn&language=zh-CN
```

本地预览：

```bash
cd /Users/mac/news/apps/web
python3 -m http.server 4173
```

部署时可以直接把 `apps/web` 部署到 Vercel。
