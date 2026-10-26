'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { usePathname } from 'next/navigation';
import {
  TOUR,
  TOUR_ROUTES,
  TOUR_START_EVENT,
  consumeTourPending,
  endTour,
  getTourIndex,
  isTourActive,
  setTourIndex,
  startTour,
} from '@/lib/tour';
import { showToast } from '@/lib/toast';

// Tour overlay + tooltip — renders the legacy tour UI (index.html
// tour overlay + #tourTip markup) on every page so the 9-step tour
// can walk across real Next routes (home → dashboard → campaigns →
// analytics → settings). The active step index lives in
// sessionStorage (src/lib/tour.ts) so it survives each full-page
// navigation; a step whose target element is absent shows its tip
// without a highlight (legacy graceful skip).

function routeFromPath(pathname: string | null): string {
  if (!pathname) return 'home';
  const p = pathname.replace(/\.html$/, '').replace(/^\//, '');
  if (p === '' || p === 'index') return 'home';
  return p;
}

export default function TourRunner() {
  const pathname = usePathname();
  const [stepIdx, setStepIdx] = useState(-1);
  const [shown, setShown] = useState(false);
  const showTimer = useRef<number | null>(null);
  const stepIdxRef = useRef(-1);
  stepIdxRef.current = stepIdx;

  const clearHighlight = useCallback(() => {
    try {
      document
        .querySelectorAll('.tour-hl')
        .forEach((e) => e.classList.remove('tour-hl'));
    } catch {
      /* not in a browser */
    }
  }, []);

  const hide = useCallback(() => {
    if (showTimer.current) window.clearTimeout(showTimer.current);
    clearHighlight();
    setShown(false);
    setStepIdx(-1);
  }, [clearHighlight]);

  const showStep = useCallback(
    (idx: number) => {
      const step = TOUR[idx];
      if (!step) {
        hide();
        return;
      }
      // Wrong route for this step → navigate there; this page's
      // TourRunner picks the step up after the load (legacy tourShow
      // did the same via location.hash).
      if (step.route !== routeFromPath(window.location.pathname)) {
        setTourIndex(idx);
        window.location.href = TOUR_ROUTES[step.route];
        return;
      }
      setTourIndex(idx);
      setStepIdx(idx);
      // Legacy tourShow waits 500 ms before showing the tip.
      if (showTimer.current) window.clearTimeout(showTimer.current);
      showTimer.current = window.setTimeout(() => {
        setShown(true);
      }, 500);
    },
    [hide],
  );

  const goNext = useCallback(() => {
    const idx = stepIdxRef.current;
    if (idx >= TOUR.length - 1) {
      endTour();
      hide();
      showToast('Tour complete — enjoy Virello!');
      return;
    }
    setShown(false);
    showStep(idx + 1);
  }, [hide, showStep]);

  const goBack = useCallback(() => {
    const idx = stepIdxRef.current;
    if (idx > 0) {
      setShown(false);
      showStep(idx - 1);
    }
  }, [showStep]);

  const end = useCallback(() => {
    endTour();
    hide();
  }, [hide]);

  // Resume an in-progress tour after a route change (incl. the first
  // load after the login redirect).
  useEffect(() => {
    if (!isTourActive()) return;
    const idx = getTourIndex();
    if (idx < 0 || idx >= TOUR.length) {
      endTour();
      return;
    }
    const step = TOUR[idx];
    if (step.route !== routeFromPath(pathname)) return; // showStep below navigates
    setStepIdx(idx);
    if (showTimer.current) window.clearTimeout(showTimer.current);
    showTimer.current = window.setTimeout(() => setShown(true), 500);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [pathname]);

  // A tour step on another route triggers navigation from here.
  useEffect(() => {
    if (!isTourActive()) return;
    const idx = getTourIndex();
    if (idx < 0 || idx >= TOUR.length) return;
    const step = TOUR[idx];
    if (step.route !== routeFromPath(pathname)) {
      window.location.href = TOUR_ROUTES[step.route];
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [pathname]);

  // startTour() (Settings button) + the post-login pending flag.
  useEffect(() => {
    const onStart = () => {
      showToast('Website tour started — follow the highlights');
      showStep(0);
    };
    window.addEventListener(TOUR_START_EVENT, onStart);
    // First login: the login page set the pending flag before the
    // redirect — start 900 ms after this page loads (legacy timing).
    if (consumeTourPending()) {
      const t = window.setTimeout(() => {
        startTour();
      }, 900);
      return () => {
        window.removeEventListener(TOUR_START_EVENT, onStart);
        window.clearTimeout(t);
      };
    }
    return () => window.removeEventListener(TOUR_START_EVENT, onStart);
  }, [showStep]);

  // 'virello:tour-end' (fired by endTour from anywhere) hides us.
  useEffect(() => {
    const onEnd = () => hide();
    window.addEventListener('virello:tour-end', onEnd);
    return () => window.removeEventListener('virello:tour-end', onEnd);
  }, [hide]);

  // Esc ends the tour (legacy keydown handler).
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && stepIdxRef.current >= 0) end();
    };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [end]);

  // Highlight the step's target element once the tip shows.
  useEffect(() => {
    if (!shown || stepIdx < 0) return;
    const step = TOUR[stepIdx];
    if (!step) return;
    let el: Element | null = null;
    try {
      el = document.querySelector(step.selector);
    } catch {
      el = null;
    }
    if (el) {
      el.classList.add('tour-hl');
      el.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }
    return () => clearHighlight();
  }, [shown, stepIdx, clearHighlight]);

  if (stepIdx < 0 || !shown) return null;
  const step = TOUR[stepIdx];
  if (!step) return null;

  return (
    <>
      <div
        id="tourOverlay"
        style={{
          display: 'block',
          position: 'fixed',
          inset: 0,
          background: 'rgba(10,10,25,.55)',
          zIndex: 9000,
        }}
      />
      <div
        id="tourTip"
        style={{
          display: 'block',
          position: 'fixed',
          left: '50%',
          transform: 'translateX(-50%)',
          bottom: 22,
          zIndex: 9002,
          width: 'min(430px, 92vw)',
          background: '#fff',
          borderRadius: 18,
          boxShadow: '0 18px 60px rgba(0,0,0,.3)',
          padding: '20px 22px',
          border: '1px solid rgba(249,81,119,.25)',
          color: '#111827',
        }}
      >
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 10,
            marginBottom: 8,
          }}
        >
          <b id="tourTitle" style={{ fontSize: '1.05rem', flex: 1 }}>
            {step.title}
          </b>
          <span id="tourCount" className="tiny mut">
            {stepIdx + 1} / {TOUR.length}
          </span>
        </div>
        <p id="tourText" className="small" style={{ color: '#4B5563', margin: '0 0 16px' }}>
          {step.text}
        </p>
        <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
          <button
            className="btn btn-ghost btn-sm"
            id="tourBack"
            onClick={goBack}
            type="button"
            style={{ visibility: stepIdx === 0 ? 'hidden' : 'visible' }}
          >
            ← Back
          </button>
          <button className="btn btn-ghost btn-sm" onClick={end} type="button">
            Skip
          </button>
          <button
            className="btn btn-pink btn-sm"
            id="tourNext"
            style={{ marginLeft: 'auto' }}
            onClick={goNext}
            type="button"
          >
            {stepIdx === TOUR.length - 1 ? 'Finish' : 'Next →'}
          </button>
        </div>
      </div>
    </>
  );
}
