// User/profile helpers — port of the legacy SPA profile code
// (index.html:3839-3864 avatars, 3865 planLabel, 3879-3911 fetchMe /
// paintUserUI / fillProfileForm, 3921-3925 platforms, 3961-3968 photo
// upload). Used by AppShell (user card) and the profile page. The
// 60 s fetchMe cache and the virello_user localStorage cache match
// legacy exactly; there is NO login gate (app routes render logged
// out too — callers get null and show placeholder states).

import { useEffect, useState } from 'react';
import { API_BASE } from './api';
import { apiAuth, getToken } from './auth';

export type UserProfile = {
  name?: string;
  email?: string;
  plan?: string;
  credits?: number | null;
  points_balance?: number | null;
  points_level?: number | null;
  preferred_language?: string;
  locale?: string;
  avatar_url?: string;
  cover_url?: string;
  [key: string]: unknown;
};

/** free→Free, pro→Pro, scale→Scale, growth→Growth, starter→Starter. */
export function planLabel(p?: string | null): string {
  const v = (p || 'free').toLowerCase();
  if (v === 'pro') return 'Pro';
  if (v === 'scale') return 'Scale';
  if (v === 'growth') return 'Growth';
  if (v === 'starter') return 'Starter';
  return 'Free';
}

export function getCachedUser(): UserProfile | null {
  try {
    const raw = localStorage.getItem('virello_user');
    if (!raw) return null;
    return JSON.parse(raw) as UserProfile;
  } catch {
    return null;
  }
}

export function getLocalAvatar(): string | null {
  try {
    return localStorage.getItem('virello_avatar');
  } catch {
    return null;
  }
}

export function getLocalCover(): string | null {
  try {
    return localStorage.getItem('virello_cover');
  } catch {
    return null;
  }
}

let _meCache: UserProfile | null = null;
let _meCacheAt = 0;

/**
 * GET /api/v1/users/me via apiAuth (401 → refresh once, retry once,
 * else clear session + redirect — same as legacy apiAuth). 60 s cache.
 * Returns null when there is no token (logged out) or the call fails —
 * never throws.
 */
export async function fetchMe(force = false): Promise<UserProfile | null> {
  const now = Date.now();
  if (!force && _meCache && now - _meCacheAt < 60000) return _meCache;
  if (!getToken()) return null;
  try {
    const res = await apiAuth('/api/v1/users/me');
    if (!res.ok) return null;
    const data = (await res.json().catch(() => null)) as UserProfile | null;
    if (!data) return null;
    _meCache = data;
    _meCacheAt = Date.now();
    try {
      localStorage.setItem('virello_user', JSON.stringify(data));
    } catch {
      /* storage unavailable */
    }
    return data;
  } catch {
    return null;
  }
}

/** Clear the fetchMe cache (legacy sets _meCache = null after a save). */
export function clearMeCache(): void {
  _meCache = null;
  _meCacheAt = 0;
}

/**
 * GET /api/v1/connected-accounts via apiAuth. Returns the connected
 * platform keys (lowercased), or [] on any failure (legacy parity:
 * any failure renders all five rows as not-connected).
 */
export async function loadPlatforms(): Promise<string[]> {
  try {
    const res = await apiAuth('/api/v1/connected-accounts');
    if (!res.ok) return [];
    const data = (await res.json().catch(() => ({}))) as {
      connected?: unknown;
    };
    const list = Array.isArray(data.connected) ? data.connected : [];
    return list.map((x) => String(x).toLowerCase());
  } catch {
    return [];
  }
}

/**
 * Downscale an image file to max 800 px, JPEG 0.82, as a data URL
 * (legacy readImgFile, index.html:3839-3852).
 */
export function readImgFile(
  file: File,
  cb: (dataUrl: string) => void,
): void {
  const reader = new FileReader();
  reader.onload = () => {
    const img = new Image();
    img.onload = () => {
      const s = Math.min(1, 800 / Math.max(img.width, img.height));
      const c = document.createElement('canvas');
      c.width = Math.round(img.width * s);
      c.height = Math.round(img.height * s);
      c.getContext('2d')?.drawImage(img, 0, 0, c.width, c.height);
      cb(c.toDataURL('image/jpeg', 0.82));
    };
    img.src = String(reader.result);
  };
  reader.readAsDataURL(file);
}

/**
 * POST /api/v1/uploads (FormData, Bearer token — direct fetch, NOT
 * apiAuth, legacy parity) then PATCH /api/v1/users/me
 * {avatar_url|cover_url}. Silent on failure (legacy parity — the
 * local downscaled copy is what the UI shows immediately).
 */
export async function uploadProfilePhoto(
  kind: 'avatar' | 'cover',
  file: File,
): Promise<void> {
  const tok = getToken();
  if (!tok || !file) return;
  const fd = new FormData();
  fd.append('file', file);
  try {
    const res = await fetch(`${API_BASE}/api/v1/uploads`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${tok}` },
      body: fd,
    });
    const d = (await res.json().catch(() => ({}))) as { url?: string };
    if (!d || !d.url) return;
    const body: Record<string, string> = {};
    body[kind === 'cover' ? 'cover_url' : 'avatar_url'] = API_BASE + d.url;
    await apiAuth('/api/v1/users/me', {
      method: 'PATCH',
      body: JSON.stringify(body),
    });
    clearMeCache();
  } catch {
    /* silent — legacy parity */
  }
}

/**
 * Legacy syncServerPhoto (index.html:3926-3933): if there is no local
 * avatar copy but the server user has an avatar_url, fetch it (with
 * the token) and store it locally as a data URL. Returns the data URL
 * or null.
 */
export async function syncServerPhoto(
  u: UserProfile | null,
): Promise<string | null> {
  if (getLocalAvatar() || !u || !u.avatar_url) return null;
  const tok = getToken();
  let url = u.avatar_url;
  if (!url.startsWith('http')) url = API_BASE + url;
  try {
    const r = await fetch(url, {
      headers: tok ? { Authorization: `Bearer ${tok}` } : {},
    });
    if (!r.ok) return null;
    const blob = await r.blob();
    return await new Promise<string | null>((resolve) => {
      const fr = new FileReader();
      fr.onload = () => {
        try {
          localStorage.setItem('virello_avatar', String(fr.result));
        } catch {
          /* storage unavailable */
        }
        resolve(String(fr.result));
      };
      fr.onerror = () => resolve(null);
      fr.readAsDataURL(blob);
    });
  } catch {
    return null;
  }
}

/**
 * Shared hook for the app shell + app pages: cached user first
 * (legacy route() paints cached virello_user), then a live fetchMe.
 * Avatar/cover come from the local downscaled copies.
 */
export function useCurrentUser(): {
  user: UserProfile | null;
  avatar: string | null;
  cover: string | null;
  refresh: () => Promise<UserProfile | null>;
} {
  const [user, setUser] = useState<UserProfile | null>(null);
  const [avatar, setAvatar] = useState<string | null>(null);
  const [cover, setCover] = useState<string | null>(null);

  useEffect(() => {
    setUser(getCachedUser());
    setAvatar(getLocalAvatar());
    setCover(getLocalCover());
    let alive = true;
    fetchMe().then((u) => {
      if (alive && u) setUser(u);
    });
    return () => {
      alive = false;
    };
  }, []);

  const refresh = async () => {
    const u = await fetchMe(true);
    if (u) setUser(u);
    return u;
  };

  return { user, avatar, cover, refresh };
}
