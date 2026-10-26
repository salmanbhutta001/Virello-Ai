'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { notify } from '../../lib/creator';
import { PanelShell, inputStyle, rowStyle } from './shared';

/**
 * Image Tools — fully client-side canvas editor (legacy itDraw / itRotate /
 * itFlip / itDownload, index.html:3582-3623). No API call. The draw math is
 * ported verbatim from legacy, quirks included (aspect crop + rotation
 * swap handling). Supports crop via aspect (Free / 1:1 / 4:5 / 9:16 /
 * 16:9), rotate ±90°, flip H/V, filters, text overlay (top/bottom, up to
 * 3 lines), Download PNG.
 */

type Aspect = 'free' | '1:1' | '4:5' | '9:16' | '16:9';

const ASPECTS: { id: Aspect; label: string }[] = [
  { id: 'free', label: 'Free' },
  { id: '1:1', label: '1:1' },
  { id: '4:5', label: '4:5' },
  { id: '9:16', label: '9:16' },
  { id: '16:9', label: '16:9' },
];

const FILTERS: { value: string; label: string }[] = [
  { value: 'none', label: 'None' },
  { value: 'grayscale(1)', label: 'Mono' },
  { value: 'sepia(.8)', label: 'Sepia' },
  { value: 'saturate(1.6) contrast(1.1)', label: 'Vivid' },
  { value: 'sepia(.35) saturate(1.4)', label: 'Warm' },
  { value: 'saturate(.9) hue-rotate(15deg)', label: 'Cool' },
];

export default function ImageTools(props: { onBack: () => void }) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const imgRef = useRef<HTMLImageElement | null>(null);
  const [loaded, setLoaded] = useState(false);
  const [hint, setHint] = useState('No photo selected yet.');
  const [aspect, setAspect] = useState<Aspect>('free');
  const [rot, setRot] = useState(0);
  const [flipH, setFlipH] = useState(false);
  const [flipV, setFlipV] = useState(false);
  const [filter, setFilter] = useState('none');
  const [text, setText] = useState('');
  const [textPos, setTextPos] = useState<'top' | 'bottom'>('bottom');

  const draw = useCallback(() => {
    const img = imgRef.current;
    const cv = canvasRef.current;
    if (!img || !cv) return;
    const ctx = cv.getContext('2d');
    if (!ctx) return;
    const iw = img.naturalWidth;
    const ih = img.naturalHeight;
    const rotation = ((rot % 360) + 360) % 360;
    const swap = rotation === 90 || rotation === 270;
    let dw = swap ? ih : iw;
    let dh = swap ? iw : ih;
    let sx = 0;
    let sy = 0;
    let sw = iw;
    let sh = ih;
    if (aspect !== 'free') {
      const parts = aspect.split(':');
      const ta = +parts[0] / +parts[1];
      const ca = dw / dh;
      if (ca > ta) {
        sw = ih * ta;
        if (swap) sw = iw * ta;
        sx = (iw - sw) / 2;
      } else {
        sh = sw / ta;
        sy = (ih - sh) / 2;
      }
      if (swap) {
        const t2 = dw;
        dw = dh;
        dh = t2;
      }
    }
    const maxW = 900;
    const sc = Math.min(1, maxW / (swap ? dh : dw));
    cv.width = Math.round((swap ? dh : dw) * sc);
    cv.height = Math.round((swap ? dw : dh) * sc);
    ctx.save();
    ctx.filter = filter === 'none' ? 'none' : filter;
    ctx.translate(cv.width / 2, cv.height / 2);
    ctx.rotate((rotation * Math.PI) / 180);
    ctx.scale(flipH ? -1 : 1, flipV ? -1 : 1);
    ctx.drawImage(img, sx, sy, sw, sh, -cv.width / 2, -cv.height / 2, cv.width, cv.height);
    ctx.restore();
    const txt = text.trim();
    if (txt) {
      ctx.save();
      ctx.font = `bold ${Math.round(cv.width / 14)}px sans-serif`;
      ctx.textAlign = 'center';
      ctx.shadowColor = 'rgba(0,0,0,.65)';
      ctx.shadowBlur = 8;
      ctx.fillStyle = '#fff';
      ctx.strokeStyle = 'rgba(0,0,0,.5)';
      ctx.lineWidth = 3;
      const y =
        textPos === 'top' ? Math.round(cv.width / 14) + 18 : cv.height - 22;
      const lines = txt.split('\n').slice(0, 3);
      lines.forEach((line, i) => {
        const yy =
          textPos === 'top'
            ? y + i * (Math.round(cv.width / 14) + 8)
            : y - (lines.length - 1 - i) * (Math.round(cv.width / 14) + 8);
        ctx.strokeText(line, cv.width / 2, yy);
        ctx.fillText(line, cv.width / 2, yy);
      });
      ctx.restore();
    }
  }, [aspect, rot, flipH, flipV, filter, text, textPos]);

  useEffect(() => {
    if (loaded) draw();
  }, [loaded, draw]);

  function onFile(f: File | undefined) {
    if (!f) return;
    const url = URL.createObjectURL(f);
    const img = new Image();
    img.onload = () => {
      imgRef.current = img;
      setAspect('free');
      setRot(0);
      setFlipH(false);
      setFlipV(false);
      setLoaded(true);
      setHint(`${f.name} · ${img.naturalWidth}×${img.naturalHeight}`);
      URL.revokeObjectURL(url);
    };
    img.onerror = () => notify('Could not read that image');
    img.src = url;
  }

  function download() {
    const cv = canvasRef.current;
    if (!cv) return;
    const a = document.createElement('a');
    a.href = cv.toDataURL('image/png');
    a.download = 'virello-edited.png';
    document.body.appendChild(a);
    a.click();
    a.remove();
    notify('Image downloaded');
  }

  return (
    <PanelShell
      title="Image Tools"
      desc="Photo upload karo — crop, rotate, filters, text overlay. Sab kuch isi browser mein."
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
        <span className="tiny mut">{hint}</span>
      </div>

      {loaded && (
        <div style={{ display: 'flex', gap: 16, flexWrap: 'wrap', marginTop: 14 }}>
          <div style={{ flex: 1, minWidth: 260 }}>
            <canvas
              ref={canvasRef}
              style={{ width: '100%', borderRadius: 14, background: '#F1F2F6', display: 'block' }}
            />
          </div>
          <div style={{ flex: 1, minWidth: 240 }}>
            <b className="small">Aspect</b>
            <div className="chip-row" style={{ marginTop: 6 }}>
              {ASPECTS.map((a) => (
                <button
                  key={a.id}
                  type="button"
                  className={`chip${aspect === a.id ? ' active' : ''}`}
                  aria-pressed={aspect === a.id}
                  onClick={() => setAspect(a.id)}
                >
                  {a.label}
                </button>
              ))}
            </div>
            <b className="small">Rotate &amp; Flip</b>
            <div className="chip-row" style={{ marginTop: 6 }}>
              <button type="button" className="chip" onClick={() => setRot((r) => r - 90)}>
                ↺ Left
              </button>
              <button type="button" className="chip" onClick={() => setRot((r) => r + 90)}>
                Right ↻
              </button>
              <button type="button" className="chip" onClick={() => setFlipH((v) => !v)}>
                Flip H
              </button>
              <button type="button" className="chip" onClick={() => setFlipV((v) => !v)}>
                Flip V
              </button>
            </div>
            <b className="small">Filter</b>
            <div style={{ marginTop: 6 }}>
              <select
                value={filter}
                onChange={(e) => setFilter(e.target.value)}
                style={inputStyle}
                aria-label="Filter"
              >
                {FILTERS.map((f) => (
                  <option key={f.value} value={f.value}>
                    {f.label}
                  </option>
                ))}
              </select>
            </div>
            <b className="small">Text Overlay</b>
            <div style={rowStyle}>
              <input
                value={text}
                onChange={(e) => setText(e.target.value)}
                placeholder="Your text..."
                style={{ ...inputStyle, flex: 1, minWidth: 140 }}
              />
              <select
                value={textPos}
                onChange={(e) => setTextPos(e.target.value as 'top' | 'bottom')}
                style={{ ...inputStyle, width: 'auto' }}
                aria-label="Text position"
              >
                <option value="top">Top</option>
                <option value="bottom">Bottom</option>
              </select>
              <button type="button" className="chip" onClick={draw}>
                Apply
              </button>
            </div>
            <div style={rowStyle}>
              <button type="button" className="btn btn-grad btn-sm" onClick={download}>
                Download PNG
              </button>
            </div>
          </div>
        </div>
      )}
    </PanelShell>
  );
}
