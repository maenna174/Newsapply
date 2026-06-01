import { MOCK_ARTICLES, TODAY_EDITION } from '../data/MockNewsData';
import { EditionMeta, NewsArticle } from '../model/NewsModels';

@Entry
@ComponentV2
struct Index {
  @Local activeTab: string = 'today';
  @Local selectedArticleId: string = '';
  @Local lastUpdatedText: string = '刚刚';

  private articles: NewsArticle[] = MOCK_ARTICLES;
  private edition: EditionMeta = TODAY_EDITION;

  private getSelectedArticle(): NewsArticle {
    for (let index = 0; index < this.articles.length; index++) {
      const article = this.articles[index];
      if (article.id === this.selectedArticleId) {
        return article;
      }
    }
    return this.articles[0];
  }

  build() {
    Navigation() {
      if (this.selectedArticleId.length > 0) {
        this.DetailScreen(this.getSelectedArticle())
      } else {
        this.HomeScreen()
      }
    }
    .mode(NavigationMode.Stack)
    .hideToolBar(true)
    .hideTitleBar(true)
  }

  @Builder
  private HomeScreen() {
    Column() {
      this.AppHeader()
      this.TabBar()

      if (this.activeTab === 'today') {
        this.TodayScreen()
      } else {
        this.PrincipleScreen()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F6F7F2')
  }

  @Builder
  private AppHeader() {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 4 }) {
          Text('今日十条')
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor('#202124')

          Text(`${this.edition.editionDate} ${this.edition.publishedAt} 发布`)
            .fontSize(13)
            .fontColor('#687076')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text('10')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F6F7F2')
          .width(52)
          .height(52)
          .textAlign(TextAlign.Center)
          .backgroundColor('#2E6F57')
          .borderRadius(26)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.edition.statement)
        .fontSize(14)
        .lineHeight(21)
        .fontColor('#3D454D')
        .width('100%')
        .padding({ left: 14, right: 14, top: 12, bottom: 12 })
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 28, bottom: 12 })
  }

  @Builder
  private TabBar() {
    Row({ space: 8 }) {
      Button('今日')
        .height(38)
        .layoutWeight(1)
        .borderRadius(8)
        .fontSize(15)
        .fontColor(this.activeTab === 'today' ? '#FFFFFF' : '#2E6F57')
        .backgroundColor(this.activeTab === 'today' ? '#2E6F57' : '#E4EEE9')
        .onClick(() => {
          this.activeTab = 'today';
        })

      Button('原则')
        .height(38)
        .layoutWeight(1)
        .borderRadius(8)
        .fontSize(15)
        .fontColor(this.activeTab === 'principle' ? '#FFFFFF' : '#8A4D16')
        .backgroundColor(this.activeTab === 'principle' ? '#C9832B' : '#F3E7D5')
        .onClick(() => {
          this.activeTab = 'principle';
        })
    }
    .width('100%')
    .padding({ left: 18, right: 18, bottom: 8 })
  }

  @Builder
  private TodayScreen() {
    Scroll() {
      Column({ space: 12 }) {
        Row() {
          Text(`${this.edition.region} / ${this.edition.language}`)
            .fontSize(13)
            .fontColor('#687076')
            .layoutWeight(1)

          Text(`更新：${this.lastUpdatedText}`)
            .fontSize(13)
            .fontColor('#687076')
        }
        .width('100%')

        ForEach(this.articles, (article: NewsArticle, index: number) => {
          this.ArticleCard(article, index)
        }, (article: NewsArticle) => article.id)

        Text('所有新闻条目的顺序由服务端每日版本决定，本端不会根据点击、停留或收藏进行重排。')
          .fontSize(12)
          .lineHeight(18)
          .fontColor('#7A8288')
          .textAlign(TextAlign.Center)
          .width('100%')
          .padding({ top: 8, bottom: 22 })
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 4 })
    }
    .layoutWeight(1)
  }

  @Builder
  private ArticleCard(article: NewsArticle, index: number) {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Text(`${index + 1}`)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .width(32)
          .height(32)
          .textAlign(TextAlign.Center)
          .backgroundColor(index < 3 ? '#B34B45' : '#2E6F57')
          .borderRadius(16)

        Column({ space: 4 }) {
          Text(article.title)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#202124')
            .lineHeight(25)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Row({ space: 8 }) {
            this.Tag(article.category, '#E4EEE9', '#2E6F57')
            Text(article.source)
              .fontSize(12)
              .fontColor('#687076')
            Text(article.publishedAt)
              .fontSize(12)
              .fontColor('#687076')
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Text(article.summary)
        .fontSize(14)
        .fontColor('#3D454D')
        .lineHeight(21)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(`入选理由：${article.selectionReason}`)
        .fontSize(12)
        .fontColor('#8A4D16')
        .lineHeight(18)
        .padding({ left: 10, right: 10, top: 8, bottom: 8 })
        .backgroundColor('#F3E7D5')
        .borderRadius(8)
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .onClick(() => {
      this.selectedArticleId = article.id;
    })
  }

  @Builder
  private DetailScreen(article: NewsArticle) {
    Column() {
      Row() {
        Button('返回')
          .height(36)
          .fontSize(14)
          .fontColor('#2E6F57')
          .backgroundColor('#E4EEE9')
          .borderRadius(8)
          .onClick(() => {
            this.selectedArticleId = '';
          })

        Blank()

        Text(article.readingTime)
          .fontSize(13)
          .fontColor('#687076')
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 28, bottom: 12 })

      Scroll() {
        Column({ space: 16 }) {
          Row({ space: 8 }) {
            this.Tag(article.category, '#E4EEE9', '#2E6F57')
            this.Tag(article.source, '#F3E7D5', '#8A4D16')
          }
          .width('100%')

          Text(article.title)
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#202124')
            .lineHeight(36)
            .width('100%')

          Text(`${article.publishedAt} / ${article.source}`)
            .fontSize(13)
            .fontColor('#687076')
            .width('100%')

          Divider()
            .color('#D9DED8')

          Text(article.summary)
            .fontSize(17)
            .fontColor('#30363C')
            .lineHeight(27)
            .width('100%')

          Column({ space: 8 }) {
            Text('为什么出现')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#202124')

            Text(article.selectionReason)
              .fontSize(14)
              .fontColor('#3D454D')
              .lineHeight(22)
          }
          .width('100%')
          .padding(14)
          .backgroundColor('#FFFFFF')
          .borderRadius(8)
          .alignItems(HorizontalAlign.Start)

          Column({ space: 8 }) {
            Text('原文链接')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#202124')

            Text(article.url)
              .fontSize(13)
              .fontColor('#2E6F57')
              .lineHeight(20)
              .width('100%')
          }
          .width('100%')
          .padding(14)
          .backgroundColor('#FFFFFF')
          .borderRadius(8)
          .alignItems(HorizontalAlign.Start)

          Text('第一版只展示摘要与来源链接，正式上线前需要确认每个来源的转载、摘要和图片使用授权。')
            .fontSize(12)
            .fontColor('#7A8288')
            .lineHeight(18)
            .width('100%')
            .padding({ bottom: 28 })
        }
        .width('100%')
        .padding({ left: 18, right: 18, bottom: 28 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F6F7F2')
  }

  @Builder
  private PrincipleScreen() {
    Scroll() {
      Column({ space: 12 }) {
        this.PolicyBlock('不做用户画像', '不读取点击、停留、收藏和搜索历史来判断用户兴趣。')
        this.PolicyBlock('不做个性化排序', '所有用户在同一地区和语言版本下看到同一组新闻顺序。')
        this.PolicyBlock('固定主题配额', '每日十条覆盖国内、国际、财经、科技、社会、健康、体育和补充视角。')
        this.PolicyBlock('每条保留理由', '新闻入选理由会与条目一起保存，方便后台审核和用户理解。')
        this.PolicyBlock('来源多样化', '同一事件会优先去重，并避免整期内容来自单一媒体或单一议题。')

        Text('下一步会接入后端 API：GET /editions/today。鸿蒙端仍只负责展示服务端发布版本，不参与推荐决策。')
          .fontSize(13)
          .fontColor('#687076')
          .lineHeight(20)
          .textAlign(TextAlign.Center)
          .width('100%')
          .padding({ top: 10, bottom: 26 })
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 4 })
    }
    .layoutWeight(1)
  }

  @Builder
  private PolicyBlock(title: string, body: string) {
    Row({ space: 12 }) {
      Text('✓')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .width(30)
        .height(30)
        .textAlign(TextAlign.Center)
        .backgroundColor('#2E6F57')
        .borderRadius(15)

      Column({ space: 5 }) {
        Text(title)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#202124')

        Text(body)
          .fontSize(14)
          .fontColor('#3D454D')
          .lineHeight(21)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private Tag(text: string, background: string, color: string) {
    Text(text)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor(color)
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .backgroundColor(background)
      .borderRadius(6)
  }
}
