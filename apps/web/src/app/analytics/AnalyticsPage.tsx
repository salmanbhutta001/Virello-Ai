'use client';

import { useEffect, useState } from 'react';
import AppShell from '@/components/AppShell';
import { apiAuth } from '@/lib/auth';

// Analytics — real data only (2026-11-16).
//
// GET /api/v1/analytics/overview returns the user's own recorded
// campaign events: { reach, engagement_rate, clicks, conversions }.
// With no data every field is zero — demo numbers are never served.
// No data → empty state (never fake KPIs). Has data → only the four
// real KPIs render; impressions / profile visits / follower growth /
// AI Growth Score have no real source yet, so they are not shown.
// The old hardcoded RANGES (7/30/90-day demo sets), follower chart,
// campaign table, audience donut, country bars and recommendation
// cards were removed: they showed the same fake numbers to every
// user, including brand-new ones with nothing connected.

type Overview = {
  reach: number;
  engagement_rate: number;
  clicks: number;
  conversions: number;
};

export default function AnalyticsPage() {
  const [ov, setOv] = useState<Overview | null>(null);
  const [err, setErr] = useState(false);

  useEffect(() => {
    let live = true;
    apiAuth('/api/v1/analytics/overview')
      .then(async (res) => {
        if (!res.ok) throw new Error(`overview ${res.status}`);
        const j = (await res.json()) as Overview;
        if (live) setOv(j);
      })
      .catch(() => {
        if (live) setErr(true);
      });
    return () => {
      live = false;
    };
  }, []);

  const hasData = !!ov && (ov.reach > 0 || ov.clicks > 0 || ov.conversions > 0);

  return (
    <AppShell active="analytics">
      <section id="page-analytics">
        <div className="app-top">
          <div>
            <h2 className="page-h">Analytics</h2>
            <p className="mut small">Performance across all connected platforms.</p>
          </div>
        </div>
        {ov === null && !err ? (
          <p className="small mut" style={{ marginTop: 20 }}>
            Loading your analytics…
          </p>
        ) : err ? (
          <div className="panel" style={{ marginTop: 20 }}>
            <h3 style={{ marginBottom: 6 }}>Couldn&apos;t load your analytics</h3>
            <p className="mut small" style={{ margin: 0 }}>
              Please refresh the page and try again.
            </p>
          </div>
        ) : !hasData ? (
          <div className="panel" style={{ marginTop: 20 }}>
            <h3 style={{ marginBottom: 6 }}>No analytics yet</h3>
            <p className="mut small" style={{ marginBottom: 14 }}>
              Connect a platform and run your first campaign — your real numbers will
              appear here as soon as there is activity to measure. Nothing here is
              estimated.
            </p>
            <a className="btn btn-pink" href="/profile">
              Connect a platform
            </a>
          </div>
        ) : (
          <>
            <div className="kpi-grid">
              <div className="kpi">
                <span>Reach</span>
                <b id="kReach">{ov.reach.toLocaleString('en-US')}</b>
                <span className="tiny mut">Recorded impressions</span>
              </div>
              <div className="kpi">
                <span>Link Clicks</span>
                <b id="kClick">{ov.clicks.toLocaleString('en-US')}</b>
                <span className="tiny mut">Recorded clicks</span>
              </div>
              <div className="kpi">
                <span>Engagement Rate</span>
                <b>{ov.engagement_rate}%</b>
                <span className="tiny mut">From recorded events</span>
              </div>
              <div className="kpi">
                <span>Conversions</span>
                <b>{ov.conversions.toLocaleString('en-US')}</b>
                <span className="tiny mut">Recorded conversions</span>
              </div>
            </div>
            <p className="tiny mut" style={{ marginTop: 20 }}>
              Detailed breakdowns (followers, audience, countries) are coming soon —
              these totals are your real recorded numbers.
            </p>
          </>
        )}
      </section>
    </AppShell>
  );
}
