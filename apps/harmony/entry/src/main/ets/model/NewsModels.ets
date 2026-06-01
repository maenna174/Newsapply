export class NewsArticle {
  id: string;
  title: string;
  summary: string;
  source: string;
  category: string;
  publishedAt: string;
  url: string;
  selectionReason: string;
  readingTime: string;

  constructor(
    id: string,
    title: string,
    summary: string,
    source: string,
    category: string,
    publishedAt: string,
    url: string,
    selectionReason: string,
    readingTime: string
  ) {
    this.id = id;
    this.title = title;
    this.summary = summary;
    this.source = source;
    this.category = category;
    this.publishedAt = publishedAt;
    this.url = url;
    this.selectionReason = selectionReason;
    this.readingTime = readingTime;
  }
}

export class EditionMeta {
  editionDate: string;
  region: string;
  language: string;
  publishedAt: string;
  statement: string;

  constructor(editionDate: string, region: string, language: string, publishedAt: string, statement: string) {
    this.editionDate = editionDate;
    this.region = region;
    this.language = language;
    this.publishedAt = publishedAt;
    this.statement = statement;
  }
}
