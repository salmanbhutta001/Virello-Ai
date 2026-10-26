'use client';

import { useState } from 'react';
import { apiErrorMessage, copyText, creatorApi, notify } from '../../lib/creator';
import { PanelShell, Spinner, errorStyle, inputStyle, rowStyle } from './shared';

/**
 * Distribution Engine — repurpose one post per platform (legacy
 * distributeContent, index.html:3476-3501). POST /api/v1/distribution/
 * repurpose {content, link, platforms[]} via the proxy. Renders one
 * variant per platform with per-variant Copy buttons. Footer note is
 * verbatim legacy copy.
 */

const PLATFORMS = ['instagram', 'tiktok', 'youtube', 'x', 'facebook'];

const PLATFORM_LABELS: Record<string, string> = {
  instagram: 'Instagram',
  tiktok: 'TikTok',
  youtube: 'YouTube',
  x: 'X',
  facebook: 'Facebook',
};

type Variant = { label: string; text: string };

export default function DistributionEngine(props: { onBack: () => void }) {
  const [content, setContent] = useState('');
  const [link, setLink] = useState('');
  const [platforms, setPlatforms] = useState<string[]>([...PLATFORMS]);
  const [variants, setVariants] = useState<Variant[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  function togglePlatform(p: string) {
    setPlatforms((prev) =>
      prev.includes(p) ? prev.filter((x) => x !== p) : [...prev, p],
    );
  }

  async function distribute() {
    const c = content.trim();
    if (c.length < 3) {
      notify('Please write your post first');
      return;
    }
    if (platforms.length === 0) {
      notify('Select at least one platform');
      return;
    }
    setLoading(true);
    setError('');
    setVariants([]);
    try {
      const res = await creatorApi('/api/v1/distribution/repurpose', {
        content: c,
        link: link.trim(),
        platforms,
      });
      if (!res.ok)
        throw new Error(apiErrorMessage(res.data, 'distribution failed'));
      const vs = (res.data as { variants?: Variant[] }).variants ?? [];
      if (vs.length === 0) throw new Error('no variants returned');
      setVariants(vs);
      notify(`Done — ${vs.length} platform versions ready`);
    } catch (e) {
      setError(
        `Could not distribute right now — ${e instanceof Error ? e.message : 'please try again'}. Nothing was posted anywhere. Try again in a moment.`,
      );
    } finally {
      setLoading(false);
    }
  }

  return (
    <PanelShell
      title="Distribution Engine"
      desc="Ek post likho + apna link do — AI har platform ke liye ready version banayega (aapka content, aapke accounts)."
      onBack={props.onBack}
    >
      <textarea
        rows={4}
        value={content}
        onChange={(e) => setContent(e.target.value)}
        placeholder="Paste your post, announcement, or idea here..."
        style={inputStyle}
      />
      <div style={rowStyle}>
        <input
          value={link}
          onChange={(e) => setLink(e.target.value)}
          placeholder="Your link / CTA (e.g. https://virelloai.online) — optional"
          style={{ ...inputStyle, flex: 1, minWidth: 220 }}
        />
      </div>
      <div className="chip-row" style={{ marginTop: 12 }}>
        {PLATFORMS.map((p) => (
          <button
            key={p}
            type="button"
            className={`chip${platforms.includes(p) ? ' active' : ''}`}
            aria-pressed={platforms.includes(p)}
            onClick={() => togglePlatform(p)}
          >
            {PLATFORM_LABELS[p]}
          </button>
        ))}
      </div>
      <div style={rowStyle}>
        <button
          type="button"
          className="btn btn-grad"
          onClick={() => void distribute()}
          disabled={loading}
        >
          {loading ? 'Repurposing…' : 'Repurpose for Platforms'}
        </button>
      </div>

      {loading && (
        <div style={{ marginTop: 14 }}>
          <Spinner />
          <b>Repurposing for {platforms.length} platforms…</b>
        </div>
      )}
      {error !== '' && (
        <div style={errorStyle} role="alert">
          {error}
        </div>
      )}

      {variants.length > 0 && (
        <div style={{ marginTop: 14 }}>
          {variants.map((v, i) => (
            <div
              key={`${v.label}-${i}`}
              style={{
                background: '#F7F8FC',
                border: '1px solid #ECECF1',
                borderRadius: 16,
                padding: 20,
                color: '#374151',
                fontSize: '0.93rem',
                lineHeight: 1.65,
                marginBottom: 12,
              }}
            >
              <b style={{ color: '#111827' }}>{v.label}</b>
              <div style={{ whiteSpace: 'pre-wrap', margin: '8px 0' }}>{v.text}</div>
              <button
                type="button"
                className="btn btn-ghost btn-sm"
                onClick={() =>
                  void copyText(v.text).then((ok) =>
                    notify(ok ? 'Copied to clipboard' : 'Copy failed — select the text manually'),
                  )
                }
              >
                Copy {v.label}
              </button>
            </div>
          ))}
          <p className="tiny mut">
            Post these from your own connected accounts. Virello never posts
            for you and never fakes engagement.
          </p>
        </div>
      )}
    </PanelShell>
  );
}
