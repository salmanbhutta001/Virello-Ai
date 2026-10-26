'use client';

/**
 * Newsletter subscribe — legacy behavior EXACTLY: on submit, show
 * "✓ You are subscribed — watch your inbox for the next growth guide."
 * + a toast, clear the input, and store the email NOWHERE (no fetch, no
 * API call, no storage — known false-success, awaiting Hafiz's call).
 * TODO(P2): swap the local mini-toast for the global showToast when the
 * toast lib lands (src/lib/toast.ts + <ToastRoot /> in layout).
 */

import { useEffect, useRef, useState } from 'react';

export default function SubscribeForm() {
  const [email, setEmail] = useState('');
  const [subscribed, setSubscribed] = useState(false);
  const [toast, setToast] = useState<string | null>(null);
  const timer = useRef<number | null>(null);

  useEffect(
    () => () => {
      if (timer.current) window.clearTimeout(timer.current);
    },
    [],
  );

  const onSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const value = email.trim();
    if (!value) return;
    setSubscribed(true);
    setToast(`Subscribed — growth tips are on the way to ${value}.`);
    setEmail('');
    if (timer.current) window.clearTimeout(timer.current);
    timer.current = window.setTimeout(() => setToast(null), 4200);
  };

  return (
    <>
      <form className="news-form" onSubmit={onSubmit}>
        <input
          type="email"
          required
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          placeholder="Your email"
          aria-label="Email for newsletter"
        />
        <button type="submit" className="btn btn-grad btn-sm">
          Subscribe
        </button>
      </form>
      {subscribed && (
        <p className="news-ok">
          ✓ You are subscribed — watch your inbox for the next growth guide.
        </p>
      )}
      {toast && (
        <div className="mini-toast" role="status">
          {toast}
        </div>
      )}
    </>
  );
}
