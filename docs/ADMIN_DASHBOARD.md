# 管理后台

## 功能

第一版管理后台提供：

- 导入每日版本 JSON
- 远程校验 10 条新闻格式
- 发布或保存每日版本
- 查看最近版本
- 点击最近版本里的“编辑”，载入 draft/published 版本
- 在“草稿可视化编辑”里修改 10 条新闻
- 一键载入今日草稿、质量检查、发布今日草稿
- 读取 AI API 配置、测试 AI 连接
- 在管理后台填写并保存 DeepSeek API Key
- 导入候选池 JSON，让 AI 生成每日草稿

管理后台不会接触数据库密码或 Supabase `service_role`。页面只使用 `DAILYTEN_ADMIN_TOKEN` 调用服务端 Admin API，真正的数据写入由服务端完成。
DeepSeek API Key 会由 admin Function 保存到服务端配置表。网页后台读取配置时只显示“是否已配置”和脱敏尾号，不会回显完整 Key。接口地址固定为 `https://api.deepseek.com/chat/completions`，模型固定为 `deepseek-v4-pro`。

## 本地启动

```bash
python3 -m http.server 4190 --bind 127.0.0.1 --directory apps/admin
```

打开：

```text
http://127.0.0.1:4190
```

## 部署后台 API

1. 生成管理 token：

```bash
openssl rand -hex 32
```

2. 设置 Supabase secret：

```bash
npx supabase secrets set DAILYTEN_ADMIN_TOKEN=<生成的随机值>
```

3. 应用数据库迁移：

```bash
npx supabase db push
```

这会创建 `app_settings` 表，用于后端保存 DeepSeek API Key。

4. 如果不想在后台页面填写，也可以继续用 Supabase Secret 设置 DeepSeek：

```bash
npx supabase secrets set AI_API_KEY=<你的 DeepSeek API Key>
```

5. 部署函数：

```bash
npx supabase functions deploy admin --no-verify-jwt
```

6. 在后台页面填写：

```text
Admin Function URL: https://rrufsrfkmypxvwyggtwm.supabase.co/functions/v1/admin
ADMIN_TOKEN: 上面生成的随机值
```

然后在“AI API 接入”里填写：

```text
API Key: 你的 DeepSeek API Key
```

点“保存 API”，再点“测试 AI”。

## 每日发布流程

1. 服务器定时任务每天生成 `data/candidates.<date>.json`
2. 自动调用 AI 生成 `data/daily-edition.<date>.ai-draft.json`
3. 自动 dry-run 校验，并保存为数据库 `draft`
4. 打开管理后台，在“最近版本”里点“编辑”
5. 在“草稿可视化编辑”里微调 10 条新闻
6. 点“质量检查”，检查标题、摘要、来源集中度、分类集中度、重复链接、发布时间等问题
7. 点“发布今日草稿”，如果只有提醒项，可确认后发布；如果有错误项，需要先修正
8. App、Web 会继续读取同一个 `/editions/today` API

## 服务器自动草稿

服务器上使用 systemd timer 自动运行：

```bash
systemctl status dailyten-ai-draft.timer
journalctl -u dailyten-ai-draft.service -n 80 --no-pager
```

计划时间：

```text
每天 08:10，Asia/Shanghai
```

执行内容：

```bash
cd /opt/newsapply
node scripts/daily-ai-draft.mjs --limit 50
```

## 自动审核并发布

如果要完全自动化，可以把定时任务切换到：

```bash
cd /opt/newsapply
node scripts/daily-auto-publish.mjs --limit 50 --allow-warnings
```

这个脚本会依次执行：

1. 抓取候选池
2. 调用 AI 生成 10 条 draft
3. 调用后台质量检查
4. 没有阻断错误时发布 draft

`--allow-warnings` 只允许提醒项自动通过；结构错误、重复链接、不是 10 条等阻断错误仍会失败并保留 draft。
如果希望更保守，可以去掉 `--allow-warnings`，有任何提醒项时都不自动发布。

## 安全注意

- 不要把 `DAILYTEN_ADMIN_TOKEN` 提交到 GitHub。
- 不要把 Supabase `service_role` 填到网页后台。
- 管理后台第一版建议只在本地打开，不建议公开部署。
