'use client';

/**
 * App screenshots carousel — 7 images blog-images/app-shots/01…07.jpg
 * (hot-linked from virelloai.online, like legacy). Tabs + prev/next +
 * touch/mouse-drag swipe (>40px).
 */

import { useRef, useState } from 'react';

const SHOTS = [
  { src: 'https://virelloai.online/blog-images/app-shots/01-splash.jpg', tab: 'Splash', cap: 'Splash — Welcome to Virello AI' },
  { src: 'https://virelloai.online/blog-images/app-shots/02-home.jpg', tab: 'Home', cap: 'Home — Your AI Growth Manager dashboard' },
  { src: 'https://virelloai.online/blog-images/app-shots/03-discover.jpg', tab: 'Discover', cap: 'Discover — Trending products & topics' },
  { src: 'https://virelloai.online/blog-images/app-shots/04-create-top.jpg', tab: 'Create', cap: 'Create Hub — AI Image, Video, Scripts & more' },
  { src: 'https://virelloai.online/blog-images/app-shots/05-create-bottom.jpg', tab: 'AI Tools', cap: 'Create Hub — Templates, Captions, Voiceover & tools' },
  { src: 'https://virelloai.online/blog-images/app-shots/06-grow.jpg', tab: 'Grow', cap: 'Grow — AI Campaign Insights & management' },
  { src: 'https://virelloai.online/blog-images/app-shots/07-shop.jpg', tab: 'Shop', cap: 'Shop — Curated products you might like' },
];

export default function AppShotsCarousel() {
  const [cur, setCur] = useState(0);
  const startX = useRef<number | null>(null);

  const show = (i: number) =>
    setCur(((i % SHOTS.length) + SHOTS.length) % SHOTS.length);
  const prev = () => show(cur - 1);
  const next = () => show(cur + 1);

  const onSwipeEnd = (x: number) => {
    if (startX.current === null) return;
    const dx = x - startX.current;
    startX.current = null;
    if (Math.abs(dx) > 40) {
      if (dx < 0) next();
      else prev();
    }
  };

  return (
    <div className="app-shots" style={{ marginTop: 56, textAlign: 'center' }}>
      <span className="kicker">App Preview</span>
      <h3 style={{ fontSize: 28, margin: '12px 0 8px' }}>
        See Virello <span className="grad-text">in action</span>
      </h3>
      <p className="mut" style={{ marginBottom: 28 }}>
        Real screenshots from the Virello AI app
      </p>

      <div
        className="shot-tabs"
        style={{
          display: 'flex',
          gap: 10,
          justifyContent: 'center',
          flexWrap: 'wrap',
          marginBottom: 28,
        }}
      >
        {SHOTS.map((s, i) => (
          <button
            key={s.tab}
            type="button"
            className={`shot-tab${i === cur ? ' active' : ''}`}
            onClick={() => show(i)}
          >
            {s.tab}
          </button>
        ))}
      </div>

      <div
        className="shot-viewer"
        style={{
          position: 'relative',
          maxWidth: 340,
          margin: '0 auto',
          touchAction: 'pan-y',
          userSelect: 'none',
        }}
        onTouchStart={(e) => {
          startX.current = e.touches[0].clientX;
        }}
        onTouchEnd={(e) => onSwipeEnd(e.changedTouches[0].clientX)}
        onMouseDown={(e) => {
          startX.current = e.clientX;
        }}
        onMouseUp={(e) => onSwipeEnd(e.clientX)}
      >
        <div
          className="phone-frame"
          style={{
            borderRadius: 36,
            overflow: 'hidden',
            boxShadow: '0 24px 64px rgba(0,0,0,.18)',
            border: '1px solid var(--line)',
          }}
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={SHOTS[cur].src}
            alt="Virello app screenshot"
            draggable={false}
            style={{ width: '100%', display: 'block' }}
          />
        </div>
        <button
          type="button"
          onClick={prev}
          aria-label="Previous"
          className="shot-arrow shot-arrow-prev"
        >
          ‹
        </button>
        <button
          type="button"
          onClick={next}
          aria-label="Next"
          className="shot-arrow shot-arrow-next"
        >
          ›
        </button>
      </div>
      <p className="mut small" style={{ marginTop: 16 }}>
        {SHOTS[cur].cap}
      </p>
    </div>
  );
}
