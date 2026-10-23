'use client';

import { useState } from 'react';
import Link from 'next/link';

const NAV = [
  { href: '/', label: 'Home' },
  { href: '/features.html', label: 'Features' },
  { href: '/how.html', label: 'How It Works' },
  { href: '/pricing.html', label: 'Pricing' },
  { href: '/blog.html', label: 'Blog' },
  { href: '/score.html', label: 'Free AI Score' },
  // Phase 1: Shop still lives in the app shell at /#/shop.
  // Phase 2 (full cutover) moves it to the Next.js /shop route below.
  { href: '/#/shop', label: 'Shop' },
  { href: '/about.html', label: 'About' },
  { href: '/help.html', label: 'Help' },
];

export default function Header() {
  const [open, setOpen] = useState(false);
  return (
    <header className="site-header">
      <div className="wrap bar">
        <Link href="/" className="logo" aria-label="Virello AI home">
          <span className="vmark">V</span>
          <span>
            Virello <span className="grad-text">AI</span>
          </span>
        </Link>
        <nav className="main-nav" aria-label="Main">
          {NAV.map((n) => (
            <a key={n.href} href={n.href}>
              {n.label}
            </a>
          ))}
        </nav>
        <div className="header-cta">
          <a className="btn btn-ghost btn-sm" href="/login.html">
            Log In
          </a>
          <a className="btn btn-grad btn-sm" href="/login.html">
            Get Started
          </a>
          <button
            className="menu-btn"
            aria-label="Menu"
            onClick={() => setOpen((v) => !v)}
          >
            ☰
          </button>
        </div>
      </div>
      <nav className={`mobile-nav${open ? ' open' : ''}`} aria-label="Mobile">
        {NAV.map((n) => (
          <a key={n.href} href={n.href} onClick={() => setOpen(false)}>
            {n.label}
          </a>
        ))}
        <a href="/login.html">Log In / Sign Up</a>
      </nav>
    </header>
  );
}
