import type { Metadata } from 'next';
import type { ReactNode } from 'react';

export const metadata: Metadata = {
  title: 'Pricing',
  description:
    'Start free. Upgrade when the AI has earned it. Every plan includes legitimate growth only — no bots, no fake engagement, no surprises.',
};

type Feature = { text: string; included: boolean };

const FREE_FEATURES: Feature[] = [
  { text: 'AI content analysis & viral scoring', included: true },
  { text: 'Audience insights', included: true },
  { text: 'Free Grow AI — organic growth up to 1,000 impressions', included: true },
  { text: 'Campaign simulation', included: true },
  { text: 'Basic analytics', included: true },
  { text: '3 active campaigns', included: true },
  { text: 'AI Paid Boost', included: false },
  { text: 'Advanced AI reports', included: false },
];

const PRO_FEATURES: Feature[] = [
  { text: 'Everything in Free', included: true },
  { text: 'AI Paid Boost with budget pacing', included: true },
  { text: 'Boost packages: Starter $10 · Growth $25 · Pro $50 · Scale $100', included: true },
  { text: '25 active campaigns', included: true },
  { text: 'Full analytics & audience insights', included: true },
  { text: 'AI insights & report credits included monthly', included: true },
  { text: 'Country targeting with AI reasons', included: true },
];

const BUSINESS_FEATURES: Feature[] = [
  { text: 'Everything in Pro', included: true },
  { text: '100 active campaigns', included: true },
  { text: 'Multiple brands & team seats', included: true },
  { text: 'Priority AI processing', included: true },
  { text: 'Advanced fraud & brand-safety reporting', included: true },
  { text: 'Priority support', included: true },
];

const COMPARE_ROWS: { feature: string; free: ReactNode; pro: ReactNode; business: ReactNode }[] = [
  {
    feature: 'AI content analysis & viral score',
    free: <Yes>Included</Yes>,
    pro: <Yes>Included</Yes>,
    business: <Yes>Included</Yes>,
  },
  { feature: 'Active campaigns', free: '3', pro: '25', business: '100' },
  {
    feature: 'Free Grow AI (organic)',
    free: <Yes>Up to 1,000 impressions</Yes>,
    pro: <Yes>Included</Yes>,
    business: <Yes>Included</Yes>,
  },
  {
    feature: 'AI Paid Boost',
    free: <span className="mut">—</span>,
    pro: <Yes>Included</Yes>,
    business: <Yes>Included</Yes>,
  },
  {
    feature: 'Country targeting (248 countries & territories)',
    free: 'AI Recommended',
    pro: <Yes>Full control</Yes>,
    business: <Yes>Full control</Yes>,
  },
  { feature: 'Analytics', free: 'Basic', pro: 'Full', business: 'Full + team reports' },
  {
    feature: 'Fraud & Safety protection',
    free: <Yes>Included</Yes>,
    pro: <Yes>Included</Yes>,
    business: <Yes>Advanced</Yes>,
  },
  { feature: 'Support', free: 'Help Center', pro: 'Standard', business: 'Priority' },
];

const TRUST_ITEMS: { icon: ReactNode; text: string }[] = [
  {
    icon: (
      <path d="M12 3l7 3v5c0 5-3 8-7 10-4-2-7-5-7-10V6l7-3z" />
    ),
    text: 'Secure payments via Google Play Billing',
  },
  {
    icon: (
      <>
        <path d="M21 12a9 9 0 1 1-2.6-6.3" />
        <path d="M21 4v5h-5" />
      </>
    ),
    text: 'Cancel anytime',
  },
  {
    icon: (
      <>
        <rect x="4" y="10" width="16" height="10" rx="2" />
        <path d="M8 10V7a4 4 0 0 1 8 0v3" />
      </>
    ),
    text: 'Verified purchase tokens & refund protection',
  },
];

function Yes({ children }: { children: ReactNode }) {
  return <span style={{ color: 'var(--good)' }}>{children}</span>;
}

function FeatureList({ features }: { features: Feature[] }) {
  return (
    <ul style={{ listStyle: 'none', margin: '20px 0 26px', display: 'grid', gap: 11 }}>
      {features.map((f) => (
        <li
          key={f.text}
          style={{
            display: 'flex',
            gap: 10,
            fontSize: 15,
            color: f.included ? 'var(--txt)' : 'var(--mut2)',
          }}
        >
          <span
            aria-hidden="true"
            style={{ color: f.included ? 'var(--good)' : 'var(--bad)', fontWeight: 800 }}
          >
            {f.included ? '✓' : '✕'}
          </span>
          <span>{f.text}</span>
        </li>
      ))}
    </ul>
  );
}

export default function PricingPage() {
  return (
    <>
      <section className="hero">
        <div className="wrap">
          <span className="kicker">Pricing</span>
          <h1 className="h-xl">
            Honest pricing for <span className="grad-text">real growth</span>
          </h1>
          <p className="lead">
            Start free. Upgrade when the AI has earned it. Every plan includes
            legitimate growth only — no bots, no fake engagement, no surprises.
          </p>
          <p className="mut small">
            Yearly billing saves 20% — Pro is $15/month and Business / Agency is
            $39/month when billed yearly.
          </p>
        </div>
      </section>

      <section className="section" style={{ paddingTop: 16 }}>
        <div className="wrap">
          <div className="grid grid-3" style={{ alignItems: 'stretch' }}>
            <div className="card">
              <h3>Free</h3>
              <p className="mut small">For creators testing the waters</p>
              <div className="price-tag" style={{ marginTop: 14 }}>
                $0
                <small style={{ fontSize: 16, fontWeight: 600, color: 'var(--mut)' }}>
                  /forever
                </small>
              </div>
              <FeatureList features={FREE_FEATURES} />
              <a className="btn btn-ghost" href="/login.html" style={{ width: '100%' }}>
                Get Started Free
              </a>
            </div>

            <div
              className="card"
              style={{
                position: 'relative',
                borderColor: 'rgba(249, 81, 119, 0.45)',
                boxShadow: 'var(--glow)',
              }}
            >
              <span
                style={{
                  position: 'absolute',
                  top: -14,
                  left: '50%',
                  transform: 'translateX(-50%)',
                  background: 'var(--grad)',
                  color: '#fff',
                  fontFamily: 'var(--font-d)',
                  fontSize: 12,
                  fontWeight: 700,
                  letterSpacing: '0.08em',
                  textTransform: 'uppercase',
                  padding: '6px 14px',
                  borderRadius: 999,
                  whiteSpace: 'nowrap',
                }}
              >
                Most Popular
              </span>
              <h3>Pro</h3>
              <p className="mut small">For creators growing seriously</p>
              <div className="price-tag" style={{ marginTop: 14 }}>
                $19
                <small style={{ fontSize: 16, fontWeight: 600, color: 'var(--mut)' }}>
                  /month
                </small>
              </div>
              <p className="small mut">Billed monthly</p>
              <FeatureList features={PRO_FEATURES} />
              <a className="btn btn-grad" href="/login.html" style={{ width: '100%' }}>
                Start Growing
              </a>
            </div>

            <div className="card">
              <h3>Business / Agency</h3>
              <p className="mut small">For teams and client work</p>
              <div className="price-tag" style={{ marginTop: 14 }}>
                $49
                <small style={{ fontSize: 16, fontWeight: 600, color: 'var(--mut)' }}>
                  /month
                </small>
              </div>
              <p className="small mut">Billed monthly</p>
              <FeatureList features={BUSINESS_FEATURES} />
              <a className="btn btn-ghost" href="/login.html" style={{ width: '100%' }}>
                Talk To Us
              </a>
            </div>
          </div>

          <div
            style={{
              display: 'flex',
              gap: 26,
              justifyContent: 'center',
              flexWrap: 'wrap',
              marginTop: 40,
            }}
          >
            {TRUST_ITEMS.map((item) => (
              <span
                key={item.text}
                className="mut small"
                style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}
              >
                <svg
                  width="18"
                  height="18"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="var(--pink)"
                  strokeWidth="1.8"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  aria-hidden="true"
                >
                  {item.icon}
                </svg>
                {item.text}
              </span>
            ))}
          </div>

          <h2 className="h-md center" style={{ margin: '70px 0 26px' }}>
            Compare plans
          </h2>
          <div style={{ overflowX: 'auto' }}>
            <table
              style={{
                width: '100%',
                borderCollapse: 'collapse',
                fontSize: 15,
                minWidth: 640,
              }}
            >
              <thead>
                <tr>
                  {['Feature', 'Free', 'Pro', 'Business'].map((h) => (
                    <th
                      key={h}
                      style={{
                        textAlign: 'left',
                        fontFamily: 'var(--font-d)',
                        padding: '12px 14px',
                        borderBottom: '1px solid var(--line2)',
                      }}
                    >
                      {h}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {COMPARE_ROWS.map((row) => (
                  <tr key={row.feature}>
                    <td style={{ padding: '12px 14px', borderBottom: '1px solid var(--line)' }}>
                      {row.feature}
                    </td>
                    <td style={{ padding: '12px 14px', borderBottom: '1px solid var(--line)' }}>
                      {row.free}
                    </td>
                    <td style={{ padding: '12px 14px', borderBottom: '1px solid var(--line)' }}>
                      {row.pro}
                    </td>
                    <td style={{ padding: '12px 14px', borderBottom: '1px solid var(--line)' }}>
                      {row.business}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </section>
    </>
  );
}
