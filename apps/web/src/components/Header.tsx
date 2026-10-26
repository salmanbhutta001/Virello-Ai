'use client';

import { useEffect, useState } from 'react';
import { usePathname } from 'next/navigation';
import { API_BASE } from '@/lib/api';

/* Header matches the main virelloai.online site shell exactly:
   official logo image, same nav, top pill strip, shared theme
   (localStorage 'virello-theme') and shared login state
   (localStorage 'virello_token') — so public pages never look or
   behave like a separate website. Pre-paint state comes from the
   inline script in layout.tsx (data-theme / data-auth on <html>);
   CSS shows/hides the auth buttons from those attributes, so there
   is no flicker and no wrong button flash. */

const NAV = [
  { href: '/', label: 'Home', key: 'home' },
  { href: '/features.html', label: 'Features', key: 'features' },
  { href: '/how.html', label: 'How It Works', key: 'how' },
  { href: '/pricing.html', label: 'Pricing', key: 'pricing' },
  { href: '/blog.html', label: 'Blog', key: 'blog' },
  { href: '/score.html', label: 'Free AI Score', key: 'score' },
  { href: '/shop.html', label: 'Shop', key: 'shop' },
  { href: '/about.html', label: 'About', key: 'about' },
  { href: '/help.html', label: 'Help', key: 'help' },
];

const STRIP = [
  { href: '/', label: 'Home', key: 'home' },
  { href: '/features.html', label: 'Features', key: 'features' },
  { href: '/how.html', label: 'How It Works', key: 'how' },
  { href: '/pricing.html', label: 'Pricing', key: 'pricing' },
  { href: '/blog.html', label: 'Blog', key: 'blog' },
  { href: '/about.html', label: 'About Us', key: 'about' },
  // Help Center / Contact / Trust & Safety live in the footer only
  // (Hafiz, 2026-10-25) — removed from the top strip.
];

function activeKey(pathname: string | null): string {
  if (!pathname) return '';
  if (pathname === '/' || pathname === '/index.html') return 'home';
  // Prerender paths carry NO .html (routes: /features, /blog) while live
  // URLs do (/features.html). The old regex required .html, so prerendered
  // HTML shipped with NO active marker on any page except /blog (which
  // only worked via the startsWith fallback) — the underline was missing
  // on features/about/etc. Accept both forms so prerender and client agree.
  const m = pathname.match(/^\/([a-z]+)(?:-[^/]*)?(?:\.html)?$/);
  if (m) return m[1];
  if (pathname.startsWith('/blog')) return 'blog';
  return '';
}

export default function Header() {
  const [open, setOpen] = useState(false);
  const pathname = usePathname();
  const active = activeKey(pathname);

  useEffect(() => {
    // Keep <html data-theme/data-auth> in sync with the shared keys.
    const sync = () => {
      try {
        const t = localStorage.getItem('virello-theme');
        document.documentElement.setAttribute(
          'data-theme',
          t === 'light' ? 'light' : 'dark',
        );
        document.documentElement.setAttribute(
          'data-auth',
          localStorage.getItem('virello_token') ? 'in' : 'out',
        );
      } catch {
        /* storage unavailable — pre-paint defaults stand */
      }
    };
    sync();
    window.addEventListener('storage', sync);
    return () => window.removeEventListener('storage', sync);
  }, []);

  // Session timeout — same rules as the legacy SPA shell: 30 min idle or
  // 24 h since login logs out; an expiring access token is silently
  // refreshed while the session is still valid.
  useEffect(() => {
    const IDLE_MS = 30 * 60 * 1000;
    const MAX_MS = 24 * 60 * 60 * 1000;
    const tokenExpMs = (tok: string): number => {
      try {
        const p = tok.split('.')[1];
        if (!p) return 0;
        const j = JSON.parse(
          atob(p.replace(/-/g, '+').replace(/_/g, '/')),
        ) as { exp?: number };
        return j.exp ? j.exp * 1000 : 0;
      } catch {
        return 0;
      }
    };
    const get = (k: string): string | null => {
      try {
        return localStorage.getItem(k);
      } catch {
        return null;
      }
    };
    const num = (k: string): number => {
      const v = parseInt(get(k) || '0', 10);
      return Number.isFinite(v) ? v : 0;
    };
    let refreshing: Promise<boolean> | null = null;
    const refresh = (): Promise<boolean> => {
      if (refreshing) return refreshing;
      const rt = get('virello_refresh_token');
      if (!rt) return Promise.resolve(false);
      refreshing = fetch(`${API_BASE}/auth/refresh`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ refresh_token: rt }),
      })
        .then((r) =>
          r
            .json()
            .catch(() => ({}))
            .then((d) => ({ res: r, data: d as Record<string, unknown> })),
        )
        .then(({ res, data }) => {
          const nested = data.data as Record<string, unknown> | undefined;
          const at = (data.access_token ?? nested?.access_token) as
            | string
            | undefined;
          const nrt = (data.refresh_token ?? nested?.refresh_token) as
            | string
            | undefined;
          if (res.ok && at) {
            try {
              localStorage.setItem('virello_token', at);
              if (nrt) localStorage.setItem('virello_refresh_token', nrt);
            } catch {
              /* ignore */
            }
            return true;
          }
          return false;
        })
        .catch(() => false)
        .then((ok) => {
          refreshing = null;
          return ok;
        });
      return refreshing;
    };
    const expire = () => {
      try {
        localStorage.removeItem('virello_token');
        localStorage.removeItem('virello_refresh_token');
        localStorage.removeItem('virello_user');
        localStorage.removeItem('virello_last_at');
        localStorage.removeItem('virello_login_at');
      } catch {
        /* ignore */
      }
      document.documentElement.setAttribute('data-auth', 'out');
      window.location.href = '/login.html';
    };
    const check = () => {
      const tok = get('virello_token');
      if (!tok) return;
      const now = Date.now();
      const loginAt = num('virello_login_at');
      if (!loginAt) {
        try {
          localStorage.setItem('virello_login_at', String(now));
          localStorage.setItem('virello_last_at', String(now));
        } catch {
          /* ignore */
        }
        return;
      }
      if (now - loginAt > MAX_MS) {
        expire();
        return;
      }
      const last = num('virello_last_at') || loginAt;
      if (now - last > IDLE_MS) {
        expire();
        return;
      }
      const exp = tokenExpMs(tok);
      if (exp && exp <= now + 60000) {
        const rt = get('virello_refresh_token');
        if (!rt || tokenExpMs(rt) <= now) {
          expire();
          return;
        }
        void refresh().then((ok) => {
          if (!ok) expire();
        });
      }
    };
    let lastNote = 0;
    const note = () => {
      const n = Date.now();
      if (n - lastNote < 30000) return;
      lastNote = n;
      try {
        localStorage.setItem('virello_last_at', String(n));
      } catch {
        /* ignore */
      }
    };
    const events = ['click', 'keydown', 'scroll', 'touchstart', 'mousemove'];
    events.forEach((ev) =>
      window.addEventListener(ev, note, { passive: true }),
    );
    document.addEventListener('visibilitychange', check);
    const timer = window.setInterval(check, 60000);
    check();
    return () => {
      events.forEach((ev) => window.removeEventListener(ev, note));
      document.removeEventListener('visibilitychange', check);
      window.clearInterval(timer);
    };
  }, []);

  const toggleTheme = () => {
    const next =
      document.documentElement.getAttribute('data-theme') === 'light'
        ? 'dark'
        : 'light';
    document.documentElement.setAttribute('data-theme', next);
    try {
      localStorage.setItem('virello-theme', next);
    } catch {
      /* ignore */
    }
  };

  const logout = () => {
    try {
      localStorage.removeItem('virello_token');
      localStorage.removeItem('virello_refresh_token');
      localStorage.removeItem('virello_user');
      localStorage.removeItem('virello_last_at');
      localStorage.removeItem('virello_login_at');
    } catch {
      /* ignore */
    }
    document.documentElement.setAttribute('data-auth', 'out');
    window.location.href = '/';
  };

  return (
    <header className="site-header">
      <div className="wrap bar">
        <a href="/" aria-label="Virello AI home">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            className="logo-img"
            src="/logo-virello.png"
            alt="Virello AI"
            width={560}
            height={175}
          />
        </a>
        <nav className="main-nav" aria-label="Main">
          {NAV.map((n) => (
            <a
              key={n.key}
              href={n.href}
              className={active === n.key ? 'active' : undefined}
            >
              {n.label}
            </a>
          ))}
          <a href="/login.html" className="auth-out">
            Dashboard
          </a>
          <a href="/dashboard.html" className="auth-in">
            Dashboard
          </a>
        </nav>
        <div className="header-cta">
          <a
            className="icon-btn auth-in"
            href="/settings.html"
            aria-label="Settings"
            title="Settings"
          >
            <svg viewBox="0 0 24 24">
              <circle cx="12" cy="12" r="3" />
              <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z" />
            </svg>
          </a>
          <button
            className="theme-toggle"
            onClick={toggleTheme}
            aria-label="Switch theme"
            title="Switch theme"
            type="button"
          >
            <svg className="ic-sun" viewBox="0 0 24 24" aria-hidden="true">
              <circle cx="12" cy="12" r="4" />
              <path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" />
            </svg>
            <svg className="ic-moon" viewBox="0 0 24 24" aria-hidden="true">
              <path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z" />
            </svg>
          </button>
          <a className="btn btn-ghost btn-sm auth-out" href="/login.html">
            Log In
          </a>
          <a className="btn btn-grad btn-sm auth-out" href="/login.html">
            Get Started
          </a>
          <button
            className="btn btn-grad btn-sm auth-in"
            onClick={logout}
            type="button"
          >
            Log Out
          </button>
          <button
            className="menu-btn"
            aria-label="Menu"
            onClick={() => setOpen((v) => !v)}
            type="button"
          >
            ☰
          </button>
        </div>
      </div>
      <nav className="topnav-strip" aria-label="Pages">
        <a href="/" className={active === 'home' ? 'active' : undefined}>
          Home
        </a>
        <a href="/shop.html" className="nav-spot">
          Shop
        </a>
        {STRIP.slice(1, 5).map((n) => (
          <a
            key={n.key}
            href={n.href}
            className={active === n.key ? 'active' : undefined}
          >
            {n.label}
          </a>
        ))}
        <a href="/login.html" className="nav-spot auth-out">
          Dashboard
        </a>
        <a href="/dashboard.html" className="nav-spot auth-in">
          Dashboard
        </a>
        {STRIP.slice(5).map((n) => (
          <a
            key={n.key}
            href={n.href}
            className={active === n.key ? 'active' : undefined}
          >
            {n.label}
          </a>
        ))}
      </nav>
      <nav className={`mobile-nav${open ? ' open' : ''}`} aria-label="Mobile">
        {NAV.map((n) => (
          <a key={n.key} href={n.href} onClick={() => setOpen(false)}>
            {n.label}
          </a>
        ))}
        <a href="/contact.html" onClick={() => setOpen(false)}>
          Contact
        </a>
        <a href="/trust.html" onClick={() => setOpen(false)}>
          Trust &amp; Safety
        </a>
        <a href="/login.html" className="auth-out" onClick={() => setOpen(false)}>
          Log In / Sign Up
        </a>
        <a href="/dashboard.html" className="auth-in" onClick={() => setOpen(false)}>
          Dashboard
        </a>
      </nav>
    </header>
  );
}
