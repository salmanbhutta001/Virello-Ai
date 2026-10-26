'use client';

import { useEffect, useState } from 'react';
import { notify } from '../../lib/creator';
import { PanelShell, inputStyle, rowStyle } from './shared';

/**
 * Voiceover Studio — browser `speechSynthesis` ONLY (legacy voiceInit /
 * Speak / Stop, index.html:3652-3675). No server call. Loads the voice
 * list, prefers an Urdu voice when one exists, rate 0.5–2, pitch 0–2.
 */

export default function VoiceoverStudio(props: { onBack: () => void }) {
  const [text, setText] = useState('');
  const [voices, setVoices] = useState<SpeechSynthesisVoice[]>([]);
  const [voiceIdx, setVoiceIdx] = useState(0);
  const [rate, setRate] = useState(1);
  const [pitch, setPitch] = useState(1);
  const [supported, setSupported] = useState(true);

  useEffect(() => {
    if (!('speechSynthesis' in window)) {
      setSupported(false);
      return;
    }
    const load = () => {
      const list = window.speechSynthesis.getVoices();
      setVoices(list);
      const ur = list.findIndex(
        (v) => v.lang && v.lang.toLowerCase().indexOf('ur') === 0,
      );
      if (ur >= 0) setVoiceIdx(ur);
    };
    load();
    window.speechSynthesis.onvoiceschanged = load;
    return () => {
      window.speechSynthesis.onvoiceschanged = null;
    };
  }, []);

  function speak() {
    if (!('speechSynthesis' in window)) {
      notify('Voice not supported in this browser');
      return;
    }
    const txt = text.trim();
    if (txt.length < 2) {
      notify('Type something for the voice to say');
      return;
    }
    window.speechSynthesis.cancel();
    const u = new SpeechSynthesisUtterance(txt);
    if (voices[voiceIdx]) u.voice = voices[voiceIdx];
    u.rate = rate;
    u.pitch = pitch;
    window.speechSynthesis.speak(u);
  }

  function stop() {
    if ('speechSynthesis' in window) window.speechSynthesis.cancel();
  }

  return (
    <PanelShell
      title="Voiceover Studio"
      desc="Text likho — phone/browser ki awaz mein suno. Voice, speed aur pitch adjust karo."
      onBack={props.onBack}
    >
      <textarea
        rows={4}
        value={text}
        onChange={(e) => setText(e.target.value)}
        placeholder="Type what the voice should say..."
        style={inputStyle}
      />
      <div style={rowStyle}>
        <select
          value={voiceIdx}
          onChange={(e) => setVoiceIdx(+e.target.value)}
          style={{ ...inputStyle, flex: 1, minWidth: 180 }}
          aria-label="Voice"
        >
          {!supported ? (
            <option>Voice not supported in this browser</option>
          ) : voices.length === 0 ? (
            <option>Loading voices...</option>
          ) : (
            voices.map((v, i) => (
              <option key={`${v.name}-${v.lang}`} value={i}>
                {v.name} ({v.lang}){v.default ? ' — default' : ''}
              </option>
            ))
          )}
        </select>
        <label className="small">
          Speed{' '}
          <input
            type="range"
            min={0.5}
            max={2}
            step={0.1}
            value={rate}
            onChange={(e) => setRate(+e.target.value)}
            style={{ width: 90 }}
          />
        </label>
        <label className="small">
          Pitch{' '}
          <input
            type="range"
            min={0}
            max={2}
            step={0.1}
            value={pitch}
            onChange={(e) => setPitch(+e.target.value)}
            style={{ width: 90 }}
          />
        </label>
      </div>
      <div style={rowStyle}>
        <button type="button" className="btn btn-grad btn-sm" onClick={speak}>
          ▶ Speak
        </button>
        <button type="button" className="btn btn-ghost btn-sm" onClick={stop}>
          Stop
        </button>
      </div>
    </PanelShell>
  );
}
