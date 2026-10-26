import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Features',
  description:
    'Every Virello feature serves one job: getting your content in front of the people most likely to love it — legitimately.',
  alternates: { canonical: '/features.html' },
};

type FeatureCard = { icon: string; title: string; text: string };

const FEATURES: FeatureCard[] = [
  {
    icon: '✦',
    title: 'AI Content Analysis',
    text: 'Deep analysis of hooks, pacing, captions and format. Get a viral-potential score and concrete fixes before you launch.',
  },
  {
    icon: '◎',
    title: 'Smart Audience Matching',
    text: 'AI matches your content with audience segments that have genuinely shown interest in your niche — across 248 countries & territories.',
  },
  {
    icon: '↗',
    title: 'Organic Growth Engine',
    text: 'Free Grow AI optimizes posting strategy and discovery, winds down gracefully near free-plan reach caps, and never touches your money.',
  },
  {
    icon: '»',
    title: 'AI Paid Boost',
    text: 'Paid Boost AI paces your budget, watches cost-efficiency and respects the geo and package limits you approve — nothing more.',
  },
  {
    icon: '▤',
    title: 'Real-Time Analytics',
    text: 'Live reach, impressions, engagement, profile visits, clicks and follower growth — per post, per campaign, per country.',
  },
  {
    icon: '✓',
    title: 'Fraud & Safety Protection',
    text: 'A dedicated Fraud & Safety agent filters invalid activity and keeps every campaign compliant with platform rules.',
  },
  {
    icon: '↻',
    title: 'AI Optimization',
    text: 'The Optimization agent tests, learns and adjusts daily — shifting effort toward what is provably working for your content.',
  },
  {
    icon: '⊕',
    title: 'Global Reach, Local Sense',
    text: 'AI Recommended geography, worldwide campaigns or hand-picked countries — every suggested country comes with a reason you approve.',
  },
  {
    icon: '✚',
    title: 'Creator Hub & AI Tools',
    text: 'Create and edit videos with AI assistance, generate content ideas, and manage your whole creator workflow in one place.',
  },
  {
    icon: '✎',
    title: 'Ask Virello',
    text: 'One AI assistant that routes your request to the right agent — growth advice, campaign help, shop and support, in your language.',
  },
  {
    icon: '✷',
    title: 'Secure Connections',
    text: 'Accounts connect through official, authorized sign-in only. Virello never asks for or stores your social media password.',
  },
  {
    icon: '❖',
    title: 'Plain-Language Reports',
    text: 'Weekly summaries that explain what grew, why it grew, and what the AI will do next — no jargon, no vanity metrics.',
  },
];

export default function FeaturesPage() {
  return (
    <main>
      <section className="section">
        <div className="wrap center">
          <span className="kicker">Features</span>
          <h1 className="h-xl">
            Built to grow you. <span className="grad-text">Powered by AI.</span>
          </h1>
          <p className="lead" style={{ marginTop: 18 }}>
            Every Virello feature serves one job: getting your content in front
            of the people most likely to love it — legitimately.
          </p>
        </div>
      </section>

      <section className="section" style={{ paddingTop: 0 }}>
        <div className="wrap">
          <div className="grid grid-3">
            {FEATURES.map((f) => (
              <div key={f.title} className="card">
                <span className="icon">{f.icon}</span>
                <h3>{f.title}</h3>
                <p>{f.text}</p>
              </div>
            ))}
          </div>

          <div className="card center" style={{ marginTop: 44, padding: 48 }}>
            <h2 className="h-md">See it working on your own content</h2>
            <p className="lead" style={{ margin: '12px auto 24px' }}>
              The free plan includes content analysis, viral scoring and
              audience insights. No card required.
            </p>
            <a className="btn btn-grad auth-out" href="/login.html">
              Start Growing Free
            </a>
            <a className="btn btn-grad auth-in" href="/#/dashboard">
              Start Growing Free
            </a>
            <p className="small" style={{ marginTop: 18 }}>
              Try it first: <a href="/score.html">score your post free</a>
              {' · '}
              <a href="/free-caption-generator.html">
                generate captions free
              </a>
            </p>
          </div>
        </div>
      </section>
    </main>
  );
}
