// Website tour — port of the legacy SPA tour (index.html:3970-4014).
//
// Legacy behavior, preserved:
// - 9 steps: home hero → features → dashboard grow-box → Creator Hub →
//   Distribution → Spotlight → campaigns table → analytics KPIs →
//   settings. Steps whose target element is absent are skipped
//   gracefully (the tip still shows, just without a highlight).
// - Auto-starts on first login (virello_tour_seen unset): the login
//   page sets a sessionStorage pending flag before redirecting; the
//   TourRunner starts the tour 900 ms after the new page loads.
// - Esc ends the tour. startTour() marks the tour seen immediately.
// - Navigation between steps: in the SPA this was a hash change in
//   the same document; in Next each step route is a real page, so the
//   active step index lives in sessionStorage and survives the
//   full-page navigation (virello_tour_active + virello_tour_idx).
// - "Take a Tour" in Settings calls startTour() directly.

export type TourStep = { route: string; selector: string; title: string; text: string };

export const TOUR: TourStep[] = [
  {
    route: 'home',
    selector: '.hero',
    title: 'Welcome to Virello',
    text: 'Your AI Growth Manager for social media — paste a post, pick a goal, and let AI grow. Legit organic growth, no bots, ever.',
  },
  {
    route: 'home',
    selector: '#page-features',
    title: 'Features',
    text: 'Everything Virello does — AI content analysis, audience insights, campaign automation and more.',
  },
  {
    route: 'dashboard',
    selector: '.grow-box',
    title: 'Grow a new post',
    text: 'Paste any post link, pick your goal and press LET AI GROW. After that, use the two buttons to repurpose it or get featured.',
  },
  {
    route: 'dashboard',
    selector: '#creatorCards',
    title: 'Creator Hub — 14 free tools',
    text: 'AI Image Studio, Video Creator, Script Writer, Voiceover Studio and more. All free, no credit charge.',
  },
  {
    route: 'dashboard',
    selector: '#cardDistribute',
    title: 'Distribution Engine',
    text: 'One post becomes five — platform-optimized versions for Instagram, TikTok, YouTube, X and Facebook, with your link in the right place.',
  },
  {
    route: 'dashboard',
    selector: '#cardSpotlight',
    title: 'Get Featured',
    text: 'Submit your best post for Virello Spotlight. If selected, we feature it on our official accounts with credit to you.',
  },
  {
    route: 'campaigns',
    selector: '#campTable',
    title: 'Campaigns',
    text: 'Every AI campaign running for you — reach, engagement, budget and progress in one table.',
  },
  {
    route: 'analytics',
    selector: '#page-analytics .kpi-grid',
    title: 'Analytics',
    text: 'Your performance across all connected platforms. Connect your accounts to see real numbers.',
  },
  {
    route: 'settings',
    selector: '#page-settings',
    title: 'Settings',
    text: 'Appearance, language, notifications, privacy and your account — all in one place.',
  },
];

export const TOUR_ROUTES: Record<string, string> = {
  home: '/',
  dashboard: '/dashboard.html',
  campaigns: '/campaigns.html',
  analytics: '/analytics.html',
  settings: '/settings.html',
};

const K_SEEN = 'virello_tour_seen';
const K_ACTIVE = 'virello_tour_active';
const K_IDX = 'virello_tour_idx';
const K_PENDING = 'virello_tour_pending';

/** Event the TourRunner listens for (startTour dispatches it). */
export const TOUR_START_EVENT = 'virello:tour-start';

export function tourSeen(): boolean {
  try {
    return localStorage.getItem(K_SEEN) === '1';
  } catch {
    return false;
  }
}

export function tourMarkSeen(): void {
  try {
    localStorage.setItem(K_SEEN, '1');
  } catch {
    /* storage unavailable */
  }
}

export function getTourIndex(): number {
  try {
    const v = parseInt(sessionStorage.getItem(K_IDX) || '-1', 10);
    return Number.isFinite(v) ? v : -1;
  } catch {
    return -1;
  }
}

export function isTourActive(): boolean {
  try {
    return sessionStorage.getItem(K_ACTIVE) === '1';
  } catch {
    return false;
  }
}

export function setTourIndex(idx: number): void {
  try {
    sessionStorage.setItem(K_ACTIVE, '1');
    sessionStorage.setItem(K_IDX, String(idx));
  } catch {
    /* storage unavailable */
  }
}

export function endTourState(): void {
  try {
    sessionStorage.removeItem(K_ACTIVE);
    sessionStorage.removeItem(K_IDX);
  } catch {
    /* storage unavailable */
  }
}

/** Start (or restart) the tour from step 0. Marks it seen, like legacy. */
export function startTour(): void {
  tourMarkSeen();
  setTourIndex(0);
  try {
    window.dispatchEvent(new CustomEvent(TOUR_START_EVENT));
  } catch {
    /* not in a browser */
  }
}

/** End the tour (clears the active state). */
export function endTour(): void {
  endTourState();
  try {
    window.dispatchEvent(new CustomEvent('virello:tour-end'));
  } catch {
    /* not in a browser */
  }
}

/**
 * Called by the login form on first login, before the redirect:
 * the TourRunner on the landing page picks this up and starts the
 * tour 900 ms after navigation (legacy: startTour 900 ms after
 * navigation, index.html:2836-2837).
 */
export function scheduleTourAfterLogin(): void {
  try {
    sessionStorage.setItem(K_PENDING, '1');
  } catch {
    /* storage unavailable */
  }
}

/** Consumed once by the TourRunner on the landing page. */
export function consumeTourPending(): boolean {
  try {
    if (sessionStorage.getItem(K_PENDING) === '1') {
      sessionStorage.removeItem(K_PENDING);
      return true;
    }
    return false;
  } catch {
    return false;
  }
}
