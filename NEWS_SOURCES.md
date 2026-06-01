# 第一版推荐新闻源

## 接入原则

第一版只建议接入“标题、摘要、链接、发布时间、来源”这些元数据，不建议未经授权抓取全文、图片或视频。商业化上线前，需要逐一确认新闻源的使用条款或采购授权。

优先级：

1. 有官方 RSS、API 或正式供稿接口
2. 来源稳定，能覆盖公共议题
3. 不依赖用户画像或平台热榜
4. 能保留原始链接和来源署名
5. 不把社交媒体爆料作为主新闻源

## 建议第一批接入

| 来源 | 推荐用途 | 接入方式 | 备注 |
| --- | --- | --- | --- |
| 中国新闻网 | 国内、社会、财经、国际中文报道 | 官方 RSS | 适合作为中文综合新闻池 |
| 人民网 | 时政、社会、政策解读 | 官方 RSS / 栏目页 | 适合作为国内公共事务来源 |
| 新华网 | 国内、国际、权威通稿 | 官方站点 / RSS 页面 / 供稿服务 | 商业使用优先走授权或供稿 |
| 中国政府网 | 政策、国务院信息、部委动态 | 官方站点 | 不作为普通新闻流，适合政策类补充 |
| 中国领事服务网 | 出行提醒、海外安全提醒 | 官方 RSS | 适合国际/公共安全补充 |
| 工业和信息化部 | 科技产业、工业政策 | 官方 RSS | 适合科技/产业类公共信息 |
| BBC News | 国际、科技、健康、商业 | 官方 RSS | 适合作为国际视角来源 |
| Reuters | 国际、财经、商业 | 商业授权 / 数据服务优先 | 不建议未授权抓全文 |
| Associated Press | 国际、美国、突发 | 商业授权 / 官方站点 | 公共 RSS 状态不稳定，商业化需授权 |
| Al Jazeera English | 国际、中东、全球南方视角 | RSS / 官方站点 | 作为国际视角补充 |
| 联合国新闻中文 | 国际组织、人道、气候、发展 | 官方站点 / RSS 服务 | 适合降低单一媒体视角 |
| WHO | 公共卫生、全球健康 | 官方 newsroom / RSS | 健康类新闻优先来源 |
| NASA | 科学、航天、地球观测 | 官方 RSS | 适合科学/科技类别 |
| World Bank | 经济发展、全球数据、发展议题 | 官方新闻页 | 适合财经/国际发展补充 |

## 第一版分类配额建议

| 每日类别 | 备选来源 |
| --- | --- |
| 国内 / 本地公共事务 | 中国新闻网、人民网、新华网、中国政府网 |
| 国际 | BBC News、Reuters、AP、Al Jazeera、联合国新闻 |
| 财经 / 民生 | 中国新闻网、Reuters、World Bank |
| 科技 / 科学 | 工业和信息化部、NASA、BBC Technology |
| 社会 / 法治 | 中国新闻网、人民网、BBC |
| 文化 / 教育 / 健康 | WHO、BBC Health、中国新闻网 |
| 体育 / 生活方式 | BBC Sport、综合新闻源体育栏目 |
| 编辑补充视角 | 联合国新闻、World Bank、专题机构来源 |

## 不建议第一版使用

- 未授权全文镜像站
- 只靠爬虫生成的第三方 RSS
- 社交平台热搜
- 个性化聚合平台推荐流
- 无来源署名的自媒体搬运号
- 付费媒体的全文绕过抓取

## 最小可行组合

如果只先接 8 个，建议：

1. 中国新闻网
2. 人民网
3. 新华网
4. BBC News
5. Reuters 或 AP，优先采购授权
6. Al Jazeera English
7. WHO
8. NASA

这样可以先覆盖国内、国际、财经、科技、健康、科学几个基本面，同时保持来源多样性。

## 参考入口

- 中国新闻网 RSS: https://www.chinanews.com.cn/rss/
- 人民网 RSS: https://politics.people.com.cn/ywkx/GB/368825/index.html
- 新华网: https://www.news.cn/linktous.htm
- 中国领事服务网 RSS: https://cs.mfa.gov.cn/rss/
- 工业和信息化部 RSS: https://wap.miit.gov.cn/RRSdy/
- BBC News feeds: https://feeds.bbci.co.uk/news/10628494
- Thomson Reuters RSS / alerts: https://ir.thomsonreuters.com/rss-feeds
- ABC News RSS: https://abcnews.com/Site/page/rss-feeds-3520115
- 联合国新闻中文: https://news.un.org/zh
- WHO Newsroom: https://www.who.int/news-room
- NASA RSS: https://www.nasa.gov/?p=539799
- World Bank News: https://www.worldbank.org/ext/en/news
