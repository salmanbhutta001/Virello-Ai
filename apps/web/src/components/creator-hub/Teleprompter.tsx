'use client';

import { useEffect, useRef, useState } from 'react';
import { notify } from '../../lib/creator';
import { PanelShell, inputStyle, rowStyle } from './shared';

/**
 * Teleprompter — auto-scroll overlay (legacy prompterStart/Tick/Toggle/
 * Font/Close, index.html:3624-3651). Esc closes it. Speed 10–120
 * (default 40); scroll advances `speed/60` px per animation frame from
 * the bottom of the viewport; when the text scrolls fully past, it stops
 * and the button becomes "Replay". Font size 18–72px (default 32).
 */

export default function Teleprompter(props: { onBack: () => void }) {
  const [text, setText] = useState('');
  const [open, setOpen] = useState(false);
  const [playing, setPlaying] = useState(false);
  const [playLabel, setPlayLabel] = useState('Pause');
  const [speed, setSpeed] = useState(40);
  const [fontSize, setFontSize] = useState(32);
  const yRef = useRef(0);
  const playingRef = useRef(false);
  const speedRef = useRef(40);
  const rafRef = useRef(0);
  const scrollRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    speedRef.current = speed;
  }, [speed]);

  useEffect(() => {
    // Esc closes the overlay (legacy: Esc ends the tour/prompter pattern).
    function onKey(e: KeyboardEvent) {
      if (e.key === 'Escape') close();
    }
    if (open) window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open ]);

  useEffect(() => () => cancelAnimationFrame(rafRef.current), []);

  function tick() {
    if (playingRef.current) {
      yRef.current -= speedRef.current / 60;
      const sc = scrollRef.current;
      if (sc) {
        sc.style.top = `${yRef.current}px`;
        if (yRef.current < -sc.offsetHeight) {
          playingRef.current = false;
          setPlaying(false);
          setPlayLabel('Replay');
        }
      }
    }
    rafRef.current = requestAnimationFrame(tick);
  }

  function start() {
    const txt = text.trim();
    if (txt.length < 3) {
      notify('Paste your script first');
      return;
    }
    yRef.current = window.innerHeight;
    playingRef.current = true;
    setPlaying(true);
    setPlayLabel('Pause');
    setOpen(true);
    cancelAnimationFrame(rafRef.current);
    rafRef.current = requestAnimationFrame(tick);
    notify('Recording tip: prop your phone and read at a natural pace');
  }

  function toggle() {
    const sc = scrollRef.current;
    if (!playingRef.current && sc && yRef.current < -sc.offsetHeight) {
      yRef.current = window.innerHeight;
    }
    playingRef.current = !playingRef.current;
    setPlaying(playingRef.current);
    setPlayLabel(playingRef.current ? 'Pause' : 'Play');
  }

  function changeFont(d: number) {
    setFontSize((f) => Math.max(18, Math.min(72, f + d * 4)));
  }

  function close() {
    cancelAnimationFrame(rafRef.current);
    playingRef.current = false;
    setPlaying(false);
    setOpen(false);
  }

  return (
    <>
      <PanelShell
        title="Teleprompter"
        desc="Script paste karo, Start dabao — text khud scroll hoga jab aap record karo."
        onBack={props.onBack}
      >
        <textarea
          rows={5}
          value={text}
          onChange={(e) => setText(e.target.value)}
          placeholder="Paste your script here..."
          style={inputStyle}
        />
        <div style={rowStyle}>
          <button type="button" className="btn btn-grad" onClick={start}>
            Start Teleprompter
          </button>
        </div>
      </PanelShell>

      {open && (
        <div
          style={{
            display: 'flex',
            flexDirection: 'column',
            position: 'fixed',
            inset: 0,
            background: '#0B0B0E',
            zIndex: 9999,
          }}
          role="dialog"
          aria-label="Teleprompter"
        >
          <div
            style={{
              display: 'flex',
              gap: 10,
              alignItems: 'center',
              padding: '14px 18px',
              background: 'rgba(255,255,255,.06)',
              flexWrap: 'wrap',
            }}
          >
            <button type="button" className="btn btn-grad btn-sm" onClick={toggle}>
              {playLabel}
            </button>
            <label className="small" style={{ color: '#fff' }}>
              Speed{' '}
              <input
                type="range"
                min={10}
                max={120}
                value={speed}
                onChange={(e) => setSpeed(+e.target.value)}
                style={{ width: 110 }}
              />
            </label>
            <button type="button" className="chip" onClick={() => changeFont(1)}>
              A+
            </button>
            <button type="button" className="chip" onClick={() => changeFont(-1)}>
              A-
            </button>
            <button
              type="button"
              className="btn btn-ghost btn-sm"
              style={{ marginLeft: 'auto', color: '#fff' }}
              onClick={close}
            >
              Close
            </button>
          </div>
          <div style={{ flex: 1, overflow: 'hidden', position: 'relative', padding: '0 8vw' }}>
            <div
              ref={scrollRef}
              style={{
                position: 'absolute',
                left: '8vw',
                right: '8vw',
                top: '100%',
                color: '#fff',
                fontSize,
                lineHeight: 1.7,
                fontWeight: 600,
                whiteSpace: 'pre-wrap',
              }}
            >
              {text.trim()}
            </div>
          </div>
        </div>
      )}
    </>
  );
}
