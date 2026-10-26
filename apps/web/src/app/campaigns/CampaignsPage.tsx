'use client';

import { useEffect, useState } from 'react';
import AppShell from '@/components/AppShell';
import { isLoggedIn } from '@/lib/auth';

// Campaigns — port of legacy #page-campaigns (index.html:1869-1897).
//
// ⚠️ LEGACY PARITY — HARDCODED DEMO DATA, preserved as-is:
// The 6 rows below are static demo rows (no API call, no per-campaign
// actions — no pause/resume, edit or delete exists in legacy either).
// - LOGGED OUT (no virello_user): rows show, filtered by tab, with the
//   demo note "Sample campaign data for this website preview…".
// - LOGGED IN (virello_user present — isLoggedIn() reads the USER key,
//   not the token, per the legacy split-brain): ALL rows are hidden
//   and #campEmpty shows "No campaigns yet — paste a post URL in the
//   Grow box…", demo note hidden.
// - Dashboard search arrives via sessionStorage 'virello_camp_search'
//   (set by the dashboard) and filters the rows by substring, with
//   the "N campaign(s) match …" / "No campaigns match …" empty text.

type CampStatus = 'all' | 'active' | 'paused' | 'done';

type CampRow = {
  name: string;
  sub: string;
  goal: string;
  status: 'active' | 'paused' | 'done';
  badge: string;
  badgeClass: string;
  reach: string;
  eng: string;
  budget: string;
  progress: number;
  progressNote: string;
  grad: string;
  icon: React.ReactNode;
};

const ROWS: CampRow[] = [
  {
    name: 'Summer Reel Push',
    sub: 'Instagram · Paid Boost AI',
    goal: 'More Views',
    status: 'active',
    badge: 'Active',
    badgeClass: 'b-active',
    reach: '64.2K',
    eng: '9.8K',
    budget: '$25 · Growth pkg',
    progress: 68,
    progressNote: 'Day 9 of 14',
    grad: 'linear-gradient(135deg,#F95177,#D6336C)',
    icon: <path d="M8 5v14l11-7z" />,
  },
  {
    name: 'Course Launch Boost',
    sub: 'YouTube · Paid Boost AI',
    goal: 'More Sales',
    status: 'active',
    badge: 'Active',
    badgeClass: 'b-active',
    reach: '41.7K',
    eng: '5.1K',
    budget: '$50 · Pro pkg',
    progress: 34,
    progressNote: 'Day 10 of 30',
    grad: 'linear-gradient(135deg,#8B5CF6,#6366F1)',
    icon: (
      <>
        <rect x="3" y="6" width="13" height="12" rx="2" />
        <path d="M16 10l5-3v10l-5-3" />
      </>
    ),
  },
  {
    name: 'Daily Tips — Free Grow',
    sub: 'TikTok · Free Grow AI',
    goal: 'More Followers',
    status: 'active',
    badge: 'Active',
    badgeClass: 'b-active',
    reach: '12.9K',
    eng: '2.4K',
    budget: '$0 · Organic',
    progress: 82,
    progressNote: '820 / 1,000 impressions',
    grad: 'linear-gradient(135deg,#0EA5E9,#2563EB)',
    icon: <path d="M12 21c-4 0-7-2.5-7-6.5C5 9 9 4 12 3c3 1 7 6 7 11.5 0 4-3 6.5-7 6.5z" />,
  },
  {
    name: 'Weekly Tips Series',
    sub: 'Facebook · Free Grow AI',
    goal: 'Engagement',
    status: 'paused',
    badge: 'Paused',
    badgeClass: 'b-paused',
    reach: '8.3K',
    eng: '1.1K',
    budget: '$0 · Organic',
    progress: 45,
    progressNote: 'Paused by you',
    grad: 'linear-gradient(135deg,#F59E0B,#D97706)',
    icon: <path d="M21 12a8 8 0 0 1-11.6 7.1L4 20l1-5.2A8 8 0 1 1 21 12z" />,
  },
  {
    name: 'Ramadan Recipe Series',
    sub: 'Instagram · Paid Boost AI',
    goal: 'More Views',
    status: 'done',
    badge: 'Completed',
    badgeClass: 'b-done',
    reach: '96.5K',
    eng: '14.6K',
    budget: '$25 · Growth pkg',
    progress: 100,
    progressNote: 'Finished · +1,204 followers',
    grad: 'linear-gradient(135deg,#10B981,#059669)',
    icon: <path d="M4 12.5l5 5L20 6.5" />,
  },
  {
    name: 'New Year Challenge',
    sub: 'TikTok · Paid Boost AI',
    goal: 'More Followers',
    status: 'done',
    badge: 'Completed',
    badgeClass: 'b-done',
    reach: '58.1K',
    eng: '7.9K',
    budget: '$10 · Starter pkg',
    progress: 100,
    progressNote: 'Finished · +863 followers',
    grad: 'linear-gradient(135deg,#EC4899,#9333EA)',
    icon: (
      <>
        <circle cx="12" cy="12" r="9" />
        <path d="M12 7v5l3.5 2" />
      </>
    ),
  },
];

const TABS: { key: CampStatus; label: string }[] = [
  { key: 'all', label: 'All Campaigns' },
  { key: 'active', label: 'Active' },
  { key: 'paused', label: 'Paused' },
  { key: 'done', label: 'Completed' },
];

export default function CampaignsPage() {
  const [status, setStatus] = useState<CampStatus>('all');
  const [loggedIn, setLoggedIn] = useState(false);
  const [searchQ, setSearchQ] = useState<string | null>(null);

  // Legacy route() re-applies the current filter on entry; the
  // dashboard search arrives via sessionStorage (see header comment).
  useEffect(() => {
    setLoggedIn(isLoggedIn());
    try {
      const q = sessionStorage.getItem('virello_camp_search');
      if (q) {
        sessionStorage.removeItem('virello_camp_search');
        setStatus('all');
        setSearchQ(q);
      }
    } catch {
      /* ignore */
    }
  }, []);

  const visible = loggedIn
    ? []
    : ROWS.filter((r) => {
        if (status !== 'all' && r.status !== status) return false;
        if (searchQ) {
          const hay =
            `${r.name} ${r.sub} ${r.goal} ${r.badge} ${r.reach} ${r.eng} ${r.budget} ${r.progressNote}`.toLowerCase();
          if (!hay.includes(searchQ)) return false;
        }
        return true;
      });

  let emptyText: string | null = null;
  if (loggedIn) {
    emptyText =
      'No campaigns yet — paste a post URL in the Grow box and press LET AI GROW to create your first campaign.';
  } else if (searchQ) {
    emptyText =
      visible.length > 0
        ? `${visible.length} campaign(s) match "${searchQ}"`
        : `No campaigns match "${searchQ}".`;
  } else if (visible.length === 0) {
    emptyText = 'No campaigns in this view.';
  }
  // Legacy: the empty line is always shown when logged in or after a
  // dashboard search; otherwise only when a tab filter empties the list.
  const showEmpty = loggedIn || searchQ !== null || visible.length === 0;
  const showDemoNote = !loggedIn && searchQ === null;

  function newCampaign() {
    try {
      sessionStorage.setItem('virello_focus_grow', '1');
    } catch {
      /* ignore */
    }
    window.location.href = '/dashboard.html';
  }

  return (
    <AppShell active="campaigns">
      <div className="app-top">
        <div>
          <h2 className="page-h">Campaigns</h2>
          <p className="mut small">Every campaign Virello&apos;s AI is running for you.</p>
        </div>
        <div style={{ marginLeft: 'auto' }}>
          <button className="btn btn-pink" onClick={newCampaign} type="button">
            + New Campaign
          </button>
        </div>
      </div>
      <div className="tabs" style={{ marginBottom: 20 }} id="campTabs">
        {TABS.map((t) => (
          <button
            key={t.key}
            className={`tab${status === t.key ? ' on' : ''}`}
            onClick={() => {
              setStatus(t.key);
              setSearchQ(null);
            }}
            type="button"
          >
            {t.label}
          </button>
        ))}
      </div>
      <div className="panel" style={{ padding: '8px 20px' }}>
        <div className="table-scroll">
          <table className="data" id="campTable">
            <thead>
              <tr>
                <th>Campaign</th>
                <th>Goal</th>
                <th>Status</th>
                <th>Reach</th>
                <th>Engagement</th>
                <th>Budget</th>
                <th>Progress</th>
              </tr>
            </thead>
            <tbody>
              {visible.map((r) => (
                <tr key={r.name} data-status={r.status}>
                  <td>
                    <div className="camp-cell">
                      <span className="thumb" style={{ background: r.grad }}>
                        <svg viewBox="0 0 24 24">{r.icon}</svg>
                      </span>
                      <div>
                        <b>{r.name}</b>
                        <p className="tiny mut">{r.sub}</p>
                      </div>
                    </div>
                  </td>
                  <td>{r.goal}</td>
                  <td>
                    <span className={`badge ${r.badgeClass}`}>{r.badge}</span>
                  </td>
                  <td>{r.reach}</td>
                  <td>{r.eng}</td>
                  <td>{r.budget}</td>
                  <td style={{ minWidth: 120 }}>
                    <div className="progress">
                      <i style={{ width: `${r.progress}%` }} />
                    </div>
                    <span className="tiny mut">{r.progressNote}</span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {showEmpty && emptyText && (
          <p className="mut small" id="campEmpty" style={{ display: 'block', padding: '18px 4px' }}>
            {emptyText}
          </p>
        )}
      </div>
      {showDemoNote && (
        <p className="tiny mut" id="campDemoNote" style={{ marginTop: 18 }}>
          Sample campaign data for this website preview. Your real campaigns live in the Virello app.
        </p>
      )}
    </AppShell>
  );
}
