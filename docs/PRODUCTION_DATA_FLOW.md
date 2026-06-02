# 生产数据流程

## 第一版目标

每天发布一个公共版本，每版固定 10 条新闻。客户端只读取服务端发布好的顺序，不根据用户点击、停留、收藏或搜索历史重排。

```text
新闻源 / RSS / 人工收集
  ↓
生成候选池 data/candidates.<date>.json
  ↓
编辑筛选 10 条
  ↓
填写 data/daily-edition.<date>.json
  ↓
本地校验
  ↓
写入 Supabase
  ↓
App / Web 读取 editions API
```

## 每天怎么发布

如果使用自动任务，早上会自动完成候选池和草稿生成：

```bash
node scripts/daily-auto-draft.mjs
```

它会生成：

```text
data/candidates.<date>.json
data/daily-edition.<date>.json
```

自动任务不会发布到 Supabase。

如果要用 AI 编辑助理生成草稿：

```bash
node scripts/ai-draft-edition.mjs data/candidates.2026-06-03.json
```

默认接入 DeepSeek API：

```text
AI_API_URL=https://api.deepseek.com/chat/completions
AI_MODEL=deepseek-v4-flash
```

AI 只读取候选池，按公共编辑规则选出 10 条，不使用用户画像。生成结果仍需在审核台或管理后台中人工确认。

手动流程如下。

1. 抓取 RSS 候选池：

```bash
node scripts/fetch-candidates.mjs --date 2026-06-02
```

2. 查看候选清单：

```bash
node scripts/list-candidates.mjs data/candidates.2026-06-02.json
```

也可以使用本地审核台：

```bash
python3 -m http.server 4180 --directory apps/editor
```

打开 `http://127.0.0.1:4180`，导入 `data/candidates.2026-06-02.json`，选择 10 条后导出每日 JSON。

3. 从候选清单里挑 10 个 `candidateId`，生成每日草稿：

```bash
node scripts/make-edition-from-candidates.mjs \
  data/candidates.2026-06-02.json \
  --pick 3,7,11,14,18,21,25,29,31,34
```

也可以先让脚本按固定公共配额生成一版草稿，再人工改：

```bash
node scripts/make-edition-from-candidates.mjs \
  data/candidates.2026-06-02.json \
  --auto-draft
```

4. 打开 `data/daily-edition.2026-06-02.json` 做人工确认。

每条新闻必须包含：

- 标题
- 摘要
- 原文链接
- 来源名称和首页
- 分类
- 发布时间
- 入选理由

5. 本地校验：

```bash
node scripts/publish-edition.mjs data/daily-edition.2026-06-02.json --dry-run
```

如果校验提示摘要太短、链接重复、分类不合法，先修改 `data/daily-edition.2026-06-02.json`，再重新 dry-run。RSS 候选只是素材池，不等于可以无审核发布。

6. 发布到 Supabase：

```bash
SUPABASE_URL=https://rrufsrfkmypxvwyggtwm.supabase.co \
DAILYTEN_SUPABASE_SECRET_KEY=<service-role-key> \
node scripts/publish-edition.mjs data/daily-edition.2026-06-02.json --publish
```

也可以把这两个变量放到本地 `.env`。`.env` 已被 `.gitignore` 忽略，不能提交。

7. 验证 API：

```bash
curl "https://rrufsrfkmypxvwyggtwm.supabase.co/functions/v1/editions/today?region=cn&language=zh-CN"
```

## 选题规则

第一版使用“公共编辑规则”，不使用个性化推荐算法。

建议配额：

- 国内 / 公共服务：1-2 条
- 国际：1 条
- 财经：1 条
- 科技 / 科学：1 条
- 健康 / 教育：1-2 条
- 社会民生：1-2 条
- 体育 / 文化 / 长期议题：1-2 条

单一来源每天不超过 3 条。单一主题每天不超过 2 条。第 8-10 位可用于补充长期议题，避免所有注意力被突发热点占满。

## 数据安全

- `service_role` 只能在本地发布脚本、Supabase Functions、Vercel Server/CI 中使用。
- HarmonyOS、网页前端、移动端不能保存 `service_role`。
- 客户端只读 `editions` API。
- 发布脚本只保存元数据，不保存未授权全文。

## 失败处理

如果发布错了：

1. 修正同一个 `data/daily-edition.<date>.json`
2. 重新执行 `--publish`

脚本会按日期、地区、语言覆盖同一期的 10 条排序，不会创建重复版本。

如果要临时下架，可以在 Supabase SQL Editor 执行：

```sql
update daily_editions
set status = 'draft',
    updated_at = now()
where edition_date = '2026-06-02'
  and region = 'cn'
  and language = 'zh-CN';
```

## 后续升级

第二版可以把候选池写入 Supabase：

- 检查 robots.txt 和抓取频率
- 写入 `articles`，状态为 `candidate`
- 编辑从候选池中挑 10 条发布

即便接入爬虫，最终每日版本仍由固定公共规则和编辑审核决定。
