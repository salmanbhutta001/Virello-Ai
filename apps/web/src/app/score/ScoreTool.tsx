'use client';

/**
 * Free AI Post Score — legacy parity with standalone score.html:
 * paste text + platform picker → POST /api/v1/public/score {text, platform}
 * → render score ring, breakdown bars, tips, note. No signup.
 * Share button downloads a 1080×1080 score card PNG (canvas, like legacy).
 */

import { useEffect, useRef, useState } from 'react';
import { API_BASE } from '@/lib/api';

const PLATFORMS = [
  { value: 'instagram', label: 'Instagram' },
  { value: 'tiktok', label: 'TikTok' },
  { value: 'youtube', label: 'YouTube' },
  { value: 'x', label: 'X (Twitter)' },
  { value: 'facebook', label: 'Facebook' },
];

const BAR_NAMES: Record<string, string> = {
  hook: 'Hook strength',
  clarity: 'Clarity',
  engagement: 'Engagement potential',
  discoverability: 'Discoverability',
};

type ScoreResult = {
  score: number;
  mode?: string;
  breakdown?: Record<string, number>;
  tips?: string[];
  note?: string;
};

export default function ScoreTool() {
  const [platform, setPlatform] = useState('instagram');
  const [text, setText] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<ScoreResult | null>(null);
  const [displayScore, setDisplayScore] = useState(0);
  const arcRef = useRef<SVGCircleElement>(null);
  const resultRef = useRef<HTMLDivElement>(null);

  // Animate the ring + counter when a result lands.
  useEffect(() => {
    if (!result) return;
    const arc = arcRef.current;
    if (arc) {
      arc.style.transition = 'stroke-dashoffset 1.2s ease';
      requestAnimationFrame(() => {
        arc.style.strokeDashoffset = String(402 - (402 * result.score) / 100);
      });
    }
    let n = 0;
    const t = window.setInterval(() => {
      n += 2;
      if (n >= result.score) {
        n = result.score;
        window.clearInterval(t);
      }
      setDisplayScore(n);
    }, 24);
    document.querySelectorAll<HTMLElement>('.score-bar .fill').forEach((f) => {
      f.style.width = `${f.dataset.v ?? 0}%`;
    });
    resultRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    return () => window.clearInterval(t);
  }, [result]);

  const analyze = async () => {
    const value = text.trim();
    setError(null);
    if (value.length < 10) {
      setError('Please paste at least 10 characters of your draft.');
      return;
    }
    setBusy(true);
    setResult(null);
    try {
      const r = await fetch(`${API_BASE}/public/score`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: value, platform }),
      });
      const d = (await r.json()) as ScoreResult & { detail?: string };
      if (!r.ok) throw new Error(d.detail ?? 'Something went wrong. Please try again.');
      setResult(d);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Something went wrong. Please try again.');
    } finally {
      setBusy(false);
    }
  };

  const share = () => {
    if (!result) return;
    const c = document.createElement('canvas');
    c.width = 1080;
    c.height = 1080;
    const x = c.getContext('2d');
    if (!x) return;
    x.fillStyle = '#0B0B14';
    x.fillRect(0, 0, 1080, 1080);
    const g = x.createLinearGradient(0, 0, 1080, 1080);
    g.addColorStop(0, 'rgba(168,85,247,.16)');
    g.addColorStop(1, 'rgba(59,130,246,.16)');
    x.fillStyle = g;
    x.fillRect(0, 0, 1080, 1080);
    const draw = () => {
      x.textAlign = 'center';
      x.fillStyle = '#EDEDF4';
      x.font = '800 64px Inter, sans-serif';
      x.fillText('Virello AI', 540, 400);
      x.font = '600 40px Inter, sans-serif';
      x.fillStyle = '#a855f7';
      x.fillText('My AI Post Score', 540, 470);
      const gg = x.createLinearGradient(340, 0, 740, 0);
      gg.addColorStop(0, '#a855f7');
      gg.addColorStop(1, '#3b82f6');
      x.fillStyle = gg;
      x.font = '800 230px Inter, sans-serif';
      x.fillText(String(result.score), 540, 720);
      x.fillStyle = '#9a9ab0';
      x.font = '500 34px Inter, sans-serif';
      x.fillText(
        `${platform.charAt(0).toUpperCase()}${platform.slice(1)} post`,
        540,
        790,
      );
      x.fillStyle = '#EDEDF4';
      x.font = '600 36px Inter, sans-serif';
      x.fillText('Score yours free:', 540, 880);
      x.fillStyle = '#3b82f6';
      x.fillText('virelloai.online/score.html', 540, 930);
      const a = document.createElement('a');
      a.download = 'virello-ai-score.png';
      a.href = c.toDataURL('image/png');
      a.click();
    };
    const img = new Image();
    img.crossOrigin = 'anonymous';
    img.onload = draw;
    img.onerror = draw;
    img.src = 'https://virelloai.online/blog-images/favicon.png';
  };

  return (
    <div className="tool-wrap">
      <div className="card tool-card">
        <div className="field">
          <label htmlFor="score-platform">Platform</label>
          <select
            id="score-platform"
            value={platform}
            onChange={(e) => setPlatform(e.target.value)}
            style={{ maxWidth: 280 }}
          >
            {PLATFORMS.map((p) => (
              <option key={p.value} value={p.value}>
                {p.label}
              </option>
            ))}
          </select>
        </div>
        <div className="field">
          <label htmlFor="score-draft">Your post draft</label>
          <textarea
            id="score-draft"
            maxLength={2000}
            value={text}
            onChange={(e) => setText(e.target.value)}
            placeholder="Paste your caption, hook, or full post text here… (min 10 characters)"
            rows={6}
          />
          <p className="small mut" style={{ marginTop: 8 }}>
            {text.length}/2000 characters · Free: 10 scores per hour
          </p>
        </div>
        <button
          type="button"
          className="btn btn-grad"
          onClick={() => void analyze()}
          disabled={busy}
        >
          {busy ? 'Analyzing…' : 'Analyze my post'}
        </button>
        {error && <div className="tool-error">{error}</div>}
        {busy && (
          <p className="mut center" style={{ marginTop: 24 }}>
            🤖 AI is reading your draft…
          </p>
        )}

        {result && (
          <div className="tool-result" ref={resultRef}>
            <div
              style={{
                display: 'flex',
                gap: 24,
                alignItems: 'center',
                flexWrap: 'wrap',
              }}
            >
              <div className="score-ring">
                <svg width="150" height="150">
                  <circle cx="75" cy="75" r="64" fill="none" stroke="#26263a" strokeWidth="12" />
                  <circle
                    ref={arcRef}
                    cx="75"
                    cy="75"
                    r="64"
                    fill="none"
                    stroke="url(#score-g)"
                    strokeWidth="12"
                    strokeLinecap="round"
                    strokeDasharray="402"
                    strokeDashoffset="402"
                  />
                  <defs>
                    <linearGradient id="score-g" x1="0" y1="0" x2="1" y2="1">
                      <stop offset="0" stopColor="#a855f7" />
                      <stop offset="1" stopColor="#3b82f6" />
                    </linearGradient>
                  </defs>
                </svg>
                <div className="num">
                  <b>{displayScore}</b>
                  <span>
                    {result.mode === 'heuristic' ? 'Instant estimate' : 'AI Score'}
                  </span>
                </div>
              </div>
              <div style={{ flex: 1, minWidth: 220 }}>
                {Object.keys(BAR_NAMES).map((k) => {
                  const v = result.breakdown?.[k] ?? 0;
                  return (
                    <div key={k} className="score-bar">
                      <div className="t">
                        <span>{BAR_NAMES[k]}</span>
                        <span>{v}</span>
                      </div>
                      <div className="track">
                        <div className="fill" data-v={v} />
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
            <div style={{ marginTop: 22 }}>
              <h3 style={{ fontSize: 16, marginBottom: 12 }}>
                3 ways to make it stronger
              </h3>
              <ul style={{ listStyle: 'none' }}>
                {(result.tips ?? []).map((t, i) => (
                  <li key={i} className="score-tip">
                    💡 {t}
                  </li>
                ))}
              </ul>
            </div>
            {result.note && (
              <p className="small mut" style={{ marginTop: 16, lineHeight: 1.6 }}>
                {result.note}
              </p>
            )}
            <p className="small mut" style={{ marginTop: 8, lineHeight: 1.6 }}>
              This is an AI estimate of content-quality signals — not a promise
              of virality, reach, or followers.
            </p>
            <div className="tool-actions" style={{ marginTop: 22 }}>
              <button type="button" className="btn btn-ghost" onClick={share}>
                📤 Share my score
              </button>
            </div>
          </div>
        )}
      </div>
      <div className="center" style={{ marginTop: 48, fontSize: 14 }}>
        <p className="mut">
          Want the full AI Growth Manager?{' '}
          <a href="/pricing.html" style={{ color: 'var(--pink)', fontWeight: 600 }}>
            See Virello AI plans →
          </a>
        </p>
        <p style={{ marginTop: 12 }}>
          <a href="/blog.html" style={{ color: 'var(--pink)', fontWeight: 600 }}>
            ← Read the creator playbook
          </a>
        </p>
      </div>
    </div>
  );
}
