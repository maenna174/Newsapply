import { AI_ARTICLES, MOCK_ARTICLES, TODAY_EDITION } from '../data/MockNewsData';
import { EditionMeta, NewsArticle } from '../model/NewsModels';
import { DailyNewsService } from '../services/DailyNewsService';

@Entry
@ComponentV2
struct Index {
  @Local activeTab: string = 'today';
  @Local selectedArticleId: string = '';
  @Local selectedArticle: NewsArticle = MOCK_ARTICLES[0];
  @Local selectedCategory: string = '全部';
  @Local statusText: string = '正在读取今日新闻';
  @Local isLoading: boolean = false;
  @Local articles: NewsArticle[] = MOCK_ARTICLES;
  @Local edition: EditionMeta = TODAY_EDITION;

  private dailyNewsService: DailyNewsService = new DailyNewsService();
  private categoryOrder: string[] = ['全部', '国内', '国际', '财经', '科技', '健康', '教育', '社会', '体育', '视角'];

  aboutToAppear(): void {
    this.loadTodayNews();
  }

  onPageShow(): void {
    this.loadTodayNews('正在同步最新新闻');
  }

  onBackPress(): boolean {
    if (this.selectedArticleId.length > 0) {
      this.closeDetail();
      return true;
    }
    return false;
  }

  private closeDetail(): void {
    this.selectedArticleId = '';
  }

  private openArticle(article: NewsArticle): void {
    this.selectedArticle = article;
    this.selectedArticleId = article.id;
  }

  private loadTodayNews(message: string = '正在读取今日新闻'): void {
    if (this.isLoading) {
      return;
    }

    this.isLoading = true;
    this.statusText = message;
    this.dailyNewsService.fetchToday()
      .then((result) => {
        if (result.articles.length > 0) {
          this.articles = result.articles;
          this.edition = result.edition;
          this.statusText = `已同步 ${result.edition.editionDate || '线上版本'} · ${result.articles.length} 条`;
          if (this.selectedCategory !== '全部' && this.countByCategory(this.selectedCategory) === 0) {
            this.selectedCategory = '全部';
          }
        } else {
          this.statusText = '暂无线上内容，正在显示本地样例';
        }
      })
      .catch((error: Error) => {
        this.statusText = error.message || '更新失败，正在显示本地样例';
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  private getSelectedArticle(): NewsArticle {
    if (this.selectedArticleId.length > 0 && this.selectedArticle.id === this.selectedArticleId) {
      return this.selectedArticle;
    }
    for (let index = 0; index < this.articles.length; index++) {
      if (this.articles[index].id === this.selectedArticleId) {
        return this.articles[index];
      }
    }
    for (let index = 0; index < AI_ARTICLES.length; index++) {
      if (AI_ARTICLES[index].id === this.selectedArticleId) {
        return AI_ARTICLES[index];
      }
    }
    return this.articles[0];
  }

  private getVisibleArticles(): NewsArticle[] {
    if (this.selectedCategory === '全部') {
      return this.articles;
    }

    const result: NewsArticle[] = [];
    for (let index = 0; index < this.articles.length; index++) {
      const article = this.articles[index];
      if (article.category === this.selectedCategory) {
        result.push(article);
      }
    }
    return result;
  }

  private getCategories(): string[] {
    const result: string[] = [];
    for (let index = 0; index < this.categoryOrder.length; index++) {
      const category = this.categoryOrder[index];
      if (category === '全部' || this.countByCategory(category) > 0) {
        result.push(category);
      }
    }
    return result;
  }

  private countByCategory(category: string): number {
    if (category === '全部') {
      return this.articles.length;
    }

    let count = 0;
    for (let index = 0; index < this.articles.length; index++) {
      if (this.articles[index].category === category) {
        count++;
      }
    }
    return count;
  }

  private statusColor(): string {
    return this.statusText.includes('失败') ? '#B34B45' : '#2E6F57';
  }

  private statusBackground(): string {
    return this.statusText.includes('失败') ? '#F5E5E3' : '#E7F1EB';
  }

  private categorySoftColor(category: string): string {
    switch (category) {
      case '国内':
        return '#E8F0FF';
      case '国际':
        return '#E9ECFF';
      case '财经':
        return '#FFF1D8';
      case '科技':
        return '#E4F2F4';
      case '健康':
        return '#E7F3E8';
      case '教育':
        return '#F0E8FF';
      case '体育':
        return '#EAF0E0';
      case '视角':
        return '#F5E8DD';
      case '模型':
        return '#E8F0FF';
      case '产业':
        return '#FFF1D8';
      case '开源':
        return '#E7F3E8';
      case '开发者':
        return '#E4F2F4';
      case '医疗':
        return '#F5E5E3';
      case '治理':
        return '#E9ECFF';
      case '硬件':
        return '#EAF0E0';
      case '安全':
        return '#F3E7D5';
      case '应用':
        return '#F0E8FF';
      default:
        return '#E4EEE9';
    }
  }

  private categoryTextColor(category: string): string {
    switch (category) {
      case '财经':
        return '#8A4D16';
      case '国内':
        return '#245D9A';
      case '国际':
        return '#4B4F9C';
      case '科技':
        return '#1F6C73';
      case '健康':
        return '#2E6F57';
      case '教育':
        return '#6550A8';
      case '体育':
        return '#5C6F2E';
      case '视角':
        return '#8A4D16';
      case '模型':
        return '#245D9A';
      case '产业':
        return '#8A4D16';
      case '开源':
        return '#2E6F57';
      case '开发者':
        return '#1F6C73';
      case '医疗':
        return '#B34B45';
      case '治理':
        return '#4B4F9C';
      case '硬件':
        return '#5C6F2E';
      case '安全':
        return '#8A4D16';
      case '应用':
        return '#6550A8';
      default:
        return '#2E6F57';
    }
  }

  private rankLabel(index: number): string {
    const rank = index + 1;
    return rank < 10 ? `0${rank}` : `${rank}`;
  }

  private heroLightDegree(): number {
    return this.isLoading ? 0.82 : 0.96;
  }

  private cardLightDegree(index: number): number {
    if (index < 3) {
      return 0.96;
    }
    return 0.9;
  }

  private chipLightDegree(active: boolean = false): number {
    return active ? 0.96 : 0.91;
  }

  private isDetailOpen(): boolean {
    return this.selectedArticleId.length > 0;
  }

  private activeTabIndex(): number {
    return this.activeTab === 'ai' ? 1 : 0;
  }

  private tabByIndex(index: number): string {
    return index === 1 ? 'ai' : 'today';
  }

  private switchTab(tab: string): void {
    this.activeTab = tab;
  }

  private switchTabIndex(index: number): void {
    this.activeTab = this.tabByIndex(index);
  }

  private detailBackgroundBlur(): number {
    return this.isDetailOpen() ? 18 : 0;
  }

  private detailBackgroundScale(): number {
    return this.isDetailOpen() ? 0.985 : 1;
  }

  build() {
    Stack() {
      Column() {
        this.HomeScreen()
      }
      .width('100%')
      .height('100%')
      .blur(this.detailBackgroundBlur())
      .scale({ x: this.detailBackgroundScale(), y: this.detailBackgroundScale() })
      .animation({ duration: 260, curve: Curve.EaseOut })

      if (this.isDetailOpen()) {
        this.DetailScreen(this.getSelectedArticle())
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F4F1EA')
  }

  @Builder
  private HomeScreen() {
    Stack({ alignContent: Alignment.Bottom }) {
      Swiper() {
        this.TodayContent()
        this.AiScreen()
      }
      .index(this.activeTabIndex())
      .indicator(false)
      .loop(false)
      .duration(260)
      .curve(Curve.EaseOut)
      .onChange((index: number) => {
        this.switchTabIndex(index);
      })
      .width('100%')
      .height('100%')

      this.FloatingTabBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F4F1EA')
  }

  @Builder
  private TodayContent() {
    Column() {
      Refresh({ refreshing: this.isLoading, offset: 70 }) {
        Scroll() {
          Column({ space: 14 }) {
            this.HeroHeader()
            this.CategoryBar()

            if (this.getVisibleArticles().length > 0) {
              this.ListHeader()
              ForEach(this.getVisibleArticles(), (article: NewsArticle, index: number) => {
                this.ArticleCard(article, index)
              }, (article: NewsArticle) => article.id)
            } else {
              this.EmptyState()
            }

          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 104 })
        }
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
      .onRefreshing(() => {
        this.loadTodayNews('正在下拉刷新');
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F4F1EA')
  }

  @Builder
  private AiScreen() {
    Scroll() {
      Column({ space: 14 }) {
        Column({ space: 10 }) {
          Text('AI 新闻')
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')

          Text('模型、应用、硬件、治理与安全，每天只看最值得关注的 10 条。')
            .fontSize(14)
            .fontColor('#DDEBE5')
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 22, bottom: 20 })
        .backgroundColor('#173D35')
        .lightUpEffect(0.96)
        .borderRadius(24)
        .shadow({ radius: 20, color: 'rgba(23, 61, 53, 0.20)', offsetY: 8 })
        .alignItems(HorizontalAlign.Start)

        Row() {
          Text('AI 快讯列表')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#171A1F')
            .layoutWeight(1)

          Text(`${AI_ARTICLES.length} 条`)
            .fontSize(13)
            .fontColor('#687076')
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .backgroundColor('#FFFFFF')
            .lightUpEffect(0.9)
            .borderRadius(13)
        }
        .width('100%')
        .padding({ top: 4, bottom: 2 })

        ForEach(AI_ARTICLES, (article: NewsArticle, index: number) => {
          this.AiArticleCard(article, index)
        }, (article: NewsArticle) => article.id)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 104 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F4F1EA')
  }

  @Builder
  private FloatingTabBar() {
    Row({ space: 8 }) {
      this.FloatingTabItem('today', '今日', '10')
      this.FloatingTabItem('ai', 'AI', 'AI')
    }
    .padding({ left: 8, right: 8, top: 8, bottom: 8 })
    .backgroundColor('rgba(255, 252, 246, 0.92)')
    .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR)
    .lightUpEffect(0.96)
    .border({ width: 1, color: 'rgba(231, 221, 205, 0.86)' })
    .borderRadius(28)
    .shadow({ radius: 22, color: 'rgba(46, 39, 28, 0.16)', offsetY: 8 })
    .margin({ left: 24, right: 24, bottom: 20 })
  }

  @Builder
  private FloatingTabItem(tab: string, label: string, mark: string) {
    Row({ space: 7 }) {
      Text(mark)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.activeTab === tab ? '#FFFFFF' : '#173D35')
        .width(22)
        .height(22)
        .textAlign(TextAlign.Center)
        .backgroundColor(this.activeTab === tab ? '#173D35' : '#E7F1EB')
        .lightUpEffect(this.chipLightDegree(this.activeTab === tab))
        .borderRadius(11)

      Text(label)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.activeTab === tab ? '#173D35' : '#687076')
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .height(42)
    .backgroundColor(this.activeTab === tab ? '#FFFFFF' : 'rgba(255, 255, 255, 0)')
    .lightUpEffect(this.chipLightDegree(this.activeTab === tab))
    .borderRadius(22)
    .onClick(() => {
      this.switchTab(tab);
    })
  }

  @Builder
  private AiFeaturedCard(article: NewsArticle) {
    Column({ space: 14 }) {
      Row() {
        this.Tag('AI 头条', '#173D35', '#FFFFFF')
        this.Tag(article.category, this.categorySoftColor(article.category), this.categoryTextColor(article.category))
        Blank()
        Text(article.readingTime)
          .fontSize(12)
          .fontColor('#687076')
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(article.title)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#171A1F')
        .lineHeight(32)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Text(article.summary)
        .fontSize(15)
        .fontColor('#3D454D')
        .lineHeight(24)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Row() {
        Text(article.source)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#202124')
          .layoutWeight(1)

        Text('查看详情')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#173D35')
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .backgroundColor('#E7F1EB')
          .lightUpEffect(0.92)
          .borderRadius(16)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#FFFCF6')
    .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
    .lightUpEffect(0.96)
    .borderRadius(22)
    .border({ width: 1, color: '#E7DDCD' })
    .shadow({ radius: 16, color: 'rgba(46, 39, 28, 0.08)', offsetY: 6 })
    .onClick(() => {
      this.openArticle(article);
    })
  }

  @Builder
  private AiArticleCard(article: NewsArticle, index: number) {
    Row({ space: 13 }) {
      Text(this.rankLabel(index))
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(index < 3 ? '#B34B45' : '#173D35')
        .width(36)
        .height(36)
        .textAlign(TextAlign.Center)
        .backgroundColor(index < 3 ? '#F5E5E3' : '#E7F1EB')
        .lightUpEffect(this.chipLightDegree(index < 3))
        .borderRadius(18)

      Column({ space: 9 }) {
        Row({ space: 7 }) {
          this.Tag(article.category, this.categorySoftColor(article.category), this.categoryTextColor(article.category))
          Text(article.source)
            .fontSize(12)
            .fontColor('#687076')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(article.publishedAt)
            .fontSize(12)
            .fontColor('#687076')
        }
        .width('100%')

        Text(article.title)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#171A1F')
          .lineHeight(24)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Text(article.summary)
          .fontSize(13)
          .fontColor('#687076')
          .lineHeight(19)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('›')
        .fontSize(24)
        .fontColor('#B7BDB8')
    }
    .width('100%')
    .padding(14)
    .backgroundColor('rgba(255, 255, 255, 0.88)')
    .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
    .lightUpEffect(this.cardLightDegree(index))
    .borderRadius(18)
    .alignItems(VerticalAlign.Center)
    .shadow({ radius: 10, color: 'rgba(46, 39, 28, 0.05)', offsetY: 3 })
    .onClick(() => {
      this.openArticle(article);
    })
  }

  @Builder
  private HeroHeader() {
    Column({ space: 16 }) {
      Row() {
        Column({ space: 6 }) {
          Text('DAILY BRIEFING')
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor('#A9D3C0')
            .letterSpacing(1.2)

          Text('今日十条')
            .fontSize(34)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')

          Text(`${this.edition.editionDate} · ${this.edition.publishedAt}`)
            .fontSize(13)
            .fontColor('#DDEBE5')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Column({ space: 0 }) {
          Text(`${this.articles.length}`)
            .fontSize(25)
            .fontWeight(FontWeight.Bold)
            .fontColor('#173D35')
            .height(30)
            .textAlign(TextAlign.Center)

          Text('条')
            .fontSize(11)
            .fontColor('#5B7069')
            .textAlign(TextAlign.Center)
        }
          .width(62)
          .height(62)
          .justifyContent(FlexAlign.Center)
          .backgroundColor('#FFFFFF')
          .lightUpEffect(0.96)
          .borderRadius(31)
          .shadow({ radius: 12, color: 'rgba(0, 0, 0, 0.16)', offsetY: 4 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 8 }) {
        this.Tag(this.edition.region.toUpperCase(), 'rgba(255, 255, 255, 0.18)', '#FFFFFF')
        this.Tag(this.edition.language, 'rgba(255, 255, 255, 0.18)', '#FFFFFF')
        Text(this.edition.publishedAt)
          .fontSize(12)
          .fontColor('#DDEBE5')
      }
      .width('100%')

      Text(this.edition.statement)
        .fontSize(14)
        .fontColor('#F3F8F5')
        .lineHeight(22)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Row({ space: 10 }) {
        Text(this.statusText)
          .fontSize(12)
          .fontColor(this.statusColor())
          .layoutWeight(1)
          .padding({ left: 10, right: 10, top: 7, bottom: 7 })
          .backgroundColor(this.statusBackground())
          .lightUpEffect(0.9)
          .borderRadius(16)

        Button(this.isLoading ? '同步中' : '同步最新')
          .height(36)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#173D35')
          .backgroundColor('#FFFFFF')
          .lightUpEffect(0.96)
          .borderRadius(18)
          .padding({ left: 13, right: 13 })
          .enabled(!this.isLoading)
          .onClick(() => {
            this.loadTodayNews('正在同步最新新闻');
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 20, bottom: 18 })
    .backgroundColor('#173D35')
    .lightUpEffect(this.heroLightDegree())
    .borderRadius(24)
    .shadow({ radius: 20, color: 'rgba(23, 61, 53, 0.24)', offsetY: 8 })
  }

  @Builder
  private CategoryBar() {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(this.getCategories(), (category: string) => {
          this.CategoryPill(category)
        }, (category: string) => category)
      }
      .padding({ right: 12 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
  }

  @Builder
  private CategoryPill(category: string) {
    Text(`${category} ${this.countByCategory(category)}`)
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.selectedCategory === category ? '#FFFFFF' : '#3D454D')
      .padding({ left: 14, right: 14, top: 9, bottom: 9 })
      .backgroundColor(this.selectedCategory === category ? '#173D35' : '#FFFFFF')
      .lightUpEffect(this.chipLightDegree(this.selectedCategory === category))
      .borderRadius(20)
      .border({ width: 1, color: this.selectedCategory === category ? '#173D35' : '#E2D8C9' })
      .onClick(() => {
        this.selectedCategory = category;
      })
  }

  @Builder
  private FeaturedCard(article: NewsArticle) {
    Column({ space: 14 }) {
      Row() {
        this.Tag('今日重点', '#B34B45', '#FFFFFF')
        this.Tag(article.category, this.categorySoftColor(article.category), this.categoryTextColor(article.category))
        Blank()
        Text(article.readingTime)
          .fontSize(12)
          .fontColor('#687076')
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(article.title)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#171A1F')
        .lineHeight(32)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Text(article.summary)
        .fontSize(15)
        .fontColor('#3D454D')
        .lineHeight(24)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Row() {
        Column({ space: 3 }) {
          Text(article.source)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#202124')

          Text(article.publishedAt)
            .fontSize(12)
            .fontColor('#687076')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text('阅读全文')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#173D35')
          .padding({ left: 11, right: 11, top: 7, bottom: 7 })
          .backgroundColor('#E7F1EB')
          .lightUpEffect(0.92)
          .borderRadius(16)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#FFFCF6')
    .lightUpEffect(0.96)
    .borderRadius(22)
    .border({ width: 1, color: '#E7DDCD' })
    .shadow({ radius: 16, color: 'rgba(46, 39, 28, 0.08)', offsetY: 6 })
    .onClick(() => {
      this.openArticle(article);
    })
  }

  @Builder
  private ListHeader() {
    Row() {
      Text(this.selectedCategory === '全部' ? '全部新闻' : `${this.selectedCategory}新闻`)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#171A1F')
        .layoutWeight(1)

      Text(`${this.getVisibleArticles().length} 条`)
        .fontSize(13)
        .fontColor('#687076')
        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
        .backgroundColor('#FFFFFF')
        .lightUpEffect(0.9)
        .borderRadius(13)
    }
    .width('100%')
    .padding({ top: 4, bottom: 2 })
  }

  @Builder
  private ArticleCard(article: NewsArticle, index: number) {
    Row({ space: 13 }) {
      Text(this.rankLabel(index))
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(index < 3 ? '#B34B45' : '#173D35')
        .width(36)
        .height(36)
        .textAlign(TextAlign.Center)
        .backgroundColor(index < 3 ? '#F5E5E3' : '#E7F1EB')
        .lightUpEffect(this.chipLightDegree(index < 3))
        .borderRadius(18)

      Column({ space: 9 }) {
        Row({ space: 7 }) {
          this.Tag(article.category, this.categorySoftColor(article.category), this.categoryTextColor(article.category))
          Text(article.source)
            .fontSize(12)
            .fontColor('#687076')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(article.publishedAt)
            .fontSize(12)
            .fontColor('#687076')
        }
        .width('100%')

        Text(article.title)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#171A1F')
          .lineHeight(24)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Text(article.summary)
          .fontSize(13)
          .fontColor('#687076')
          .lineHeight(19)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('›')
        .fontSize(24)
        .fontColor('#B7BDB8')
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#FFFFFF')
    .lightUpEffect(this.cardLightDegree(index))
    .borderRadius(18)
    .alignItems(VerticalAlign.Center)
    .shadow({ radius: 10, color: 'rgba(46, 39, 28, 0.05)', offsetY: 3 })
    .onClick(() => {
      this.openArticle(article);
    })
  }

  @Builder
  private EmptyState() {
    Column({ space: 10 }) {
      Text('暂无内容')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#202124')

      Text('当前分类没有新闻，换个分类看看。')
        .fontSize(14)
        .fontColor('#687076')
    }
    .width('100%')
    .padding({ top: 44, bottom: 44 })
    .backgroundColor('#FFFFFF')
    .lightUpEffect(0.92)
    .borderRadius(20)
  }

  @Builder
  private DetailScreen(article: NewsArticle) {
    Column() {
      Row() {
        Button('返回')
          .height(36)
          .fontSize(14)
          .fontColor('#2E6F57')
          .backgroundColor('rgba(228, 238, 233, 0.82)')
          .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
          .lightUpEffect(0.94)
          .borderRadius(18)
          .onClick(() => {
            this.closeDetail();
          })

        Blank()

        Text(`阅读 ${article.readingTime}`)
          .fontSize(13)
          .fontColor('#3D454D')
          .padding({ left: 11, right: 11, top: 7, bottom: 7 })
          .backgroundColor('rgba(255, 255, 255, 0.78)')
          .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
          .lightUpEffect(0.9)
          .borderRadius(16)
      }
      .width('100%')
      .padding({ left: 10, right: 10, top: 8, bottom: 8 })
      .backgroundColor('rgba(255, 252, 246, 0.72)')
      .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR)
      .lightUpEffect(0.94)
      .border({ width: 1, color: 'rgba(231, 221, 205, 0.72)' })
      .borderRadius(24)
      .margin({ left: 16, right: 16, top: 18, bottom: 12 })

      Scroll() {
        Column({ space: 16 }) {
          Column({ space: 14 }) {
            Row({ space: 8 }) {
              this.Tag(article.category, '#FFFFFF', '#2E6F57')
              this.Tag(article.source, '#F3E7D5', '#8A4D16')
            }
            .width('100%')

            Text(article.title)
              .fontSize(29)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .lineHeight(38)
              .width('100%')

            Row() {
              Text(article.publishedAt)
                .fontSize(13)
                .fontColor('#DDEBE5')
                .layoutWeight(1)

              Text('固定公共排序')
                .fontSize(12)
                .fontColor('#DDEBE5')
            }
            .width('100%')
          }
          .width('100%')
          .padding({ left: 18, right: 18, top: 20, bottom: 18 })
          .backgroundColor('#173D35')
          .lightUpEffect(0.96)
          .borderRadius(24)
          .shadow({ radius: 20, color: 'rgba(23, 61, 53, 0.20)', offsetY: 8 })
          .alignItems(HorizontalAlign.Start)

          Column({ space: 10 }) {
            Text('新闻摘要')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#202124')

            Text(article.summary)
              .fontSize(17)
              .fontColor('#30363C')
              .lineHeight(28)
              .width('100%')
          }
          .width('100%')
          .padding(18)
          .backgroundColor('#FFFFFF')
          .lightUpEffect(0.94)
          .borderRadius(20)
          .shadow({ radius: 10, color: 'rgba(46, 39, 28, 0.05)', offsetY: 3 })
          .alignItems(HorizontalAlign.Start)

          Column({ space: 10 }) {
            Text('为什么入选')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#202124')

            Text(article.selectionReason)
              .fontSize(14)
              .fontColor('#3D454D')
              .lineHeight(22)
              .width('100%')
          }
          .width('100%')
          .padding(18)
          .backgroundColor('#FFF8EC')
          .lightUpEffect(0.95)
          .borderRadius(20)
          .border({ width: 1, color: '#F0DDC1' })
          .alignItems(HorizontalAlign.Start)

          Column({ space: 8 }) {
            Text('原文地址')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#202124')

            Text(article.url)
              .fontSize(13)
              .fontColor('#2E6F57')
              .lineHeight(20)
              .width('100%')
          }
          .width('100%')
          .padding(18)
          .backgroundColor('#FFFFFF')
          .lightUpEffect(0.94)
          .borderRadius(20)
          .shadow({ radius: 10, color: 'rgba(46, 39, 28, 0.05)', offsetY: 3 })
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 28 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(244, 241, 234, 0.84)')
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN)
  }

  @Builder
  private Tag(text: string, background: string, color: string) {
    Text(text)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor(color)
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .backgroundColor(background)
      .lightUpEffect(0.9)
      .borderRadius(7)
  }
}
