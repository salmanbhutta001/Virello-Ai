'use client';

import { useState } from 'react';
import { apiErrorMessage, creatorApi, notify } from '../../lib/creator';
import { PanelShell, Spinner, errorStyle, inputStyle, rowStyle } from './shared';

/**
 * Get Featured (Spotlight) — submit a post for featuring (legacy
 * spotlightSubmit, index.html:3503-3522). POST /api/v1/spotlight/submit
 * {content, link, creator_handle, creator_email, consent:true} DIRECT
 * to API_BASE (not a proxy path). Requires non-empty content + the
 * consent checkbox. Success shows the server's message.
 */

export default function Spotlight(props: { onBack: () => void }) {
  const [content, setContent] = useState('');
  const [link, setLink] = useState('');
  const [handle, setHandle] = useState('');
  const [email, setEmail] = useState('');
  const [consent, setConsent] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [done, setDone] = useState('');

  async function submit() {
    const c = content.trim();
    if (c.length < 3) {
      notify('Please write your post first');
      return;
    }
    if (!consent) {
      notify('Please tick the consent checkbox first');
      return;
    }
    setLoading(true);
    setError('');
    setDone('');
    try {
      const res = await creatorApi('/api/v1/spotlight/submit', {
        content: c,
        link: link.trim(),
        creator_handle: handle.trim(),
        creator_email: email.trim(),
        consent: true,
      });
      if (!res.ok)
        throw new Error(apiErrorMessage(res.data, 'submission failed'));
      const msg = (res.data as { message?: unknown }).message;
      setDone(typeof msg === 'string' && msg !== '' ? msg : 'We will review it soon.');
      notify('Submitted for Spotlight review');
    } catch (e) {
      setError(
        `Could not submit — ${e instanceof Error ? e.message : 'please try again'}`,
      );
    } finally {
      setLoading(false);
    }
  }

  return (
    <PanelShell
      title="Get Featured — Virello Spotlight"
      desc="Apna best post submit karo. Agar select hua to Virello ke official accounts par aapke naam ke saath “Featured Creator” ke tag se share hoga — sab ko pata hoga ke ye featured hai."
      onBack={props.onBack}
    >
      <textarea
        rows={4}
        value={content}
        onChange={(e) => setContent(e.target.value)}
        placeholder="Your post text..."
        style={inputStyle}
      />
      <div style={rowStyle}>
        <input
          value={link}
          onChange={(e) => setLink(e.target.value)}
          placeholder="Your link (e.g. https://yourshop.com)"
          style={{ ...inputStyle, flex: 1, minWidth: 220 }}
        />
        <input
          value={handle}
          onChange={(e) => setHandle(e.target.value)}
          placeholder="Your @handle (for credit)"
          style={{ ...inputStyle, flex: 1, minWidth: 160 }}
        />
      </div>
      <div style={rowStyle}>
        <input
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          placeholder="Email (optional — we will notify you if featured)"
          style={{ ...inputStyle, flex: 1, minWidth: 220 }}
        />
      </div>
      <label
        className="small"
        style={{
          display: 'flex',
          gap: 8,
          alignItems: 'flex-start',
          margin: '10px 0',
          cursor: 'pointer',
        }}
      >
        <input
          type="checkbox"
          checked={consent}
          onChange={(e) => setConsent(e.target.checked)}
          style={{ marginTop: 3 }}
        />
        <span>
          I agree that Virello may feature this post on Virello&apos;s official
          social media accounts <b>with credit to me</b>, labeled as a
          Featured Creator post. I understand it will be publicly visible as
          featured content.
        </span>
      </label>
      <div style={rowStyle}>
        <button
          type="button"
          className="btn btn-grad"
          onClick={() => void submit()}
          disabled={loading}
        >
          {loading ? 'Submitting…' : 'Submit for Spotlight'}
        </button>
      </div>

      {loading && (
        <div style={{ marginTop: 14 }}>
          <Spinner />
          <b>Submitting…</b>
        </div>
      )}
      {error !== '' && (
        <div style={errorStyle} role="alert">
          {error}
        </div>
      )}
      {done !== '' && (
        <div style={{ marginTop: 14 }}>
          <b>⭐ Submitted!</b>
          <p className="small">{done}</p>
        </div>
      )}
    </PanelShell>
  );
}
