import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'How It Works',
  description:
    "No dashboards to learn, no ads manager to fight. Paste your post, choose your goal, set an optional budget — Virello's AI handles everything.",
  alternates: { canonical: '/how.html' },
};

type Step = { num: string; title: string; text: string };
type TimelineItem = { when: string; title: string; text: string };

const STEPS: Step[] = [
  {
    num: '1',
    title: 'Paste Your Post',
    text: 'Paste a link to any post or video from Instagram, YouTube, TikTok, Facebook or X. The AI Content Analysis agent scores it instantly — hook, format, caption and viral potential.',
  },
  {
    num: '2',
    title: 'Choose Your Goal',
    text: 'More views, more followers, more engagement or more sales. Your goal drives the whole strategy: which audiences, which countries, which pacing.',
  },
  {
    num: '3',
    title: 'Set Optional Budget',
    text: 'Stay on the free Organic Growth Engine, or pick a boost package. You approve the budget and targeting — the AI can never spend beyond what you set.',
  },
  {
    num: '4',
    title: 'Let AI Grow',
    text: 'Ten specialized AI agents take over: audience matching, campaign management, daily optimization, fraud protection and clear reporting.',
  },
];

const TIMELINE: TimelineItem[] = [
  {
    when: '1m',
    title: 'Minute 1 — Analysis',
    text: 'Content scored; improvement tips shown (better hook, caption, hashtags).',
  },
  {
    when: '5m',
    title: 'Minute 5 — Audience strategy',
    text: 'Segments and countries proposed with reasons. You approve with one tap.',
  },
  {
    when: '1h',
    title: 'Hour 1 — Growth begins',
    text: 'Organic discovery or paid boost goes live inside your approved limits.',
  },
  {
    when: '24h',
    title: 'Daily — Optimization & reporting',
    text: "The AI shifts effort to what's working and reports in plain language.",
  },
];

export default function HowPage() {
  return (
    <main>
      <section className="section">
        <div className="wrap center">
          <span className="kicker">How It Works</span>
          <h1 className="h-xl">
            Four steps. <span className="grad-text">Thirty seconds.</span>
          </h1>
          <p className="lead" style={{ marginTop: 18 }}>
            No dashboards to learn, no ads manager to fight. This is the entire
            process — Virello&apos;s AI handles everything after step four.
          </p>
        </div>
      </section>

      <section className="section" style={{ paddingTop: 0 }}>
        <div className="wrap">
          <div className="grid grid-4">
            {STEPS.map((s) => (
              <div key={s.num} className="card">
                <span className="icon">{s.num}</span>
                <h3>{s.title}</h3>
                <p>{s.text}</p>
              </div>
            ))}
          </div>

          <div className="center" style={{ marginTop: 70 }}>
            <span className="kicker">After You Press Let AI Grow</span>
            <h2 className="h-lg">
              What happens in the{' '}
              <span className="grad-text">first 24 hours</span>
            </h2>
            <p className="lead" style={{ marginTop: 16 }}>
              A look inside the first 24 hours of a campaign.
            </p>
          </div>
          <div className="grid grid-2" style={{ marginTop: 44 }}>
            {TIMELINE.map((t) => (
              <div key={t.title} className="card">
                <span className="icon" style={{ fontSize: 15 }}>
                  {t.when}
                </span>
                <h3>{t.title}</h3>
                <p>{t.text}</p>
              </div>
            ))}
          </div>

          <div className="grid grid-3" style={{ marginTop: 56 }}>
            <div className="card">
              <h3>Free Grow AI</h3>
              <p>
                Organic, worldwide, $0. Optimizes discovery and winds down
                gracefully near the free plan&apos;s 1,000-impression cap.
                Never touches money.
              </p>
            </div>
            <div className="card">
              <h3>Paid Boost AI</h3>
              <p>
                Budget pacing, cost-efficiency and geo awareness. Every
                decision is tagged to your plan and visible in your reports.
                Boost packages in the app: Starter $10 · Growth $25 · Pro $50.
              </p>
            </div>
            <div className="card">
              <h3>Shared Safety Rails</h3>
              <p>
                Both agents run under the same Fraud &amp; Safety rules —
                legitimate audiences only, platform-compliant methods only.
              </p>
            </div>
          </div>

          <div className="center" style={{ marginTop: 48 }}>
            <a className="btn btn-grad auth-out" href="/login.html">
              Try It On Your Post — Free
            </a>
            <a className="btn btn-grad auth-in" href="/#/dashboard">
              Try It On Your Post — Free
            </a>
            <p className="small" style={{ marginTop: 18 }}>
              Before you start: <a href="/score.html">score your post</a>
              {' · '}
              <a href="/pricing.html">see Free vs Paid Boost pricing</a>
            </p>
          </div>
        </div>
      </section>
    </main>
  );
}
