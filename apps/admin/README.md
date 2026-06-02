# 今日十条管理后台

这是第一版管理后台，用于把审核后的 `data/daily-edition.<date>.json` 写入 Supabase。

## 本地打开

```bash
python3 -m http.server 4190 --bind 127.0.0.1 --directory apps/admin
```

打开：

```text
http://127.0.0.1:4190
```

## 上线前准备

部署 admin Edge Function：

```bash
npx supabase functions deploy admin --no-verify-jwt
```

设置管理 token：

```bash
openssl rand -hex 32
npx supabase secrets set DAILYTEN_ADMIN_TOKEN=<上一步生成的随机值>
```

`DAILYTEN_ADMIN_TOKEN` 是管理后台登录口令，不是 Supabase `service_role`。`service_role` 继续只放在 Supabase Function secrets 中。

应用数据库迁移：

```bash
npx supabase db push
```

这会创建 `app_settings` 表。之后可以直接在后台“AI API 接入”里填写 DeepSeek API 地址、模型、Key 并保存。
网页后台不会回显完整 DeepSeek Key，只会显示脱敏状态。

## 使用

1. 打开管理后台。
2. 填写 Admin Function URL：

```text
https://rrufsrfkmypxvwyggtwm.supabase.co/functions/v1/admin
```

3. 填写 `DAILYTEN_ADMIN_TOKEN`。
4. 点“检查连接”。
5. 可选：在“AI API 接入”里填写 API 地址、模型、Key，点“保存 API”。
6. 点“测试 AI”。
7. 导入 `data/candidates.<date>.json`，点“生成草稿”。
8. 检查生成的每日版本 JSON。
9. 点“远程校验”。
10. 点“发布/保存”。
