import { http } from '@kit.NetworkKit';
import { EditionMeta, NewsArticle } from '../model/NewsModels';

const DAILY_NEWS_API: string = 'http://121.37.178.24/functions/v1/editions/today?region=cn&language=zh-CN';

interface ApiEdition {
  date?: string;
  region?: string;
  language?: string;
  publishedAt?: string;
  statement?: string;
}

interface ApiArticle {
  id?: string;
  title?: string;
  summary?: string;
  source?: string | ApiSource;
  category?: string;
  publishedAt?: string;
  url?: string;
}

interface ApiSource {
  name?: string;
  homepageUrl?: string;
}

interface ApiEditionItem {
  position?: number;
  selectionReason?: string;
  article?: ApiArticle;
}

interface DailyNewsResponse {
  edition?: ApiEdition;
  items?: ApiEditionItem[];
  error?: string;
  message?: string;
}

export class DailyNewsResult {
  edition: EditionMeta;
  articles: NewsArticle[];

  constructor(edition: EditionMeta, articles: NewsArticle[]) {
    this.edition = edition;
    this.articles = articles;
  }
}

export class DailyNewsService {
  async fetchToday(): Promise<DailyNewsResult> {
    const request = http.createHttp();
    try {
      const response = await request.request(this.freshApiUrl(), {
        method: http.RequestMethod.GET,
        header: {
          'Accept': 'application/json',
          'Cache-Control': 'no-cache'
        },
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 15000
      });

      const body = `${response.result}`;
      const data = this.parseResponse(body);

      if (response.responseCode !== 200) {
        throw new Error(data.message || data.error || `今日新闻加载失败 (${response.responseCode})`);
      }

      return this.normalize(data);
    } catch (error) {
      const message = error instanceof Error ? error.message : `${error}`;
      throw new Error(`网络请求失败：${message}`);
    } finally {
      request.destroy();
    }
  }

  private freshApiUrl(): string {
    return `${DAILY_NEWS_API}&_t=${Date.now()}`;
  }

  private parseResponse(body: string): DailyNewsResponse {
    try {
      return JSON.parse(body) as DailyNewsResponse;
    } catch (_) {
      return {
        message: '今日新闻响应格式异常'
      };
    }
  }

  private normalize(data: DailyNewsResponse): DailyNewsResult {
    const edition = data.edition || {};
    const articles: NewsArticle[] = [];
    const items = data.items || [];

    for (let index = 0; index < items.length; index++) {
      const item = items[index];
      const article = item.article || {};
      const title = `${article.title || ''}`.trim();
      if (title.length === 0) {
        continue;
      }

      const summary = `${article.summary || ''}`.trim();
      articles.push(new NewsArticle(
        `${article.id || `remote-${index}`}`,
        title,
        summary,
        this.sourceName(article.source),
        this.categoryLabel(`${article.category || 'news'}`),
        this.formatPublishedAt(`${article.publishedAt || ''}`),
        `${article.url || ''}`,
        `${item.selectionReason || '按公共重要性、来源多样性和主题配额入选。'}`,
        this.estimateReadingTime(summary)
      ));
    }

    return new DailyNewsResult(
      new EditionMeta(
        `${edition.date || ''}`,
        `${edition.region || 'cn'}`,
        `${edition.language || 'zh-CN'}`,
        this.formatPublishedAt(`${edition.publishedAt || ''}`),
        `${edition.statement || '本期新闻按公共重要性、来源多样性和主题配额生成，不基于个人阅读行为排序。'}`
      ),
      articles
    );
  }

  private sourceName(source?: string | ApiSource): string {
    if (typeof source === 'string') {
      return source.length > 0 ? source : '未知来源';
    }
    return `${source?.name || '未知来源'}`;
  }

  private categoryLabel(category: string): string {
    switch (category) {
      case 'domestic':
        return '国内';
      case 'international':
        return '国际';
      case 'finance':
        return '财经';
      case 'technology':
        return '科技';
      case 'health':
        return '健康';
      case 'education':
        return '教育';
      case 'society':
        return '社会';
      case 'sports':
        return '体育';
      case 'perspective':
        return '视角';
      default:
        return category;
    }
  }

  private formatPublishedAt(value: string): string {
    if (value.length < 16) {
      return value.length > 0 ? value : '刚刚';
    }

    const date = new Date(value);
    const hours = date.getHours();
    const minutes = date.getMinutes();

    if (Number.isNaN(hours) || Number.isNaN(minutes)) {
      return value.substring(11, 16);
    }

    return `${this.twoDigits(hours)}:${this.twoDigits(minutes)}`;
  }

  private twoDigits(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  private estimateReadingTime(summary: string): string {
    const minutes = Math.max(1, Math.ceil(summary.length / 160));
    return `${minutes} 分钟`;
  }
}
