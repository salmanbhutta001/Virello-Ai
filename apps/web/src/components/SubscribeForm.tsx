'use client';

/**
 * Newsletter subscribe — legacy behavior EXACTLY: on submit, show
 * "✓ You are subscribed — watch your inbox for the next growth guide."
 * + a toast, clear the input, and store the email NOWHERE (no fetch, no
 * API call, no storage — known false-success, awaiting Hafiz's call).
 * Toast uses the global showToast (P2) — no second toast system.
 */

import { useState } from 'react';
import { showToast } from '@/lib/toast';

export default function SubscribeForm() {
  const [email, setEmail] = useState('');
  const [subscribed, setSubscribed] = useState(false);

  const onSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const value = email.trim();
    if (!value) return;
    setSubscribed(true);
    showToast(`Subscribed — growth tips are on the way to ${value}.`);
    setEmail('');
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
    </>
  );
}
