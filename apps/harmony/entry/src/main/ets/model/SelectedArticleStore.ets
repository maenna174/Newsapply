import { MOCK_ARTICLES } from '../data/MockNewsData';
import { NewsArticle } from './NewsModels';

export class SelectedArticleStore {
  private static currentArticle: NewsArticle = MOCK_ARTICLES[0];
  private static currentList: NewsArticle[] = MOCK_ARTICLES;

  public static setArticle(article: NewsArticle, articleList: NewsArticle[]): void {
    SelectedArticleStore.currentArticle = article;
    SelectedArticleStore.currentList = articleList;
  }

  public static getArticle(): NewsArticle {
    return SelectedArticleStore.currentArticle;
  }

  public static hasPrevious(): boolean {
    return SelectedArticleStore.currentIndex() > 0;
  }

  public static hasNext(): boolean {
    const index = SelectedArticleStore.currentIndex();
    return index >= 0 && index < SelectedArticleStore.currentList.length - 1;
  }

  public static selectPrevious(): NewsArticle {
    const index = SelectedArticleStore.currentIndex();
    if (index > 0) {
      SelectedArticleStore.currentArticle = SelectedArticleStore.currentList[index - 1];
    }
    return SelectedArticleStore.currentArticle;
  }

  public static selectNext(): NewsArticle {
    const index = SelectedArticleStore.currentIndex();
    if (index >= 0 && index < SelectedArticleStore.currentList.length - 1) {
      SelectedArticleStore.currentArticle = SelectedArticleStore.currentList[index + 1];
    }
    return SelectedArticleStore.currentArticle;
  }

  private static currentIndex(): number {
    for (let index = 0; index < SelectedArticleStore.currentList.length; index++) {
      if (SelectedArticleStore.currentList[index].id === SelectedArticleStore.currentArticle.id) {
        return index;
      }
    }
    return -1;
  }
}
