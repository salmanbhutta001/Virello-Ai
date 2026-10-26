'use client';

/**
 * Mock dashboard preview — static, non-functional (legacy parity).
 * Goal pills toggle .on only (pickGoal), no other effect.
 */

import { useState } from 'react';

const GOALS = ['More Views', 'More Followers', 'More Engagement', 'More Sales'];

export default function MockDashboard() {
  const [goal, setGoal] = useState('More Views');

  return (
    <div className="mock-wrap">
      <div className="mock-glow" />
      <div
        className="mock"
        role="img"
        aria-label="Preview of the Virello creator dashboard with a post URL input, growth goals and performance statistics"
      >
        <div className="mock-bar">
          <span className="dot" style={{ background: '#F87171' }} />
          <span className="dot" style={{ background: '#FBBF24' }} />
          <span className="dot" style={{ background: '#34D399' }} />
          <span className="mock-url">app.virelloai.online/dashboard</span>
        </div>
        <div className="mock-body">
          <div className="mock-side">
            <div className="ms-item on">◆ Dashboard</div>
            <div className="ms-item">▣ Campaigns</div>
            <div className="ms-item">▤ Analytics</div>
            <div className="ms-item">✦ Insights</div>
            <div className="ms-item">◉ Profile</div>
          </div>
          <div className="mock-main">
            <p
              style={{
                fontFamily: 'var(--font-d)',
                fontWeight: 700,
                fontSize: '1.05rem',
              }}
            >
              Good evening, Creator
            </p>
            <p style={{ margin: '8px 0 4px' }}>
              <span className="ai-chip">AI Growth Score · 86/100</span>
            </p>
            <p className="mut small" style={{ margin: '2px 0 18px' }}>
              Your AI manager is watching 3 active campaigns.
            </p>
            <div className="paste-box">
              <span>instagram.com/reel/your-post-link…</span>
              <a className="btn btn-grad btn-sm" href="/dashboard.html">
                LET AI GROW
              </a>
            </div>
            <div className="goal-row">
              {GOALS.map((g) => (
                <button
                  key={g}
                  type="button"
                  className={`goal${goal === g ? ' on' : ''}`}
                  onClick={() => setGoal(g)}
                >
                  {g}
                </button>
              ))}
            </div>
            <div className="stat-grid">
              <div className="stat-cell">
                <span>Total Reach</span>
                <b>128.4K</b>
                <span className="up">↑ 32.5% this week</span>
              </div>
              <div className="stat-cell">
                <span>Engagement</span>
                <b>18.2K</b>
                <span className="up">↑ 18.1% this week</span>
              </div>
              <div className="stat-cell">
                <span>New Followers</span>
                <b>+2,847</b>
                <span className="up">↑ 24.7% this week</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
