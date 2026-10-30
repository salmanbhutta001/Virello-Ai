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
  // Optional: added by the 2026-10-27 SEO fixes. `date` is the real publish
  // date (only where it could be established from publish records — 12/19);
  // `seoTitle` is the short SERP title for the 5 articles whose full title
  // + " — Virello AI" ran 96–127 chars. `category` comes from the legacy
  // homepage ARTICLES data. Absent fields fall back cleanly.
  // 2026-10-29 template upgrade: `tldr` = 5 key-takeaway bullets rendered in
  // a "Key takeaways" box after the hero; `updated` = YYYY-MM-DD of the last
  // refresh, rendered as "Last updated" + BlogPosting dateModified.
  date?: string;
  seoTitle?: string;
  category?: string;
  tldr?: string[];
  updated?: string;
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
    // Short SERP title where one exists (5 long titles); the full title
    // stays as the on-page H1. Template " — Virello AI" still applies.
    title: article.seoTitle ?? article.title,
    description: article.description,
    alternates: { canonical: `/blog/${article.slug}.html` },
    openGraph: {
      type: 'article',
      title: article.title,
      description: article.description,
      url: `https://virelloai.online/blog/${article.slug}.html`,
      images: [{ url: article.hero }],
    },
    twitter: {
      card: 'summary_large_image',
      title: article.seoTitle ?? article.title,
      description: article.description,
      images: [article.hero],
    },
  };
}

export default async function ArticlePage({ params }: Props) {
  const { slug } = await params;
  const index = articles.findIndex((a) => a.slug === slug);
  if (index === -1) notFound();
  const article = articles[index];

  // "Related articles": topical picks per article (3 each), not list order.
  // Every slug in this map must exist in articles.json.
  const relatedMap: Record<string, string[]> = {
    'why-your-reels-are-stuck-at-200-views': [
      'your-post-flopped-now-what',
      'honest-instagram-reels-playbook',
      'the-first-two-seconds-writing-hooks',
    ],
    'hashtags-in-2026-what-still-works': [
      'instagram-algorithm-2026-honestly-explained',
      'honest-instagram-reels-playbook',
      'posting-times-decoded',
    ],
    'instagram-algorithm-2026-honestly-explained': [
      'honest-instagram-reels-playbook',
      'hashtags-in-2026-what-still-works',
      'analytics-without-self-deception',
    ],
    'honest-tiktok-playbook-new-creators': [
      'youtube-shorts-vs-tiktok-where-to-start',
      'honest-instagram-reels-playbook',
      'one-post-five-platforms-repurposing-playbook',
    ],
    'your-post-flopped-now-what': [
      'the-first-two-seconds-writing-hooks',
      'why-your-reels-are-stuck-at-200-views',
      'posting-times-decoded',
    ],
    'plan-a-month-of-content-in-one-afternoon': [
      'one-post-five-platforms-repurposing-playbook',
      'the-first-two-seconds-writing-hooks',
      'posting-times-decoded',
    ],
    'honest-creator-home-studio-guide': [
      'youtube-shorts-vs-tiktok-where-to-start',
      'honest-instagram-reels-playbook',
      'the-first-two-seconds-writing-hooks',
    ],
    'analytics-without-self-deception': [
      'reach-is-not-growth-5-numbers-that-matter',
      'how-ai-content-analysis-actually-works',
      'instagram-algorithm-2026-honestly-explained',
    ],
    'comments-are-the-new-followers': [
      'honest-instagram-reels-playbook',
      'growing-on-x-2026-text-first-playbook',
      'reach-is-not-growth-5-numbers-that-matter',
    ],
    'free-grow-vs-paid-boost': [
      'inside-the-ai-growth-orchestrator',
      'what-an-ai-growth-manager-actually-does',
      'why-fake-followers-cost-more',
    ],
    'growing-on-x-2026-text-first-playbook': [
      'honest-instagram-reels-playbook',
      'comments-are-the-new-followers',
      'youtube-shorts-vs-tiktok-where-to-start',
    ],
    'honest-instagram-reels-playbook': [
      'why-your-reels-are-stuck-at-200-views',
      'instagram-algorithm-2026-honestly-explained',
      'hashtags-in-2026-what-still-works',
    ],
    'honest-state-of-social-media-late-2026': [
      'why-fake-followers-cost-more',
      'spot-the-scam-growth-service-signs',
      'free-grow-vs-paid-boost',
    ],
    'how-ai-content-analysis-actually-works': [
      'inside-the-ai-growth-orchestrator',
      'analytics-without-self-deception',
      'your-post-flopped-now-what',
    ],
    'inside-the-ai-growth-orchestrator': [
      'how-ai-content-analysis-actually-works',
      'what-an-ai-growth-manager-actually-does',
      'free-grow-vs-paid-boost',
    ],
    'one-post-five-platforms-repurposing-playbook': [
      'plan-a-month-of-content-in-one-afternoon',
      'honest-instagram-reels-playbook',
      'honest-creator-home-studio-guide',
    ],
    'posting-times-decoded': [
      'comments-are-the-new-followers',
      'honest-instagram-reels-playbook',
      'hashtags-in-2026-what-still-works',
    ],
    'reach-is-not-growth-5-numbers-that-matter': [
      'analytics-without-self-deception',
      'comments-are-the-new-followers',
      'what-an-ai-growth-manager-actually-does',
    ],
    'spot-the-scam-growth-service-signs': [
      'why-fake-followers-cost-more',
      'honest-state-of-social-media-late-2026',
      'free-grow-vs-paid-boost',
    ],
    'the-first-two-seconds-writing-hooks': [
      'your-post-flopped-now-what',
      'honest-instagram-reels-playbook',
      'why-your-reels-are-stuck-at-200-views',
    ],
    'what-an-ai-growth-manager-actually-does': [
      'inside-the-ai-growth-orchestrator',
      'how-ai-content-analysis-actually-works',
      'free-grow-vs-paid-boost',
    ],
    'why-fake-followers-cost-more': [
      'spot-the-scam-growth-service-signs',
      'honest-state-of-social-media-late-2026',
      'free-grow-vs-paid-boost',
    ],
    'youtube-shorts-vs-tiktok-where-to-start': [
      'honest-tiktok-playbook-new-creators',
      'honest-instagram-reels-playbook',
      'instagram-algorithm-2026-honestly-explained',
    ],
  };
  const relatedSlugs =
    relatedMap[article.slug] ??
    [1, 2, 3].map((i) => articles[(index + i) % articles.length].slug);
  const more = relatedSlugs
    .map((s) => articles.find((a) => a.slug === s))
    .filter((a): a is Article => Boolean(a));

  // BlogPosting JSON-LD (SEO fixes 2026-10-27). datePublished only when a
  // real publish date is recorded in articles.json (12/19); the other 7
  // omit it rather than carry a guessed date. dateModified renders from the
  // `updated` field (2026-10-29+), which is set whenever an article is
  // refreshed — including the 2026-10-29 template-upgrade refresh of all
  // articles.
  const wordCount = (html: string) =>
    html
      .replace(/<[^>]*>/g, ' ')
      .replace(/&[a-zA-Z]+;/g, ' ')
      .split(/\s+/)
      .filter(Boolean).length;
  const formatDate = (iso: string) => {
    const [y, m, d] = iso.split('-').map(Number);
    return new Date(y, m - 1, d).toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    });
  };
  // FAQ extraction (2026-10-29): the article bodies carry their FAQ as
  // <h3>Frequently asked questions</h3> + <h4>Q</h4><p>A</p> pairs. Mirror
  // them into FAQPage JSON-LD so the visible FAQs can win rich results.
  // Articles without an FAQ section simply get no FAQPage block.
  const extractFaqs = (html: string): { q: string; a: string }[] => {
    const marker = html.match(/<h3>Frequently asked questions<\/h3>/);
    if (!marker || marker.index === undefined) return [];
    let seg = html.slice(marker.index + marker[0].length);
    const nextH3 = seg.search(/<h3>/);
    if (nextH3 !== -1) seg = seg.slice(0, nextH3);
    const strip = (s: string) =>
      s
        .replace(/<[^>]*>/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();
    const pairs: { q: string; a: string }[] = [];
    const re = /<h4>([\s\S]*?)<\/h4>\s*<p>([\s\S]*?)<\/p>/g;
    let mm: RegExpExecArray | null;
    while ((mm = re.exec(seg)) !== null) {
      pairs.push({ q: strip(mm[1]), a: strip(mm[2]) });
    }
    return pairs;
  };
  const faqs = extractFaqs(article.body);
  const faqJsonLd = faqs.length
    ? {
        '@context': 'https://schema.org',
        '@type': 'FAQPage',
        mainEntity: faqs.map((f) => ({
          '@type': 'Question',
          name: f.q,
          acceptedAnswer: { '@type': 'Answer', text: f.a },
        })),
      }
    : null;
  const jsonLd = {
    '@context': 'https://schema.org',
    '@type': 'BlogPosting',
    headline: article.title,
    description: article.description,
    // AEO 2026-10-28: the visible "Short answer" box below renders this
    // same description, so abstract matches the page text.
    abstract: article.description,
    image: article.hero,
    author: {
      '@type': 'Organization',
      name: 'Virello Team',
      url: 'https://virelloai.online/',
    },
    publisher: {
      '@type': 'Organization',
      name: 'Virello AI',
      url: 'https://virelloai.online/',
      logo: {
        '@type': 'ImageObject',
        url: 'https://virelloai.online/logo-virello.png',
      },
    },
    ...(article.date ? { datePublished: article.date } : {}),
    ...(article.updated ? { dateModified: article.updated } : {}),
    mainEntityOfPage: `https://virelloai.online/blog-${article.slug}.html`,
    articleSection: article.category,
    wordCount: wordCount(article.body),
    inLanguage: 'en',
  };

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />
      {faqJsonLd && (
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(faqJsonLd) }}
        />
      )}
      <section className="section" style={{ paddingBottom: 24 }}>
        <div className="wrap">
          <div className="center" style={{ maxWidth: 820, margin: '0 auto' }}>
            <span className="kicker">Virello Blog</span>
            <h1 className="h-lg">{article.title}</h1>
            <p className="mut small" style={{ marginTop: 14 }}>
              {article.meta}
              {article.updated && (
                <> · Last updated {formatDate(article.updated)}</>
              )}
            </p>
            {/* Short answer (AEO 2026-10-28): the article's own
                description, rendered as a direct answer up front so
                readers — and answer engines — get the point in 2–3
                sentences before the full article. */}
            <div
              className="card"
              style={{
                maxWidth: 820,
                margin: '28px auto 0',
                padding: '20px 24px',
                textAlign: 'left',
                borderColor: 'rgba(249, 81, 119, 0.35)',
              }}
            >
              <p style={{ margin: 0, fontSize: 15, lineHeight: 1.65 }}>
                <strong style={{ fontFamily: 'var(--font-d)' }}>
                  Short answer:{' '}
                </strong>
                {article.description}
              </p>
            </div>
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

      {/* Key takeaways (2026-10-29 template upgrade): 5 bullets from the
          article's own content, rendered right after the hero so readers —
          and answer engines — get the substance before the full read. Only
          renders when the article carries a `tldr` array. */}
      {article.tldr && article.tldr.length > 0 && (
        <section style={{ paddingBottom: 8 }}>
          <div className="wrap">
            <div
              className="card"
              style={{
                maxWidth: 820,
                margin: '0 auto',
                padding: '20px 24px',
                textAlign: 'left',
                borderColor: 'rgba(120, 20, 58, 0.25)',
              }}
            >
              <h2 style={{ fontSize: 17, margin: '0 0 10px' }}>
                Key takeaways
              </h2>
              <ul
                style={{
                  margin: 0,
                  paddingLeft: 20,
                  fontSize: 15,
                  lineHeight: 1.7,
                }}
              >
                {article.tldr.map((t, i) => (
                  <li key={i} style={{ marginBottom: 6 }}>
                    {t}
                  </li>
                ))}
              </ul>
            </div>
          </div>
        </section>
      )}

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
          {/* Author byline (2026-10-29 template upgrade): visible E-E-A-T
              signal on every article. */}
          <div
            className="card"
            style={{
              maxWidth: 820,
              margin: '32px auto 0',
              padding: '20px 24px',
              textAlign: 'left',
            }}
          >
            <p style={{ margin: 0, fontSize: 14, lineHeight: 1.65 }}>
              <strong style={{ fontFamily: 'var(--font-d)' }}>
                Written by the Virello Team
              </strong>
              <br />
              <span className="mut">
                We build Virello AI — your AI growth manager for social media.
                Honest analytics, real audiences, no bots, no fake engagement.
              </span>
            </p>
          </div>
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
            <a href="/login.html" className="btn btn-grad auth-out">
              Get Started Free
            </a>
            <a href="/dashboard.html" className="btn btn-grad auth-in">
              Get Started Free
            </a>
          </div>

          <p
            className="small center"
            style={{ marginTop: 22, color: 'var(--mut)' }}
          >
            Explore Virello:{' '}
            <a href="/shop.html">Shop</a>
            {' · '}
            <a href="/score.html">Score your post</a>
            {' · '}
            <a href="/free-caption-generator.html">Free caption generator</a>
            {' · '}
            <a href="/pricing.html">Pricing</a>
          </p>

          <h2 className="h-md" style={{ margin: '56px 0 20px' }}>
            Related articles
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
