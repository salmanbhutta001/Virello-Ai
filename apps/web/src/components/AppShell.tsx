'use client';

import { useEffect, useState } from 'react';
import type { ReactNode } from 'react';
import { logout, hasToken } from '@/lib/auth';
import { planLabel, useCurrentUser } from '@/lib/user';

// AppShell — shared chrome for the 5 app routes (plan §1.4).
// Port of the legacy sidebar layout (index.html:1525-1550 + §12):
// logo, Main links (Dashboard / Campaigns / Analytics), Account links
// (Profile / Settings / Subscription → /pricing.html / Help Center →
// /help.html / Back to Website → /), theme toggle, Log Out
// (auth-aware), user card (avatar / name / meta), mobile burger
// (the burger lives in each page's top bar and toggles the sidebar
// via the 'virello:toggle-sidebar' event). The active side item gets
// .on. The public Header/Footer are hidden on app routes (they
// return null there) — the Next equivalent of legacy body.app-mode,
// which hid header.site / footer.site / #publicMain. There is NO
// login gate: the shell renders logged-out too (placeholder user
// card), exactly like legacy.

export type AppRoute =
  | 'dashboard'
  | 'campaigns'
  | 'analytics'
  | 'profile'
  | 'settings';

/** Dispatched by a page's burger button to open/close the sidebar. */
export function toggleSidebar(): void {
  try {
    window.dispatchEvent(new CustomEvent('virello:toggle-sidebar'));
  } catch {
    /* not in a browser */
  }
}

const MAIN_LINKS: { key: AppRoute; href: string; label: string; icon: ReactNode }[] = [
  {
    key: 'dashboard',
    href: '/dashboard.html',
    label: 'Dashboard',
    icon: (
      <>
        <rect x="3" y="3" width="7.5" height="9" rx="1.5" />
        <rect x="13.5" y="3" width="7.5" height="5.5" rx="1.5" />
        <rect x="13.5" y="12" width="7.5" height="9" rx="1.5" />
        <rect x="3" y="15.5" width="7.5" height="5.5" rx="1.5" />
      </>
    ),
  },
  {
    key: 'campaigns',
    href: '/campaigns.html',
    label: 'Campaigns',
    icon: (
      <>
        <circle cx="12" cy="12" r="9" />
        <circle cx="12" cy="12" r="5" />
        <circle cx="12" cy="12" r="1" />
      </>
    ),
  },
  {
    key: 'analytics',
    href: '/analytics.html',
    label: 'Analytics',
    icon: <path d="M4 20V10M10 20V4M16 20v-8M2 20h20" />,
  },
];

const ACCOUNT_LINKS: { key: AppRoute; href: string; label: string; icon: ReactNode }[] = [
  {
    key: 'profile',
    href: '/profile.html',
    label: 'Profile',
    icon: (
      <>
        <circle cx="12" cy="8" r="4" />
        <path d="M4 21c.8-4 4-6 8-6s7.2 2 8 6" />
      </>
    ),
  },
  {
    key: 'settings',
    href: '/settings.html',
    label: 'Settings',
    icon: (
      <>
        <circle cx="12" cy="12" r="3" />
        <path d="M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M19.1 4.9L17 7M7 17l-2.1 2.1" />
      </>
    ),
  },
];

function SideIcon({ children }: { children: ReactNode }) {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true">
      {children}
    </svg>
  );
}

export default function AppShell({
  active,
  children,
}: {
  active: AppRoute;
  children: ReactNode;
}) {
  const { user, avatar } = useCurrentUser();
  const [open, setOpen] = useState(false);
  const [theme, setTheme] = useState<'light' | 'dark'>('dark');
  const [loggedIn, setLoggedIn] = useState(false);

  // Keep <html data-auth> in sync (the Header normally does this, but
  // it renders null on app routes — its effect still runs; this is a
  // belt-and-braces copy for the .auth-in/.auth-out rules).
  useEffect(() => {
    try {
      document.documentElement.setAttribute(
        'data-auth',
        hasToken() ? 'in' : 'out',
      );
      setLoggedIn(hasToken());
      setTheme(
        document.documentElement.getAttribute('data-theme') === 'light'
          ? 'light'
          : 'dark',
      );
    } catch {
      /* storage unavailable */
    }
  }, []);

  useEffect(() => {
    const onToggle = () => setOpen((v) => !v);
    window.addEventListener('virello:toggle-sidebar', onToggle);
    const onStorage = (e: StorageEvent) => {
      if (e.key === 'virello-theme') {
        setTheme(e.newValue === 'light' ? 'light' : 'dark');
      }
    };
    window.addEventListener('storage', onStorage);
    return () => {
      window.removeEventListener('virello:toggle-sidebar', onToggle);
      window.removeEventListener('storage', onStorage);
    };
  }, []);

  const toggleTheme = () => {
    const next = theme === 'light' ? 'dark' : 'light';
    try {
      document.documentElement.classList.add('theming');
    } catch {
      /* ignore */
    }
    document.documentElement.setAttribute('data-theme', next);
    try {
      localStorage.setItem('virello-theme', next);
    } catch {
      /* ignore */
    }
    setTheme(next);
    window.setTimeout(() => {
      try {
        document.documentElement.classList.remove('theming');
      } catch {
        /* ignore */
      }
    }, 480);
  };

  const name = user?.name || 'Your account';
  const firstName = name === 'Your account' ? 'V' : name.trim().charAt(0).toUpperCase();
  let country = '';
  try {
    country = localStorage.getItem('virello_country') || '';
  } catch {
    /* ignore */
  }
  const meta = `${planLabel(user?.plan)} Plan${country ? ` · ${country}` : ''}`;

  return (
    <div className="app-shell">
      <aside className={`sidebar${open ? ' open' : ''}`} id="sidebar">
        <div className="side-topbar">
          <button
            className="icon-btn"
            onClick={() => window.history.back()}
            aria-label="Back"
            type="button"
          >
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
              <path d="M19 12H5M12 19l-7-7 7-7" />
            </svg>
          </button>
          <a href="/">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img className="logo-img" src="/logo-virello.png" alt="Virello AI" />
          </a>
          <button
            className="icon-btn"
            onClick={() => setOpen(false)}
            aria-label="Close sidebar"
            type="button"
          >
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round">
              <path d="M18 6L6 18M6 6l12 12" />
            </svg>
          </button>
        </div>
        <span className="side-label">Main</span>
        {MAIN_LINKS.map((l) => (
          <a
            key={l.key}
            className={`side-item${active === l.key ? ' on' : ''}`}
            href={l.href}
            data-side={l.key}
            onClick={() => setOpen(false)}
          >
            <SideIcon>{l.icon}</SideIcon>
            {l.label}
          </a>
        ))}
        <span className="side-label">Account</span>
        {ACCOUNT_LINKS.map((l) => (
          <a
            key={l.key}
            className={`side-item${active === l.key ? ' on' : ''}`}
            href={l.href}
            data-side={l.key}
            onClick={() => setOpen(false)}
          >
            <SideIcon>{l.icon}</SideIcon>
            {l.label}
          </a>
        ))}
        <a className="side-item" href="/pricing.html" onClick={() => setOpen(false)}>
          <SideIcon>
            <path d="M12 3v18M16.5 6.5c-.8-1-2.4-1.5-4.5-1.5-2.8 0-4.5 1.3-4.5 3.2 0 4.6 9.3 2.4 9.3 7 0 2-2 3.3-4.8 3.3-2.2 0-3.9-.7-4.8-1.8" />
          </SideIcon>
          Subscription
        </a>
        <a className="side-item" href="/help.html" onClick={() => setOpen(false)}>
          <SideIcon>
            <circle cx="12" cy="12" r="9" />
            <path d="M9.5 9.3A2.6 2.6 0 0 1 12 7.5c1.4 0 2.5 1 2.5 2.2 0 1.7-2.3 2-2.3 3.5M12 17h.01" />
          </SideIcon>
          Help Center
        </a>
        <a className="side-item" href="/" onClick={() => setOpen(false)}>
          <SideIcon>
            <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9" />
          </SideIcon>
          Back to Website
        </a>
        <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginTop: 'auto' }}>
          <button
            className="theme-toggle"
            onClick={toggleTheme}
            aria-label="Switch theme"
            style={{ flex: 1, marginTop: 0 }}
            type="button"
          >
            <svg className="ic-sun" viewBox="0 0 24 24" aria-hidden="true">
              <circle cx="12" cy="12" r="4" />
              <path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" />
            </svg>
            <svg className="ic-moon" viewBox="0 0 24 24" aria-hidden="true">
              <path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z" />
            </svg>
            <span className="theme-state">{theme === 'light' ? 'Light theme' : 'Dark theme'}</span>
          </button>
        </div>
        {loggedIn && (
          <button
            className="side-item"
            id="sideLogout"
            style={{ width: '100%', background: 'none', textAlign: 'left' }}
            onClick={() => logout(true)}
            type="button"
          >
            <SideIcon>
              <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9" />
            </SideIcon>
            Log Out
          </button>
        )}
        <div className="side-user">
          <span className="avatar" id="sideAvatar">
            {avatar ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={avatar}
                style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block', borderRadius: '50%' }}
                alt="Profile photo"
              />
            ) : (
              firstName
            )}
          </span>
          <div style={{ minWidth: 0 }}>
            <b style={{ fontSize: '.9rem', display: 'block' }} id="sideUserName">
              {name}
            </b>
            <span className="tiny mut" id="sideUserMeta">
              {user ? meta : 'Virello member'}
            </span>
          </div>
        </div>
      </aside>

      <div className="app-main">{children}</div>
    </div>
  );
}
