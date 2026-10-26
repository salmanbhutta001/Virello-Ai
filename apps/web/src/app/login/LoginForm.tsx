'use client';

import { useEffect, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import {
  login,
  signup,
  requestPasswordReset,
  setPlan,
} from '@/lib/auth';
import { scheduleTourAfterLogin } from '@/lib/tour';
import { showToast } from '@/lib/toast';

// Login / signup page — port of legacy #page-login
// (index.html:1130-1181 HTML; 2795-2848 JS). Titles, button labels,
// plan notes, error mapping and redirect timing match legacy exactly.
// "Remember me" is present with NO behavior (legacy parity — flagged).
// NO referral_code is ever sent (legacy parity).
//
// First login: legacy starts the guided tour 900 ms after navigation
// (startTour, legacy §14). The tour lives in src/lib/tour.ts +
// src/components/TourRunner.tsx (mounted in the root layout); on
// first login we set the pending flag here and the TourRunner starts
// it 900 ms after the landing page loads.

const PLAN_NOTE_FREE =
  'Free plan selected — $0 forever, no payment needed. Create your account (or log in) and you will go straight to Let AI Grow.';

function planNoteFor(plan: string | null): string | null {
  if (!plan) return null;
  if (plan === 'free') return PLAN_NOTE_FREE;
  return `Selected plan: ${plan} — create your account (or log in) to continue with the ${plan} plan. Plan billing is completed securely in the Virello app via Google Play.`;
}

export default function LoginForm() {
  const searchParams = useSearchParams();
  const plan = searchParams.get('plan');
  const next = searchParams.get('next');

  const [mode, setMode] = useState<'login' | 'signup'>('login');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [name, setName] = useState('');
  const [confirm, setConfirm] = useState('');
  const [busy, setBusy] = useState(false);
  const [sendingReset, setSendingReset] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);

  // Plan from query (?plan=): any plan present → note shown + force
  // the signup tab (legacy applyPlanFromHash, index.html:2939).
  useEffect(() => {
    if (plan) setMode('signup');
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [plan]);

  const planNote = planNoteFor(plan);
  const isSignup = mode === 'signup';

  const toggleTheme = () => {
    const nextTheme =
      document.documentElement.getAttribute('data-theme') === 'light'
        ? 'dark'
        : 'light';
    document.documentElement.setAttribute('data-theme', nextTheme);
    try {
      localStorage.setItem('virello-theme', nextTheme);
    } catch {
      /* ignore */
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setInfo(null);
    if (isSignup && password !== confirm) {
      setError('Passwords do not match — please type the same password in both fields.');
      return;
    }
    setBusy(true);
    try {
      const result = isSignup
        ? await signup(email.trim(), password, name.trim())
        : await login(email.trim(), password);
      if (!result.ok) {
        if (result.error === 'ACCOUNT_CREATED_LOGIN') {
          // Signup succeeded but no token came back: switch to the
          // login tab and ask the user to log in (legacy parity).
          setMode('login');
          setInfo('Account created — now log in with your email and password.');
          showToast('Account created — please log in.');
        } else {
          setError(result.error ?? 'Something went wrong. Please try again.');
        }
        return;
      }
      // Success — legacy authSubmit (index.html:2815-2840).
      const firstLogin = (() => {
        try {
          return localStorage.getItem('virello_tour_seen') !== '1';
        } catch {
          return false;
        }
      })();
      // First login → the tour starts 900 ms after navigation
      // (legacy authSubmit, index.html:2836-2837). The flag is picked
      // up by the TourRunner on the landing page.
      if (firstLogin) scheduleTourAfterLogin();
      showToast(
        isSignup ? 'Account created — welcome to Virello!' : 'Welcome back!',
      );
      const toDashboard = next === 'dashboard';
      if (toDashboard) setPlan('free');
      window.setTimeout(() => {
        window.location.href = toDashboard ? '/dashboard.html' : '/';
      }, 600);
    } finally {
      setBusy(false);
    }
  };

  const handleForgot = async (e: React.MouseEvent) => {
    e.preventDefault();
    const em = email.trim();
    if (!em) {
      showToast('Enter your email above first, then tap Forgot password.');
      document.getElementById('authEmail')?.focus();
      return;
    }
    setSendingReset(true);
    try {
      await requestPasswordReset(em);
      setInfo(
        `If an account exists for ${em}, a password reset link is on its way. Check your inbox (and spam folder).`,
      );
      showToast('Password reset requested — check your email.');
    } catch {
      setError('We could not start the reset just now. Please try again in a moment.');
    } finally {
      setSendingReset(false);
    }
  };

  return (
    <div className="auth-wrap">
      <div className="auth-visual">
        <a href="/">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img className="logo-img" src="/logo-virello.png" alt="Virello AI" />
        </a>
        <div>
          <h2 style={{ fontSize: 'clamp(1.8rem, 3.4vw, 2.6rem)', maxWidth: 440 }}>
            Your AI <span className="grad-text">Growth Manager</span> is waiting.
          </h2>
          <p className="mut" style={{ maxWidth: 400, marginTop: 14 }}>
            Join creators growing on Instagram, YouTube, TikTok, Facebook and X —
            with real audiences and zero bots.
          </p>
          <div style={{ display: 'flex', gap: 26, marginTop: 30, flexWrap: 'wrap' }}>
            <div>
              <b style={{ fontFamily: 'var(--font-d)', fontSize: '1.3rem' }}>248</b>
              <p className="tiny mut">Countries supported</p>
            </div>
            <div>
              <b style={{ fontFamily: 'var(--font-d)', fontSize: '1.3rem' }}>10</b>
              <p className="tiny mut">AI agents on your team</p>
            </div>
            <div>
              <b style={{ fontFamily: 'var(--font-d)', fontSize: '1.3rem' }}>0</b>
              <p className="tiny mut">Bots. Ever.</p>
            </div>
          </div>
        </div>
        <p className="tiny mut">
          Protected by secure, authorized sign-in. Virello never asks for your
          social media password.
        </p>
      </div>

      <div className="auth-form-side">
        <div className="auth-card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 12 }}>
            <a href="/" className="small" style={{ color: 'var(--pink)', fontWeight: 600 }}>
              ← Back to home
            </a>
            <button
              className="theme-toggle"
              onClick={toggleTheme}
              aria-label="Switch theme"
              title="Switch theme"
              type="button"
            >
              <svg className="ic-sun" viewBox="0 0 24 24" aria-hidden="true">
                <circle cx="12" cy="12" r="4" />
                <path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" />
              </svg>
              <svg className="ic-moon" viewBox="0 0 24 24" aria-hidden="true">
                <path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z" />
              </svg>
            </button>
          </div>

          <h2 className="page-h" style={{ fontSize: '1.7rem', marginTop: 16 }}>
            {isSignup ? 'Create your account' : 'Welcome back'}
          </h2>
          <p className="mut small">
            {isSignup
              ? 'Start free — no credit card required.'
              : 'Log in to your Virello dashboard.'}
          </p>

          {planNote && <p className="auth-note">{planNote}</p>}
          {error && (
            <p className="auth-msg error" role="alert">
              {error}
            </p>
          )}
          {info && (
            <p className="auth-msg info" role="status">
              {info}
            </p>
          )}

          <div className="auth-tabs" role="tablist">
            <button
              type="button"
              className={mode === 'login' ? 'on' : undefined}
              onClick={() => setMode('login')}
            >
              Log In
            </button>
            <button
              type="button"
              className={mode === 'signup' ? 'on' : undefined}
              onClick={() => setMode('signup')}
            >
              Sign Up
            </button>
          </div>

          <form onSubmit={handleSubmit}>
            {isSignup && (
              <div className="field">
                <label className="lbl" htmlFor="authName">
                  Full name
                </label>
                <input
                  className="inp"
                  id="authName"
                  type="text"
                  placeholder="Your name"
                  autoComplete="name"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                />
              </div>
            )}
            <div className="field">
              <label className="lbl" htmlFor="authEmail">
                Email
              </label>
              <input
                className="inp"
                id="authEmail"
                type="email"
                placeholder="you@example.com"
                required
                autoComplete="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
              />
            </div>
            <div className="field">
              <label className="lbl" htmlFor="authPass">
                Password
              </label>
              <input
                className="inp"
                id="authPass"
                type="password"
                placeholder="••••••••"
                required
                autoComplete={isSignup ? 'new-password' : 'current-password'}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
            </div>
            {isSignup && (
              <div className="field">
                <label className="lbl" htmlFor="authPass2">
                  Confirm password
                </label>
                <input
                  className="inp"
                  id="authPass2"
                  type="password"
                  placeholder="••••••••"
                  autoComplete="new-password"
                  value={confirm}
                  onChange={(e) => setConfirm(e.target.value)}
                />
              </div>
            )}
            <div
              style={{
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                marginBottom: 20,
              }}
            >
              {/* "Remember me" — present with NO behavior (legacy parity).
                  The checkbox is never read by any code, same as legacy. */}
              <label
                style={{
                  display: 'flex',
                  gap: 8,
                  alignItems: 'center',
                  fontSize: '0.87rem',
                  color: 'var(--mut)',
                }}
              >
                <input
                  type="checkbox"
                  defaultChecked
                  style={{ accentColor: 'var(--pink)' }}
                />{' '}
                Remember me
              </label>
              <a
                href="#"
                className="small"
                style={{ color: 'var(--pink)', fontWeight: 600 }}
                onClick={handleForgot}
              >
                {sendingReset ? 'Sending…' : 'Forgot password?'}
              </a>
            </div>
            <button
              className="btn btn-pink"
              type="submit"
              style={{ width: '100%' }}
              disabled={busy}
            >
              {busy ? (
                <>
                  <span className="spin" />
                  Please wait…
                </>
              ) : isSignup ? (
                'Create Free Account'
              ) : (
                'Log In'
              )}
            </button>
          </form>

          <p className="tiny mut" style={{ textAlign: 'center', marginTop: 22 }}>
            By continuing you agree to Virello&apos;s Terms and Privacy Policy.
            Your Virello account works in the app and on this website with the
            same email and password.
          </p>
          <div className="trust-row" style={{ marginTop: 18 }}>
            <span className="trust-item">
              <svg viewBox="0 0 24 24">
                <rect x="4" y="10" width="16" height="10" rx="2" />
                <path d="M8 10V7a4 4 0 0 1 8 0v3" />
              </svg>
              Encrypted sign-in
            </span>
            <span className="trust-item">
              <svg viewBox="0 0 24 24">
                <path d="M12 3l7 3v5c0 5-3 8-7 10-4-2-7-5-7-10V6l7-3z" />
              </svg>
              No password sharing
            </span>
          </div>
        </div>
      </div>
    </div>
  );
}
