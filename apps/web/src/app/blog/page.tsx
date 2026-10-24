import type { Metadata } from 'next';
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

export const metadata: Metadata = {
  title: 'Blog',
  description:
    'Honest growth playbooks from the Virello team: analytics, hooks, repurposing, platform strategy and how AI growth tools actually work — no fake-engagement shortcuts.',
  alternates: { canonical: '/blog.html' },
  openGraph: {
    type: 'website',
    title: 'Blog — Virello AI',
    description:
      'Honest growth playbooks from the Virello team — analytics, hooks, repurposing and platform strategy.',
    url: 'https://virelloai.online/blog.html',
  },
};

export default function BlogIndexPage() {
  // Newest article first (articles.json is newest-first) — the featured
  // hero post; the grid below shows the rest so nothing appears twice.
  const [featured, ...rest] = articles;
  return (
    <>
      <section className="hero">
        <div className="wrap">
          <span className="kicker">Virello Blog</span>
          <h1 className="h-xl">
            Growth, <span className="grad-text">without the gimmicks</span>
          </h1>
          <p className="lead">
            Honest playbooks on analytics, content and AI growth tools — what
            actually works, what is a scam, and how to tell the difference.
          </p>
        </div>
      </section>

      {featured && (
        <section className="section" style={{ paddingTop: 16, paddingBottom: 0 }}>
          <div className="wrap">
            <a
              href={`/blog/${featured.slug}.html`}
              className="card hero-post"
              style={{ padding: 0 }}
            >
              <img
                className="hero-post-img"
                src={featured.hero}
                alt=""
              />
              <div className="hero-post-body">
                <span
                  className="small"
                  style={{ color: 'var(--pink)', fontWeight: 700, letterSpacing: '0.12em', textTransform: 'uppercase' }}
                >
                  Featured
                </span>
                <p className="small mut" style={{ marginBottom: 0 }}>{featured.meta}</p>
                <h2 style={{ marginBottom: 0 }}>{featured.title}</h2>
                <p style={{ flex: 1 }}>{featured.description}</p>
                <span
                  className="small"
                  style={{ color: 'var(--pink)', fontWeight: 600 }}
                >
                  Read article →
                </span>
              </div>
            </a>
          </div>
        </section>
      )}

      <section className="section" style={{ paddingTop: 32 }}>
        <div className="wrap">
          <div className="grid grid-3">
            {rest.map((a) => (
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
                {/* Plain <img>: static export has no image optimizer configured. */}
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
                <div
                  style={{
                    padding: '22px',
                    display: 'flex',
                    flexDirection: 'column',
                    gap: 8,
                    flex: 1,
                  }}
                >
                  <p className="small mut">{a.meta}</p>
                  <h3 style={{ marginBottom: 0 }}>{a.title}</h3>
                  <p style={{ flex: 1 }}>{a.description}</p>
                  <span
                    className="small"
                    style={{ color: 'var(--pink)', fontWeight: 600 }}
                  >
                    Read article →
                  </span>
                </div>
              </a>
            ))}
          </div>
        </div>
      </section>
    </>
  );
}
