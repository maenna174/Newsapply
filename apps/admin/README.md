# 今日十条管理后台

这是管理后台，用于生成、编辑、校验和发布每日 10 条新闻。当前线上部署使用自托管 Node API：

```text
http://121.37.178.24/admin-ui/
```

## 本地打开

```bash
python3 -m http.server 4190 --bind 127.0.0.1 --directory apps/admin
```

打开：

```text
http://127.0.0.1:4190
```

## 使用

1. 打开管理后台。
2. Admin Function URL 使用：

```text
http://121.37.178.24/functions/v1/admin
```

3. 填写 `DAILYTEN_ADMIN_TOKEN`。
4. 点“检查连接”。
5. 在“AI API 接入”里填写 DeepSeek API Key，点“保存 API”。后端固定使用 `https://api.deepseek.com/chat/completions` 和 `deepseek-v4-pro`。
6. 点“测试 AI”。
7. 导入 `data/candidates.<date>.json`，点“生成草稿”；或者在“最近版本”里点“编辑”载入自动生成的 draft。
8. 在“草稿可视化编辑”里直接修改标题、摘要、来源、分类、发布时间和入选理由。
9. 点“远程校验”。
10. 点“发布/保存”。

## 每日自动草稿

服务器上已启用 systemd timer：

```bash
systemctl status dailyten-ai-draft.timer
journalctl -u dailyten-ai-draft.service -n 80 --no-pager
```

每天 `08:10` 会执行：

```bash
cd /opt/newsapply
node scripts/daily-ai-draft.mjs --limit 50
```

它会抓取 50 条候选、调用 AI 生成 10 条草稿、dry-run 校验，并保存为数据库里的 `draft`，等待人工审核发布。
