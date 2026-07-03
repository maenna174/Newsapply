import { NewsArticle } from '../model/NewsModels';
import { SelectedArticleStore } from '../model/SelectedArticleStore';

@Entry
@ComponentV2
struct Detail {
  @Local article: NewsArticle = SelectedArticleStore.getArticle();
  @Local environmentReady: boolean = false;
  @Local isDarkMode: boolean = false;

  private detailScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.syncSystemDarkMode();
    this.article = SelectedArticleStore.getArticle();
  }

  private syncSystemDarkMode(): void {
    if (!this.environmentReady) {
      Environment.envProp<ColorMode>('colorMode', ColorMode.LIGHT);
      this.environmentReady = true;
    }
    const colorMode: ColorMode | undefined = AppStorage.get<ColorMode>('colorMode');
    if (colorMode !== undefined) {
      this.isDarkMode = colorMode === ColorMode.DARK;
    }
  }

  private pageBackground(): Resource {
    return $r('app.color.detail_overlay_background');
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

  private detailToolbarBackground(): Resource {
    return $r('app.color.detail_toolbar_background');
  }

  private accentColor(): Resource {
    return $r('app.color.accent_color');
  }

  private glassShadowColor(): Resource {
    return $r('app.color.glass_shadow_color');
  }

  private detailControlBackground(): ResourceColor {
    return this.isDarkMode ? 'rgba(44, 44, 46, 0.82)' : 'rgba(255, 255, 255, 0.82)';
  }

  private detailControlSoftBackground(): ResourceColor {
    return this.isDarkMode ? 'rgba(44, 44, 46, 0.78)' : 'rgba(255, 255, 255, 0.78)';
  }

  private hasPreviousArticle(): boolean {
    return SelectedArticleStore.hasPrevious();
  }

  private hasNextArticle(): boolean {
    return SelectedArticleStore.hasNext();
  }

  private switchToPreviousArticle(): void {
    if (!this.hasPreviousArticle()) {
      return;
    }
    this.article = SelectedArticleStore.selectPrevious();
    this.detailScroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false });
  }

  private switchToNextArticle(): void {
    if (!this.hasNextArticle()) {
      return;
    }
    this.article = SelectedArticleStore.selectNext();
    this.detailScroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false });
  }

  build() {
    Column() {
      Row() {
        Button('‹ 返回')
          .height(36)
          .fontSize(14)
          .fontColor(this.accentColor())
          .backgroundColor(this.detailControlBackground())
          .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
          .lightUpEffect(0.94)
          .borderRadius(18)
          .onClick(() => {
            try {
              this.getUIContext().getRouter().back();
            } catch (error) {
            }
          })

        Blank()

        Text('阅读 ' + this.article.readingTime)
          .fontSize(13)
          .fontColor(this.primaryTextColor())
          .padding({ left: 11, right: 11, top: 7, bottom: 7 })
          .backgroundColor(this.detailControlSoftBackground())
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
      .borderRadius(24)
      .shadow({ radius: 14, color: this.glassShadowColor(), offsetY: 5 })
      .margin({ left: 16, right: 16, top: 18, bottom: 12 })

      Scroll(this.detailScroller) {
        Column({ space: 16 }) {
          Column({ space: 14 }) {
            Row({ space: 8 }) {
              this.Tag(this.article.category, 'rgba(255, 255, 255, 0.92)', this.accentColor())
              this.Tag(this.article.source, 'rgba(255, 255, 255, 0.22)', '#FFFFFF')
            }
            .width('100%')

            Text(this.article.title)
              .fontSize(29)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .lineHeight(38)
              .width('100%')

            Row() {
              Text(this.article.publishedAt)
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
          .borderRadius(24)
          .border({ width: 1, color: 'rgba(255, 255, 255, 0.26)' })
          .shadow({ radius: 18, color: this.glassShadowColor(), offsetY: 8 })
          .alignItems(HorizontalAlign.Start)

          this.DetailBlock('新闻摘要', this.article.summary, this.primaryTextColor(), this.surfaceColor())
          this.DetailBlock('为什么入选', this.article.selectionReason, this.secondaryTextColor(), this.softSurfaceColor())
          this.DetailBlock('原文地址', this.article.url, this.accentColor(), this.surfaceColor())

          Row({ space: 12 }) {
            Button('上一条')
              .height(44)
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.hasPreviousArticle() ? '#FFFFFF' : this.tertiaryTextColor())
              .backgroundColor(this.hasPreviousArticle() ? this.accentColor() : this.elevatedSurfaceColor())
              .borderRadius(22)
              .layoutWeight(1)
              .enabled(this.hasPreviousArticle())
              .onClick(() => {
                this.switchToPreviousArticle();
              })

            Button('下一条')
              .height(44)
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.hasNextArticle() ? '#FFFFFF' : this.tertiaryTextColor())
              .backgroundColor(this.hasNextArticle() ? this.accentColor() : this.elevatedSurfaceColor())
              .borderRadius(22)
              .layoutWeight(1)
              .enabled(this.hasNextArticle())
              .onClick(() => {
                this.switchToNextArticle();
              })
          }
          .width('100%')
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 28 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBackground())
  }

  @Builder
  private DetailBlock(title: string, content: string, contentColor: ResourceColor, background: ResourceColor) {
    Column({ space: 10 }) {
      Text(title)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.primaryTextColor())

      Text(content)
        .fontSize(title === '新闻摘要' ? 17 : 14)
        .fontColor(contentColor)
        .lineHeight(title === '新闻摘要' ? 28 : 22)
        .width('100%')
    }
    .width('100%')
    .padding(20)
    .backgroundColor(background)
    .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
    .lightUpEffect(0.94)
    .borderRadius(24)
    .border({ width: 1, color: this.subtleBorderColor() })
    .shadow({ radius: 14, color: this.glassShadowColor(), offsetY: 5 })
    .alignItems(HorizontalAlign.Start)
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
