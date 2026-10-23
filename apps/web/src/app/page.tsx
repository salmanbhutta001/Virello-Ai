import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: { absolute: 'Virello AI — Your AI Growth Manager' },
  description:
    'Virello AI is your AI Growth Manager: paste a post, choose a goal, set an optional budget, and let AI grow it. Real audiences, honest analytics, no fake engagement.',
};

type Step = { num: string; title: string; text: string };
type FeatureCard = { icon: string; title: string; text: string };
type Agent = { name: string; role: string };

const STEPS: Step[] = [
  {
    num: '1',
    title: 'Paste Your Post',
    text: 'Drop in a link from Instagram, YouTube, TikTok, Facebook or X.',
  },
  {
    num: '2',
    title: 'Choose Your Goal',
    text: 'Views, followers, engagement or sales — the AI builds a strategy around it.',
  },
  {
    num: '3',
    title: 'Set Optional Budget',
    text: 'Grow free with the Organic Engine, or add a budget for an AI Paid Boost.',
  },
  {
    num: '4',
    title: 'Let AI Grow',
    text: 'Ten AI agents manage, optimize and report — you just watch it grow.',
  },
];

const PLATFORM_FEATURES: FeatureCard[] = [
  {
    icon: '✦',
    title: 'AI Content Analysis',
    text: 'Every post is scored for hook strength, clarity and viral potential before a single rupee or dollar is spent.',
  },
  {
    icon: '◎',
    title: 'Smart Audience Matching',
    text: 'Your content is matched with genuinely interested audiences across 248 countries & territories — never random traffic.',
  },
  {
    icon: '↗',
    title: 'Organic Growth Engine',
    text: 'Free Grow AI optimizes discovery, timing and recommendations — worldwide organic growth with a $0 budget.',
  },
  {
    icon: '»',
    title: 'AI Paid Boost',
    text: 'Paid Boost AI manages authorized campaigns inside the budget and targeting limits you approve. Full control, zero guesswork.',
  },
  {
    icon: '▤',
    title: 'Real-Time Analytics',
    text: 'Reach, engagement, follower growth and campaign performance — tracked live and explained in plain language.',
  },
  {
    icon: '✓',
    title: 'Fraud & Safety Protection',
    text: 'Every campaign is monitored for invalid activity. No bots, no fake engagement, no unsafe account access — guaranteed by design.',
  },
];

const AGENTS: Agent[] = [
  { name: 'Content Analysis Agent', role: 'Scores every post before launch' },
  { name: 'Audience Agent', role: 'Finds your people, worldwide' },
  { name: 'Market Research Agent', role: 'Researches your market and what is trending in it' },
  { name: 'Creative Agent', role: 'Content ideas and creative direction for your posts' },
  { name: 'Campaign Agent', role: 'Runs and paces your boosts' },
  { name: 'Analytics Agent', role: 'Tracks results and explains them in plain language' },
  { name: 'Optimization Agent', role: 'Improves results every single day' },
  { name: 'Budget Agent', role: 'Keeps spending inside the limits you approve' },
  { name: 'Fraud & Safety Agent', role: 'Blocks invalid activity 24/7' },
  { name: 'AI Support Agent', role: 'Help and answers, in your language' },
];

const TRUST_POINTS: string[] = [
  'No fake views, followers or likes — ever',
  'No password sharing — secure, authorized connections only',
  'Transparent analytics — every number traceable to real activity',
  'You approve the budget and targeting. AI never spends beyond it',
];

const STATS: { value: string; label: string }[] = [
  { value: '10', label: 'Specialized AI agents working on every campaign' },
  { value: '248', label: 'Countries & territories available for audience targeting' },
  { value: '4-Step', label: 'Setup — paste, choose, budget, grow' },
  { value: '0', label: 'Bots, fake views or fake followers. Ever.' },
];

export default function HomePage() {
  return (
    <main>
      {/* Hero */}
      <section className="hero">
        <div className="wrap">
          <span className="kicker">AI-Powered Social Growth</span>
          <h1 className="h-xl">
            Your AI <span className="grad-text">Growth Manager</span>
          </h1>
          <p className="lead">
            Paste your post, choose your goal, set an optional budget — and
            Virello&apos;s AI handles analysis, audience strategy, growth
            optimization, campaign management and reporting. Real growth from
            real people. Never bots, never fake engagement.
          </p>
          <div className="hero-cta">
            <a className="btn btn-grad" href="/login.html">
              Get Started Free
            </a>
            <a className="btn btn-ghost" href="/login.html">
              Let AI Grow →
            </a>
          </div>
          <p className="small mut" style={{ marginTop: 18 }}>
            Free plan included · No credit card required · No password sharing —
            ever
          </p>
          <div
            style={{
              display: 'flex',
              gap: 10,
              justifyContent: 'center',
              flexWrap: 'wrap',
              marginTop: 26,
            }}
          >
            {['Instagram', 'YouTube', 'TikTok', 'Facebook', 'X'].map((p) => (
              <span key={p} className="chip">
                {p}
              </span>
            ))}
          </div>
        </div>
      </section>

      {/* Stats band */}
      <section className="section-sm">
        <div className="wrap">
          <div className="grid grid-4">
            {STATS.map((s) => (
              <div key={s.label} className="card center">
                <div
                  style={{
                    fontFamily: 'var(--font-d)',
                    fontSize: 34,
                    fontWeight: 800,
                  }}
                >
                  {s.value}
                </div>
                <p style={{ marginTop: 6 }}>{s.label}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* How it works strip */}
      <section className="section">
        <div className="wrap">
          <div className="center">
            <span className="kicker">How Virello Grows You</span>
            <h2 className="h-lg">
              One post in. <span className="grad-text">A full growth team</span>{' '}
              on it.
            </h2>
            <p className="lead" style={{ marginTop: 16 }}>
              You bring the content. Virello&apos;s AI Growth Orchestrator
              analyses it, finds the people most likely to love it, and manages
              everything from there.
            </p>
          </div>
          <div className="grid grid-4" style={{ marginTop: 44 }}>
            {STEPS.map((s) => (
              <div key={s.num} className="card">
                <span className="icon">{s.num}</span>
                <h3>{s.title}</h3>
                <p>{s.text}</p>
              </div>
            ))}
          </div>
          <div className="center" style={{ marginTop: 40 }}>
            <a className="btn btn-ghost" href="/how.html">
              See How It Works
            </a>
          </div>
        </div>
      </section>

      {/* Growth modes */}
      <section className="section" style={{ paddingTop: 0 }}>
        <div className="wrap">
          <div className="center">
            <span className="kicker">Growth Modes</span>
            <h2 className="h-lg">
              Grow free — or boost with a{' '}
              <span className="grad-text">budget you approve</span>
            </h2>
          </div>
          <div className="grid grid-2" style={{ marginTop: 44 }}>
            <div className="card">
              <span className="icon">↗</span>
              <h3>AI Organic Growth</h3>
              <p>
                Free Grow AI optimizes discovery, timing and recommendations —
                worldwide organic growth with a $0 budget. It winds down
                gracefully near free-plan reach caps and never touches your
                money.
              </p>
            </div>
            <div className="card">
              <span className="icon">»</span>
              <h3>AI Paid Boost</h3>
              <p>
                Paid Boost AI manages authorized campaigns inside the budget and
                targeting limits you approve — pacing spend, watching
                cost-efficiency, and never spending beyond what you set.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Inside the platform */}
      <section className="section" style={{ paddingTop: 0 }}>
        <div className="wrap">
          <div className="center">
            <span className="kicker">Inside The Platform</span>
            <h2 className="h-lg">
              Everything a creator needs.{' '}
              <span className="grad-text">Nothing they don&apos;t.</span>
            </h2>
          </div>
          <div className="grid grid-3" style={{ marginTop: 44 }}>
            {PLATFORM_FEATURES.map((f) => (
              <div key={f.title} className="card">
                <span className="icon">{f.icon}</span>
                <h3>{f.title}</h3>
                <p>{f.text}</p>
              </div>
            ))}
          </div>
          <div className="center" style={{ marginTop: 40 }}>
            <a className="btn btn-grad" href="/features.html">
              Explore All Features
            </a>
          </div>
        </div>
      </section>

      {/* Legitimate by design + AI team */}
      <section className="section" style={{ paddingTop: 0 }}>
        <div className="wrap">
          <div className="center">
            <span className="kicker">Legitimate By Design</span>
            <h2 className="h-lg">
              Growth your account can{' '}
              <span className="grad-text">actually keep</span>
            </h2>
            <p className="lead" style={{ marginTop: 16 }}>
              Fake followers get removed. Bot views get accounts flagged.
              Virello only does growth that lasts: real content, shown to real
              people who genuinely care about it.
            </p>
          </div>
          <div className="grid grid-2" style={{ marginTop: 44 }}>
            {TRUST_POINTS.map((t) => (
              <div key={t} className="card">
                <p style={{ color: 'var(--txt)', fontSize: 16 }}>
                  <span style={{ color: 'var(--pink)', fontWeight: 700 }}>
                    ✓{' '}
                  </span>
                  {t}
                </p>
              </div>
            ))}
          </div>
          <div className="center" style={{ marginTop: 36 }}>
            <a className="btn btn-ghost" href="/trust.html">
              Our Trust &amp; Safety Promise
            </a>
          </div>

          <div className="center" style={{ marginTop: 84 }}>
            <span className="kicker">Meet Your AI Team</span>
            <h2 className="h-lg">The AI Growth Orchestrator</h2>
            <p className="lead" style={{ marginTop: 16 }}>
              Ten specialists, one manager: Virello. Every campaign is run by
              ten specialized AI agents working together.
            </p>
          </div>
          <div className="grid grid-4" style={{ marginTop: 44 }}>
            {AGENTS.map((a) => (
              <div key={a.name} className="card">
                <h3 style={{ fontSize: 17 }}>{a.name}</h3>
                <p>{a.role}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Shop teaser */}
      <section className="section" style={{ paddingTop: 0 }}>
        <div className="wrap">
          <div className="card center" style={{ padding: 48 }}>
            <span className="kicker">Virello Shop</span>
            <h2 className="h-md">
              Hot in the <span className="grad-text">Shop</span> right now
            </h2>
            <p className="lead" style={{ margin: '14px auto 26px' }}>
              Live trending picks from the Virello Shop — refreshed around the
              clock.
            </p>
            <a className="btn btn-grad" href="/#/shop">
              Browse the Shop →
            </a>
          </div>
        </div>
      </section>

      {/* Creator Hub teaser */}
      <section className="section" style={{ paddingTop: 0 }}>
        <div className="wrap">
          <div className="center">
            <span className="kicker">Creator Hub</span>
            <h2 className="h-lg">
              Create, ask, grow — <span className="grad-text">one place</span>
            </h2>
          </div>
          <div className="grid grid-2" style={{ marginTop: 44 }}>
            <div className="card">
              <span className="icon">✚</span>
              <h3>Creator Hub &amp; AI Tools</h3>
              <p>
                Create and edit videos with AI assistance, generate content
                ideas, and manage your whole creator workflow in one place.
              </p>
            </div>
            <div className="card">
              <span className="icon">✎</span>
              <h3>Ask Virello</h3>
              <p>
                One AI assistant that routes your request to the right agent —
                growth advice, campaign help, shop and support, in your
                language.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Pricing teaser */}
      <section className="section" style={{ paddingTop: 0 }}>
        <div className="wrap">
          <div className="card center" style={{ padding: 48 }}>
            <span className="kicker">Pricing</span>
            <h2 className="h-md">Start free. No card required.</h2>
            <p className="lead" style={{ margin: '14px auto 26px' }}>
              The free plan includes content analysis, viral scoring and
              audience insights. Add a budget only when you want a Paid Boost.
            </p>
            <div className="hero-cta">
              <a className="btn btn-grad" href="/pricing.html">
                See Pricing
              </a>
              <a className="btn btn-ghost" href="/blog.html">
                Read the Blog
              </a>
            </div>
          </div>
        </div>
      </section>

      {/* Final CTA */}
      <section className="section" style={{ paddingTop: 0 }}>
        <div className="wrap">
          <div className="card center" style={{ padding: 56 }}>
            <h2 className="h-lg">
              Ready to meet your{' '}
              <span className="grad-text">AI Growth Manager?</span>
            </h2>
            <p className="lead" style={{ margin: '14px auto 28px' }}>
              Start free today. Paste your first post and watch Virello&apos;s
              AI go to work in minutes.
            </p>
            <div className="hero-cta">
              <a className="btn btn-grad" href="/login.html">
                Try Virello Free
              </a>
              <a className="btn btn-ghost" href="/pricing.html">
                See Pricing
              </a>
            </div>
          </div>
        </div>
      </section>
    </main>
  );
}
