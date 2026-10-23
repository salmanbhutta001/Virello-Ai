import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import articlesData from '@/data/articles.json';

type Article = {
  slug: string;
  title: string;
  description: string;
  meta: string;
  hero: string;
  body: string;
};

const articles = articlesData as Article[];

type Props = { params: Promise<{ slug: string }> };

export function generateStaticParams(): { slug: string }[] {
  return articles.map((a) => ({ slug: a.slug }));
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params;
  const article = articles.find((a) => a.slug === slug);
  if (!article) return { title: 'Article not found' };
  return {
    title: article.title,
    description: article.description,
    alternates: { canonical: `/blog/${article.slug}.html` },
    openGraph: {
      type: 'article',
      title: article.title,
      description: article.description,
      url: `https://virelloai.online/blog/${article.slug}.html`,
      images: [{ url: article.hero }],
    },
  };
}

export default async function ArticlePage({ params }: Props) {
  const { slug } = await params;
  const index = articles.findIndex((a) => a.slug === slug);
  if (index === -1) notFound();
  const article = articles[index];

  // "More articles": the next 3 pieces in the list, wrapping around.
  const more = [1, 2, 3].map((i) => articles[(index + i) % articles.length]);

  return (
    <>
      <section className="section" style={{ paddingBottom: 24 }}>
        <div className="wrap">
          <div className="center" style={{ maxWidth: 820, margin: '0 auto' }}>
            <span className="kicker">Virello Blog</span>
            <h1 className="h-lg">{article.title}</h1>
            <p className="mut small" style={{ marginTop: 14 }}>
              {article.meta}
            </p>
          </div>
          <img
            src={article.hero}
            alt=""
            style={{
              width: '100%',
              maxWidth: 920,
              margin: '36px auto 0',
              aspectRatio: '16 / 9',
              objectFit: 'cover',
              borderRadius: 'var(--r-lg)',
            }}
          />
        </div>
      </section>

      <section style={{ paddingBottom: 24 }}>
        <div className="wrap">
          {/*
            article.body is our own generated static content (same HTML the
            legacy static blog-<slug>.html pages shipped) — trusted, first-party
            markup, so dangerouslySetInnerHTML is acceptable here. Never feed
            user-submitted HTML into this.
          */}
          <div
            className="post-body"
            dangerouslySetInnerHTML={{ __html: article.body }}
          />
        </div>
      </section>

      <section className="section" style={{ paddingTop: 32 }}>
        <div className="wrap">
          <div className="card center" style={{ maxWidth: 760, margin: '0 auto' }}>
            <h2 className="h-md">
              Put this into practice with <span className="grad-text">Virello AI</span>
            </h2>
            <p className="lead" style={{ margin: '14px auto 24px' }}>
              Paste a post, choose a goal, and let your AI Growth Manager
              analyse, optimise and grow it — real audiences, honest analytics.
            </p>
            <a href="/login.html" className="btn btn-grad">
              Get Started Free
            </a>
          </div>

          <h2 className="h-md" style={{ margin: '56px 0 20px' }}>
            More articles
          </h2>
          <div className="grid grid-3">
            {more.map((a) => (
              <a
                key={a.slug}
                href={`/blog/${a.slug}.html`}
                className="card"
                style={{
                  padding: 0,
                  overflow: 'hidden',
                  display: 'flex',
                  flexDirection: 'column',
                }}
              >
                <img
                  src={a.hero}
                  alt=""
                  loading="lazy"
                  style={{
                    width: '100%',
                    aspectRatio: '16 / 9',
                    objectFit: 'cover',
                  }}
                />
                <div style={{ padding: '20px' }}>
                  <p className="small mut" style={{ marginBottom: 6 }}>
                    {a.meta}
                  </p>
                  <h3 style={{ marginBottom: 0, fontSize: 17 }}>{a.title}</h3>
                </div>
              </a>
            ))}
          </div>
        </div>
      </section>
    </>
  );
}
