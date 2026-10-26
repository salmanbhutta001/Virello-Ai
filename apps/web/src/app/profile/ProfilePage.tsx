'use client';

import { useEffect, useRef, useState } from 'react';
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

const PLATFORMS: { key: string; label: string; bg: string }[] = [
  { key: 'instagram', label: 'Instagram', bg: 'linear-gradient(135deg,#F95177,#D6336C)' },
  { key: 'tiktok', label: 'TikTok', bg: '#1F2937' },
  { key: 'youtube', label: 'YouTube', bg: '#7F1D1D' },
  { key: 'facebook', label: 'Facebook', bg: '#1D4ED8' },
  { key: 'x', label: 'X', bg: '#111827' },
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
                        <span className="thumb" style={{ background: p.bg }} />
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
