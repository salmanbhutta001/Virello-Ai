import type { Metadata } from 'next';
import type { ReactNode } from 'react';

export const metadata: Metadata = {
  title: 'Trust & Safety',
  description:
    "Virello's rules are simple, public and non-negotiable: no fake views, no fake followers, no bots, no password access — real growth, no shortcuts.",
};

const NEVER: { lead: string; text: string }[] = [
  {
    lead: 'No fake views.',
    text: 'Every view in your analytics comes from a real person watching real content.',
  },
  {
    lead: 'No fake followers.',
    text: 'We never sell, rent or simulate followers, likes or comments.',
  },
  {
    lead: 'No bots or automation farms.',
    text: 'No bot networks, traffic exchanges or artificial engagement of any kind.',
  },
  {
    lead: 'No password access.',
    text: 'We never ask for, see or store your social media password.',
  },
  {
    lead: 'No spending without approval.',
    text: 'AI can never exceed the budget and targeting you set.',
  },
];

const ALWAYS: { lead: string; text: string }[] = [
  {
    lead: 'Legitimate matching.',
    text: 'Content is shown to audiences with genuine, declared interest in the niche.',
  },
  {
    lead: 'Authorized campaigns.',
    text: 'Paid boosts run through proper channels, inside your approved limits.',
  },
  {
    lead: 'Transparent analytics.',
    text: 'Every number traces back to real activity — nothing inflated, nothing hidden.',
  },
  {
    lead: 'Secure connections.',
    text: 'Accounts connect via official sign-in only; payments use verified Google Play Billing tokens.',
  },
  {
    lead: 'Fraud prevention.',
    text: 'A dedicated Fraud & Safety agent monitors every campaign for invalid activity, around the clock.',
  },
];

function PromiseList({
  items,
  mark,
  color,
}: {
  items: { lead: string; text: string }[];
  mark: string;
  color: string;
}) {
  return (
    <ul style={{ listStyle: 'none', display: 'grid', gap: 13 }}>
      {items.map((item) => (
        <li key={item.lead} style={{ display: 'flex', gap: 10, fontSize: 15 }}>
          <span aria-hidden="true" style={{ color, fontWeight: 800 }}>
            {mark}
          </span>
          <span>
            <strong>{item.lead}</strong> {item.text}
          </span>
        </li>
      ))}
    </ul>
  );
}

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

export default function TrustPage() {
  return (
    <>
      <section className="hero">
        <div className="wrap">
          <span className="kicker">Trust &amp; Safety</span>
          <h1 className="h-xl">
            Real growth. <span className="grad-text">No shortcuts.</span>
          </h1>
          <p className="lead">
            Virello&apos;s rules are simple, public and non-negotiable. This page
            is our promise — to creators, to platforms, and to the audiences who
            trust what they see.
          </p>
        </div>
      </section>

      <section className="section" style={{ paddingTop: 20 }}>
        <div className="wrap">
          <div className="grid grid-2" style={{ alignItems: 'stretch' }}>
            <div
              className="card"
              style={{ borderColor: 'rgba(248, 113, 113, 0.4)' }}
            >
              <h3 style={{ marginBottom: 16 }}>
                What Virello will{' '}
                <span style={{ color: 'var(--bad)' }}>never</span> do
              </h3>
              <PromiseList items={NEVER} mark="✕" color="var(--bad)" />
            </div>
            <div
              className="card"
              style={{ borderColor: 'rgba(52, 211, 153, 0.35)' }}
            >
              <h3 style={{ marginBottom: 16 }}>
                What Virello <span style={{ color: 'var(--good)' }}>always</span>{' '}
                does
              </h3>
              <PromiseList items={ALWAYS} mark="✓" color="var(--good)" />
            </div>
          </div>

          <div className="grid grid-3" style={{ marginTop: 22 }}>
            <div className="card">
              <Icon>
                <rect x="4" y="10" width="16" height="10" rx="2" />
                <path d="M8 10V7a4 4 0 0 1 8 0v3M12 14.5v2" />
              </Icon>
              <h3>Your privacy</h3>
              <p>
                Your data is used to run and improve your campaigns — never sold
                as fake engagement, never shared as a growth shortcut. Read the
                full{' '}
                <a
                  href="/privacy.html"
                  style={{ color: 'var(--pink)', textDecoration: 'underline' }}
                >
                  privacy policy
                </a>
                .
              </p>
            </div>
            <div className="card">
              <Icon>
                <path d="M12 3l7 3v5c0 5-3 8-7 10-4-2-7-5-7-10V6l7-3z" />
                <path d="M9 12l2 2 4-4" />
              </Icon>
              <h3>Customer protection</h3>
              <p>
                Verified purchase tokens, a transaction ledger and clear refund
                handling protect every payment. If a paid generation or campaign
                fails on our side, it is reviewed for credit — automatically.
              </p>
            </div>
            <div className="card">
              <Icon>
                <path d="M4 20V10M10 20V4M16 20v-8M22 20H2" />
              </Icon>
              <h3>Honest AI claims</h3>
              <p>
                AI scores and projections are estimates that guide decisions —
                not guarantees of virality or income. We&apos;ll always label
                them that way.
              </p>
            </div>
          </div>

          <div
            className="card center"
            style={{ marginTop: 26, padding: '44px 28px' }}
          >
            <h2 className="h-md">Grow the way that lasts</h2>
            <p
              className="mut"
              style={{ maxWidth: 480, margin: '12px auto 24px' }}
            >
              Accounts built on real audiences don&apos;t get wiped out by the
              next platform cleanup. Start free, grow honestly.
            </p>
            <a className="btn btn-grad auth-out" href="/login.html">
              Start Growing — The Right Way
            </a>
            <a className="btn btn-grad auth-in" href="/dashboard.html">
              Start Growing — The Right Way
            </a>
          </div>
        </div>
      </section>
    </>
  );
}
