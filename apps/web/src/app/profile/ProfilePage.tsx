'use client';

import { useEffect, useRef, useState } from 'react';
import type { ReactNode } from 'react';
import AppShell from '@/components/AppShell';
import { apiAuth, getToken, requestPasswordReset } from '@/lib/auth';
import {
  clearMeCache,
  fetchMe,
  getCachedUser,
  getLocalAvatar,
  getLocalCover,
  loadPlatforms,
  planLabel,
  readImgFile,
  syncServerPhoto,
  uploadProfilePhoto,
} from '@/lib/user';
import type { UserProfile } from '@/lib/user';
import { showToast } from '@/lib/toast';

// Profile — port of legacy #page-profile (index.html:1970-2028).
// Real API via apiAuth: GET /users/me (60 s cache → virello_user),
// PATCH /users/me {name, preferred_language}, avatar/cover upload
// (POST /api/v1/uploads FormData + PATCH avatar_url/cover_url; local
// downscale to 800 px JPEG 0.82 → virello_avatar / virello_cover),
// GET /connected-accounts. Country is saved to virello_country
// locally only. Preferences are localStorage only (virello_prefs).
// Connected platforms: 5 fixed rows INCLUDING X as a connectable
// platform (display-only, no connect buttons — legacy parity; only
// Virello's OWN X profile links were removed elsewhere).

const COUNTRIES = [
  'Pakistan',
  'United Arab Emirates',
  'United Kingdom',
  'United States',
  'India',
  'Bangladesh',
  'Canada',
  'Australia',
  'Germany',
  'Other',
];

// Official brand glyphs (same paths as the legacy homepage footer).
// Rendered white on the brand-color thumb; inline fill beats the
// `.thumb svg { fill: none }` rule in globals.css.
const brandIcon = (d: string): ReactNode => (
  <svg viewBox="0 0 24 24" style={{ fill: '#fff', stroke: 'none' }} aria-hidden="true">
    <path d={d} />
  </svg>
);

const PLATFORMS: { key: string; label: string; bg: string; icon: ReactNode }[] = [
  { key: 'instagram', label: 'Instagram', bg: 'linear-gradient(135deg,#F95177,#D6336C)', icon: brandIcon('M12 2.2c3.2 0 3.6 0 4.9.1 3.3.1 4.8 1.7 4.9 4.9.1 1.3.1 1.6.1 4.8s0 3.6-.1 4.8c-.1 3.2-1.7 4.8-4.9 4.9-1.3.1-1.6.1-4.9.1-3.2 0-3.6 0-4.8-.1-3.3-.1-4.8-1.7-4.9-4.9-.1-1.3-.1-1.6-.1-4.8s0-3.6.1-4.8C2.4 4 4 2.4 7.2 2.3c1.2-.1 1.6-.1 4.8-.1zM12 0C8.7 0 8.3 0 7.1.1 2.7.3.3 2.7.1 7.1 0 8.3 0 8.7 0 12s0 3.7.1 4.9c.2 4.4 2.6 6.8 7 7 1.2.1 1.6.1 4.9.1s3.7 0 4.9-.1c4.4-.2 6.8-2.6 7-7 .1-1.2.1-1.6.1-4.9s0-3.7-.1-4.9c-.2-4.4-2.6-6.8-7-7C15.7 0 15.3 0 12 0zm0 5.9A6.1 6.1 0 1 0 18.1 12 6.1 6.1 0 0 0 12 5.9zm0 10.1A4 4 0 1 1 16 12a4 4 0 0 1-4 4zm6.4-11.8a1.4 1.4 0 1 1-1.4 1.4 1.4 1.4 0 0 1 1.4-1.4z') },
  { key: 'tiktok', label: 'TikTok', bg: '#1F2937', icon: brandIcon('M16.6 3c.4 2.2 1.8 3.6 4 3.9v3c-1.6 0-3-.5-4-1.3v6.6c0 3.5-2.3 5.8-5.5 5.8A5.4 5.4 0 0 1 5.6 15c0-3.3 2.7-5.7 6.1-5.4v3.1c-1.6-.4-3 .7-3 2.2 0 1.3 1 2.3 2.3 2.3 1.5 0 2.5-1.1 2.5-2.9V3h3.1z') },
  { key: 'youtube', label: 'YouTube', bg: '#7F1D1D', icon: brandIcon('M19.6 6.7a4.8 4.8 0 0 1-3.4-3.4C15.9 3 13 3 12 3s-3.9 0-4.2.3A4.8 4.8 0 0 0 4.4 6.7 50 50 0 0 0 4 12a50 50 0 0 0 .4 5.3 4.8 4.8 0 0 0 3.4 3.4c.3.3 3.2.3 4.2.3s3.9 0 4.2-.3a4.8 4.8 0 0 0 3.4-3.4A50 50 0 0 0 20 12a50 50 0 0 0-.4-5.3zM10 15.5v-7l6 3.5z') },
  { key: 'facebook', label: 'Facebook', bg: '#1D4ED8', icon: brandIcon('M24 12a12 12 0 1 0-13.9 11.9v-8.4h-3v-3.5h3V9.4c0-3 1.8-4.7 4.5-4.7 1.3 0 2.7.2 2.7.2v3h-1.5c-1.5 0-2 1-2 1.9V12h3.4l-.5 3.5h-2.9v8.4A12 12 0 0 0 24 12z') },
  { key: 'x', label: 'X', bg: '#111827', icon: brandIcon('M18.9 2H22l-6.8 7.8L23.3 22h-6.3l-4.9-6.4L6.4 22H3.3l7.3-8.3L1 2h6.5l4.4 5.9L18.9 2zm-1.1 18h1.7L7.6 3.9H5.8L17.8 20z') },
];

type Prefs = { tips: boolean; alerts: boolean; news: boolean };

function loadPrefs(): Prefs {
  const p: Prefs = { tips: true, alerts: true, news: false };
  try {
    const s = localStorage.getItem('virello_prefs');
    if (s) {
      const o = JSON.parse(s) as Partial<Prefs>;
      if (o) {
        p.tips = o.tips !== false;
        p.alerts = o.alerts !== false;
        p.news = !!o.news;
      }
    }
  } catch {
    /* ignore */
  }
  return p;
}

export default function ProfilePage() {
  const [user, setUser] = useState<UserProfile | null>(null);
  const [avatar, setAvatar] = useState<string | null>(null);
  const [cover, setCover] = useState<string | null>(null);
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [country, setCountry] = useState('Pakistan');
  const [language, setLanguage] = useState('en');
  const [platforms, setPlatforms] = useState<string[] | null>(null);
  const [prefs, setPrefs] = useState<Prefs>({ tips: true, alerts: true, news: false });
  const [saving, setSaving] = useState(false);
  const [sendingReset, setSendingReset] = useState(false);
  const [flash, setFlash] = useState(false);
  const nameRef = useRef<HTMLInputElement>(null);
  const formPanelRef = useRef<HTMLDivElement>(null);

  function applyToForm(u: UserProfile) {
    // Legacy fillProfileForm skips the name field while it is focused.
    if (document.activeElement !== nameRef.current) setName(u.name || '');
    setEmail(u.email || '');
    setLanguage(u.preferred_language || u.locale || 'en');
    try {
      const saved = localStorage.getItem('virello_country') || '';
      if (saved && COUNTRIES.includes(saved)) setCountry(saved);
    } catch {
      /* ignore */
    }
  }

  useEffect(() => {
    const cached = getCachedUser();
    if (cached) {
      setUser(cached);
      applyToForm(cached);
    }
    setAvatar(getLocalAvatar());
    setCover(getLocalCover());
    setPrefs(loadPrefs());
    // Legacy loadProfile: force a fresh /users/me, then platforms.
    fetchMe(true).then((u) => {
      if (u) {
        setUser(u);
        applyToForm(u);
        syncServerPhoto(u).then((d) => {
          if (d) setAvatar(d);
        });
      }
      loadPlatforms().then(setPlatforms);
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  function onPhotoFile(kind: 'avatar' | 'cover', file: File | undefined) {
    if (!file || !getToken()) return;
    readImgFile(file, (dataUrl) => {
      try {
        localStorage.setItem(
          kind === 'cover' ? 'virello_cover' : 'virello_avatar',
          dataUrl,
        );
      } catch {
        /* storage unavailable */
      }
      if (kind === 'cover') setCover(dataUrl);
      else setAvatar(dataUrl);
    });
    void uploadProfilePhoto(kind, file);
  }

  function editProfileFocus() {
    formPanelRef.current?.scrollIntoView({ behavior: 'smooth', block: 'center' });
    setFlash(true);
    window.setTimeout(() => setFlash(false), 1600);
    window.setTimeout(() => nameRef.current?.focus(), 450);
  }

  async function saveProfile() {
    const n = name.trim();
    if (!n) {
      showToast('Please enter your full name.');
      return;
    }
    try {
      localStorage.setItem('virello_country', country);
    } catch {
      /* ignore */
    }
    setSaving(true);
    try {
      const res = await apiAuth('/api/v1/users/me', {
        method: 'PATCH',
        body: JSON.stringify({ name: n, preferred_language: language }),
      });
      if (res.ok) {
        clearMeCache();
        const u = await fetchMe(true);
        if (u) {
          setUser(u);
          applyToForm(u);
        }
        showToast('Profile saved');
      } else {
        showToast('Could not save — please try again.');
      }
    } catch {
      showToast('Could not reach the server. Check your connection and try again.');
    } finally {
      setSaving(false);
    }
  }

  async function changePassword() {
    const em = user?.email || email;
    if (!em) {
      showToast('Your account email was not found.');
      return;
    }
    setSendingReset(true);
    try {
      await requestPasswordReset(em);
      showToast(`Password reset link sent to ${em} — check your inbox.`);
    } catch (e) {
      const msg = e instanceof Error ? e.message : '';
      showToast(
        msg.startsWith('reset request failed')
          ? 'Could not start the reset just now. Please try again.'
          : 'Could not reach the server. Check your connection and try again.',
      );
    } finally {
      setSendingReset(false);
    }
  }

  function savePrefs(next: Prefs) {
    setPrefs(next);
    try {
      localStorage.setItem('virello_prefs', JSON.stringify(next));
    } catch {
      /* ignore */
    }
    showToast('Preference saved');
  }

  const plan = planLabel(user?.plan);
  const meta = `${plan} Plan${country && user ? ` · ${country}` : ''}`;
  const initial = user?.name ? user.name.trim().charAt(0).toUpperCase() : 'V';
  const credits = user?.credits != null ? String(user.credits) : '—';
  const points = user?.points_balance != null ? String(user.points_balance) : '—';
  const level = user?.points_level != null ? `Level ${user.points_level}` : '—';

  return (
    <AppShell active="profile">
      <section id="page-profile">
        <div className="app-top">
          <div>
            <h2 className="page-h">Profile</h2>
            <p className="mut small">Your account, platforms, subscription and preferences.</p>
          </div>
          <div style={{ marginLeft: 'auto' }}>
            <button className="btn btn-pink" onClick={editProfileFocus} type="button">
              Edit Profile
            </button>
          </div>
        </div>
        <div className="grid" style={{ gridTemplateColumns: '1fr 1.6fr', gap: 20, alignItems: 'start' }} id="profGrid">
          <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
            <div className="panel" style={{ textAlign: 'center', overflow: 'hidden', padding: 0 }}>
              <div
                id="profCover"
                style={{
                  height: 120,
                  background: cover
                    ? undefined
                    : 'linear-gradient(135deg,#F95177,#7c3aed)',
                  backgroundImage: cover ? `url(${cover})` : undefined,
                  backgroundSize: 'cover',
                  backgroundPosition: 'center',
                  position: 'relative',
                }}
              >
                <label
                  className="btn btn-sm"
                  style={{ position: 'absolute', right: 10, bottom: 10, cursor: 'pointer', background: 'rgba(255,255,255,.92)', border: '1px solid #E5E7EB' }}
                  title="Change cover photo"
                >
                  Change cover
                  <input
                    type="file"
                    id="coverFile"
                    accept="image/*"
                    style={{ display: 'none' }}
                    onChange={(e) => onPhotoFile('cover', e.target.files?.[0])}
                  />
                </label>
              </div>
              <div style={{ padding: '0 20px 20px', marginTop: -42, position: 'relative' }}>
                <span
                  className="avatar"
                  id="profAvatar"
                  style={{ width: 84, height: 84, fontSize: '2rem', margin: '0 auto 10px', border: '4px solid #fff', boxShadow: '0 4px 14px rgba(0,0,0,.12)', overflow: 'hidden' }}
                >
                  {avatar ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={avatar} style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }} alt="Profile photo" />
                  ) : (
                    initial
                  )}
                </span>
                <div style={{ marginBottom: 12 }}>
                  <label className="btn btn-ghost btn-sm" style={{ cursor: 'pointer' }}>
                    Change photo
                    <input
                      type="file"
                      id="avatarFile"
                      accept="image/*"
                      style={{ display: 'none' }}
                      onChange={(e) => onPhotoFile('avatar', e.target.files?.[0])}
                    />
                  </label>
                </div>
                <h3 style={{ fontSize: '1.2rem' }} id="profName">
                  {user?.name || 'Your account'}
                </h3>
                <p className="mut small" id="profMeta">
                  {user ? meta : 'Virello member'}
                </p>
                <div style={{ display: 'flex', gap: 8, justifyContent: 'center', marginTop: 14, flexWrap: 'wrap' }}>
                  <span className="ai-chip" id="profPlanChip">
                    {plan} Plan
                  </span>
                  <span className="ai-chip" id="profCreditsChip">
                    AI credits: {credits}
                  </span>
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 10, marginTop: 20 }}>
                  <div>
                    <b style={{ fontFamily: 'var(--font-d)' }} id="profStatPlan">
                      {plan}
                    </b>
                    <p className="tiny mut">Current plan</p>
                  </div>
                  <div>
                    <b style={{ fontFamily: 'var(--font-d)' }} id="profStatCredits">
                      {credits}
                    </b>
                    <p className="tiny mut">AI credits</p>
                  </div>
                  <div>
                    <b style={{ fontFamily: 'var(--font-d)' }} id="profStatPoints">
                      {points}
                    </b>
                    <p className="tiny mut">Reward points</p>
                  </div>
                </div>
              </div>
            </div>
            <div className="panel">
              <h3 style={{ marginBottom: 14 }}>Subscription &amp; credits</h3>
              <div style={{ display: 'flex', justifyContent: 'space-between' }} className="small">
                <span className="mut">Current plan</span>
                <b id="subPlan">{plan}</b>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 10 }} className="small">
                <span className="mut">AI credits</span>
                <b id="subCredits">{credits}</b>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 10 }} className="small">
                <span className="mut">Reward points</span>
                <b id="subPoints">{points}</b>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 10 }} className="small">
                <span className="mut">Points level</span>
                <b id="subLevel">{level}</b>
              </div>
              <a className="btn btn-ghost btn-sm" href="/pricing.html" style={{ marginTop: 18, width: '100%' }}>
                Manage Plan
              </a>
            </div>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
            <div
              className="panel"
              id="profFormPanel"
              ref={formPanelRef}
              style={flash ? { boxShadow: '0 0 0 3px rgba(249,81,119,.45)' } : undefined}
            >
              <h3 style={{ marginBottom: 18 }}>Account information</h3>
              <div className="two-col" style={{ gap: 14 }}>
                <div className="field">
                  <label className="lbl" htmlFor="pfName">
                    Full name
                  </label>
                  <input
                    className="inp"
                    id="pfName"
                    ref={nameRef}
                    autoComplete="name"
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                  />
                </div>
                <div className="field">
                  <label className="lbl" htmlFor="pfEmail">
                    Email
                  </label>
                  <input
                    className="inp"
                    type="email"
                    id="pfEmail"
                    readOnly
                    title="Your account email"
                    value={email}
                    onChange={() => {
                      /* readonly — legacy parity */
                    }}
                  />
                </div>
                <div className="field">
                  <label className="lbl" htmlFor="pfCountry">
                    Country
                  </label>
                  <select
                    className="sel"
                    id="pfCountry"
                    value={country}
                    onChange={(e) => setCountry(e.target.value)}
                  >
                    {COUNTRIES.map((c) => (
                      <option key={c}>{c}</option>
                    ))}
                  </select>
                </div>
                <div className="field">
                  <label className="lbl" htmlFor="pfLanguage">
                    Language
                  </label>
                  <select
                    className="sel"
                    id="pfLanguage"
                    value={language}
                    onChange={(e) => setLanguage(e.target.value)}
                  >
                    <option value="en">English</option>
                    <option value="ur">Urdu</option>
                    <option value="ar">Arabic</option>
                  </select>
                </div>
              </div>
              <button className="btn btn-pink btn-sm" id="pfSaveBtn" onClick={saveProfile} disabled={saving} type="button">
                {saving ? 'Saving…' : 'Save Changes'}
              </button>
            </div>
            <div className="panel">
              <h3 style={{ marginBottom: 8 }}>Connected platforms</h3>
              <p className="mut small" style={{ marginBottom: 8 }}>
                Connected through official sign-in. Virello never stores your passwords.
              </p>
              <div id="platList">
                {platforms === null ? (
                  <p className="small mut" style={{ margin: 0 }}>
                    Loading your connected platforms…
                  </p>
                ) : (
                  PLATFORMS.map((p) => {
                    const on = platforms.includes(p.key);
                    return (
                      <div className="pref-row" key={p.key}>
                        <span className="thumb" style={{ background: p.bg }}>
                          {p.icon}
                        </span>
                        <div style={{ flex: 1 }}>
                          <b style={{ fontSize: '.93rem' }}>{p.label}</b>
                          <p className="tiny mut">
                            {on ? 'Connected to your Virello account' : 'Not connected'}
                          </p>
                        </div>
                        {on ? (
                          <span className="badge b-active">Connected</span>
                        ) : (
                          <span className="tiny mut">Not connected</span>
                        )}
                      </div>
                    );
                  })
                )}
              </div>
            </div>
            <div className="panel">
              <h3 style={{ marginBottom: 8 }}>Security</h3>
              <div className="pref-row">
                <div style={{ flex: 1 }}>
                  <b style={{ fontSize: '.93rem' }}>Password</b>
                  <p className="tiny mut">We will email you a secure link to set a new password</p>
                </div>
                <button className="btn btn-ghost btn-sm" onClick={changePassword} disabled={sendingReset} type="button">
                  {sendingReset ? 'Sending…' : 'Change'}
                </button>
              </div>
            </div>
            <div className="panel">
              <h3 style={{ marginBottom: 8 }}>Preferences</h3>
              {(
                [
                  ['tips', 'AI Recommendations', 'Weekly optimization tips from your AI agents', 'pfPrefTips'],
                  ['alerts', 'Campaign alerts', 'Notify me when a campaign finishes or needs approval', 'pfPrefAlerts'],
                  ['news', 'Product news', 'New features and growth guides', 'pfPrefNews'],
                ] as const
              ).map(([key, label, sub, id]) => (
                <div className="pref-row" key={key}>
                  <div style={{ flex: 1 }}>
                    <b style={{ fontSize: '.93rem' }}>{label}</b>
                    <p className="tiny mut">{sub}</p>
                  </div>
                  <label className="switch">
                    <input
                      type="checkbox"
                      id={id}
                      checked={prefs[key]}
                      onChange={(e) => savePrefs({ ...prefs, [key]: e.target.checked })}
                    />
                    <i />
                  </label>
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>
    </AppShell>
  );
}
