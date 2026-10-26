'use client';

import { useState } from 'react';
import { apiErrorMessage, copyText, creatorApi, notify } from '../../lib/creator';
import { PanelShell, Spinner, errorStyle, inputStyle, outStyle, rowStyle } from './shared';

/**
 * Script Writer / Story Writer / Content Converter — one component, three
 * kinds (legacy genTextTool, index.html:3455-3474):
 * POST /api/v1/media/generate-text {kind, prompt, niche? / format?}
 * (via proxy). Story supports length + language (incl. Urdu) — the
 * language is folded into `format` as "{len} urdu" exactly like legacy.
 * Output in the kind's output box with a copy action. Failure: inline
 * error + "Nothing fake was created."
 */

export type TextKind = 'script' | 'story' | 'convert';

const META: Record<TextKind, { title: string; desc: string; btn: string; copy: string }> = {
  script: {
    title: 'Script Writer',
    desc: 'Topic likho — AI poora video script likhega: hook, timed beats, CTA.',
    btn: 'Write Script',
    copy: 'Copy Script',
  },
  story: {
    title: 'Story Writer',
    desc: 'Koi topic do — AI mukammal kahani likhega, aapki length aur language mein.',
    btn: 'Write Story',
    copy: 'Copy Story',
  },
  convert: {
    title: 'Content Converter',
    desc: 'Koi bhi text paste karo — AI usay video script, carousel, thread ya story caption mein badal dega.',
    btn: 'Convert',
    copy: 'Copy Result',
  },
};

const NICHES = ['', 'Food', 'Fitness', 'Fashion', 'Tech', 'Business', 'Education', 'Travel'];

const CONVERT_FORMATS = ['Video Script', 'Carousel', 'Thread', 'Story Caption'];

export default function TextTools(props: { kind: TextKind; onBack: () => void }) {
  const { kind, onBack } = props;
  const meta = META[kind];
  const [prompt, setPrompt] = useState('');
  const [niche, setNiche] = useState('');
  const [storyLen, setStoryLen] = useState('medium');
  const [storyLang, setStoryLang] = useState('English');
  const [convertFmt, setConvertFmt] = useState('Video Script');
  const [out, setOut] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  async function generate() {
    const p = prompt.trim();
    if (p.length < 3) {
      notify('Please write a little more first');
      return;
    }
    setLoading(true);
    setError('');
    setOut('');
    const body: Record<string, string> = { kind, prompt: p };
    if (kind === 'script') body.niche = niche;
    if (kind === 'story')
      body.format = storyLen + (storyLang === 'Urdu' ? ' urdu' : '');
    if (kind === 'convert') body.format = convertFmt;
    try {
      const res = await creatorApi('/api/v1/media/generate-text', body);
      if (!res.ok)
        throw new Error(apiErrorMessage(res.data, 'generation failed'));
      setOut(String((res.data as { text?: unknown }).text ?? ''));
      notify('Done — ready to copy');
    } catch (e) {
      setError(
        `Could not generate right now — ${e instanceof Error ? e.message : 'please try again'}. Nothing fake was created. Try again in a moment.`,
      );
    } finally {
      setLoading(false);
    }
  }

  return (
    <PanelShell title={meta.title} desc={meta.desc} onBack={onBack}>
      {kind === 'convert' ? (
        <textarea
          rows={4}
          value={prompt}
          onChange={(e) => setPrompt(e.target.value)}
          placeholder="Paste your text, blog paragraph, or rough idea here..."
          style={inputStyle}
        />
      ) : (
        <div style={rowStyle}>
          <input
            value={prompt}
            onChange={(e) => setPrompt(e.target.value)}
            placeholder={
              kind === 'script'
                ? 'e.g. 5-minute chai recipe for hostel students'
                : 'e.g. A small shopkeeper who never gave up'
            }
            style={{ ...inputStyle, flex: 1, minWidth: 220 }}
          />
          {kind === 'script' && (
            <select
              value={niche}
              onChange={(e) => setNiche(e.target.value)}
              style={{ ...inputStyle, width: 'auto' }}
              aria-label="Niche (optional)"
            >
              <option value="">Niche (optional)</option>
              {NICHES.filter(Boolean).map((n) => (
                <option key={n} value={n}>
                  {n}
                </option>
              ))}
            </select>
          )}
          {kind === 'story' && (
            <>
              <select
                value={storyLen}
                onChange={(e) => setStoryLen(e.target.value)}
                style={{ ...inputStyle, width: 'auto' }}
                aria-label="Story length"
              >
                <option value="short">Short (~120 words)</option>
                <option value="medium">Medium (~300 words)</option>
                <option value="long">Long (~600 words)</option>
              </select>
              <select
                value={storyLang}
                onChange={(e) => setStoryLang(e.target.value)}
                style={{ ...inputStyle, width: 'auto' }}
                aria-label="Story language"
              >
                <option value="English">English</option>
                <option value="Urdu">Urdu</option>
              </select>
            </>
          )}
        </div>
      )}

      {kind === 'convert' && (
        <div className="chip-row" style={{ marginTop: 12 }}>
          {CONVERT_FORMATS.map((f) => (
            <button
              key={f}
              type="button"
              className={`chip${convertFmt === f ? ' active' : ''}`}
              aria-pressed={convertFmt === f}
              onClick={() => setConvertFmt(f)}
            >
              {f}
            </button>
          ))}
        </div>
      )}

      <div style={rowStyle}>
        <button
          type="button"
          className="btn btn-grad"
          onClick={() => void generate()}
          disabled={loading}
        >
          {loading ? 'Writing…' : meta.btn}
        </button>
      </div>

      {loading && (
        <div style={{ marginTop: 14 }}>
          <Spinner />
          <b>Writing with AI…</b>
        </div>
      )}

      {error !== '' && (
        <div style={errorStyle} role="alert">
          {error}
        </div>
      )}

      {out !== '' && (
        <>
          <div style={outStyle}>{out}</div>
          <div style={rowStyle}>
            <button
              type="button"
              className="btn btn-ghost btn-sm"
              onClick={() =>
                void copyText(out).then((ok) =>
                  notify(ok ? 'Copied to clipboard' : 'Copy failed — select the text manually'),
                )
              }
            >
              {meta.copy}
            </button>
          </div>
        </>
      )}
    </PanelShell>
  );
}
