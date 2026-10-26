'use client';

import { useRef, useState } from 'react';
import {
  apiErrorMessage,
  assembleVideoUrl,
  copyText,
  creatorApi,
  downloadText,
  downloadUrl,
  draftKindLabel,
  notify,
} from '../../lib/creator';
import type { Draft } from '../../lib/creator';
import { Spinner, errorStyle, inputStyle, rowStyle } from './shared';

/**
 * The shared generation workspace: 3 main tools (image / video / caption)
 * + the in-memory drafts list. Legacy parity (inventory §12.1a,
 * index.html:3255-3400):
 * - image: POST /api/v1/media/generate-image {prompt, aspect} → image +
 *   provider/model/dimensions caption + Download / Regenerate /
 *   "Grow this post" (loads a fake instagram.com/p/virello-draft-{n}/
 *   URL into the dashboard Grow box, #growUrl, when it is on the page).
 * - video: 4 SEQUENTIAL generate-image calls (9:16 storyboard frames
 *   HOOK / STEP 1 / STEP 2 / RESULT+CTA) → grid + Download script (.txt)
 *   + "Create MP4 Video (free)" via POST /api/v1/media/assemble-video
 *   JSON {image_urls, captions, seconds_per_scene:5}.
 * - caption: POST /api/v1/media/generate-caption {topic} → hook +
 *   caption + hashtags, Copy / Another version.
 * - Generate with an empty prompt uses the current tool's first idea
 *   (legacy: value.trim() || ideas[0]).
 * - Failures show an inline error + "No placeholder was created" — never
 *   fake content.
 */

export type MainTool = 'image' | 'video' | 'caption';

export const CREATOR_TOOLS: Record<
  MainTool,
  { title: string; desc: string; btn: string; ideas: string[] }
> = {
  image: {
    title: 'AI Image Studio',
    desc: 'Describe the image you want. The AI will generate a concept you can post or refine.',
    btn: 'Generate',
    ideas: [
      'Bright flat-lay of skincare products on a pink background, morning light',
      'Cozy home office desk setup with laptop and coffee, warm sunlight',
      'Vibrant street food stall at night in Lahore, steam rising, cinematic',
    ],
  },
  video: {
    title: 'AI Video Creator',
    desc: 'Describe your video idea — the AI builds a 4-scene vertical storyboard with script, audio and posting cues.',
    btn: 'Generate Storyboard',
    ideas: [
      '5-minute chai recipe for hostel students',
      'Morning skincare routine for oily skin',
      'Small business packaging orders ASMR',
    ],
  },
  caption: {
    title: 'Caption & Hook Writer',
    desc: 'Give a topic — the AI writes a scroll-stopping hook, full caption and hashtag set.',
    btn: 'Write Caption',
    ideas: [
      '5-minute chai recipe for hostel students',
      'Why your reels get no views',
      'New skincare launch announcement',
    ],
  },
};

type Aspect = '4:5' | '9:16' | '1:1';

const FORMATS: { id: Aspect; label: string }[] = [
  { id: '4:5', label: 'Post · 4:5' },
  { id: '9:16', label: 'Story · 9:16' },
  { id: '1:1', label: 'Square · 1:1' },
];

/** The 4 fixed storyboard scenes (legacy genCreatorVideo). */
const SCENES = [
  {
    t: '0-3s · HOOK',
    txt: 'Open on the end result first.',
    dir: 'extreme close-up of the final result, dramatic lighting',
  },
  {
    t: '3-9s · STEP 1',
    txt: 'Fast cut — first step in close-up, captions burned in.',
    dir: 'close-up of hands doing the first step, bright natural light',
  },
  {
    t: '9-15s · STEP 2',
    txt: 'The step everyone skips — slow zoom, beat drop on the reveal.',
    dir: 'slow zoom on the key moment, cinematic',
  },
  {
    t: '15-20s · RESULT + CTA',
    txt: 'Final result reveal. CTA: Save this for tonight!',
    dir: 'wide hero shot of the final result, vibrant',
  },
];

type ImageResult = {
  url: string;
  width?: number;
  height?: number;
  provider?: string;
  model?: string;
};

type VideoResult = { thumbs: string[]; script: string };

type CaptionResult = { hook: string; caption: string; hashtags: string[] };

function errText(e: unknown): string {
  return e instanceof Error ? e.message : 'please try again';
}

export default function Workspace(props: {
  tool: MainTool;
  drafts: Draft[];
  onAddDraft: (d: Draft) => void;
  onDeleteDraft: (i: number) => void;
}) {
  const { tool, drafts, onAddDraft, onDeleteDraft } = props;
  const meta = CREATOR_TOOLS[tool];
  const [prompt, setPrompt] = useState('');
  const [fmt, setFmt] = useState<Aspect>('4:5');
  const [loading, setLoading] = useState('');
  const [error, setError] = useState('');
  const [image, setImage] = useState<ImageResult | null>(null);
  const [imagePrompt, setImagePrompt] = useState('');
  const [video, setVideo] = useState<VideoResult | null>(null);
  const [caption, setCaption] = useState<CaptionResult | null>(null);
  const [captionFull, setCaptionFull] = useState('');
  const [captionProvider, setCaptionProvider] = useState('');
  const [mp4Url, setMp4Url] = useState('');
  const [mp4Busy, setMp4Busy] = useState(false);
  const genSeed = useRef(0);

  function resetResult() {
    setError('');
    setImage(null);
    setVideo(null);
    setCaption(null);
    setMp4Url('');
  }

  async function genImage(p: string) {
    setLoading('Generating your image…');
    try {
      const res = await creatorApi('/api/v1/media/generate-image', {
        prompt: p,
        aspect: fmt,
      });
      if (!res.ok)
        throw new Error(apiErrorMessage(res.data, 'generation failed'));
      const d = res.data as {
        image_url?: string;
        width?: number;
        height?: number;
        provider?: string;
        model?: string;
      };
      genSeed.current += 1;
      setImage({
        url: d.image_url ?? '',
        width: d.width,
        height: d.height,
        provider: d.provider,
        model: d.model,
      });
      setImagePrompt(p);
      onAddDraft({ type: 'image', title: p, thumb: d.image_url ?? '', text: '' });
      notify('Image generated — saved to your drafts below');
    } catch (e) {
      setError(
        `Image generation failed right now — ${errText(e)}. No placeholder was created. Tap Generate again in a moment.`,
      );
    } finally {
      setLoading('');
    }
  }

  async function genVideo(p: string) {
    setLoading('Generating your 4 storyboard frames…');
    try {
      const thumbs: string[] = [];
      for (let idx = 0; idx < SCENES.length; idx++) {
        const sc = SCENES[idx];
        setLoading(`Generating frame ${idx + 1} of 4…`);
        const res = await creatorApi('/api/v1/media/generate-image', {
          prompt: `${p}, ${sc.dir}, vertical cinematic still, no text`,
          aspect: '9:16',
        });
        if (!res.ok)
          throw new Error(apiErrorMessage(res.data, 'frame generation failed'));
        thumbs.push((res.data as { image_url?: string }).image_url ?? '');
      }
      const script =
        'VIRELLO AI — VIDEO SCRIPT\nIdea: ' +
        p +
        '\nFormat: 20s vertical (9:16)\n\n' +
        SCENES.map(
          (sc, i) => `${sc.t}\n${sc.txt}\nFrame: ${thumbs[i]}`,
        ).join('\n\n');
      setVideo({ thumbs, script });
      onAddDraft({ type: 'video', title: p, thumb: thumbs[0] ?? '', text: script });
      notify('Storyboard generated — saved to your drafts below');
    } catch (e) {
      setError(
        `Storyboard frames failed — ${errText(e)}. No placeholder was created. Tap Generate again in a moment.`,
      );
    } finally {
      setLoading('');
    }
  }

  async function genCaption(p: string) {
    setLoading('Writing your hook & caption…');
    try {
      const res = await creatorApi('/api/v1/media/generate-caption', {
        topic: p,
      });
      if (!res.ok) {
        throw new Error(
          res.res.status === 503
            ? 'AI writer is warming up — please try again in a bit.'
            : apiErrorMessage(res.data, 'caption generation failed'),
        );
      }
      const d = res.data as {
        hook?: string;
        caption?: string;
        hashtags?: string[];
        provider?: string;
      };
      const hook = d.hook ?? '';
      const cap = d.caption ?? '';
      const tags = (d.hashtags ?? []).map((h) => `#${h}`).join(' ');
      const full = `Hook: ${hook}\n\nCaption: ${cap}\n\nHashtags: ${tags}`;
      setCaption({ hook, caption: cap, hashtags: d.hashtags ?? [] });
      setCaptionFull(full);
      setCaptionProvider(d.provider ?? 'ai');
      onAddDraft({ type: 'caption', title: p, thumb: '', text: full });
      notify('Caption generated — saved to your drafts below');
    } catch (e) {
      setError(
        `${errText(e) || 'Caption writing failed — please try again'}. No placeholder text was created.`,
      );
    } finally {
      setLoading('');
    }
  }

  function generate() {
    const p = prompt.trim() || meta.ideas[0];
    resetResult();
    if (tool === 'image') void genImage(p);
    else if (tool === 'video') void genVideo(p);
    else void genCaption(p);
  }

  function giveIdea() {
    const ideas = meta.ideas;
    setPrompt(ideas[Math.floor(Math.random() * ideas.length)]);
    notify('Idea loaded — tap Generate');
  }

  /** Legacy "Grow this post": load a fake draft URL into the Grow box. */
  function growThisPost() {
    const url = `https://www.instagram.com/p/virello-draft-${genSeed.current}/`;
    const input = document.getElementById('growUrl') as HTMLInputElement | null;
    if (input) {
      input.value = url;
      input.focus();
      notify('Draft loaded in the Grow box — hit LET AI GROW');
    } else {
      // The Hub is mounted on the dashboard, so the Grow box is normally
      // present; if P3's dashboard is not rendering it yet, copy the URL.
      void copyText(url).then(() =>
        notify('Grow box is not on this page — draft link copied instead'),
      );
    }
  }

  async function storyboardToMp4() {
    if (!video) return;
    setMp4Busy(true);
    try {
      const res = await fetch(assembleVideoUrl(), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          image_urls: video.thumbs,
          captions: SCENES.map((s) => s.t),
          seconds_per_scene: 5,
        }),
      });
      if (!res.ok) {
        const j: unknown = await res.json().catch(() => ({}));
        throw new Error(apiErrorMessage(j, 'assembly failed'));
      }
      const blob = await res.blob();
      setMp4Url(URL.createObjectURL(blob));
      notify('Your AI video is ready');
    } catch (e) {
      notify(`MP4 failed: ${errText(e) || 'try again'}`);
    } finally {
      setMp4Busy(false);
    }
  }

  function draftAct(i: number) {
    const d = drafts[i];
    if (!d) return;
    if (d.type === 'caption') {
      void copyText(d.text).then((ok) =>
        notify(ok ? 'Caption copied' : 'Copy failed — select the text manually'),
      );
    } else if (d.type === 'video') {
      downloadText(d.text, 'virello-video-script.txt');
      notify('Storyboard script downloaded');
    } else {
      downloadUrl(d.thumb, 'virello-image.png');
      notify('Image downloading');
    }
  }

  return (
    <div
      style={{
        background: 'var(--surface)',
        border: '1px solid var(--line)',
        borderRadius: 16,
        padding: 22,
        marginTop: 18,
      }}
    >
      <h3 style={{ margin: '0 0 6px' }}>{meta.title}</h3>
      <p style={{ margin: '0 0 16px', color: 'var(--mut)', fontSize: '0.9rem' }}>
        {meta.desc}
      </p>
      <textarea
        aria-label="Prompt"
        rows={3}
        value={prompt}
        onChange={(e) => setPrompt(e.target.value)}
        placeholder="e.g. Bright flat-lay of skincare products on a pink background, morning light..."
        style={{ ...inputStyle, resize: 'vertical' }}
      />
      {tool === 'image' && (
        <div className="chip-row" style={{ marginTop: 12 }}>
          {FORMATS.map((f) => (
            <button
              key={f.id}
              type="button"
              className={`chip${fmt === f.id ? ' active' : ''}`}
              aria-pressed={fmt === f.id}
              onClick={() => setFmt(f.id)}
            >
              {f.label}
            </button>
          ))}
        </div>
      )}
      <div style={rowStyle}>
        <button
          type="button"
          className="btn btn-grad"
          onClick={generate}
          disabled={loading !== ''}
        >
          {loading !== '' ? 'Working…' : meta.btn}
        </button>
        <button type="button" className="btn btn-ghost" onClick={giveIdea}>
          Give me an idea
        </button>
      </div>

      {loading !== '' && (
        <div style={{ marginTop: 18 }}>
          <Spinner />
          <b style={{ color: 'var(--txt)' }}>{loading}</b>
          <p style={{ margin: '8px 0 0', fontSize: '0.85rem' }}>
            Real AI generation — this takes a few seconds…
          </p>
        </div>
      )}

      {error !== '' && (
        <div style={errorStyle} role="alert">
          {error}
        </div>
      )}

      {image && (
        <div style={{ marginTop: 18 }}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={image.url}
            alt="AI generated image"
            style={{
              width: '100%',
              maxWidth: 560,
              borderRadius: 14,
              display: 'block',
            }}
          />
          <p style={{ margin: '12px 0 0', fontSize: '0.9rem', color: '#374151' }}>
            Image generated for &ldquo;{imagePrompt}&rdquo; · {fmt} ·{' '}
            {image.width}&times;{image.height} · AI ({image.provider}/
            {image.model}) · ready to post.
          </p>
          <div style={rowStyle}>
            <button
              type="button"
              className="btn btn-ghost btn-sm"
              onClick={() => {
                downloadUrl(image.url, 'virello-image.png');
                notify('Image downloading');
              }}
            >
              Download
            </button>
            <button
              type="button"
              className="btn btn-ghost btn-sm"
              onClick={() => {
                resetResult();
                void genImage(imagePrompt);
              }}
            >
              Regenerate
            </button>
            <button
              type="button"
              className="btn btn-ghost btn-sm"
              onClick={growThisPost}
            >
              Grow this post
            </button>
          </div>
        </div>
      )}

      {video && (
        <div style={{ marginTop: 18 }}>
          <p style={{ margin: '0 0 4px', fontWeight: 700, color: 'var(--txt)' }}>
            Storyboard generated for &ldquo;{prompt.trim() || meta.ideas[0]}&rdquo;
            — 20s vertical (9:16), AI frames
          </p>
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fill,minmax(140px,1fr))',
              gap: 12,
              marginTop: 12,
            }}
          >
            {SCENES.map((sc, i) => (
              <figure key={sc.t} style={{ margin: 0 }}>
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={video.thumbs[i]}
                  alt={sc.t}
                  loading="lazy"
                  style={{ width: '100%', borderRadius: 12, display: 'block' }}
                />
                <figcaption
                  style={{ fontSize: '0.85rem', color: 'var(--mut)', marginTop: 6 }}
                >
                  <b style={{ color: 'var(--txt)' }}>{sc.t}</b>
                  <br />
                  {sc.txt}
                </figcaption>
              </figure>
            ))}
          </div>
          <p style={{ margin: '12px 0 0', fontSize: '0.88rem', color: 'var(--mut)' }}>
            Audio: trending slowed track, beat drop at 9s · Post: today 7:30 PM
            PKT · Captions: on, bold white with shadow
          </p>
          <div style={rowStyle}>
            <button
              type="button"
              className="btn btn-ghost btn-sm"
              onClick={() => {
                downloadText(video.script, 'virello-video-script.txt');
                notify('Script downloaded — shoot it scene by scene');
              }}
            >
              Download script (.txt)
            </button>
            <button
              type="button"
              className="btn btn-ghost btn-sm"
              onClick={() => {
                resetResult();
                void genVideo(prompt.trim() || meta.ideas[0]);
              }}
            >
              New storyboard
            </button>
          </div>
          <div style={{ ...rowStyle, marginTop: 14 }}>
            <button
              type="button"
              className="btn btn-grad btn-sm"
              onClick={() => void storyboardToMp4()}
              disabled={mp4Busy}
            >
              {mp4Busy ? 'Building MP4…' : '🎬 Create MP4 Video (free)'}
            </button>
          </div>
          {mp4Url !== '' && (
            <div style={{ marginTop: 12 }}>
              <video
                src={mp4Url}
                controls
                style={{
                  width: '100%',
                  maxWidth: 340,
                  borderRadius: 14,
                  display: 'block',
                  background: '#000',
                }}
              />
              <a
                href={mp4Url}
                download="virello-ai-video.mp4"
                className="btn btn-ghost btn-sm"
                style={{ textDecoration: 'none', marginTop: 8, display: 'inline-block' }}
              >
                Download MP4
              </a>
            </div>
          )}
        </div>
      )}

      {caption && (
        <div style={{ marginTop: 18 }}>
          <div
            style={{
              background: '#F7F8FC',
              border: '1px solid #ECECF1',
              borderRadius: 16,
              padding: 20,
              color: '#374151',
              fontSize: '0.93rem',
              lineHeight: 1.65,
            }}
          >
            <b style={{ color: '#111827' }}>Hook:</b> &ldquo;{caption.hook}&rdquo;
            <br />
            <br />
            <b style={{ color: '#111827' }}>Caption:</b> {caption.caption}
            <br />
            <br />
            <b style={{ color: '#111827' }}>Hashtags:</b>{' '}
            {caption.hashtags.map((h) => `#${h}`).join(' ')}
            <br />
            <br />
            <span style={{ fontSize: '0.78rem', color: '#9CA3AF' }}>
              Written by Virello AI ({captionProvider})
            </span>
          </div>
          <div style={rowStyle}>
            <button
              type="button"
              className="btn btn-ghost btn-sm"
              onClick={() =>
                void copyText(captionFull).then((ok) =>
                  notify(
                    ok
                      ? 'Caption copied — paste it straight into your post'
                      : 'Copy failed — select the text manually',
                  ),
                )
              }
            >
              Copy caption
            </button>
            <button
              type="button"
              className="btn btn-ghost btn-sm"
              onClick={() => {
                resetResult();
                void genCaption(prompt.trim() || meta.ideas[0]);
              }}
            >
              Another version
            </button>
          </div>
        </div>
      )}

      {drafts.length > 0 && (
        <div style={{ marginTop: 22 }}>
          <h4 style={{ margin: '0 0 4px', fontSize: '1rem', color: '#111827' }}>
            Your drafts
          </h4>
          <p style={{ margin: 0, color: '#6B7280', fontSize: '0.85rem' }}>
            Everything you generate is saved here — download it, copy it, or
            grow it.
          </p>
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fill,minmax(220px,1fr))',
              gap: 14,
              marginTop: 12,
            }}
          >
            {drafts.map((d, i) => (
              <div
                key={`${d.type}-${i}`}
                style={{
                  border: '1px solid var(--line)',
                  borderRadius: 14,
                  overflow: 'hidden',
                  background: 'var(--surface)',
                }}
              >
                {d.thumb !== '' ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={d.thumb}
                    alt=""
                    loading="lazy"
                    style={{
                      width: '100%',
                      height: 140,
                      objectFit: 'cover',
                      display: 'block',
                    }}
                  />
                ) : (
                  <div
                    style={{
                      height: 140,
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      fontSize: 40,
                      background: 'var(--surface2)',
                    }}
                  >
                    {d.type === 'video' ? '🎬' : '✍️'}
                  </div>
                )}
                <div style={{ padding: 12 }}>
                  <b
                    style={{
                      display: 'block',
                      fontSize: '0.9rem',
                      color: 'var(--txt)',
                    }}
                  >
                    {d.title}
                  </b>
                  <span style={{ fontSize: '0.82rem', color: 'var(--mut)' }}>
                    {draftKindLabel(d.type)}
                  </span>
                  <div style={{ display: 'flex', gap: 8, marginTop: 10 }}>
                    <button
                      type="button"
                      className="btn btn-ghost btn-sm"
                      onClick={() => draftAct(i)}
                    >
                      {d.type === 'caption' ? 'Copy' : 'Download'}
                    </button>
                    <button
                      type="button"
                      className="btn btn-ghost btn-sm"
                      onClick={() => onDeleteDraft(i)}
                    >
                      Delete
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
