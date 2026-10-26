'use client';

import { useEffect, useState } from 'react';
import AppShell from '@/components/AppShell';
import { logout } from '@/lib/auth';
import { startTour } from '@/lib/tour';
import { showToast } from '@/lib/toast';

// Settings — port of legacy #page-settings (index.html:2029-2088).
// - Appearance: Light/Dark chips write the shared 'virello-theme'
//   key (same as the header toggle); toast "Light theme on" /
//   "Dark theme on".
// - Language: English / اردو chips store 'virello-lang' ONLY — no
//   i18n exists in legacy; the choice is stored and reflected in the
//   chip state, nothing is translated (preserved as-is).
// - Privacy & data: links to /privacy.html (new tab) and /trust.html.
// - Website tour: "Take a Tour" starts the 9-step tour.
// - Notifications: localStorage only ('virello-notifs', defaults
//   rec:true, camp:true, week:false); toast on save.
// - Account: Open Profile → /profile.html; Log Out → logout(true)
//   (app routes → /login.html, per plan §2.1).

type NotifPrefs = { rec: boolean; camp: boolean; week: boolean };

function loadNotifPrefs(): NotifPrefs {
  const p: NotifPrefs = { rec: true, camp: true, week: false };
  try {
    const sv = localStorage.getItem('virello-notifs');
    if (sv) {
      const o = JSON.parse(sv) as Partial<NotifPrefs>;
      if (o) {
        p.rec = !!o.rec;
        p.camp = !!o.camp;
        p.week = !!o.week;
      }
    }
  } catch {
    /* ignore */
  }
  return p;
}

export default function SettingsPage() {
  const [theme, setTheme] = useState<'light' | 'dark'>('dark');
  const [lang, setLang] = useState('en');
  const [notifs, setNotifs] = useState<NotifPrefs>({ rec: true, camp: true, week: false });

  useEffect(() => {
    try {
      setTheme(
        document.documentElement.getAttribute('data-theme') === 'light' ? 'light' : 'dark',
      );
      setLang(localStorage.getItem('virello-lang') || 'en');
    } catch {
      /* ignore */
    }
    setNotifs(loadNotifPrefs());
    const onStorage = (e: StorageEvent) => {
      if (e.key === 'virello-theme') {
        setTheme(e.newValue === 'light' ? 'light' : 'dark');
      }
    };
    window.addEventListener('storage', onStorage);
    return () => window.removeEventListener('storage', onStorage);
  }, []);

  function setThemeChoice(t: 'light' | 'dark') {
    try {
      document.documentElement.classList.add('theming');
    } catch {
      /* ignore */
    }
    document.documentElement.setAttribute('data-theme', t);
    try {
      localStorage.setItem('virello-theme', t);
    } catch {
      /* ignore */
    }
    setTheme(t);
    window.setTimeout(() => {
      try {
        document.documentElement.classList.remove('theming');
      } catch {
        /* ignore */
      }
    }, 480);
    showToast(t === 'light' ? 'Light theme on' : 'Dark theme on');
  }

  function setLangChoice(l: string) {
    try {
      localStorage.setItem('virello-lang', l);
    } catch {
      /* ignore */
    }
    setLang(l);
    showToast(l === 'ur' ? 'Language set to Urdu' : 'Language set to English');
  }

  function saveNotifPrefs(next: NotifPrefs) {
    setNotifs(next);
    try {
      localStorage.setItem('virello-notifs', JSON.stringify(next));
    } catch {
      /* ignore */
    }
    showToast('Notification preferences saved');
  }

  return (
    <AppShell active="settings">
      <section id="page-settings">
        <div className="app-top">
          <div>
            <h2 className="page-h">Settings</h2>
            <p className="mut small">Appearance, language, notifications and privacy — one place.</p>
          </div>
        </div>
        <div className="grid" style={{ gridTemplateColumns: '1fr 1fr', gap: 20, alignItems: 'start' }}>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
            <div className="dash-card">
              <h3 style={{ margin: '0 0 4px' }}>Appearance</h3>
              <p className="small" style={{ margin: '0 0 16px', color: '#6B7280' }}>
                Website and dashboard share one theme.
              </p>
              <div style={{ display: 'flex', gap: 10 }} id="themeSeg">
                <button
                  className={`chip${theme === 'light' ? ' on' : ''}`}
                  data-theme-choice="light"
                  onClick={() => setThemeChoice('light')}
                  type="button"
                >
                  Light
                </button>
                <button
                  className={`chip${theme === 'dark' ? ' on' : ''}`}
                  data-theme-choice="dark"
                  onClick={() => setThemeChoice('dark')}
                  type="button"
                >
                  Dark
                </button>
              </div>
            </div>
            <div className="dash-card">
              <h3 style={{ margin: '0 0 4px' }}>Language</h3>
              <p className="small" style={{ margin: '0 0 16px', color: '#6B7280' }}>
                Interface language for the website.
              </p>
              <div style={{ display: 'flex', gap: 10 }} id="langSeg">
                <button
                  className={`chip${lang === 'en' ? ' on' : ''}`}
                  data-lang-choice="en"
                  onClick={() => setLangChoice('en')}
                  type="button"
                >
                  English
                </button>
                <button
                  className={`chip${lang === 'ur' ? ' on' : ''}`}
                  data-lang-choice="ur"
                  onClick={() => setLangChoice('ur')}
                  type="button"
                >
                  اردو
                </button>
              </div>
            </div>
            <div className="dash-card">
              <h3 style={{ margin: '0 0 4px' }}>Privacy &amp; data</h3>
              <p className="small" style={{ margin: '0 0 16px', color: '#6B7280' }}>
                How Virello handles your information.
              </p>
              <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
                <a className="btn btn-ghost btn-sm" href="/privacy.html" target="_blank" rel="noopener">
                  Privacy Policy
                </a>
                <a className="btn btn-ghost btn-sm" href="/trust.html">
                  Trust &amp; Safety
                </a>
              </div>
            </div>
            <div className="dash-card">
              <h3 style={{ margin: '0 0 4px' }}>Website tour</h3>
              <p className="small" style={{ margin: '0 0 16px', color: '#6B7280' }}>
                New here? Replay the guided tour of the website and dashboard.
              </p>
              <button
                className="btn btn-pink btn-sm"
                onClick={() => {
                  startTour();
                }}
                type="button"
              >
                Take a Tour
              </button>
            </div>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
            <div className="dash-card">
              <h3 style={{ margin: '0 0 12px' }}>Notifications</h3>
              {(
                [
                  ['rec', 'AI recommendations', 'Weekly optimization tips from your AI agents', 'ntfRec'],
                  ['camp', 'Campaign alerts', 'When a campaign finishes or needs approval', 'ntfCamp'],
                  ['week', 'Weekly growth report', 'Every Monday — reach, followers, top posts', 'ntfWeek'],
                ] as const
              ).map(([key, label, sub, id]) => (
                <div className="rec" key={key}>
                  <div style={{ flex: 1 }}>
                    <b style={{ fontSize: '.93rem' }}>{label}</b>
                    <p className="small" style={{ color: '#6B7280', margin: '2px 0 0' }}>
                      {sub}
                    </p>
                  </div>
                  <label className="switch">
                    <input
                      type="checkbox"
                      id={id}
                      checked={notifs[key]}
                      onChange={(e) => saveNotifPrefs({ ...notifs, [key]: e.target.checked })}
                    />
                    <i />
                  </label>
                </div>
              ))}
            </div>
            <div className="dash-card">
              <h3 style={{ margin: '0 0 4px' }}>Account</h3>
              <p className="small" style={{ margin: '0 0 16px', color: '#6B7280' }}>
                Manage your profile or sign out.
              </p>
              <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
                <a className="btn btn-ghost btn-sm" href="/profile.html">
                  Open Profile
                </a>
                <button className="btn btn-ghost btn-sm" onClick={() => logout(true)} type="button">
                  Log Out
                </button>
              </div>
            </div>
          </div>
        </div>
      </section>
    </AppShell>
  );
}
