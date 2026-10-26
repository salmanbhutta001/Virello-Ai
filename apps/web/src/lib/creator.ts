/**
 * Creator Hub API layer — plan §2.3 (P4).
 *
 * Exact interface from the migration plan:
 *   WP_AI_PATHS — the 4 paths that go through the WordPress proxy
 *   creatorApi(path, body) — { ok, res, data }, NO auth header (legacy parity)
 *
 * Proxy pattern (same as CaptionTool in
 * src/app/free-caption-generator/CaptionTool.tsx): relative
 * `ai-proxy.php?p=...` first, absolute `https://virelloai.online/` fallback.
 * The fallback fires when the relative call cannot be reached (e.g. the page
 * is previewed off-origin) — same as CaptionTool, which retries on any
 * failure of the relative call, including a non-OK proxy response.
 *
 * NOTE — API_BASE trap: the Next `API_BASE` (src/lib/api.ts) already ends
 * in `/api/v1`, while legacy `API_BASE` was the bare origin and the paths
 * below start with `/api/v1/...`. Direct (non-proxy) calls therefore use
 * the origin with the trailing `/api/v1` stripped, so the path is NOT
 * doubled (`/api/v1/api/v1/...`). The proxy paths are sent verbatim as the
 * `p=` value, exactly like legacy.
 *
 * TOAST — merged with P2: `notify()` delegates to the single global
 * `showToast` from `./toast` (element #toast in <ToastRoot />).
 */

import { API_BASE } from './api';
import { showToast } from './toast';

export const WP_AI_PATHS: string[] = [
  '/api/v1/media/generate-text',
  '/api/v1/media/generate-caption',
  '/api/v1/media/generate-image',
  '/api/v1/distribution/repurpose',
];

/** Origin without the trailing `/api/v1` (see header note). */
const API_ORIGIN = API_BASE.replace(/\/api\/v1\/?$/, '');

export type CreatorApiResult = {
  ok: boolean;
  res: Response;
  data: unknown;
};

type JsonRecord = Record<string, unknown>;

function asRecord(data: unknown): JsonRecord {
  return data !== null && typeof data === 'object' && !Array.isArray(data)
    ? (data as JsonRecord)
    : {};
}

/** Pull a human-readable `detail`/`message` out of an API error payload. */
export function apiErrorMessage(data: unknown, fallback: string): string {
  const d = asRecord(data);
  const detail = d.detail;
  const message = d.message;
  if (typeof detail === 'string' && detail.trim() !== '') return detail;
  if (typeof message === 'string' && message.trim() !== '') return message;
  return fallback;
}

export async function creatorApi(
  path: string,
  body?: unknown,
): Promise<CreatorApiResult> {
  const isProxy = WP_AI_PATHS.includes(path);
  const urls = isProxy
    ? [
        `ai-proxy.php?p=${encodeURIComponent(path)}`,
        `https://virelloai.online/ai-proxy.php?p=${encodeURIComponent(path)}`,
      ]
    : [`${API_ORIGIN}${path}`];

  let lastError: unknown = null;
  for (let i = 0; i < urls.length; i++) {
    const url = urls[i];
    const isLast = i === urls.length - 1;
    try {
      const res = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body ?? {}),
      });
      const data: unknown = await res.json().catch(() => ({}));
      // A non-OK relative proxy response usually means the page is
      // previewed off-origin (ai-proxy.php not reachable there) — try the
      // absolute URL once, mirroring CaptionTool. Any other outcome is final.
      if (!res.ok && isProxy && !isLast) continue;
      return { ok: res.ok, res, data };
    } catch (e) {
      lastError = e;
      if (isLast) throw e;
    }
  }
  // Unreachable in practice (the loop either returns or throws).
  throw lastError instanceof Error
    ? lastError
    : new Error('Could not reach the Virello server.');
}

/** Assemble-video endpoint (direct to API_BASE — NOT a WP_AI_PATHS proxy path). */
export const ASSEMBLE_VIDEO_PATH = '/api/v1/media/assemble-video';

export function assembleVideoUrl(): string {
  return `${API_BASE}/media/assemble-video`;
}

/* ------------------------------------------------------------------ */
/* Toast — local fallback until P2's src/lib/toast.ts lands (see header) */
/* ------------------------------------------------------------------ */

/**
 * Show a short toast — delegates to the single global toast (P2's
 * showToast, element #toast in <ToastRoot />). No second toast system.
 */
export function notify(msg: string): void {
  showToast(msg);
}

/* ------------------------------------------------------------------ */
/* Shared small helpers (clipboard + downloads, legacy parity)         */
/* ------------------------------------------------------------------ */

/** Clipboard write with the legacy execCommand fallback. Returns success. */
export async function copyText(text: string): Promise<boolean> {
  try {
    await navigator.clipboard.writeText(text);
    return true;
  } catch {
    try {
      const ta = document.createElement('textarea');
      ta.value = text;
      ta.style.position = 'fixed';
      ta.style.opacity = '0';
      document.body.appendChild(ta);
      ta.select();
      document.execCommand('copy');
      document.body.removeChild(ta);
      return true;
    } catch {
      return false;
    }
  }
}

/** Download a Blob under `name` (legacy Blob-download pattern). */
export function downloadBlob(blob: Blob, name: string): void {
  const u = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = u;
  a.download = name;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(u), 2000);
}

/** Download plain text under `name`. */
export function downloadText(text: string, name: string): void {
  downloadBlob(new Blob([text], { type: 'text/plain' }), name);
}

/**
 * Download a remote URL: fetch → blob → save, falling back to opening the
 * URL in a new tab when the fetch fails (legacy `creatorDl` parity).
 */
export function downloadUrl(url: string, name: string): void {
  fetch(url)
    .then((r) => r.blob())
    .then((b) => downloadBlob(b, name))
    .catch(() => window.open(url, '_blank'));
}

/* ------------------------------------------------------------------ */
/* Drafts — in-memory only, lost on reload (legacy parity)             */
/* ------------------------------------------------------------------ */

export type DraftType = 'image' | 'video' | 'caption';

export type Draft = {
  type: DraftType;
  title: string;
  thumb: string;
  text: string;
};

export function draftKindLabel(type: DraftType): string {
  return type === 'image'
    ? 'AI Image'
    : type === 'video'
      ? 'Video storyboard'
      : 'Caption & hashtags';
}
