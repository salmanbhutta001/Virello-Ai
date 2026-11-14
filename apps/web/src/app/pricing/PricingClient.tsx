'use client';

import { useState } from 'react';
import type { ReactNode } from 'react';
import { isLoggedIn, setPlan } from '@/lib/auth';
import { showToast } from '@/lib/toast';
import { PRICING_FAQS } from './faqs';

// Pricing CTAs + modals — port of legacy #page-pricing wiring
// (index.html:1047-1129 HTML; 2634-2640 setBilling; 2762-2794
// openCheckout/closeCheckout/openTalk/closeTalk/submitTalk/
// activateFreePlan). P2 owns ONLY this wiring, not a redesign:
// copy, feature lists, compare table and trust row are unchanged
// from the existing Next page (Business bullets verified against
// legacy index.html:1100-1129 — they match exactly).
//
// Behaviours (legacy parity):
// - Billing toggle: Monthly/Yearly swaps the .price-num values
//   (data-m/data-y) and the bill-note; yearly = −20%.
// - Free → $0 checkout modal; "Activate Free Plan — $0" sets
//   virello_plan='free'; logged-in → toast + /dashboard.html;
//   logged-out → toast + /login.html?plan=free&next=dashboard.
//   The checkout modal has NO backdrop-click close (parity).
// - Pro → Google Play link (app is live; no toast).
// - Business → talk modal; submit validates, closes the modal and
//   opens the user's mail app after 400 ms (mailto to
//   support@virelloai.online). Nothing is sent to any server.

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
    icon: <path d="M12 3l7 3v5c0 5-3 8-7 10-4-2-7-5-7-10V6l7-3z" />,
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

function CloseIcon() {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true">
      <path d="M6 6l12 12M18 6L6 18" />
    </svg>
  );
}

export default function PricingClient() {
  const [billing, setBilling] = useState<'m' | 'y'>('m');
  const [checkoutOpen, setCheckoutOpen] = useState(false);
  const [talkOpen, setTalkOpen] = useState(false);
  const [talkName, setTalkName] = useState('');
  const [talkEmail, setTalkEmail] = useState('');
  const [talkCompany, setTalkCompany] = useState('');
  const [talkTeam, setTalkTeam] = useState('1–5');
  const [talkMsg, setTalkMsg] = useState('');

  const yearly = billing === 'y';
  const billNote = yearly ? 'Billed yearly — 20% saved' : 'Billed monthly';

  const activateFreePlan = () => {
    setPlan('free');
    setCheckoutOpen(false);
    if (isLoggedIn()) {
      showToast('Free plan activated — welcome aboard!');
      window.setTimeout(() => {
        window.location.href = '/dashboard.html';
      }, 600);
    } else {
      showToast('Almost there — log in or create your account to activate the Free plan.');
      window.setTimeout(() => {
        window.location.href = '/login.html?plan=free&next=dashboard';
      }, 600);
    }
  };

  const submitTalk = () => {
    const n = talkName.trim();
    const e = talkEmail.trim();
    const c = talkCompany.trim();
    const m = talkMsg.trim();
    if (!n) {
      showToast('Please enter your name.');
      return;
    }
    if (!e || e.indexOf('@') < 1) {
      showToast('Please enter a valid email.');
      return;
    }
    if (!m) {
      showToast('Please tell us what you want to achieve.');
      return;
    }
    const subject = encodeURIComponent(`Business Plan Inquiry — ${n}`);
    const body = encodeURIComponent(
      `Name: ${n}\nEmail: ${e}\nCompany: ${c || '—'}\nTeam size: ${talkTeam}\n\nMessage:\n${m}`,
    );
    setTalkOpen(false);
    showToast('Opening your email app — we reply within 1 business day.');
    window.setTimeout(() => {
      window.location.href = `mailto:support@virelloai.online?subject=${subject}&body=${body}`;
    }, 400);
  };

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
          <div style={{ marginTop: 30 }}>
            <div className="toggle" role="group" aria-label="Billing period">
              <button
                type="button"
                className={billing === 'm' ? 'on' : undefined}
                onClick={() => setBilling('m')}
              >
                Monthly
              </button>
              <button
                type="button"
                className={billing === 'y' ? 'on' : undefined}
                onClick={() => setBilling('y')}
              >
                Yearly<span className="save-tag">−20%</span>
              </button>
            </div>
          </div>
          <p className="mut small" style={{ marginTop: 16 }}>
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
              <button
                type="button"
                className="btn btn-ghost"
                style={{ width: '100%' }}
                onClick={() => setCheckoutOpen(true)}
                aria-label="Choose the Free plan"
              >
                Get Started Free
              </button>
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
                $<span className="price-num" data-m="19" data-y="15">{yearly ? 15 : 19}</span>
                <small style={{ fontSize: 16, fontWeight: 600, color: 'var(--mut)' }}>
                  /month
                </small>
              </div>
              <p className="small mut bill-note">{billNote}</p>
              <FeatureList features={PRO_FEATURES} />
              <a
                href="https://play.google.com/store/apps/details?id=com.virello.virello"
                target="_blank"
                rel="noopener"
                className="btn btn-grad"
                style={{ width: '100%' }}
                aria-label="Choose the Pro plan"
              >
                Start Growing
              </a>
            </div>

            <div className="card">
              <h3>Business / Agency</h3>
              <p className="mut small">For teams and client work</p>
              <div className="price-tag" style={{ marginTop: 14 }}>
                $<span className="price-num" data-m="49" data-y="39">{yearly ? 39 : 49}</span>
                <small style={{ fontSize: 16, fontWeight: 600, color: 'var(--mut)' }}>
                  /month
                </small>
              </div>
              <p className="small mut bill-note">{billNote}</p>
              <FeatureList features={BUSINESS_FEATURES} />
              <button
                type="button"
                className="btn btn-ghost"
                style={{ width: '100%' }}
                onClick={() => setTalkOpen(true)}
              >
                Talk To Us
              </button>
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

          {/* Pricing FAQ (AEO 2026-10-28) — same PRICING_FAQS array as the
              FAQPage JSON-LD in page.tsx, so visible text and schema match. */}
          <h2 className="h-md center" style={{ margin: '70px 0 26px' }}>
            Pricing questions, answered
          </h2>
          <div style={{ maxWidth: 820, margin: '0 auto' }}>
            {PRICING_FAQS.map((f) => (
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

          <p className="small center" style={{ marginTop: 36 }}>
            Not sure yet? <a href="/score.html">Score a post free</a>
            {' · '}
            <a href="/free-caption-generator.html">
              try the free caption generator
            </a>
            {' · '}
            <a href="/features.html">see all features</a>
            {' · '}
            <a href="/virello-vs-predis-ai.html">
              compare Virello with Buffer and Predis.ai
            </a>
          </p>
        </div>
      </section>

      {/* $0 checkout modal — legacy index.html:2099-2114.
          No backdrop-click close (parity: closes only via × or the
          activate button). */}
      <div
        className={`modal-bg${checkoutOpen ? ' open' : ''}`}
        role="dialog"
        aria-modal="true"
      >
        <div className="modal" style={{ maxWidth: 420 }}>
          <button
            type="button"
            className="icon-btn"
            style={{ float: 'right' }}
            onClick={() => setCheckoutOpen(false)}
            aria-label="Close checkout"
          >
            <CloseIcon />
          </button>
          <span className="cat-tag">Checkout</span>
          <h3 style={{ marginTop: 8 }}>Free Plan</h3>
          <p className="mut" style={{ margin: '6px 0 16px' }}>
            For creators testing the waters
          </p>
          <div
            style={{
              background: 'var(--surface2)',
              borderRadius: 12,
              padding: '14px 16px',
              marginBottom: 14,
            }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
              <span>Plan</span>
              <strong>Free</strong>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
              <span>Billing</span>
              <span className="mut">$0 / forever</span>
            </div>
            <div
              style={{
                display: 'flex',
                justifyContent: 'space-between',
                fontSize: '1.1rem',
                borderTop: '1px solid var(--line)',
                paddingTop: 10,
              }}
            >
              <span>Total due today</span>
              <strong>$0.00</strong>
            </div>
          </div>
          <p className="tiny mut" style={{ marginBottom: 16 }}>
            No payment required — the Free plan is $0 forever. Includes AI
            content analysis, audience insights, Free Grow AI up to 1,000
            impressions, and 3 active campaigns.
          </p>
          <button
            type="button"
            className="btn btn-pink"
            style={{ width: '100%' }}
            onClick={activateFreePlan}
          >
            Activate Free Plan — $0
          </button>
        </div>
      </div>

      {/* Talk To Us modal — legacy index.html:2115-2129. */}
      <div
        className={`modal-bg${talkOpen ? ' open' : ''}`}
        role="dialog"
        aria-modal="true"
        onClick={(e) => {
          if (e.target === e.currentTarget) setTalkOpen(false);
        }}
      >
        <div className="modal" style={{ maxWidth: 480 }}>
          <button
            type="button"
            className="icon-btn"
            style={{ float: 'right' }}
            onClick={() => setTalkOpen(false)}
            aria-label="Close contact form"
          >
            <CloseIcon />
          </button>
          <span className="cat-tag">Business / Agency</span>
          <h3 style={{ marginTop: 8 }}>Talk To Us</h3>
          <p className="mut" style={{ margin: '6px 0 16px' }}>
            Tell us about your team — we reply within 1 business day.
          </p>
          <div className="field">
            <label className="lbl" htmlFor="talkName">
              Full name
            </label>
            <input
              className="inp"
              id="talkName"
              type="text"
              placeholder="Your name"
              autoComplete="name"
              value={talkName}
              onChange={(e) => setTalkName(e.target.value)}
            />
          </div>
          <div className="field">
            <label className="lbl" htmlFor="talkEmail">
              Work email
            </label>
            <input
              className="inp"
              id="talkEmail"
              type="email"
              placeholder="you@company.com"
              autoComplete="email"
              value={talkEmail}
              onChange={(e) => setTalkEmail(e.target.value)}
            />
          </div>
          <div className="field">
            <label className="lbl" htmlFor="talkCompany">
              Company / Agency
            </label>
            <input
              className="inp"
              id="talkCompany"
              type="text"
              placeholder="Company name"
              autoComplete="organization"
              value={talkCompany}
              onChange={(e) => setTalkCompany(e.target.value)}
            />
          </div>
          <div className="field">
            <label className="lbl" htmlFor="talkTeam">
              Team size
            </label>
            <select
              className="inp"
              id="talkTeam"
              value={talkTeam}
              onChange={(e) => setTalkTeam(e.target.value)}
            >
              <option>1–5</option>
              <option>6–20</option>
              <option>21–50</option>
              <option>50+</option>
            </select>
          </div>
          <div className="field">
            <label className="lbl" htmlFor="talkMsg">
              What do you want to achieve?
            </label>
            <textarea
              className="inp"
              id="talkMsg"
              rows={4}
              placeholder="e.g. We manage 12 client brands and need 100 campaigns with team seats…"
              style={{ resize: 'vertical' }}
              value={talkMsg}
              onChange={(e) => setTalkMsg(e.target.value)}
            />
          </div>
          <button
            type="button"
            className="btn btn-pink"
            style={{ width: '100%' }}
            onClick={submitTalk}
          >
            Send Message
          </button>
          <p className="tiny mut" style={{ marginTop: 12, textAlign: 'center' }}>
            Prefer email? Write to us at{' '}
            <a
              href="mailto:support@virelloai.online"
              style={{ color: 'var(--pink)', fontWeight: 600 }}
            >
              support@virelloai.online
            </a>
          </p>
        </div>
      </div>
    </>
  );
}
