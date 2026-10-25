'use client';

import { useState } from 'react';

/**
 * Free AI Caption + Hashtag Generator (client island).
 *
 * Generation runs through the site's own free AI proxy — the same
 * ai-proxy.php the Creator Hub tools already use (Pollinations, no key,
 * no paid service). The page is a static export, so the proxy is called
 * on the live origin: relative `ai-proxy.php?p=...` first, with an
 * absolute virelloai.online fallback if the relative call cannot reach it.
 */

type Platform = 'instagram' | 'tiktok' | 'x';
type Tone = 'friendly' | 'professional' | 'playful';

const PLATFORMS: {
  id: Platform;
  label: string;
  hint: string;
  tagNote: string;
}[] = [
  {
    id: 'instagram',
    label: 'Instagram',
    hint: 'Give 8 to 12 hashtags.',
    tagNote: 'Instagram works well with 8–12 hashtags.',
  },
  {
    id: 'tiktok',
    label: 'TikTok',
    hint: 'Keep the caption short and punchy, give 3 to 5 hashtags.',
    tagNote: 'TikTok works best with 3–5 hashtags.',
  },
  {
    id: 'x',
    label: 'X',
    hint: 'Keep the whole caption under 200 characters, give 3 to 5 hashtags.',
    tagNote: 'X posts must stay under 280 characters in total.',
  },
];

const TONES: { id: Tone; label: string }[] = [
  { id: 'friendly', label: 'Friendly' },
  { id: 'professional', label: 'Professional' },
  { id: 'playful', label: 'Playful' },
];

type CaptionResult = {
  hook: string;
  caption: string;
  hashtags: string[];
};

const PROXY_PATH = '/api/v1/media/generate-caption';

async function callCaptionProxy(topic: string): Promise<CaptionResult> {
  const urls = [
    `ai-proxy.php?p=${encodeURIComponent(PROXY_PATH)}`,
    `https://virelloai.online/ai-proxy.php?p=${encodeURIComponent(PROXY_PATH)}`,
  ];
  let lastError = '';
  for (const url of urls) {
    try {
      const res = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ topic }),
      });
      const data = (await res.json().catch(() => null)) as {
        hook?: string;
        caption?: string;
        hashtags?: string[];
        detail?: string;
      } | null;
      if (!res.ok) {
        throw new Error(
          (data && data.detail) ||
            'The AI writer could not be reached — please try again.',
        );
      }
      if (!data || typeof data.caption !== 'string' || data.caption.trim() === '') {
        throw new Error('The AI writer returned an empty caption — please try again.');
      }
      return {
        hook: typeof data.hook === 'string' ? data.hook : '',
        caption: data.caption,
        hashtags: Array.isArray(data.hashtags)
          ? data.hashtags.map((h) => String(h).replace(/^#+/, '').trim()).filter(Boolean)
          : [],
      };
    } catch (e) {
      lastError =
        e instanceof Error ? e.message : 'Could not reach the AI writer.';
      // A failed relative call may just mean the page is previewed off-origin;
      // fall through to the absolute URL. Any other failure is final.
      if (url === urls[urls.length - 1]) throw new Error(lastError);
    }
  }
  throw new Error(lastError || 'Could not reach the AI writer.');
}

async function copyText(text: string): Promise<boolean> {
  try {
    await navigator.clipboard.writeText(text);
    return true;
  } catch {
    try {
      const ta = document.createElement('textarea');
      ta.value = text;
      ta.style.position = 'fixed';
      ta.style.opacity = '0';
      document.body.appendChild(ta);
      ta.select();
      document.execCommand('copy');
      document.body.removeChild(ta);
      return true;
    } catch {
      return false;
    }
  }
}

export default function CaptionTool() {
  const [topic, setTopic] = useState('');
  const [keywords, setKeywords] = useState('');
  const [platform, setPlatform] = useState<Platform>('instagram');
  const [tone, setTone] = useState<Tone>('friendly');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [result, setResult] = useState<CaptionResult | null>(null);
  const [copied, setCopied] = useState('');

  const platformMeta = PLATFORMS.find((p) => p.id === platform) as (typeof PLATFORMS)[number];
  const toneLabel = (TONES.find((t) => t.id === tone) as (typeof TONES)[number]).label;

  const fullText = result
    ? `${result.hook ? result.hook + '\n\n' : ''}${result.caption}${
        result.hashtags.length ? '\n\n' + result.hashtags.map((h) => `#${h}`).join(' ') : ''
      }`
    : '';
  const xCount = fullText.length;

  async function generate() {
    const cleanTopic = topic.trim();
    if (cleanTopic.length < 3) {
      setError('Please describe your post in a few words first.');
      return;
    }
    setLoading(true);
    setError('');
    setResult(null);
    setCopied('');
    const prompt =
      `${cleanTopic}` +
      (keywords.trim() ? ` Keywords to include: ${keywords.trim()}.` : '') +
      ` — Write it for ${platformMeta.label}, ${toneLabel.toLowerCase()} tone. ${platformMeta.hint}`;
    try {
      const out = await callCaptionProxy(prompt);
      setResult(out);
    } catch (e) {
      setError(
        e instanceof Error
          ? e.message
          : 'Something went wrong — please check your connection and try again.',
      );
    } finally {
      setLoading(false);
    }
  }

  async function handleCopy(what: 'caption' | 'tags' | 'all', text: string) {
    const ok = await copyText(text);
    setCopied(ok ? what : 'failed');
    if (ok) window.setTimeout(() => setCopied(''), 2000);
  }

  return (
    <div className="tool-wrap">
      <div className="card tool-card">
        <div className="field">
          <label htmlFor="tool-topic">What is your post about?</label>
          <textarea
            id="tool-topic"
            rows={3}
            value={topic}
            onChange={(e) => setTopic(e.target.value)}
            placeholder="e.g. My new handmade ceramic mugs, fresh out of the kiln"
            maxLength={500}
          />
        </div>

        <div className="field">
          <label htmlFor="tool-keywords">
            Keywords to include <span className="mut">(optional)</span>
          </label>
          <input
            id="tool-keywords"
            type="text"
            value={keywords}
            onChange={(e) => setKeywords(e.target.value)}
            placeholder="e.g. handmade, small batch, coffee lover"
            maxLength={200}
          />
        </div>

        <div className="field">
          <label>Platform</label>
          <div className="chip-row" role="group" aria-label="Platform">
            {PLATFORMS.map((p) => (
              <button
                key={p.id}
                type="button"
                className={`chip${platform === p.id ? ' active' : ''}`}
                onClick={() => setPlatform(p.id)}
                aria-pressed={platform === p.id}
              >
                {p.label}
              </button>
            ))}
          </div>
          <p className="small mut" style={{ marginTop: 8 }}>{platformMeta.tagNote}</p>
        </div>

        <div className="field">
          <label>Tone</label>
          <div className="chip-row" role="group" aria-label="Tone">
            {TONES.map((t) => (
              <button
                key={t.id}
                type="button"
                className={`chip${tone === t.id ? ' active' : ''}`}
                onClick={() => setTone(t.id)}
                aria-pressed={tone === t.id}
              >
                {t.label}
              </button>
            ))}
          </div>
        </div>

        <button
          type="button"
          className="btn btn-grad"
          onClick={generate}
          disabled={loading || topic.trim().length < 3}
          style={{ width: '100%' }}
        >
          {loading ? 'Writing your caption…' : 'Generate Caption — Free'}
        </button>
        <p className="small mut center" style={{ marginTop: 10 }}>
          Free to try — no signup, no card. A fair-use limit keeps the free
          tool up for everyone.
        </p>

        {error !== '' && (
          <div className="tool-error" role="alert">
            {error}
          </div>
        )}

        {result && (
          <div className="tool-result">
            {result.hook !== '' && (
              <p className="result-hook">{result.hook}</p>
            )}
            <p className="result-caption">{result.caption}</p>
            {result.hashtags.length > 0 && (
              <div className="tag-list">
                {result.hashtags.map((h) => (
                  <span key={h} className="tag">#{h}</span>
                ))}
              </div>
            )}
            {platform === 'x' && (
              <p className={`small char-count${xCount > 280 ? ' over' : ''}`}>
                {xCount} / 280 characters
                {xCount > 280
                  ? ' — over the X limit, copy the caption without some hashtags.'
                  : ' — fits X.'}
              </p>
            )}
            <div className="tool-actions">
              <button
                type="button"
                className="btn btn-ghost btn-sm"
                onClick={() => handleCopy('caption', result.caption)}
              >
                {copied === 'caption' ? 'Copied ✓' : 'Copy caption'}
              </button>
              {result.hashtags.length > 0 && (
                <button
                  type="button"
                  className="btn btn-ghost btn-sm"
                  onClick={() =>
                    handleCopy('tags', result.hashtags.map((h) => `#${h}`).join(' '))
                  }
                >
                  {copied === 'tags' ? 'Copied ✓' : 'Copy hashtags'}
                </button>
              )}
              <button
                type="button"
                className="btn btn-ghost btn-sm"
                onClick={() => handleCopy('all', fullText)}
              >
                {copied === 'all' ? 'Copied ✓' : 'Copy everything'}
              </button>
              <button
                type="button"
                className="btn btn-ghost btn-sm"
                onClick={generate}
                disabled={loading}
              >
                Generate again
              </button>
            </div>
            {copied === 'failed' && (
              <p className="small" style={{ color: 'var(--warn)', marginTop: 8 }}>
                Copy did not work in this browser — select the text and copy it manually.
              </p>
            )}
            <p className="small mut" style={{ marginTop: 12 }}>
              AI-written — give it a quick read before posting. Virello never
              promises viral reach or fake engagement.
            </p>
          </div>
        )}
      </div>
    </div>
  );
}
