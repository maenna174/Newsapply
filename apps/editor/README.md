# 今日十条审核台

本目录是本地静态审核界面，用来从 `data/candidates.<date>.json` 里挑 10 条新闻并导出 `data/daily-edition.<date>.json`。

```bash
python3 -m http.server 4180 --directory apps/editor
```

打开：

```text
http://127.0.0.1:4180
```

页面只在浏览器本地处理候选 JSON，不保存或上传 `service_role`。
