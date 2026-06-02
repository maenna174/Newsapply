# 管理后台

## 功能

第一版管理后台提供：

- 导入每日版本 JSON
- 远程校验 10 条新闻格式
- 发布或保存每日版本
- 查看最近版本
- 读取 AI API 配置、测试 AI 连接
- 在管理后台填写并保存 AI API 地址、模型、Key
- 导入候选池 JSON，让 AI 生成每日草稿

管理后台不会接触 Supabase `service_role`。页面只使用 `DAILYTEN_ADMIN_TOKEN` 调用 Supabase Edge Function，真正的数据写入由 `supabase/functions/admin` 在服务端完成。
DeepSeek API Key 会由 admin Function 保存到服务端配置表。网页后台读取配置时只显示“是否已配置”和脱敏尾号，不会回显完整 Key。

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

这会创建 `app_settings` 表，用于后端保存 AI API 配置。

4. 如果不想在后台页面填写，也可以继续用 Supabase Secret 设置 DeepSeek：

```bash
npx supabase secrets set AI_API_KEY=<你的 DeepSeek API Key>
npx supabase secrets set AI_API_URL=https://api.deepseek.com/chat/completions
npx supabase secrets set AI_MODEL=deepseek-v4-flash
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
API 地址: https://api.deepseek.com/chat/completions
模型: deepseek-v4-flash
API Key: 你的 DeepSeek API Key
```

API 地址也可以按 DeepSeek 文档填写 base URL：

```text
https://api.deepseek.com
```

后端会自动转成 `/chat/completions` 接口。

点“保存 API”，再点“测试 AI”。

## 每日发布流程

1. 自动任务生成 `data/daily-edition.<date>.json`
2. 打开审核台微调 10 条新闻
3. 打开管理后台
4. 首次使用时，在“AI API 接入”保存 DeepSeek 配置并测试
5. 如果使用 AI，先导入 `data/candidates.<date>.json`，点“生成草稿”
6. 检查草稿内容，必要时手工修改每日 JSON
7. 点“远程校验”
8. 点“发布/保存”
9. App、Web 会继续读取同一个 `/editions/today` API

## 安全注意

- 不要把 `DAILYTEN_ADMIN_TOKEN` 提交到 GitHub。
- 不要把 Supabase `service_role` 填到网页后台。
- 管理后台第一版建议只在本地打开，不建议公开部署。
