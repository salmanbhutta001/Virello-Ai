import type { Metadata } from 'next';
import type { ReactNode } from 'react';

export const metadata: Metadata = {
  title: { absolute: 'About Virello AI — Your AI Growth Manager' },
  description:
    "Virello exists because great creators shouldn't need a marketing degree, an ads account and a data team to be discovered.",
  alternates: { canonical: '/about.html' },
  openGraph: { url: 'https://virelloai.online/about.html' },
};

const STATS: { value: string; label: string }[] = [
  { value: '10', label: 'Specialized AI agents' },
  { value: '248', label: 'Countries & territories for targeting' },
  { value: '5', label: 'Social platforms supported' },
  { value: '3', label: 'App stores live today — AppGallery, APKPure, Uptodown' },
];

function Icon({ children }: { children: ReactNode }) {
  return (
    <div className="icon">
      <svg
        width="22"
        height="22"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
        aria-hidden="true"
      >
        {children}
      </svg>
    </div>
  );
}

export default function AboutPage() {
  return (
    <>
      <section className="hero">
        <div className="wrap">
          <span className="kicker">About Us</span>
          <h1 className="h-xl">
            Growth, run by AI. <span className="grad-text">Built on trust.</span>
          </h1>
          <p className="lead">
            Virello exists because great creators shouldn&apos;t need a marketing
            degree, an ads account and a data team to be discovered.
          </p>
        </div>
      </section>

      <section className="section" style={{ paddingTop: 20 }}>
        <div className="wrap">
          <div className="grid grid-2">
            <div className="card">
              <Icon>
                <circle cx="12" cy="12" r="9" />
                <circle cx="12" cy="12" r="5" />
                <circle cx="12" cy="12" r="1" />
              </Icon>
              <h3>Our Mission</h3>
              <p>
                To give every creator and business a personal AI Growth Manager:
                paste a post, state a goal, and let AI handle analysis, audience
                strategy, campaign management and reporting — so talent, not
                budget or connections, decides who gets seen.
              </p>
            </div>
            <div className="card">
              <Icon>
                <path d="M2 12s3.5-6.5 10-6.5S22 12 22 12s-3.5 6.5-10 6.5S2 12 2 12z" />
                <circle cx="12" cy="12" r="3" />
              </Icon>
              <h3>Our Vision</h3>
              <p>
                A social internet where discovery is fair: where a teenager
                filming in Lahore, a baker in London and a tutor in Texas all get
                matched with the audiences who will genuinely love what they
                make.
              </p>
            </div>
          </div>

          <div className="card" style={{ marginTop: 22 }}>
            <h3 style={{ fontSize: 21, marginBottom: 12 }}>
              The AI-first growth philosophy
            </h3>
            <p style={{ marginBottom: 14 }}>
              Virello is built around one central AI Core with ten specialized
              agents — Content Analysis, Audience, Market Research, Creative,
              Campaign, Analytics, Optimization, Budget, Fraud &amp; Safety, and
              AI Support — coordinated by an AI Growth Orchestrator. &quot;Ask
              Virello&quot; routes any request to the right specialist.
            </p>
            <p>
              Our AI layer is provider-agnostic by design, and our growth
              philosophy is not negotiable:{' '}
              <strong style={{ color: 'var(--txt)' }}>
                genuine recurring value, real audiences, transparent numbers.
              </strong>{' '}
              We will never sell fake engagement, because fake engagement
              destroys the very accounts we&apos;re here to grow.
            </p>
          </div>

          <div className="grid grid-4" style={{ marginTop: 26 }}>
            {STATS.map((s) => (
              <div className="card center" key={s.label}>
                <div className="price-tag grad-text">{s.value}</div>
                <p className="small" style={{ marginTop: 6 }}>
                  {s.label}
                </p>
              </div>
            ))}
          </div>

          <div className="grid grid-3" style={{ marginTop: 26 }}>
            <div className="card">
              <h3>Legitimate growth only</h3>
              <p>
                AI matches content with genuinely interested audiences. No bots,
                no engagement farms, no shortcuts that get accounts punished.
              </p>
            </div>
            <div className="card">
              <h3>Global, multilingual</h3>
              <p>
                Built for a worldwide audience with strong US/UK support and a
                multilingual experience — English, Urdu, Arabic and many more
                languages.
              </p>
            </div>
            <div className="card">
              <h3>Creators keep control</h3>
              <p>
                You approve goals, budgets and countries. The AI recommends with
                reasons — you always have the final say.
              </p>
            </div>
          </div>

          <div className="center" style={{ marginTop: 48 }}>
            <a className="btn btn-grad auth-out" href="/login.html">
              Join Virello Free
            </a>
            <a className="btn btn-grad auth-in" href="/dashboard.html">
              Join Virello Free
            </a>
            <p className="small" style={{ marginTop: 18 }}>
              Read how creators grow: <a href="/blog.html">the Virello blog</a>
            </p>
          </div>
        </div>
      </section>
    </>
  );
}
