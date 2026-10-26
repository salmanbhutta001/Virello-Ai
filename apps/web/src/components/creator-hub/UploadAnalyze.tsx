'use client';

import { useState } from 'react';
import { notify } from '../../lib/creator';
import { PanelShell, Spinner, inputStyle, rowStyle } from './shared';

/**
 * Upload & Analyze — fully client-side honest readiness report (legacy
 * analyzePhoto, index.html:3722-3758). Reads dimensions/file size from
 * the image, produces a computed score. NO API call. Scoring ported
 * verbatim: base 50, +10 caption, +8 for 1–8 hashtags, −5 for >8,
 * +8 for ≥2 MP, −8 for <0.5 MP, clamped 5–98.
 */

type Check = { ok: boolean | null; label: string; detail: string };

export default function UploadAnalyze(props: { onBack: () => void }) {
  const [file, setFile] = useState<File | null>(null);
  const [caption, setCaption] = useState('');
  const [busy, setBusy] = useState(false);
  const [score, setScore] = useState<number | null>(null);
  const [checks, setChecks] = useState<Check[]>([]);
  const [error, setError] = useState('');

  function onFile(f: File | undefined) {
    if (!f) return;
    setFile(f);
    setScore(null);
    setChecks([]);
    setError('');
  }

  function analyze() {
    if (!file) {
      notify('Choose a photo first');
      return;
    }
    const f = file;
    const cap = caption.trim();
    setBusy(true);
    setError('');
    const url = URL.createObjectURL(f);
    const img = new Image();
    img.onload = () => {
      const w = img.naturalWidth;
      const h = img.naturalHeight;
      const mp = (w * h) / 1e6;
      const kb = Math.round(f.size / 1024);
      const list: Check[] = [];
      let s = 50;
      const add = (ok: boolean | null, label: string, detail: string, pts?: number) => {
        list.push({ ok, label, detail });
        if (pts) s += pts;
      };
      if (cap)
        add(true, 'Caption added', `${cap.length} characters — captions lift engagement.`, 10);
      else
        add(false, 'No caption', 'Add a caption so the AI can match this to the right audience.', 0);
      const tags = cap.match(/#\w+/g) || [];
      if (tags.length >= 1 && tags.length <= 8)
        add(true, `${tags.length} hashtag(s)`, 'Good range — discoverable without looking spammy.', 8);
      else if (tags.length > 8)
        add(false, `${tags.length} hashtags`, 'More than 8 looks spammy — keep the best 3–5.', -5);
      else add(null, 'No hashtags', '2–4 relevant hashtags help discovery.', 0);
      if (cap && cap.length < 20)
        add(null, 'Short caption', 'One more line about who this is for helps.', 0);
      if (mp >= 2) add(true, `High resolution (${w}×${h})`, 'Sharp on all screens.', 8);
      else if (mp >= 0.5)
        add(null, `Medium resolution (${w}×${h})`, 'Fine for feeds; 1080px+ wide is ideal.', 0);
      else
        add(false, `Low resolution (${w}×${h})`, 'May look blurry fullscreen — use a sharper photo.', -8);
      const ar = w / h;
      const arLabel = ar > 1.2 ? 'Landscape' : ar < 0.8 ? 'Portrait' : 'Square';
      add(
        ar >= 0.8 && ar <= 1.0 ? true : null,
        `Aspect: ${arLabel} (${w}:${h})`,
        ar >= 0.8 && ar <= 1.0
          ? '4:5 portrait gets the most feed space.'
          : 'Portrait 4:5 usually performs best in feed.',
        0,
      );
      if (kb > 8000)
        add(null, `Heavy file (${(kb / 1024).toFixed(1)} MB)`, 'Compress before uploading for faster loads.', 0);
      s = Math.max(5, Math.min(98, Math.round(s)));
      setScore(s);
      setChecks(list);
      setBusy(false);
      URL.revokeObjectURL(url);
    };
    img.onerror = () => {
      setError('Could not read that photo.');
      setBusy(false);
      URL.revokeObjectURL(url);
    };
    img.src = url;
  }

  return (
    <PanelShell
      title="Upload & Analyze"
      desc="Photo upload karo + caption likho — posting se pehle honest readiness report."
      onBack={props.onBack}
    >
      <div style={rowStyle}>
        <label className="btn btn-ghost btn-sm" style={{ cursor: 'pointer' }}>
          Choose Photo
          <input
            type="file"
            accept="image/*"
            style={{ display: 'none' }}
            onChange={(e) => onFile(e.target.files?.[0])}
          />
        </label>
        <input
          value={caption}
          onChange={(e) => setCaption(e.target.value)}
          placeholder="Your caption (optional)..."
          style={{ ...inputStyle, flex: 1, minWidth: 220 }}
        />
      </div>
      <div style={rowStyle}>
        <button
          type="button"
          className="btn btn-grad btn-sm"
          onClick={analyze}
          disabled={busy}
        >
          Analyze
        </button>
      </div>

      {busy && (
        <div style={{ marginTop: 14 }}>
          <Spinner />
          <b style={{ color: 'var(--txt)' }}>Analyzing…</b>
        </div>
      )}
      {error !== '' && (
        <div style={{ marginTop: 14 }}>
          <b>{error}</b>
        </div>
      )}

      {score !== null && (
        <div style={{ marginTop: 14 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 14, marginBottom: 8 }}>
            <div
              style={{
                width: 64,
                height: 64,
                borderRadius: '50%',
                background: `conic-gradient(#F95177 ${score * 3.6}deg,#EDEEF3 0)`,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <b
                style={{
                  background: '#fff',
                  width: 50,
                  height: 50,
                  borderRadius: '50%',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  color: '#111827',
                }}
              >
                {score}
              </b>
            </div>
            <div>
              <b>Readiness score</b>
              <p className="tiny mut" style={{ margin: '2px 0 0' }}>
                Heuristic estimate from your file + caption — not a guarantee.
              </p>
            </div>
          </div>
          {checks.map((c) => {
            const col = c.ok === true ? '#10B981' : c.ok === false ? '#EF4444' : '#F59E0B';
            const ch = c.ok === true ? '✓' : c.ok === false ? '✕' : '•';
            return (
              <div
                key={c.label}
                style={{ display: 'flex', gap: 10, alignItems: 'flex-start', marginTop: 10 }}
              >
                <span
                  style={{
                    background: col,
                    color: '#fff',
                    width: 22,
                    height: 22,
                    borderRadius: '50%',
                    display: 'inline-flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontSize: 12,
                    flex: 'none',
                  }}
                >
                  {ch}
                </span>
                <div>
                  <b>{c.label}</b>
                  <br />
                  <span className="mut small">{c.detail}</span>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </PanelShell>
  );
}
