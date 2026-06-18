import { ConfigurationConstant } from '@kit.AbilityKit';
import { HdsTabs, hdsMaterial } from '@kit.UIDesignKit';
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
  @Local themeMode: string = 'system';
  @Local systemDarkMode: boolean = false;
  @Local environmentReady: boolean = false;
  @Local isDarkMode: boolean = false;
  @Local articles: NewsArticle[] = MOCK_ARTICLES;
  @Local aiArticles: NewsArticle[] = AI_ARTICLES;
  @Local edition: EditionMeta = TODAY_EDITION;

  private dailyNewsService: DailyNewsService = new DailyNewsService();
  private detailScroller: Scroller = new Scroller();
  private themeSyncTimer: number = -1;
  private categoryOrder: string[] = ['全部', '国内', '国际', '财经', '科技', '健康', '教育', '社会', '体育', '视角'];

  aboutToAppear(): void {
    this.applyThemeMode();
    this.startThemeSyncTimer();
    this.loadTodayNews();
    this.loadAiNews();
  }

  aboutToDisappear(): void {
    this.stopThemeSyncTimer();
  }

  onPageShow(): void {
    this.applyThemeMode();
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

  private statusColor(): Resource {
    if (this.statusText.includes('失败')) {
      return $r('app.color.status_error_text');
    }
    return $r('app.color.status_success_text');
  }

  private statusBackground(): Resource {
    if (this.statusText.includes('失败')) {
      return $r('app.color.status_error_background');
    }
    return $r('app.color.status_success_background');
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
    if (this.activeTab === tab) {
      return;
    }
    this.getUIContext().animateTo({ duration: 260, curve: Curve.EaseOut }, () => {
      this.activeTab = tab;
    });
  }

  private switchTabIndex(index: number): void {
    this.switchTab(this.tabByIndex(index));
  }

  private applyThemeMode(): void {
    this.syncSystemDarkMode();
    this.isDarkMode = this.themeMode === 'dark' || (this.themeMode === 'system' && this.systemDarkMode);
    this.applyAppColorMode();
  }

  private startThemeSyncTimer(): void {
    if (this.themeSyncTimer >= 0) {
      return;
    }
    this.themeSyncTimer = setInterval(() => {
      if (this.themeMode === 'system') {
        this.applyThemeMode();
      }
    }, 800);
  }

  private stopThemeSyncTimer(): void {
    if (this.themeSyncTimer < 0) {
      return;
    }
    clearInterval(this.themeSyncTimer);
    this.themeSyncTimer = -1;
  }

  private syncSystemDarkMode(): void {
    if (!this.environmentReady) {
      Environment.envProp<ColorMode>('colorMode', ColorMode.LIGHT);
      this.environmentReady = true;
    }
    const colorMode: ColorMode | undefined = AppStorage.get<ColorMode>('colorMode');
    if (colorMode !== undefined) {
      this.systemDarkMode = colorMode === ColorMode.DARK;
    }
  }

  private applyAppColorMode(): void {
    let colorMode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    if (this.themeMode === 'dark') {
      colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    } else if (this.themeMode === 'light') {
      colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    }
    try {
      getContext(this).getApplicationContext().setColorMode(colorMode);
    } catch (error) {
    }
  }

  private setThemeMode(mode: string): void {
    this.themeMode = mode;
    this.applyThemeMode();
  }

  private themeColorMode(): ThemeColorMode {
    if (this.themeMode === 'dark') {
      return ThemeColorMode.DARK;
    }
    if (this.themeMode === 'light') {
      return ThemeColorMode.LIGHT;
    }
    return ThemeColorMode.SYSTEM;
  }

  private pageBackground(): Resource {
    return $r('app.color.page_background');
  }

  private surfaceColor(): Resource {
    return $r('app.color.surface_color');
  }

  private elevatedSurfaceColor(): Resource {
    return $r('app.color.elevated_surface_color');
  }

  private softSurfaceColor(): Resource {
    return $r('app.color.soft_surface_color');
  }

  private primaryTextColor(): Resource {
    return $r('app.color.primary_text_color');
  }

  private secondaryTextColor(): Resource {
    return $r('app.color.secondary_text_color');
  }

  private tertiaryTextColor(): Resource {
    return $r('app.color.tertiary_text_color');
  }

  private subtleBorderColor(): Resource {
    return $r('app.color.subtle_border_color');
  }

  private inactiveMarkBackground(): Resource {
    return $r('app.color.inactive_mark_background');
  }

  private detailOverlayBackground(): Resource {
    return $r('app.color.detail_overlay_background');
  }

  private detailToolbarBackground(): Resource {
    return $r('app.color.detail_toolbar_background');
  }

  private accentColor(): Resource {
    return $r('app.color.accent_color');
  }

  private glassShadowColor(): Resource {
    return $r('app.color.glass_shadow_color');
  }

  private glassHighlightColor(): Resource {
    return $r('app.color.glass_highlight_color');
  }

  private themeButtonText(): string {
    if (this.themeMode === 'dark') {
      return '深色';
    }
    if (this.themeMode === 'light') {
      return '浅色';
    }
    return '跟随系统';
  }

  private themeStatusText(): string {
    if (this.themeMode === 'system') {
      return this.isDarkMode ? '跟随系统 · 当前深色' : '跟随系统 · 当前浅色';
    }
    return this.isDarkMode ? '当前为深色模式' : '当前为浅色模式';
  }

  private themeOptionBackground(mode: string): Resource {
    if (this.themeMode === mode) {
      return $r('app.color.theme_option_selected_background');
    }
    return $r('app.color.theme_option_unselected_background');
  }

  private themeOptionTextColor(mode: string): Resource {
    return this.themeMode === mode ? this.accentColor() : this.secondaryTextColor();
  }

  private settingsLightDegree(): number {
    return 0.95;
  }

  private settingsControlBackground(): Resource {
    return this.inactiveMarkBackground();
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
    WithTheme({ colorMode: this.themeColorMode() }) {
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
  }

  @Builder
  private HomeScreen() {
    Column() {
      HdsTabs({ index: this.activeTabIndex() }) {
        TabContent() {
          this.TodayContent()
        }
        .tabBar(this.TabBarItem(0, '今日', $r('sys.symbol.house')))

        TabContent() {
          this.AiScreen()
        }
        .tabBar(this.TabBarItem(1, 'AI', $r('sys.symbol.AI_person')))

        TabContent() {
          this.SettingsScreen()
        }
        .tabBar(this.TabBarItem(2, '设置', $r('sys.symbol.gearshape')))
      }
      .onChange((index: number) => {
        this.switchTabIndex(index);
      })
      .vertical(false)
      .barPosition(BarPosition.End)
      .barMode(BarMode.Fixed)
      .barHeight(64)
      .barOverlap(true)
      .barFloatingStyle({
        barSideMargin: 18,
        barBottomMargin: 28,
        lightColor: this.accentColor(),
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        },
        thermoCtrl: true,
        barOpacity: 0.88
      })
      .barBackgroundBlurStyle(BlurStyle.Regular)
      .barBackgroundColor(Color.Transparent)
      .animationDuration(260)
      .width('100%')
      .height('100%')
      .backgroundColor(this.pageBackground())
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT], [SafeAreaEdge.BOTTOM])
    .backgroundColor(this.pageBackground())
  }

  @Builder
  private TabBarItem(index: number, title: string, icon: Resource) {
    Column() {
      SymbolGlyph(icon)
        .fontColor([this.activeTabIndex() === index ? $r('sys.color.ohos_id_color_primary') : $r('sys.color.ohos_id_color_secondary')])
        .fontSize(24)
        .symbolEffect(new BounceSymbolEffect(), this.activeTabIndex() === index)

      Text(title)
        .fontSize(10)
        .fontColor(this.activeTabIndex() === index ? $r('sys.color.ohos_id_color_primary') : $r('sys.color.ohos_id_color_secondary'))
        .margin({ top: 4 })
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .height('100%')
    .width('100%')
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
          .padding({ left: 16, right: 16, top: 16, bottom: 92 })
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
      .padding({ left: 18, right: 18, top: 18, bottom: 92 })
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

              Text(this.themeStatusText())
                .fontSize(13)
                .fontColor(this.secondaryTextColor())
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            this.ThemeToggle()
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Text('默认跟随系统，也可以固定浅色或深色；会同步影响首页、AI 专区、详情页和底部导航。')
            .fontSize(13)
            .fontColor(this.tertiaryTextColor())
            .lineHeight(20)
            .width('100%')
        }
        .width('100%')
        .padding(18)
        .backgroundColor(this.surfaceColor())
        .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR)
        .lightUpEffect(this.settingsLightDegree())
        .borderRadius(28)
        .border({ width: 1, color: this.subtleBorderColor() })
        .shadow({ radius: 24, color: this.glassShadowColor(), offsetY: 10 })

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
        .lightUpEffect(this.settingsLightDegree())
        .borderRadius(28)
        .border({ width: 1, color: this.subtleBorderColor() })
        .shadow({ radius: 24, color: this.glassShadowColor(), offsetY: 10 })

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
        .lightUpEffect(this.settingsLightDegree())
        .borderRadius(28)
        .border({ width: 1, color: this.subtleBorderColor() })
        .shadow({ radius: 24, color: this.glassShadowColor(), offsetY: 10 })

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
        .backgroundColor(this.surfaceColor())
        .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
        .lightUpEffect(this.settingsLightDegree())
        .borderRadius(28)
        .border({ width: 1, color: this.subtleBorderColor() })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 22, bottom: 92 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBackground())
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
    .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
    .lightUpEffect(this.settingsLightDegree())
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
    Row({ space: 6 }) {
      this.ThemeOption('system', '跟随')
      this.ThemeOption('light', '浅色')
      this.ThemeOption('dark', '深色')
    }
    .height(38)
    .padding({ left: 4, right: 4, top: 4, bottom: 4 })
    .backgroundColor(this.settingsControlBackground())
    .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
    .lightUpEffect(0.9)
    .borderRadius(19)
    .border({ width: 1, color: this.subtleBorderColor() })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private ThemeOption(mode: string, label: string) {
    Text(label)
      .fontSize(12)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.themeOptionTextColor(mode))
      .textAlign(TextAlign.Center)
      .height(30)
      .padding({ left: 12, right: 12 })
      .backgroundColor(this.themeOptionBackground(mode))
      .borderRadius(15)
      .onClick(() => {
        this.setThemeMode(mode);
      })
  }

  @Builder
  private Tag(text: string, background: ResourceColor, color: ResourceColor) {
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
