// Auth helpers — port of the legacy SPA session/auth code
// (legacy index.html:2795-2848, 2851-2900, 3866-3878).
// Storage keys are identical to legacy; do not rename them.
// Session watchdog lives in Header.tsx (it already uses these same
// keys and the same refresh endpoint) — this module is the shared
// auth client P3 imports; there is NO login gate anywhere (legacy
// parity: app routes render logged-out too).

import { API_BASE } from './api';
import { showToast } from './toast';

export const SESSION_IDLE_MS = 30 * 60 * 1000;
export const SESSION_MAX_MS = 24 * 60 * 60 * 1000;

const K_TOKEN = 'virello_token';
const K_REFRESH = 'virello_refresh_token';
const K_USER = 'virello_user';
const K_LOGIN_AT = 'virello_login_at';
const K_LAST_AT = 'virello_last_at';
const K_PLAN = 'virello_plan';

function lsGet(key: string): string | null {
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
}

function lsSet(key: string, value: string): void {
  try {
    localStorage.setItem(key, value);
  } catch {
    /* storage unavailable */
  }
}

function lsRemove(key: string): void {
  try {
    localStorage.removeItem(key);
  } catch {
    /* storage unavailable */
  }
}

export function getToken(): string | null {
  return lsGet(K_TOKEN);
}

export function getRefreshToken(): string | null {
  return lsGet(K_REFRESH);
}

/** Store the token pair + stamp login/last-activity to now. */
export function setSession(access: string, refresh?: string | null): void {
  const now = String(Date.now());
  lsSet(K_TOKEN, access);
  if (refresh) lsSet(K_REFRESH, refresh);
  lsSet(K_LOGIN_AT, now);
  lsSet(K_LAST_AT, now);
}

/** Remove all five session keys (legacy clearSessionKeys). */
export function clearSession(): void {
  lsRemove(K_TOKEN);
  lsRemove(K_REFRESH);
  lsRemove(K_USER);
  lsRemove(K_LAST_AT);
  lsRemove(K_LOGIN_AT);
}

/** !!virello_token — what updateAuthUI uses. */
export function hasToken(): boolean {
  return !!getToken();
}

/**
 * !!virello_user — legacy parity. Campaigns empty-state + Free-plan
 * checks use this, NOT the token. Note: virello_user is written by
 * fetchMe (GET /users/me), so it is empty right after login until the
 * first profile fetch — same as legacy.
 */
export function isLoggedIn(): boolean {
  return !!lsGet(K_USER);
}

/** Base64url-decode a JWT exp claim → ms since epoch; 0 on failure. */
export function tokenExpMs(tok: string): number {
  try {
    const p = tok.split('.')[1];
    if (!p) return 0;
    let s = p.replace(/-/g, '+').replace(/_/g, '/');
    while (s.length % 4) s += '=';
    const j = JSON.parse(atob(s)) as { exp?: number };
    return j.exp ? j.exp * 1000 : 0;
  } catch {
    return 0;
  }
}

let _refreshPromise: Promise<boolean> | null = null;

/**
 * POST {API_BASE}/auth/refresh {refresh_token}; stores the new pair.
 * Concurrent calls share one in-flight request (deduped via a shared
 * promise, legacy parity). Returns false on any failure.
 */
export async function refreshAccessToken(): Promise<boolean> {
  if (_refreshPromise) return _refreshPromise;
  const rt = getRefreshToken();
  if (!rt) return Promise.resolve(false);
  _refreshPromise = fetch(`${API_BASE}/auth/refresh`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ refresh_token: rt }),
  })
    .then((r) =>
      r
        .json()
        .catch(() => ({}))
        .then((d) => ({ res: r, data: d as Record<string, unknown> })),
    )
    .then(({ res, data }) => {
      const nested = data.data as Record<string, unknown> | undefined;
      const at = (data.access_token ?? nested?.access_token) as
        | string
        | undefined;
      const nrt = (data.refresh_token ?? nested?.refresh_token) as
        | string
        | undefined;
      // Legacy also accepts data.token here; refresh responses use
      // access_token, so keep the same extraction as the watchdog.
      if (res.ok && at) {
        lsSet(K_TOKEN, at);
        if (nrt) lsSet(K_REFRESH, nrt);
        lsSet(K_LAST_AT, String(Date.now()));
        return true;
      }
      return false;
    })
    .catch(() => false)
    .then((ok) => {
      _refreshPromise = null;
      return ok;
    });
  return _refreshPromise;
}

function redirectToLogin(): void {
  try {
    if (window.location.pathname !== '/login.html') {
      window.location.href = '/login.html';
    }
  } catch {
    /* not in a browser */
  }
}

/**
 * Authenticated fetch — mirrors legacy apiAuth (index.html:3866-3878):
 * Bearer token; on 401 (and token present) refresh once, retry once
 * with the new token; if the refresh fails or the retry also 401s →
 * clearSession() + redirect /login.html.
 * Returns the raw Response (callers parse the body themselves).
 */
export async function apiAuth(
  path: string,
  init: RequestInit = {},
): Promise<Response> {
  const tok = getToken();
  const headers: Record<string, string> = {
    ...(init.headers as Record<string, string> | undefined),
  };
  if (!init.body || typeof init.body === 'string') {
    headers['Content-Type'] = headers['Content-Type'] ?? 'application/json';
  }
  if (tok) headers['Authorization'] = `Bearer ${tok}`;

  const res = await fetch(`${API_BASE}${path}`, { ...init, headers });
  if (res.status === 401 && tok) {
    const ok = await refreshAccessToken();
    if (!ok) {
      clearSession();
      redirectToLogin();
      return res;
    }
    const tok2 = getToken();
    const headers2: Record<string, string> = { ...headers };
    if (tok2) headers2['Authorization'] = `Bearer ${tok2}`;
    const retry = await fetch(`${API_BASE}${path}`, {
      ...init,
      headers: headers2,
    });
    if (retry.status === 401) {
      clearSession();
      redirectToLogin();
    }
    return retry;
  }
  return res;
}

export type AuthResult = { ok: boolean; error?: string };

/**
 * Map a failed auth response to a friendly message — legacy
 * friendlyAuthError (index.html:2808-2814).
 */
export function friendlyAuthError(
  status: number,
  data: unknown,
): string {
  let d = '';
  if (data && typeof data === 'object') {
    const rec = data as Record<string, unknown>;
    if (typeof rec.detail === 'string') d = rec.detail;
    else if (Array.isArray(rec.detail) && rec.detail.length) {
      const first = rec.detail[0] as Record<string, unknown> | undefined;
      if (first && typeof first.msg === 'string') d = first.msg;
    } else if (typeof rec.message === 'string') d = rec.message;
  }
  if (status === 401)
    return 'Incorrect email or password. Please check both and try again.';
  if (status === 409)
    return (
      d ||
      'An account with this email already exists — try logging in instead.'
    );
  if (status === 422)
    return d
      ? `Please check your details: ${d}`
      : 'Please check your details and try again.';
  if (status === 429)
    return 'Too many attempts. Please wait a few minutes and try again.';
  if (d && d.length < 160) return d;
  return 'Something went wrong on our side. Please try again in a moment.';
}

function extractTokens(data: Record<string, unknown>): {
  token: string | undefined;
  refresh: string | undefined;
} {
  const nested = data.data as Record<string, unknown> | undefined;
  const token = (data.access_token ??
    data.token ??
    nested?.access_token ??
    nested?.token) as string | undefined;
  const refresh = (data.refresh_token ?? nested?.refresh_token) as
    | string
    | undefined;
  return { token, refresh };
}

async function postAuth(
  endpoint: string,
  payload: Record<string, string>,
): Promise<{ res: Response; data: Record<string, unknown> }> {
  const res = await fetch(`${API_BASE}${endpoint}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  const data = (await res.json().catch(() => ({}))) as Record<
    string,
    unknown
  >;
  return { res, data };
}

/**
 * POST /auth/password/login. On success stores the session (token
 * extraction order: access_token → token → data.access_token →
 * data.token). Never sends referral_code (legacy parity).
 */
export async function login(
  email: string,
  password: string,
): Promise<AuthResult> {
  let res: Response;
  let data: Record<string, unknown>;
  try {
    ({ res, data } = await postAuth('/auth/password/login', {
      email,
      password,
    }));
  } catch {
    return {
      ok: false,
      error:
        'Could not reach the Virello server. Check your internet connection and try again.',
    };
  }
  if (!res.ok) return { ok: false, error: friendlyAuthError(res.status, data) };
  const { token, refresh } = extractTokens(data);
  if (token) setSession(token, refresh);
  return { ok: true };
}

/**
 * POST /auth/password/signup {email, password, name}. Returns ok:false
 * with error 'ACCOUNT_CREATED_LOGIN' when the account was created but
 * no token came back — the caller switches to the login tab and shows
 * the "now log in" info message (legacy parity).
 */
export async function signup(
  email: string,
  password: string,
  name: string,
): Promise<AuthResult> {
  let res: Response;
  let data: Record<string, unknown>;
  try {
    ({ res, data } = await postAuth('/auth/password/signup', {
      email,
      password,
      name,
    }));
  } catch {
    return {
      ok: false,
      error:
        'Could not reach the Virello server. Check your internet connection and try again.',
    };
  }
  if (!res.ok) return { ok: false, error: friendlyAuthError(res.status, data) };
  const { token, refresh } = extractTokens(data);
  if (token) {
    setSession(token, refresh);
    return { ok: true };
  }
  return { ok: false, error: 'ACCOUNT_CREATED_LOGIN' };
}

/**
 * POST /auth/password/reset/request {email}. Resolves on 200/404/422
 * (legacy treats all three as "if an account exists…" — the reset
 * link is on its way). Throws on any other status or network failure.
 */
export async function requestPasswordReset(email: string): Promise<void> {
  const res = await fetch(`${API_BASE}/auth/password/reset/request`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email }),
  });
  if (res.ok || res.status === 404 || res.status === 422) return;
  throw new Error(`reset request failed: ${res.status}`);
}

/**
 * Clear the session, toast, and redirect.
 * Default '/' (Header's logout parity); fromApp → '/login.html'
 * (plan §2.1).
 * NOTE (flagged): legacy logout() goes to #/home from app routes,
 * not #/login — the plan's /login.html is followed here, but the
 * legacy behaviour differs. See final report.
 */
export function logout(fromApp = false): void {
  clearSession();
  try {
    document.documentElement.setAttribute('data-auth', 'out');
  } catch {
    /* ignore */
  }
  showToast('You have been logged out.');
  // Brief pause so the toast is seen before the page changes
  // (legacy parity: the toast fires before any navigation).
  window.setTimeout(() => {
    window.location.href = fromApp ? '/login.html' : '/';
  }, 600);
}

/** Write-only plan key (legacy parity — written, never read). */
export function setPlan(plan: string): void {
  lsSet(K_PLAN, plan);
}
