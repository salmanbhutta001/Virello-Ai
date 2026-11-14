import type { Metadata } from 'next';
import type { ReactNode } from 'react';
import ContactForm from './ContactForm';

export const metadata: Metadata = {
  title: { absolute: 'Contact Virello AI — Questions, Billing & Press' },
  description:
    "Questions about growth, billing, partnerships or press — send us a message and we'll get back to you. Or reach us at support@virelloai.online.",
  alternates: { canonical: '/contact.html' },
  openGraph: {
    type: 'website',
    url: 'https://virelloai.online/contact.html',
    images: [
      {
        url: '/images/virello-social-card.png',
        width: 1200,
        height: 630,
        alt: 'Virello AI — Your AI Growth Manager',
      },
    ],
  },
};

const SOCIALS: { name: string; href: string }[] = [
  { name: 'Instagram', href: 'https://www.instagram.com/virelloai.online/' },
  { name: 'YouTube', href: 'https://www.youtube.com/@virelloai.online/' },
  { name: 'TikTok', href: 'https://www.tiktok.com/@virelloai.online/' },
  // X TEMPORARILY HIDDEN 2026-10-26 (@virelloai suspended; restore when reinstated):
  // { name: 'X', href: 'https://x.com/virelloai' },
  { name: 'Facebook', href: 'https://www.facebook.com/profile.php?id=61595418210450' },
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

export default function ContactPage() {
  return (
    <>
      <section className="hero">
        <div className="wrap">
          <span className="kicker">Contact Us</span>
          <h1 className="h-xl">
            Talk to a <span className="grad-text">human</span>
          </h1>
          <p className="lead">
            Questions about growth, billing, partnerships or press — send us a
            message and we&apos;ll get back to you.
          </p>
        </div>
      </section>

      <section className="section" style={{ paddingTop: 16 }}>
        <div className="wrap">
          <div className="grid grid-2" style={{ alignItems: 'start', gap: 24 }}>
            <div>
              <div className="card" style={{ marginBottom: 20 }}>
                <Icon>
                  <rect x="3" y="5" width="18" height="14" rx="2" />
                  <path d="M3 7l9 6 9-6" />
                </Icon>
                <h3>Support</h3>
                <p>
                  For account, campaign and billing help, the fastest route is
                  the Help Center — or send the form and our team will reply by
                  email.
                </p>
                <p style={{ marginTop: 12 }}>
                  Email us at{' '}
                  <a
                    href="mailto:support@virelloai.online"
                    style={{ color: 'var(--pink)', fontWeight: 600 }}
                  >
                    support@virelloai.online
                  </a>
                </p>
                <a
                  className="btn btn-ghost btn-sm"
                  href="/help.html"
                  style={{ marginTop: 16 }}
                >
                  Visit Help Center
                </a>
              </div>
              <div className="card" style={{ marginBottom: 20 }}>
                <Icon>
                  <path d="M21 12a8 8 0 0 1-11.6 7.1L4 20l1-5.2A8 8 0 1 1 21 12z" />
                </Icon>
                <h3>Ask Virello (in-app)</h3>
                <p>
                  Inside the app, Ask Virello answers instantly and routes
                  complex issues to the AI Support agent or a human.
                </p>
              </div>
              <div className="card">
                <h3>Follow Virello</h3>
                <p style={{ marginBottom: 14 }}>
                  Product news, growth tips and feature launches.
                </p>
                <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                  {SOCIALS.map((s) => (
                    <a
                      key={s.name}
                      className="chip"
                      href={s.href}
                      target="_blank"
                      rel="noreferrer"
                      aria-label={`Virello on ${s.name}`}
                    >
                      {s.name}
                    </a>
                  ))}
                </div>
              </div>
            </div>
            <ContactForm />
          </div>
        </div>
      </section>
    </>
  );
}
