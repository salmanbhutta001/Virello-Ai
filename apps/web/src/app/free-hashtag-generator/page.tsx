import type { Metadata } from 'next';
import HashtagTool from './HashtagTool';

export const metadata: Metadata = {
  title: 'Free Hashtag Generator — Instagram, TikTok & X | Virello AI',
  description:
    'Generate hashtag ideas for your post in seconds — free, no signup, no card. Type your topic, pick a niche, and copy a starter set for Instagram, TikTok or X.',
  alternates: { canonical: '/free-hashtag-generator.html' },
  openGraph: { url: 'https://virelloai.online/free-hashtag-generator.html' },
};

const STEPS = [
  {
    icon: '✎',
    title: '1. Describe your post',
    text: 'Tell the tool what your post is about — a sentence is enough. The words you type become the first hashtags.',
  },
  {
    icon: '✦',
    title: '2. Pick a niche & platform',
    text: 'Choose your niche and where you will post — Instagram, TikTok or X. Each platform gets a sensible number of tags.',
  },
  {
    icon: '⧉',
    title: '3. Copy & post',
    text: 'Copy all the hashtags at once, keep the ones that genuinely fit your post, and drop the rest. A few relevant tags beat a long list of random ones.',
  },
];

const FAQS = [
  {
    q: 'Is it really free?',
    a: 'Yes. Generating hashtags costs nothing and needs no account. The tool runs entirely in your browser — nothing you type is sent to a server.',
  },
  {
    q: 'Will these hashtags make my post go viral?',
    a: 'No — and no honest tool can promise that. Hashtags help the right people discover a good post; reach still depends on your content, your audience and the platform. These are starter ideas, not guaranteed-reach tags.',
  },
  {
    q: 'How many hashtags should I use?',
    a: 'It depends on the platform. Instagram posts usually work well with 8–12 hashtags, TikTok with 3–5, and X with just a few, because every character counts toward the 280-character limit. The tool sizes each set accordingly.',
  },
  {
    q: 'Do I need to sign up to use it?',
    a: 'No. The generator works without an account, and your text stays in your browser. If you want Virello to plan, write and grow your posts for you, that is what the free plan and the app are for — but this tool stands on its own.',
  },
];

export default function FreeHashtagGeneratorPage() {
  // FAQPage JSON-LD — built from the same FAQS array rendered visibly
  // below, so schema always matches the visible page text.
  const faqJsonLd = {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: FAQS.map((f) => ({
      '@type': 'Question',
      name: f.q,
      acceptedAnswer: { '@type': 'Answer', text: f.a },
    })),
  };
  return (
    <main>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(faqJsonLd) }}
      />
      <section className="section">
        <div className="wrap center">
          <span className="kicker">Free Tool · No Signup Needed</span>
          <h1 className="h-xl">
            Free Hashtag <span className="grad-text">Generator</span>
          </h1>
          <p className="lead" style={{ marginTop: 18 }}>
            Stuck on which hashtags to use? Describe your post, pick your
            niche, and get a starter set of hashtag ideas in seconds — free,
            no account needed, and nothing you type ever leaves your browser.
          </p>
        </div>
      </section>

      <section className="section" style={{ paddingTop: 0 }}>
        <div className="wrap">
          <HashtagTool />
        </div>
      </section>

      <section className="section" style={{ paddingTop: 0 }}>
        <div className="wrap">
          <h2 className="h-md center" style={{ marginBottom: 28 }}>
            How it works
          </h2>
          <div className="grid grid-3">
            {STEPS.map((s) => (
              <div key={s.title} className="card">
                <span className="icon">{s.icon}</span>
                <h3>{s.title}</h3>
                <p>{s.text}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="section" style={{ paddingTop: 0 }}>
        <div className="wrap">
          <h2 className="h-md center" style={{ marginBottom: 28 }}>
            Good to know
          </h2>
          <div className="grid grid-3">
            {FAQS.map((f) => (
              <div key={f.q} className="card">
                <h3>{f.q}</h3>
                <p>{f.a}</p>
              </div>
            ))}
          </div>

          <div className="card center" style={{ marginTop: 44, padding: 48 }}>
            <h2 className="h-md">Want hashtags that grow with you?</h2>
            <p className="lead" style={{ margin: '12px auto 24px' }}>
              This tool suggests one set of tags at a time. Virello AI plans
              your posts, matches them with real audiences and tracks what
              actually works — starting free.
            </p>
            <a className="btn btn-grad auth-out" href="/login.html">
              Start Growing Free
            </a>
            <a className="btn btn-grad auth-in" href="/dashboard.html">
              Open Your Dashboard
            </a>
            <p className="small" style={{ marginTop: 18 }}>
              See what else Virello does:{' '}
              <a href="/features.html">features</a>
              {' · '}
              <a href="/free-caption-generator.html">
                generate captions free
              </a>
              {' · '}
              <a href="/score.html">score your post</a>
            </p>
          </div>
        </div>
      </section>
    </main>
  );
}
