import { AI_ARTICLES, MOCK_ARTICLES, TODAY_EDITION } from '../data/MockNewsData';
import { EditionMeta, NewsArticle } from '../model/NewsModels';
import { DailyNewsService } from '../services/DailyNewsService';

@Entry
@ComponentV2
struct Index {
  @Local activeTab: string = 'today';
  @Local selectedArticleId: string = '';
  @Local detailVisible: boolean = false;
  @Local detailNextLocked: boolean = false;
  @Local selectedArticle: NewsArticle = MOCK_ARTICLES[0];
  @Local selectedCategory: string = '全部';
  @Local statusText: string = '正在读取今日新闻';
  @Local isLoading: boolean = false;
  @Local isDarkMode: boolean = false;
  @Local articles: NewsArticle[] = MOCK_ARTICLES;
  @Local aiArticles: NewsArticle[] = AI_ARTICLES;
  @Local edition: EditionMeta = TODAY_EDITION;

  private dailyNewsService: DailyNewsService = new DailyNewsService();
  private detailScroller: Scroller = new Scroller();
  private categoryOrder: string[] = ['全部', '国内', '国际', '财经', '科技', '健康', '教育', '社会', '体育', '视角'];

  aboutToAppear(): void {
    this.loadTodayNews();
    this.loadAiNews();
  }

  onPageShow(): void {
    this.loadTodayNews('正在同步最新新闻');
    this.loadAiNews();
  }

  onBackPress(): boolean {
    if (this.selectedArticleId.length > 0) {
      this.closeDetail();
      return true;
    }
    return false;
  }

  private closeDetail(): void {
    this.detailNextLocked = true;
    this.detailVisible = false;
    setTimeout(() => {
      if (!this.detailVisible) {
        this.selectedArticleId = '';
        this.detailNextLocked = false;
      }
    }, 280);
  }

  private openArticle(article: NewsArticle): void {
    this.selectedArticle = article;
    this.selectedArticleId = article.id;
    this.detailNextLocked = true;
    this.detailVisible = false;
    setTimeout(() => {
      this.detailVisible = true;
    }, 16);
    setTimeout(() => {
      if (this.selectedArticleId === article.id) {
        this.detailNextLocked = false;
      }
    }, 520);
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

  private loadAiNews(): void {
    this.dailyNewsService.fetchAi()
      .then((result) => {
        if (result.articles.length > 0) {
          this.aiArticles = result.articles;
        }
      })
      .catch(() => {
        this.aiArticles = AI_ARTICLES;
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
    for (let index = 0; index < this.aiArticles.length; index++) {
      if (this.aiArticles[index].id === this.selectedArticleId) {
        return this.aiArticles[index];
      }
    }
    for (let index = 0; index < AI_ARTICLES.length; index++) {
      if (AI_ARTICLES[index].id === this.selectedArticleId) {
        return AI_ARTICLES[index];
      }
    }
    return this.articles[0];
  }

  private detailArticleList(): NewsArticle[] {
    for (let index = 0; index < this.aiArticles.length; index++) {
      if (this.aiArticles[index].id === this.selectedArticleId) {
        return this.aiArticles;
      }
    }
    return this.getVisibleArticles();
  }

  private selectedArticleIndex(list: NewsArticle[]): number {
    for (let index = 0; index < list.length; index++) {
      if (list[index].id === this.selectedArticleId) {
        return index;
      }
    }
    return -1;
  }

  private hasNextArticle(): boolean {
    const list = this.detailArticleList();
    const index = this.selectedArticleIndex(list);
    return index >= 0 && index < list.length - 1;
  }

  private detailBottomHint(): string {
    return this.hasNextArticle() ? '继续下滑，切换下一条新闻' : '已经是最后一条新闻';
  }

  private openNextArticleFromDetail(): void {
    if (this.detailNextLocked || !this.hasNextArticle()) {
      return;
    }

    const list = this.detailArticleList();
    const index = this.selectedArticleIndex(list);
    if (index < 0 || index >= list.length - 1) {
      return;
    }

    const nextArticle = list[index + 1];
    this.detailNextLocked = true;
    this.selectedArticle = nextArticle;
    this.selectedArticleId = nextArticle.id;
    setTimeout(() => {
      this.detailScroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false });
    }, 16);
    setTimeout(() => {
      if (this.selectedArticleId === nextArticle.id) {
        this.detailNextLocked = false;
      }
    }, 650);
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
    if (this.statusText.includes('失败')) {
      return this.isDarkMode ? '#FF9F92' : '#B34B45';
    }
    return this.isDarkMode ? '#8EE0B8' : '#2E6F57';
  }

  private statusBackground(): string {
    if (this.statusText.includes('失败')) {
      return this.isDarkMode ? 'rgba(255, 69, 58, 0.18)' : '#F5E5E3';
    }
    return this.isDarkMode ? 'rgba(52, 199, 89, 0.16)' : '#E7F1EB';
  }

  private categorySoftColor(category: string): string {
    if (this.isDarkMode) {
      switch (category) {
        case '国内':
        case '模型':
          return 'rgba(10, 132, 255, 0.20)';
        case '财经':
        case '产业':
        case '安全':
        case '视角':
          return 'rgba(255, 159, 10, 0.18)';
        case '健康':
        case '开源':
          return 'rgba(52, 199, 89, 0.18)';
        case '科技':
        case '开发者':
          return 'rgba(100, 210, 255, 0.18)';
        case '医疗':
          return 'rgba(255, 69, 58, 0.18)';
        case '国际':
        case '治理':
          return 'rgba(94, 92, 230, 0.20)';
        default:
          return 'rgba(255, 255, 255, 0.10)';
      }
    }
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
    if (this.isDarkMode) {
      switch (category) {
        case '财经':
        case '产业':
        case '安全':
        case '视角':
          return '#FFD60A';
        case '健康':
        case '开源':
          return '#63E6A0';
        case '科技':
        case '开发者':
          return '#64D2FF';
        case '医疗':
          return '#FF9F92';
        case '国际':
        case '治理':
          return '#B8B5FF';
        default:
          return '#8EC5FF';
      }
    }
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
    if (this.activeTab === 'ai') {
      return 1;
    }
    if (this.activeTab === 'settings') {
      return 2;
    }
    return 0;
  }

  private tabByIndex(index: number): string {
    if (index === 1) {
      return 'ai';
    }
    if (index === 2) {
      return 'settings';
    }
    return 'today';
  }

  private switchTab(tab: string): void {
    this.activeTab = tab;
  }

  private switchTabIndex(index: number): void {
    this.activeTab = this.tabByIndex(index);
  }

  private toggleTheme(): void {
    this.isDarkMode = !this.isDarkMode;
  }

  private pageBackground(): string {
    return this.isDarkMode ? '#07101F' : '#F7FAFF';
  }

  private surfaceColor(): string {
    return this.isDarkMode ? 'rgba(28, 33, 46, 0.72)' : 'rgba(255, 255, 255, 0.82)';
  }

  private elevatedSurfaceColor(): string {
    return this.isDarkMode ? 'rgba(43, 49, 64, 0.78)' : 'rgba(255, 255, 255, 0.92)';
  }

  private softSurfaceColor(): string {
    return this.isDarkMode ? 'rgba(20, 31, 47, 0.72)' : 'rgba(236, 245, 255, 0.82)';
  }

  private primaryTextColor(): string {
    return this.isDarkMode ? '#F5F5F7' : '#1D1D1F';
  }

  private secondaryTextColor(): string {
    return this.isDarkMode ? '#C8CBD2' : '#344054';
  }

  private tertiaryTextColor(): string {
    return this.isDarkMode ? '#9EA3AF' : '#667085';
  }

  private subtleBorderColor(): string {
    return this.isDarkMode ? 'rgba(255, 255, 255, 0.16)' : 'rgba(255, 255, 255, 0.88)';
  }

  private inactiveMarkBackground(): string {
    return this.isDarkMode ? 'rgba(104, 164, 255, 0.20)' : 'rgba(255, 255, 255, 0.78)';
  }

  private detailOverlayBackground(): string {
    return this.isDarkMode ? 'rgba(7, 16, 31, 0.78)' : 'rgba(238, 243, 255, 0.72)';
  }

  private detailToolbarBackground(): string {
    return this.isDarkMode ? 'rgba(28, 33, 46, 0.62)' : 'rgba(255, 255, 255, 0.54)';
  }

  private accentColor(): string {
    return '#007AFF';
  }

  private glassShadowColor(): string {
    return this.isDarkMode ? 'rgba(0, 0, 0, 0.34)' : 'rgba(84, 118, 180, 0.12)';
  }

  private glassHighlightColor(): string {
    return this.isDarkMode ? 'rgba(255, 255, 255, 0.08)' : 'rgba(255, 255, 255, 0.42)';
  }

  private bottomBarBackground(): string {
    return this.isDarkMode ? 'rgba(10, 17, 31, 0.92)' : 'rgba(255, 255, 255, 0.94)';
  }

  private bottomTabBackground(tab: string): string {
    if (this.activeTab === tab) {
      return this.isDarkMode ? 'rgba(0, 122, 255, 0.22)' : 'rgba(0, 122, 255, 0.12)';
    }
    return 'rgba(255, 255, 255, 0)';
  }

  private bottomTabTextColor(tab: string): string {
    return this.activeTab === tab ? this.accentColor() : this.primaryTextColor();
  }

  private bottomTabMarkBackground(tab: string): string {
    if (this.activeTab === tab) {
      return this.accentColor();
    }
    return this.isDarkMode ? 'rgba(255, 255, 255, 0.10)' : 'rgba(0, 122, 255, 0.08)';
  }

  private themeButtonText(): string {
    return this.isDarkMode ? '浅色' : '深色';
  }

  private detailBackgroundBlur(): number {
    return 0;
  }

  private detailBackgroundScale(): number {
    return 1;
  }

  private detailOpacity(): number {
    return this.detailVisible ? 1 : 0;
  }

  private detailOffsetY(): number {
    return this.detailVisible ? 0 : 42;
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
        Column() {
          this.DetailScreen(this.getSelectedArticle())
        }
        .width('100%')
        .height('100%')
          .opacity(this.detailOpacity())
          .translate({ y: this.detailOffsetY() })
          .animation({ duration: 180, curve: Curve.EaseOut })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBackground())
  }

  @Builder
  private HomeScreen() {
    Tabs({ barPosition: BarPosition.End, index: this.activeTabIndex() }) {
      TabContent() {
        this.TodayContent()
      }
      .tabBar(this.BottomTabItem('today', '今日', '今'))

      TabContent() {
        this.AiScreen()
      }
      .tabBar(this.BottomTabItem('ai', 'AI', 'AI'))

      TabContent() {
        this.SettingsScreen()
      }
      .tabBar(this.BottomTabItem('settings', '设置', '设'))
    }
    .onChange((index: number) => {
      this.switchTabIndex(index);
    })
    .barBackgroundColor(this.bottomBarBackground())
    .barHeight(72)
    .animationDuration(260)
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBackground())
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
          .padding({ left: 16, right: 16, top: 16, bottom: 24 })
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
    .backgroundColor(this.pageBackground())
  }

  @Builder
  private AiScreen() {
    Scroll() {
      Column({ space: 16 }) {
        Column({ space: 10 }) {
          Row() {
            Text('AI 专区')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.accentColor())
              .letterSpacing(1.1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Text('AI 新闻专区')
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.primaryTextColor())

          Text('模型、应用、硬件、治理与安全，每天只看最值得关注的 10 条。')
            .fontSize(15)
            .fontColor(this.secondaryTextColor())
            .lineHeight(22)
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 20, bottom: 18 })
        .backgroundColor(this.surfaceColor())
        .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR)
        .lightUpEffect(0.96)
        .borderRadius(28)
        .border({ width: 1, color: this.subtleBorderColor() })
        .shadow({ radius: 22, color: this.glassShadowColor(), offsetY: 10 })
        .alignItems(HorizontalAlign.Start)

        Row() {
          Text('AI 快讯列表')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.primaryTextColor())
            .layoutWeight(1)

          Text(`${this.aiArticles.length} 条`)
            .fontSize(13)
            .fontColor(this.tertiaryTextColor())
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .backgroundColor(this.elevatedSurfaceColor())
            .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
            .lightUpEffect(0.9)
            .borderRadius(13)
        }
        .width('100%')
        .padding({ top: 4, bottom: 2 })

        ForEach(this.aiArticles, (article: NewsArticle, index: number) => {
          this.AiArticleCard(article, index)
        }, (article: NewsArticle) => article.id)
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 18, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBackground())
  }

  @Builder
  private SettingsScreen() {
    Scroll() {
      Column({ space: 16 }) {
        Column({ space: 8 }) {
          Text('设置中心')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.tertiaryTextColor())
            .letterSpacing(1.1)

          Text('设置')
            .fontSize(34)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.primaryTextColor())

          Text('管理显示、同步和内容来源。')
            .fontSize(15)
            .fontColor(this.secondaryTextColor())
        }
        .width('100%')
        .padding({ left: 4, right: 4, top: 4 })
        .alignItems(HorizontalAlign.Start)

        Column({ space: 12 }) {
          Row() {
            Column({ space: 4 }) {
              Text('外观')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.primaryTextColor())

              Text(this.isDarkMode ? '当前为深色模式' : '当前为浅色模式')
                .fontSize(13)
                .fontColor(this.secondaryTextColor())
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            this.ThemeToggle()
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Text('深色模式会同步影响首页、AI 专区、详情页和底部导航。')
            .fontSize(13)
            .fontColor(this.tertiaryTextColor())
            .lineHeight(20)
            .width('100%')
        }
        .width('100%')
        .padding(18)
        .backgroundColor(this.surfaceColor())
        .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR)
        .lightUpEffect(0.95)
        .borderRadius(28)
        .border({ width: 1, color: this.subtleBorderColor() })
        .shadow({ radius: 22, color: this.glassShadowColor(), offsetY: 9 })

        Column({ space: 12 }) {
          Text('同步')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.primaryTextColor())
            .width('100%')

          Row({ space: 10 }) {
            Button(this.isLoading ? '同步中' : '同步今日新闻')
              .height(40)
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .backgroundColor(this.accentColor())
              .borderRadius(20)
              .layoutWeight(1)
              .enabled(!this.isLoading)
              .onClick(() => {
                this.loadTodayNews('正在从设置同步');
              })

            Button('同步 AI 新闻')
              .height(40)
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.accentColor())
              .backgroundColor(this.inactiveMarkBackground())
              .borderRadius(20)
              .layoutWeight(1)
              .onClick(() => {
                this.loadAiNews();
              })
          }
          .width('100%')

          Text(this.statusText)
            .fontSize(13)
            .fontColor(this.statusColor())
            .lineHeight(20)
            .width('100%')
            .padding({ left: 12, right: 12, top: 9, bottom: 9 })
            .backgroundColor(this.statusBackground())
            .borderRadius(16)
        }
        .width('100%')
        .padding(18)
        .backgroundColor(this.surfaceColor())
        .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR)
        .lightUpEffect(0.95)
        .borderRadius(28)
        .border({ width: 1, color: this.subtleBorderColor() })
        .shadow({ radius: 22, color: this.glassShadowColor(), offsetY: 9 })

        Row({ space: 10 }) {
          this.SettingsMetric('今日新闻', `${this.articles.length}`, '条')
          this.SettingsMetric('AI 新闻', `${this.aiArticles.length}`, '条')
        }
        .width('100%')

        Column({ space: 12 }) {
          this.SettingsInfoRow('今日版本', this.edition.editionDate || '本地样例')
          this.SettingsInfoRow('语言区域', `${this.edition.region.toUpperCase()} · ${this.edition.language}`)
          this.SettingsInfoRow('排序方式', '固定公共排序，不做个性化推荐')
          this.SettingsInfoRow('AI 专区', '每日自动抓取并生成 10 条 AI 新闻')
        }
        .width('100%')
        .padding(18)
        .backgroundColor(this.surfaceColor())
        .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR)
        .lightUpEffect(0.95)
        .borderRadius(28)
        .border({ width: 1, color: this.subtleBorderColor() })
        .shadow({ radius: 22, color: this.glassShadowColor(), offsetY: 9 })

        Column({ space: 8 }) {
          Text('关于 DailyTen')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.primaryTextColor())

          Text('每天聚合 10 条公共新闻，并提供 AI 新闻专区。内容按公共重要性、来源多样性和主题覆盖排序。')
            .fontSize(14)
            .fontColor(this.secondaryTextColor())
            .lineHeight(22)
            .width('100%')
        }
        .width('100%')
        .padding(18)
        .backgroundColor(this.softSurfaceColor())
        .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
        .lightUpEffect(0.95)
        .borderRadius(28)
        .border({ width: 1, color: this.subtleBorderColor() })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 22, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBackground())
  }

  @Builder
  private BottomTabItem(tab: string, label: string, mark: string) {
    Column({ space: 4 }) {
      Text(mark)
        .fontSize(tab === 'ai' ? 11 : 12)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.activeTab === tab ? '#FFFFFF' : this.accentColor())
        .width(26)
        .height(22)
        .textAlign(TextAlign.Center)
        .backgroundColor(this.bottomTabMarkBackground(tab))
        .borderRadius(11)

      Text(label)
        .fontSize(12)
        .fontWeight(this.activeTab === tab ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.bottomTabTextColor(tab))
        .maxLines(1)
    }
    .width(74)
    .height(54)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.bottomTabBackground(tab))
    .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
    .borderRadius(18)
    .border({ width: this.activeTab === tab ? 1 : 0, color: this.subtleBorderColor() })
    .lightUpEffect(this.activeTab === tab ? 0.96 : 0.88)
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
          .fontColor(this.tertiaryTextColor())
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(article.title)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.primaryTextColor())
        .lineHeight(32)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Text(article.summary)
        .fontSize(15)
        .fontColor(this.secondaryTextColor())
        .lineHeight(24)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Row() {
        Text(article.source)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())
          .layoutWeight(1)

        Text('查看详情')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.accentColor())
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .backgroundColor(this.inactiveMarkBackground())
          .lightUpEffect(0.92)
          .borderRadius(16)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(18)
    .backgroundColor(this.surfaceColor())
    .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
    .lightUpEffect(0.96)
    .borderRadius(28)
    .border({ width: 1, color: this.subtleBorderColor() })
    .shadow({ radius: 24, color: this.glassShadowColor(), offsetY: 10 })
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
        .fontColor(index < 3 ? '#FFFFFF' : this.accentColor())
        .width(38)
        .height(38)
        .textAlign(TextAlign.Center)
        .backgroundColor(index < 3 ? '#FF3B30' : this.inactiveMarkBackground())
        .lightUpEffect(this.chipLightDegree(index < 3))
        .borderRadius(19)

      Column({ space: 9 }) {
        Row({ space: 7 }) {
          this.Tag(article.category, this.categorySoftColor(article.category), this.categoryTextColor(article.category))
          Text(article.source)
            .fontSize(12)
            .fontColor(this.tertiaryTextColor())
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(article.publishedAt)
            .fontSize(12)
            .fontColor(this.tertiaryTextColor())
        }
        .width('100%')

        Text(article.title)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())
          .lineHeight(25)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Text(article.summary)
          .fontSize(14)
          .fontColor(this.secondaryTextColor())
          .lineHeight(20)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('›')
        .fontSize(24)
        .fontColor(this.tertiaryTextColor())
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.surfaceColor())
    .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
    .lightUpEffect(this.cardLightDegree(index))
    .borderRadius(28)
    .border({ width: 1, color: this.subtleBorderColor() })
    .alignItems(VerticalAlign.Center)
    .shadow({ radius: 22, color: this.glassShadowColor(), offsetY: 8 })
    .onClick(() => {
      this.openArticle(article);
    })
  }

  @Builder
  private HeroHeader() {
    Column({ space: 16 }) {
      Row() {
        Column({ space: 6 }) {
          Text('今日新闻')
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.accentColor())
            .letterSpacing(1.2)

          Text('今日十条')
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.primaryTextColor())

          Text(`${this.edition.editionDate} · ${this.edition.publishedAt}`)
            .fontSize(13)
            .fontColor(this.secondaryTextColor())
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Column({ space: 0 }) {
          Text(`${this.articles.length}`)
            .fontSize(25)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.accentColor())
            .height(30)
            .textAlign(TextAlign.Center)

          Text('条')
            .fontSize(11)
            .fontColor(this.secondaryTextColor())
            .textAlign(TextAlign.Center)
        }
          .width(62)
          .height(62)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(this.inactiveMarkBackground())
          .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
          .lightUpEffect(0.96)
          .borderRadius(31)
          .border({ width: 1, color: this.subtleBorderColor() })
          .shadow({ radius: 18, color: this.glassShadowColor(), offsetY: 6 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 8 }) {
        this.Tag(this.edition.region.toUpperCase(), this.inactiveMarkBackground(), this.accentColor())
        this.Tag(this.edition.language, this.inactiveMarkBackground(), this.accentColor())
        Text(this.edition.publishedAt)
          .fontSize(12)
          .fontColor(this.tertiaryTextColor())
      }
      .width('100%')

      Text(this.edition.statement)
        .fontSize(14)
        .fontColor(this.secondaryTextColor())
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
          .fontColor('#FFFFFF')
          .backgroundColor(this.accentColor())
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
    .backgroundColor(this.surfaceColor())
    .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR)
    .lightUpEffect(this.heroLightDegree())
    .borderRadius(28)
    .border({ width: 1, color: this.subtleBorderColor() })
    .shadow({ radius: 24, color: this.glassShadowColor(), offsetY: 10 })
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
      .fontColor(this.selectedCategory === category ? '#FFFFFF' : this.primaryTextColor())
      .padding({ left: 14, right: 14, top: 9, bottom: 9 })
      .backgroundColor(this.selectedCategory === category ? this.accentColor() : this.surfaceColor())
      .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
      .lightUpEffect(this.chipLightDegree(this.selectedCategory === category))
      .borderRadius(20)
      .border({ width: 1, color: this.selectedCategory === category ? this.accentColor() : this.subtleBorderColor() })
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
          .fontColor(this.tertiaryTextColor())
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(article.title)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.primaryTextColor())
        .lineHeight(32)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Text(article.summary)
        .fontSize(15)
        .fontColor(this.secondaryTextColor())
        .lineHeight(24)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Row() {
        Column({ space: 3 }) {
          Text(article.source)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.primaryTextColor())

          Text(article.publishedAt)
            .fontSize(12)
            .fontColor(this.tertiaryTextColor())
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
    .backgroundColor(this.surfaceColor())
    .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
    .lightUpEffect(0.96)
    .borderRadius(28)
    .border({ width: 1, color: this.subtleBorderColor() })
    .shadow({ radius: 24, color: this.glassShadowColor(), offsetY: 10 })
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
        .fontColor(this.primaryTextColor())
        .layoutWeight(1)

      Text(`${this.getVisibleArticles().length} 条`)
        .fontSize(13)
        .fontColor(this.tertiaryTextColor())
        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
        .backgroundColor(this.elevatedSurfaceColor())
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
        .fontColor(index < 3 ? '#FFFFFF' : this.accentColor())
        .width(38)
        .height(38)
        .textAlign(TextAlign.Center)
        .backgroundColor(index < 3 ? '#FF3B30' : this.inactiveMarkBackground())
        .lightUpEffect(this.chipLightDegree(index < 3))
        .borderRadius(19)

      Column({ space: 9 }) {
        Row({ space: 7 }) {
          this.Tag(article.category, this.categorySoftColor(article.category), this.categoryTextColor(article.category))
          Text(article.source)
            .fontSize(12)
            .fontColor(this.tertiaryTextColor())
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(article.publishedAt)
            .fontSize(12)
            .fontColor(this.tertiaryTextColor())
        }
        .width('100%')

        Text(article.title)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())
          .lineHeight(25)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Text(article.summary)
          .fontSize(14)
          .fontColor(this.secondaryTextColor())
          .lineHeight(20)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('›')
        .fontSize(24)
        .fontColor(this.tertiaryTextColor())
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.surfaceColor())
    .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
    .lightUpEffect(this.cardLightDegree(index))
    .borderRadius(28)
    .border({ width: 1, color: this.subtleBorderColor() })
    .alignItems(VerticalAlign.Center)
    .shadow({ radius: 22, color: this.glassShadowColor(), offsetY: 8 })
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
        .fontColor(this.primaryTextColor())

      Text('当前分类没有新闻，换个分类看看。')
        .fontSize(14)
        .fontColor(this.tertiaryTextColor())
    }
    .width('100%')
    .padding({ top: 44, bottom: 44 })
    .backgroundColor(this.surfaceColor())
    .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
    .lightUpEffect(0.92)
    .borderRadius(28)
    .border({ width: 1, color: this.subtleBorderColor() })
  }

  @Builder
  private DetailScreen(article: NewsArticle) {
    Column() {
      Row() {
        Button('‹ 返回')
          .height(36)
          .fontSize(14)
          .fontColor(this.accentColor())
          .backgroundColor(this.isDarkMode ? 'rgba(44, 44, 46, 0.82)' : 'rgba(255, 255, 255, 0.82)')
          .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
          .lightUpEffect(0.94)
          .borderRadius(18)
          .onClick(() => {
            this.closeDetail();
          })

        Blank()

        Text(`阅读 ${article.readingTime}`)
          .fontSize(13)
          .fontColor(this.primaryTextColor())
          .padding({ left: 11, right: 11, top: 7, bottom: 7 })
          .backgroundColor(this.isDarkMode ? 'rgba(44, 44, 46, 0.78)' : 'rgba(255, 255, 255, 0.78)')
          .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
          .lightUpEffect(0.9)
          .borderRadius(16)
      }
      .width('100%')
      .padding({ left: 10, right: 10, top: 8, bottom: 8 })
      .backgroundColor(this.detailToolbarBackground())
      .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
      .lightUpEffect(0.94)
      .border({ width: 1, color: this.subtleBorderColor() })
      .borderRadius(30)
      .shadow({ radius: 20, color: this.glassShadowColor(), offsetY: 8 })
      .margin({ left: 16, right: 16, top: 18, bottom: 12 })

      Scroll(this.detailScroller) {
        Column({ space: 16 }) {
          Column({ space: 14 }) {
            Row({ space: 8 }) {
              this.Tag(article.category, 'rgba(255, 255, 255, 0.92)', this.accentColor())
              this.Tag(article.source, 'rgba(255, 255, 255, 0.22)', '#FFFFFF')
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
                .fontColor('rgba(255, 255, 255, 0.82)')
                .layoutWeight(1)

              Text('固定公共排序')
                .fontSize(12)
                .fontColor('rgba(255, 255, 255, 0.82)')
            }
            .width('100%')
          }
          .width('100%')
          .padding({ left: 22, right: 22, top: 24, bottom: 22 })
          .backgroundColor(this.accentColor())
          .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
          .lightUpEffect(0.96)
          .borderRadius(30)
          .border({ width: 1, color: 'rgba(255, 255, 255, 0.26)' })
          .shadow({ radius: 28, color: this.glassShadowColor(), offsetY: 12 })
          .alignItems(HorizontalAlign.Start)

          Column({ space: 10 }) {
            Text('新闻摘要')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.primaryTextColor())

            Text(article.summary)
              .fontSize(17)
              .fontColor(this.primaryTextColor())
              .lineHeight(28)
              .width('100%')
          }
          .width('100%')
          .padding(20)
          .backgroundColor(this.surfaceColor())
          .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
          .lightUpEffect(0.94)
          .borderRadius(30)
          .border({ width: 1, color: this.subtleBorderColor() })
          .shadow({ radius: 22, color: this.glassShadowColor(), offsetY: 8 })
          .alignItems(HorizontalAlign.Start)

          Column({ space: 10 }) {
            Text('为什么入选')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.primaryTextColor())

            Text(article.selectionReason)
              .fontSize(14)
              .fontColor(this.secondaryTextColor())
              .lineHeight(22)
              .width('100%')
          }
          .width('100%')
          .padding(20)
          .backgroundColor(this.softSurfaceColor())
          .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
          .lightUpEffect(0.95)
          .borderRadius(30)
          .border({ width: 1, color: this.subtleBorderColor() })
          .alignItems(HorizontalAlign.Start)

          Column({ space: 8 }) {
            Text('原文地址')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.primaryTextColor())

            Text(article.url)
              .fontSize(13)
              .fontColor(this.accentColor())
              .lineHeight(20)
              .width('100%')
          }
          .width('100%')
          .padding(20)
          .backgroundColor(this.surfaceColor())
          .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
          .lightUpEffect(0.94)
          .borderRadius(30)
          .border({ width: 1, color: this.subtleBorderColor() })
          .shadow({ radius: 22, color: this.glassShadowColor(), offsetY: 8 })
          .alignItems(HorizontalAlign.Start)

          Button(this.detailBottomHint())
            .height(44)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.hasNextArticle() ? '#FFFFFF' : this.tertiaryTextColor())
            .backgroundColor(this.hasNextArticle() ? this.accentColor() : this.elevatedSurfaceColor())
            .borderRadius(22)
            .enabled(this.hasNextArticle())
            .onClick(() => {
              this.openNextArticleFromDetail();
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 28 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.detailOverlayBackground())
  }

  @Builder
  private SettingsMetric(title: string, value: string, unit: string) {
    Column({ space: 4 }) {
      Text(title)
        .fontSize(13)
        .fontColor(this.tertiaryTextColor())

      Row({ space: 4 }) {
        Text(value)
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())

        Text(unit)
          .fontSize(13)
          .fontColor(this.secondaryTextColor())
          .margin({ top: 10 })
      }
      .alignItems(VerticalAlign.Center)
    }
    .layoutWeight(1)
    .padding(18)
    .backgroundColor(this.surfaceColor())
    .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR)
    .lightUpEffect(0.95)
    .borderRadius(28)
    .border({ width: 1, color: this.subtleBorderColor() })
    .shadow({ radius: 22, color: this.glassShadowColor(), offsetY: 8 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private SettingsInfoRow(title: string, value: string) {
    Row() {
      Text(title)
        .fontSize(14)
        .fontColor(this.secondaryTextColor())
        .layoutWeight(1)

      Text(value)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.primaryTextColor())
        .textAlign(TextAlign.End)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private ThemeToggle() {
    Button(this.themeButtonText())
      .height(34)
      .fontSize(12)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.accentColor())
      .backgroundColor(this.isDarkMode ? 'rgba(255, 255, 255, 0.18)' : 'rgba(255, 255, 255, 0.92)')
      .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
      .lightUpEffect(0.94)
      .borderRadius(17)
      .border({ width: 1, color: this.subtleBorderColor() })
      .padding({ left: 12, right: 12 })
      .onClick(() => {
        this.toggleTheme();
      })
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
