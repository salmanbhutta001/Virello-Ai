'use client';

import { useEffect, useRef, useState } from 'react';
import AppShell, { toggleSidebar } from '@/components/AppShell';
import CreatorHub from '@/components/creator-hub';
import { useCurrentUser } from '@/lib/user';
import { showToast } from '@/lib/toast';

// Dashboard — port of legacy #page-dashboard (index.html:1550-1868).
//
// Preserved EXACTLY as legacy (flagged, not redesigned):
// - runGrow fabricates a random 78–95 score client-side with NO API
//   call, a hardcoded geography note (Pakistan · UAE · United Kingdom)
//   and an animated progress bar. The "Campaign created" toast is
//   part of the same demo flow.
// - AI Growth Score ring 86/100 and the 4 KPI cards are hardcoded.
// - The reach chart, AI Recommendations and the "Sample data in this
//   preview" note are hardcoded static content.
// - Notifications are 3 hardcoded items (virello_notifs_read hides
//   the ping dot); clicking one marks all read and navigates.
// - Dashboard search navigates to /campaigns.html and filters the
//   hardcoded campaign rows there (via sessionStorage, because the
//   campaigns table now lives on its own page).
// - "+ New Campaign" on the campaigns page sets a flag that focuses
//   #growUrl here after 350 ms (legacy behaviour, cross-page).

const GOALS = ['More Views', 'More Followers', 'More Engagement', 'More Sales'];

const NOTIFS = [
  {
    t: 'AI recommendations',
    x: '3 new optimization tips are waiting for you in Analytics.',
    href: '/analytics.html',
  },
  {
    t: 'Campaign alert',
    x: '"Daily Tips — Free Grow" reached 820 of 1,000 free impressions.',
    href: '/campaigns.html',
  },
  {
    t: 'Weekly growth report',
    x: 'Your Monday report is ready — reach, followers, top posts.',
    href: '/analytics.html',
  },
];

/** Open a Creator Hub panel from the Grow box (legacy growToDistribute / growToSpotlight). */
function openHubPanel(panel: 'distribute' | 'spotlight', link: string) {
  try {
    window.dispatchEvent(
      new CustomEvent('virello:open-hub-panel', { detail: { panel, link } }),
    );
  } catch {
    /* not in a browser */
  }
}

export default function DashboardPage() {
  const { user, avatar } = useCurrentUser();
  const [greeting, setGreeting] = useState('Good afternoon');
  const [search, setSearch] = useState('');
  const [notifsOpen, setNotifsOpen] = useState(false);
  const [notifsRead, setNotifsRead] = useState(false);
  const [goal, setGoal] = useState('More Views');
  const [growUrl, setGrowUrl] = useState('');
  const [result, setResult] = useState<{ score: number; goal: string; url: string } | null>(null);
  const [barWidth, setBarWidth] = useState(8);
  const [actsShown, setActsShown] = useState(false);
  const growInputRef = useRef<HTMLInputElement>(null);

  // Legacy paintGreeting (index.html:3402-3408) + paintAvatars.
  useEffect(() => {
    const h = new Date().getHours();
    const g = h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
    let name = 'there';
    try {
      const raw = localStorage.getItem('virello_user');
      if (raw) {
        const o = JSON.parse(raw) as { name?: string };
        if (o?.name) name = o.name.split(' ')[0];
      }
    } catch {
      /* ignore */
    }
    setGreeting(`${g}, ${name}`);
    try {
      setNotifsRead(localStorage.getItem('virello_notifs_read') === '1');
    } catch {
      /* ignore */
    }
    // "+ New Campaign" (campaigns page) asked us to focus the Grow box.
    try {
      if (sessionStorage.getItem('virello_focus_grow') === '1') {
        sessionStorage.removeItem('virello_focus_grow');
        window.setTimeout(() => {
          const i = document.getElementById('growUrl') as HTMLInputElement | null;
          if (i) {
            i.scrollIntoView({ behavior: 'smooth', block: 'center' });
            i.focus();
          }
        }, 350);
      }
    } catch {
      /* ignore */
    }
  }, []);

  // Greeting follows the live user once fetchMe returns.
  useEffect(() => {
    if (!user?.name) return;
    const h = new Date().getHours();
    const g = h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
    setGreeting(`${g}, ${user.name.split(' ')[0]}`);
  }, [user]);

  const avatarInitial = (() => {
    const n = user?.name || '';
    return n ? n.trim().charAt(0).toUpperCase() : 'V';
  })();

  function dashSearch() {
    const q = search.trim().toLowerCase();
    if (!q) {
      showToast('Type something to search your campaigns');
      return;
    }
    try {
      sessionStorage.setItem('virello_camp_search', q);
    } catch {
      /* ignore */
    }
    window.location.href = '/campaigns.html';
  }

  function notifReadAll() {
    try {
      localStorage.setItem('virello_notifs_read', '1');
    } catch {
      /* ignore */
    }
    setNotifsRead(true);
  }

  function runGrow() {
    const url = growUrl.trim();
    if (!url) {
      showToast('Paste a post URL first — then press LET AI GROW.');
      growInputRef.current?.focus();
      return;
    }
    // DEMO (legacy parity — no API call): random score 78–95.
    const score = 78 + Math.floor(Math.random() * 18);
    setResult({ score, goal, url });
    setBarWidth(6);
    window.setTimeout(() => setBarWidth(64), 60);
    setActsShown(true);
    showToast('Campaign created — Free Grow AI is on it.');
  }

  function growToDistribute() {
    const url = growUrl.trim();
    openHubPanel('distribute', url);
    document.getElementById('creatorCards')?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    window.setTimeout(() => document.getElementById('distContent')?.focus(), 450);
    showToast('Link loaded — add your caption, then Repurpose');
  }

  function growToSpotlight() {
    const url = growUrl.trim();
    openHubPanel('spotlight', url);
    document.getElementById('creatorCards')?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    window.setTimeout(() => document.getElementById('spContent')?.focus(), 450);
    showToast('Link loaded — write your post, tick consent, Submit');
  }

  return (
    <AppShell active="dashboard">
      <div className="app-top">
        <button
          className="icon-btn"
          id="sideBurger"
          aria-label="Menu"
          onClick={toggleSidebar}
          type="button"
        >
          <svg viewBox="0 0 24 24">
            <path d="M4 7h16M4 12h16M4 17h16" />
          </svg>
        </button>
        <div>
          <h2 className="page-h" id="dashGreet">
            {greeting}
          </h2>
          <p className="mut small">Here&apos;s what your AI Growth Manager is doing today.</p>
        </div>
        <div className="search-box">
          <svg width="17" height="17" viewBox="0 0 24 24" style={{ stroke: '#9CA3AF', fill: 'none', strokeWidth: 2 }}>
            <circle cx="11" cy="11" r="7" />
            <path d="M21 21l-4.3-4.3" />
          </svg>
          <input
            id="dashSearch"
            placeholder="Search campaigns, posts…"
            aria-label="Search"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter') {
                e.preventDefault();
                dashSearch();
              }
            }}
          />
        </div>
        <div style={{ position: 'relative' }}>
          <button
            className="icon-btn"
            onClick={(e) => {
              e.stopPropagation();
              setNotifsOpen((v) => !v);
            }}
            aria-label="Notifications"
            type="button"
          >
            <svg viewBox="0 0 24 24">
              <path d="M18 9a6 6 0 1 0-12 0c0 6-2.5 7-2.5 7h17S18 15 18 9M10 20a2.2 2.2 0 0 0 4 0" />
            </svg>
            {!notifsRead && <span className="ping" id="notifPing" />}
          </button>
          {notifsOpen && (
            <div
              id="notifDrop"
              style={{
                display: 'block',
                position: 'absolute',
                right: 0,
                top: 48,
                width: 320,
                maxWidth: '86vw',
                background: '#fff',
                borderRadius: 16,
                boxShadow: '0 18px 50px rgba(0,0,0,.18)',
                border: '1px solid rgba(249,81,119,.2)',
                zIndex: 9500,
                overflow: 'hidden',
                color: '#111827',
              }}
            >
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '14px 16px 10px' }}>
                <b style={{ fontSize: '.95rem' }}>Notifications</b>
                <button className="btn btn-ghost btn-sm" onClick={notifReadAll} type="button">
                  Mark all read
                </button>
              </div>
              <div id="notifList">
                {NOTIFS.map((n) => (
                  <div
                    key={n.t}
                    style={{ padding: '12px 16px', borderTop: '1px solid #F1F2F6', cursor: 'pointer' }}
                    onClick={() => {
                      notifReadAll();
                      window.location.href = n.href;
                    }}
                  >
                    <b className="small">{n.t}</b>
                    <p className="tiny mut" style={{ margin: '4px 0 0' }}>
                      {n.x}
                    </p>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
        <span
          className="avatar"
          id="dashAvatar"
          onClick={() => {
            window.location.href = '/profile.html';
          }}
          style={{ cursor: 'pointer' }}
          title="Your profile"
        >
          {avatar ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={avatar}
              style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block', borderRadius: '50%' }}
              alt="Profile photo"
            />
          ) : (
            avatarInitial
          )}
        </span>
      </div>

      <div className="grid" style={{ gridTemplateColumns: '1.6fr 1fr', gap: 20 }} id="dashTop">
        <div className="grow-box">
          <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12, flexWrap: 'wrap', alignItems: 'center' }}>
            <h3 style={{ fontSize: '1.2rem' }}>Grow a new post</h3>
            <span className="pill-free">Free Grow AI ready · $0</span>
          </div>
          <p className="mut small" style={{ margin: '8px 0 18px', color: '#6B7280' }}>
            Paste any post link — AI analysis, audience strategy and optimization are automatic.
          </p>
          <div className="url-input">
            <input
              id="growUrl"
              ref={growInputRef}
              type="url"
              inputMode="url"
              name="post-url"
              autoComplete="off"
              placeholder="Paste your post URL…"
              aria-label="Post URL"
              value={growUrl}
              onChange={(e) => setGrowUrl(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter') {
                  e.preventDefault();
                  runGrow();
                }
              }}
            />
            <button className="btn-grow" onClick={runGrow} type="button">
              LET AI GROW
            </button>
          </div>
          <p className="small" style={{ margin: '16px 0 9px', fontWeight: 700, color: '#6B7280', fontSize: '.78rem', letterSpacing: '.04em' }}>
            YOUR GOAL
          </p>
          <div className="goal-row" style={{ margin: 0 }} id="growGoals">
            {GOALS.map((g) => (
              <button
                key={g}
                className={`goal${goal === g ? ' on' : ''}`}
                onClick={() => setGoal(g)}
                type="button"
              >
                {g}
              </button>
            ))}
          </div>
          {result && (
            <div
              id="growResult"
              style={{
                display: 'block',
                marginTop: 20,
                background: '#FFFFFF',
                border: '1px solid rgba(249,81,119,.3)',
                borderRadius: 16,
                padding: 20,
                boxShadow: '0 6px 24px rgba(249,81,119,.08)',
              }}
            >
              <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap', marginBottom: 12 }}>
                <span className="ai-chip" id="resScore">
                  Content Score {result.score}/100
                </span>
                <span className="ai-chip" id="resGoal">
                  Goal: {result.goal}
                </span>
                <span className="badge b-active">Campaign Live</span>
              </div>
              <p className="small" id="resText" style={{ color: '#374151' }}>
                AI analysis complete for {result.url} — hook rated{' '}
                {result.score > 86 ? 'strong' : 'good'}, audience segments matched in 3 countries.
                Free Grow AI campaign is now live and optimizing.
              </p>
              <div className="progress" style={{ marginTop: 14 }}>
                <i id="resBar" style={{ width: `${barWidth}%` }} />
              </div>
              <p className="tiny mut" style={{ marginTop: 10, color: '#6B7280' }}>
                AI Recommended geography: Pakistan · UAE · United Kingdom — matched to your
                post&apos;s language and audience segments.{' '}
                <a href="/campaigns.html" style={{ color: '#E63E63', fontWeight: 700 }}>
                  View in Campaigns →
                </a>
              </p>
              {actsShown && (
                <div id="growActs" style={{ display: 'flex', gap: 10, flexWrap: 'wrap', marginTop: 16 }}>
                  <button className="btn btn-pink btn-sm" onClick={growToDistribute} type="button">
                    Repurpose for Platforms →
                  </button>
                  <button
                    className="btn btn-sm"
                    style={{ border: '1.5px solid #F95177', color: '#D6336C', background: '#fff', fontWeight: 700 }}
                    onClick={growToSpotlight}
                    type="button"
                  >
                    Get Featured →
                  </button>
                </div>
              )}
            </div>
          )}
        </div>
        <div className="dash-card" style={{ display: 'flex', gap: 20, alignItems: 'center' }}>
          <svg className="score-ring" viewBox="0 0 120 120" role="img" aria-label="AI Growth Score 86 out of 100" style={{ width: 110, flex: 'none' }}>
            <circle cx="60" cy="60" r="50" stroke="#F1F2F6" strokeWidth="11" fill="none" />
            <circle cx="60" cy="60" r="50" stroke="url(#ringGrad2)" strokeWidth="11" fill="none" strokeLinecap="round" strokeDasharray="314" strokeDashoffset="44" transform="rotate(-90 60 60)" />
            <defs>
              <linearGradient id="ringGrad2" x1="0" y1="0" x2="1" y2="1">
                <stop offset="0" stopColor="#F95177" />
                <stop offset="1" stopColor="#D6336C" />
              </linearGradient>
            </defs>
            <text x="60" y="58" textAnchor="middle" fill="#111827" fontWeight="800" fontSize="30" className="ring-num">
              86
            </text>
            <text x="60" y="78" textAnchor="middle" fill="#9CA3AF" fontSize="10.5">
              / 100
            </text>
          </svg>
          <div>
            <h3>AI Growth Score</h3>
            <p className="small" style={{ margin: '6px 0 12px', color: '#6B7280' }}>
              Up 9 points this week. Your hooks and posting times are improving.
            </p>
            <span className="up">↑ Trending: Strong</span>
          </div>
        </div>
      </div>

      <div className="kpi-grid" style={{ marginTop: 20 }}>
        <div className="kpi">
          <span>Total Reach</span>
          <b>128.4K</b>
          <span className="up">↑ 32.5%</span> <span className="tiny" style={{ color: '#9CA3AF' }}>vs last week</span>
        </div>
        <div className="kpi">
          <span>Engagement</span>
          <b>18.2K</b>
          <span className="up">↑ 18.1%</span> <span className="tiny" style={{ color: '#9CA3AF' }}>vs last week</span>
        </div>
        <div className="kpi">
          <span>New Followers</span>
          <b>+2,847</b>
          <span className="up">↑ 24.7%</span> <span className="tiny" style={{ color: '#9CA3AF' }}>vs last week</span>
        </div>
        <div className="kpi">
          <span>Active Campaigns</span>
          <b>3</b>
          <span className="tiny" style={{ color: '#9CA3AF' }}>1 Free Grow · 2 Paid Boost</span>
        </div>
      </div>

      <div style={{ marginTop: 26 }}>
        <CreatorHub />
      </div>

      <div className="grid" style={{ gridTemplateColumns: '1.55fr 1fr', gap: 20, marginTop: 20 }} id="dashLower">
        <div className="dash-card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
            <h3>Reach — last 14 days</h3>
            <a className="small" href="/analytics.html" style={{ color: '#E63E63', fontWeight: 700 }}>
              Full Analytics →
            </a>
          </div>
          <svg viewBox="0 0 560 210" style={{ width: '100%', height: 'auto' }} role="img" aria-label="Line chart of reach growing steadily over 14 days">
            <defs>
              <linearGradient id="areaFill2" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0" stopColor="#F95177" stopOpacity=".28" />
                <stop offset="1" stopColor="#F95177" stopOpacity="0" />
              </linearGradient>
            </defs>
            <g stroke="#EDEEF3">
              <line x1="40" y1="30" x2="540" y2="30" />
              <line x1="40" y1="80" x2="540" y2="80" />
              <line x1="40" y1="130" x2="540" y2="130" />
              <line x1="40" y1="180" x2="540" y2="180" />
            </g>
            <path d="M40 168 L78 158 L116 162 L154 140 L192 146 L230 122 L268 128 L306 104 L344 110 L382 84 L420 92 L458 62 L496 70 L540 40 L540 190 L40 190 Z" fill="url(#areaFill2)" />
            <path d="M40 168 L78 158 L116 162 L154 140 L192 146 L230 122 L268 128 L306 104 L344 110 L382 84 L420 92 L458 62 L496 70 L540 40" fill="none" stroke="#F95177" strokeWidth="2.6" strokeLinecap="round" />
            <circle cx="540" cy="40" r="4.5" fill="#F95177" />
            <g fill="#9CA3AF" fontSize="10.5">
              <text x="36" y="205">Day 1</text>
              <text x="270" y="205">Day 7</text>
              <text x="505" y="205">Day 14</text>
            </g>
          </svg>
          <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap', marginTop: 14 }}>
            <a className="btn btn-ghost btn-sm" href="/campaigns.html">
              Summer Reel Push · <span className="up">Active</span>
            </a>
            <a className="btn btn-ghost btn-sm" href="/campaigns.html">
              Course Launch Boost · <span className="up">Active</span>
            </a>
            <a className="btn btn-ghost btn-sm" href="/campaigns.html">
              Weekly Tips Series · <span style={{ color: '#D97706', fontWeight: 700 }}>Paused</span>
            </a>
          </div>
        </div>
        <div className="dash-card">
          <h3 style={{ marginBottom: 6 }}>AI Recommendations</h3>
          <div className="rec">
            <span className="rec-ic">
              <svg viewBox="0 0 24 24">
                <circle cx="12" cy="12" r="9" />
                <path d="M12 7v5l3.5 2" />
              </svg>
            </span>
            <div>
              <b style={{ fontSize: '.93rem' }}>Post between 7–9 PM</b>
              <p className="small" style={{ color: '#6B7280' }}>Your audience is 38% more active in this window.</p>
            </div>
          </div>
          <div className="rec">
            <span className="rec-ic">
              <svg viewBox="0 0 24 24">
                <path d="M4 20V10M10 20V4M16 20v-8" />
              </svg>
            </span>
            <div>
              <b style={{ fontSize: '.93rem' }}>Shift budget to Reels</b>
              <p className="small" style={{ color: '#6B7280' }}>Reels are returning 2.3× the reach per dollar this week.</p>
            </div>
          </div>
          <div className="rec">
            <span className="rec-ic">
              <svg viewBox="0 0 24 24">
                <path d="M12 21c-4 0-7-2.5-7-6.5C5 9 9 4 12 3c3 1 7 6 7 11.5 0 4-3 6.5-7 6.5z" />
              </svg>
            </span>
            <div>
              <b style={{ fontSize: '.93rem' }}>Try UAE targeting</b>
              <p className="small" style={{ color: '#6B7280' }}>Matched segments in the UAE grew 19% for your niche.</p>
            </div>
          </div>
          <a className="btn btn-pink btn-sm" href="/analytics.html" style={{ marginTop: 16 }}>
            See All Insights
          </a>
        </div>
      </div>

      <p className="tiny" style={{ marginTop: 18, color: '#9CA3AF' }}>
        Sample data in this preview — connect your accounts to see your real numbers.
      </p>
    </AppShell>
  );
}
