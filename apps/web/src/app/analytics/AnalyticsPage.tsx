'use client';

import { useState } from 'react';
import AppShell from '@/components/AppShell';

// Analytics — port of legacy #page-analytics (index.html:1898-1969).
//
// ⚠️ LEGACY PARITY — HARDCODED DEMO DATA, preserved as-is: the range
// tabs (7/30/90 days) swap 6 hardcoded KPI sets from RANGES (no API
// call); the follower bar chart, campaign table, audience donut,
// country bars and the 3 recommendation cards are all hardcoded.
// Footer note: "Sample analytics for this website preview. Figures
// are illustrative estimates, not guarantees."

const RANGES: Record<'7' | '30' | '90', string[]> = {
  '7': ['96.2K', '158.4K', '13.1K', '5.4K', '2,108', '+2,204'],
  '30': ['412.8K', '689.3K', '57.4K', '23.1K', '8,942', '+9,318'],
  '90': ['1.14M', '1.92M', '158K', '61.7K', '24,530', '+25,940'],
};

const RANGE_TABS: { key: '7' | '30' | '90'; label: string }[] = [
  { key: '7', label: '7 Days' },
  { key: '30', label: '30 Days' },
  { key: '90', label: '90 Days' },
];

export default function AnalyticsPage() {
  const [range, setRange] = useState<'7' | '30' | '90'>('30');
  const d = RANGES[range];

  return (
    <AppShell active="analytics">
      <section id="page-analytics">
        <div className="app-top">
          <div>
            <h2 className="page-h">Analytics</h2>
            <p className="mut small">Performance across all connected platforms.</p>
          </div>
          <div className="tabs" style={{ marginLeft: 'auto' }} id="rangeTabs">
            {RANGE_TABS.map((t) => (
              <button
                key={t.key}
                className={`tab${range === t.key ? ' on' : ''}`}
                onClick={() => setRange(t.key)}
                type="button"
              >
                {t.label}
              </button>
            ))}
          </div>
        </div>
        <div className="kpi-grid">
          <div className="kpi">
            <span>Reach</span>
            <b id="kReach">{d[0]}</b>
            <span className="up">↑ 28.4%</span>
          </div>
          <div className="kpi">
            <span>Impressions</span>
            <b id="kImp">{d[1]}</b>
            <span className="up">↑ 22.9%</span>
          </div>
          <div className="kpi">
            <span>Engagement</span>
            <b id="kEng">{d[2]}</b>
            <span className="up">↑ 16.2%</span>
          </div>
          <div className="kpi">
            <span>Profile Visits</span>
            <b id="kVis">{d[3]}</b>
            <span className="up">↑ 19.8%</span>
          </div>
          <div className="kpi">
            <span>Link Clicks</span>
            <b id="kClick">{d[4]}</b>
            <span className="up">↑ 12.5%</span>
          </div>
          <div className="kpi">
            <span>Follower Growth</span>
            <b id="kFol">{d[5]}</b>
            <span className="up">↑ 24.1%</span>
          </div>
          <div className="kpi">
            <span>Engagement Rate</span>
            <b>8.3%</b>
            <span className="tiny mut">Healthy · above niche avg 5.1%</span>
          </div>
          <div className="kpi">
            <span>AI Growth Score</span>
            <b>86 / 100</b>
            <span className="up">↑ 9 pts</span>
          </div>
        </div>
        <div className="grid" style={{ gridTemplateColumns: '1.55fr 1fr', gap: 20, marginTop: 20 }} id="anaLower">
          <div className="panel">
            <h3 style={{ marginBottom: 6 }}>Follower growth</h3>
            <p className="mut small" style={{ marginBottom: 14 }}>
              Cumulative new followers in the selected period.
            </p>
            <svg viewBox="0 0 560 230" style={{ width: '100%', height: 'auto' }} role="img" aria-label="Bar chart of weekly follower growth increasing over four weeks">
              <g stroke="rgba(255,255,255,.07)">
                <line x1="40" y1="40" x2="540" y2="40" />
                <line x1="40" y1="95" x2="540" y2="95" />
                <line x1="40" y1="150" x2="540" y2="150" />
                <line x1="40" y1="195" x2="540" y2="195" />
              </g>
              <g>
                <rect x="80" y="130" width="70" height="65" rx="7" fill="#D6336C" opacity=".55" />
                <rect x="195" y="108" width="70" height="87" rx="7" fill="#D6336C" opacity=".7" />
                <rect x="310" y="82" width="70" height="113" rx="7" fill="#E63E63" opacity=".85" />
                <rect x="425" y="52" width="70" height="143" rx="7" fill="#F95177" />
              </g>
              <g fill="#fff" fontSize="12" fontWeight="600" textAnchor="middle">
                <text x="115" y="118">1,840</text>
                <text x="230" y="96">2,260</text>
                <text x="345" y="70">2,910</text>
                <text x="460" y="40">3,308</text>
              </g>
              <g fill="#6B7280" fontSize="10.5" textAnchor="middle">
                <text x="115" y="213">Week 1</text>
                <text x="230" y="213">Week 2</text>
                <text x="345" y="213">Week 3</text>
                <text x="460" y="213">Week 4</text>
              </g>
            </svg>
            <h3 style={{ margin: '22px 0 10px' }}>Campaign performance</h3>
            <div className="table-scroll">
              <table className="data">
                <tbody>
                  <tr>
                    <th>Campaign</th>
                    <th>Reach</th>
                    <th>Eng.</th>
                    <th>Cost / 1K</th>
                  </tr>
                  <tr>
                    <td>Summer Reel Push</td>
                    <td>64.2K</td>
                    <td>9.8K</td>
                    <td>$0.39</td>
                  </tr>
                  <tr>
                    <td>Course Launch Boost</td>
                    <td>41.7K</td>
                    <td>5.1K</td>
                    <td>$1.20</td>
                  </tr>
                  <tr>
                    <td>Ramadan Recipe Series</td>
                    <td>96.5K</td>
                    <td>14.6K</td>
                    <td>$0.26</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
            <div className="panel">
              <h3 style={{ marginBottom: 16 }}>Audience insights</h3>
              <div style={{ display: 'flex', gap: 20, alignItems: 'center' }}>
                <svg width="118" height="118" viewBox="0 0 120 120" role="img" aria-label="Donut chart of traffic sources: organic 46 percent, paid boost 34 percent, shares 20 percent">
                  <circle cx="60" cy="60" r="46" stroke="rgba(255,255,255,.07)" strokeWidth="15" fill="none" />
                  <circle cx="60" cy="60" r="46" stroke="#F95177" strokeWidth="15" fill="none" strokeDasharray="133 289" transform="rotate(-90 60 60)" />
                  <circle cx="60" cy="60" r="46" stroke="#8B5CF6" strokeWidth="15" fill="none" strokeDasharray="98 289" strokeDashoffset="-133" transform="rotate(-90 60 60)" />
                  <circle cx="60" cy="60" r="46" stroke="#0EA5E9" strokeWidth="15" fill="none" strokeDasharray="58 289" strokeDashoffset="-231" transform="rotate(-90 60 60)" />
                </svg>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 9, fontSize: '.88rem' }}>
                  <span>
                    <i style={{ display: 'inline-block', width: 10, height: 10, borderRadius: 3, background: '#F95177', marginRight: 8 }} />
                    Organic · 46%
                  </span>
                  <span>
                    <i style={{ display: 'inline-block', width: 10, height: 10, borderRadius: 3, background: '#8B5CF6', marginRight: 8 }} />
                    Paid Boost · 34%
                  </span>
                  <span>
                    <i style={{ display: 'inline-block', width: 10, height: 10, borderRadius: 3, background: '#0EA5E9', marginRight: 8 }} />
                    Shares · 20%
                  </span>
                </div>
              </div>
              <div style={{ marginTop: 20, display: 'flex', flexDirection: 'column', gap: 11 }}>
                {[
                  ['Pakistan', '34%', 34],
                  ['United Arab Emirates', '21%', 21],
                  ['United Kingdom', '16%', 16],
                  ['United States', '13%', 13],
                ].map(([country, pct, w]) => (
                  <div key={country as string}>
                    <div style={{ display: 'flex', justifyContent: 'space-between' }} className="small">
                      <span>{country}</span>
                      <b>{pct}</b>
                    </div>
                    <div className="progress" style={{ marginTop: 5 }}>
                      <i style={{ width: `${w}%` }} />
                    </div>
                  </div>
                ))}
              </div>
              <p className="mut small" style={{ marginTop: 16 }}>
                Top audience: women 25–34 · most active 7–10 PM PKT · top interest: education &amp; self-growth.
              </p>
            </div>
            <div className="panel">
              <h3 style={{ marginBottom: 6 }}>AI optimization recommendations</h3>
              <div className="rec">
                <span className="rec-ic">
                  <svg viewBox="0 0 24 24">
                    <path d="M13 2L4.5 13.5H11L9.5 22 19 10h-6.5L13 2z" />
                  </svg>
                </span>
                <div>
                  <b style={{ fontSize: '.93rem' }}>Raise Growth package pacing</b>
                  <p className="mut small">Cost per 1K reach dropped to $0.39 — headroom to scale safely.</p>
                </div>
              </div>
              <div className="rec">
                <span className="rec-ic">
                  <svg viewBox="0 0 24 24">
                    <circle cx="12" cy="12" r="9" />
                    <path d="M3 12h18M12 3c2.5 2.5 3.8 5.6 3.8 9s-1.3 6.5-3.8 9c-2.5-2.5-3.8-5.6-3.8-9S9.5 5.5 12 3z" />
                  </svg>
                </span>
                <div>
                  <b style={{ fontSize: '.93rem' }}>Add Canada to targeting</b>
                  <p className="mut small">Matched segments for your niche grew 14% there this month.</p>
                </div>
              </div>
              <div className="rec">
                <span className="rec-ic">
                  <svg viewBox="0 0 24 24">
                    <path d="M8 5v14l11-7z" />
                  </svg>
                </span>
                <div>
                  <b style={{ fontSize: '.93rem' }}>First 2 seconds matter</b>
                  <p className="mut small">Videos with a question in the opening hook retain 41% more viewers.</p>
                </div>
              </div>
            </div>
          </div>
        </div>
        <p className="tiny mut" style={{ marginTop: 20 }}>
          Sample analytics for this website preview. Figures are illustrative estimates, not guarantees.
        </p>
      </section>
    </AppShell>
  );
}
