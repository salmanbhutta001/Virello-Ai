import type { Metadata } from 'next';
import type { ReactNode } from 'react';

export const metadata: Metadata = {
  title: 'Help Center',
  description:
    'Search guides and answers, or browse by topic. Still stuck? Our team and the Ask Virello assistant are one tap away.',
};

const CATEGORIES: { icon: ReactNode; title: string; text: string }[] = [
  {
    icon: (
      <>
        <path d="M5 12h14" />
        <path d="M13 6l6 6-6 6" />
      </>
    ),
    title: 'Getting Started',
    text: 'Create your account, connect a platform securely, and launch your first AI growth campaign in four steps.',
  },
  {
    icon: (
      <>
        <rect x="3" y="6" width="18" height="13" rx="2" />
        <path d="M3 10h18" />
      </>
    ),
    title: 'Billing & Payments',
    text: 'Plans, Google Play Billing, purchase verification, credits, refunds and subscription management.',
  },
  {
    icon: (
      <>
        <circle cx="12" cy="12" r="9" />
        <circle cx="12" cy="12" r="5" />
        <circle cx="12" cy="12" r="1" />
      </>
    ),
    title: 'Campaigns',
    text: 'Goals, budgets, geography, pausing and understanding campaign performance and pacing.',
  },
  {
    icon: (
      <>
        <path d="M12 3l1.9 4.6L18.5 9l-4.6 1.9L12 15.5l-1.9-4.6L5.5 9l4.6-1.4L12 3z" />
        <path d="M18.5 15.5l.8 2 2 .8-2 .8-.8 2-.8-2-2-.8 2-.8.8-2z" />
      </>
    ),
    title: 'AI Growth',
    text: 'How the AI Growth Score works, what the agents do, and how optimization decisions are made.',
  },
  {
    icon: (
      <>
        <rect x="4" y="10" width="16" height="10" rx="2" />
        <path d="M8 10V7a4 4 0 0 1 8 0v3M12 14.5v2" />
      </>
    ),
    title: 'Account & Security',
    text: 'Password resets, connected platforms, secure sign-in and keeping your account safe.',
  },
  {
    icon: (
      <>
        <path d="M12 3l7 3v5c0 5-3 8-7 10-4-2-7-5-7-10V6l7-3z" />
        <path d="M9 12l2 2 4-4" />
      </>
    ),
    title: 'Trust & Safety',
    text: 'Our legitimate-growth rules, fraud prevention and how we protect your account and your money.',
  },
];

const FAQS: { q: string; a: string }[] = [
  {
    q: 'How does Virello grow my post?',
    a: "Paste your post link, choose a goal (views, followers, engagement or sales) and optionally set a budget. Virello's AI analyses your content, matches it with genuinely interested audiences, manages the campaign and optimizes daily. Growth comes from real people — never bots or fake engagement.",
  },
  {
    q: 'Is the Free plan really free?',
    a: 'Yes. The Free plan includes AI content analysis, viral scoring, audience insights, campaign simulation, basic analytics and Free Grow AI organic growth up to 1,000 impressions. No credit card is required to start.',
  },
  {
    q: 'Do you need my social media password?',
    a: 'Never. Platforms connect through official, authorized sign-in only. Virello never asks for, sees or stores your social media password, and any service that does should not be trusted.',
  },
  {
    q: 'Will Virello get my account banned?',
    a: 'Virello is built to avoid exactly that. We do not provide fake views, fake followers, bots or artificial engagement — the practices that put accounts at risk. Growth uses legitimate discovery and authorized campaigns within platform rules.',
  },
  {
    q: 'How do budgets and Paid Boost work?',
    a: 'You choose a package (Starter $10/7 days, Growth $25/14 days, Pro $50/30 days, Scale $100/30 days) and approve the targeting. Paid Boost AI paces spending for cost-efficiency inside those limits — it can never spend beyond what you approved.',
  },
  {
    q: 'Can I cancel or get a refund?',
    a: "You can cancel your subscription anytime; it stays active until the end of the billing period. Payments run through Google Play Billing with verified purchase tokens, and refunds follow Google Play's policies plus our own customer-protection review.",
  },
  {
    q: 'Which countries and languages are supported?',
    a: "Campaigns can target 248 countries and territories with region presets, and the app experience is multilingual — including English, Urdu and Arabic with full RTL support. AI Recommended geography suggests countries based on your post's language and matched audiences, and always shows its reasoning for your approval.",
  },
  {
    q: 'Where can I download the Virello app?',
    a: 'Virello is available now on Huawei AppGallery, APKPure and Uptodown — see the download section on our home page. The Google Play version is coming soon and is not yet available; beware of any site claiming otherwise.',
  },
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

export default function HelpPage() {
  return (
    <>
      <section className="hero">
        <div className="wrap">
          <span className="kicker">Help Center</span>
          <h1 className="h-xl">
            How can we <span className="grad-text">help?</span>
          </h1>
          <p className="lead">
            Search guides and answers, or browse by topic. Still stuck? Our team
            and the Ask Virello assistant are one tap away.
          </p>
        </div>
      </section>

      <section className="section" style={{ paddingTop: 20 }}>
        <div className="wrap">
          <div className="grid grid-3">
            {CATEGORIES.map((c) => (
              <div className="card" key={c.title}>
                <Icon>{c.icon}</Icon>
                <h3>{c.title}</h3>
                <p>{c.text}</p>
              </div>
            ))}
          </div>

          <h2 className="h-md" style={{ margin: '64px 0 22px' }}>
            Frequently asked questions
          </h2>
          <div>
            {FAQS.map((f) => (
              <details
                key={f.q}
                style={{
                  background: 'var(--surface)',
                  border: '1px solid var(--line)',
                  borderRadius: 'var(--r-md)',
                  padding: '18px 22px',
                  marginBottom: 12,
                }}
              >
                <summary
                  style={{
                    cursor: 'pointer',
                    fontFamily: 'var(--font-d)',
                    fontWeight: 700,
                    fontSize: 16,
                  }}
                >
                  {f.q}
                </summary>
                <p className="mut" style={{ marginTop: 10, fontSize: 15 }}>
                  {f.a}
                </p>
              </details>
            ))}
          </div>

          <div
            className="card"
            style={{
              marginTop: 52,
              display: 'flex',
              gap: 20,
              alignItems: 'center',
              flexWrap: 'wrap',
              justifyContent: 'space-between',
            }}
          >
            <div>
              <h3>Still need help?</h3>
              <p className="mut small" style={{ marginTop: 5 }}>
                Real humans, backed by the AI Support agent for fast first
                answers.
              </p>
            </div>
            <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
              <a className="btn btn-grad" href="/contact.html">
                Contact Support
              </a>
              <a className="btn btn-ghost" href="/blog.html">
                Browse Guides
              </a>
              <a className="btn btn-ghost" href="/score.html">
                Score a Post
              </a>
            </div>
          </div>
        </div>
      </section>
    </>
  );
}
