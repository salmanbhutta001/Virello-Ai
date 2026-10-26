'use client';

import { useEffect } from 'react';

// Hash-redirect (plan §1.5 / §4): old `#/…` SPA links keep working.
// Runs once per load, before anything else the page does. If the URL
// hash matches a legacy route, replace it with the clean Next URL,
// preserving query strings:
//   #/login?plan=free&next=dashboard → /login.html?plan=free&next=dashboard
//   #/dashboard → /dashboard.html
//   #/campaigns / #/analytics / #/profile / #/settings / #/shop → *.html
//   #/product/{asin} → /product.html?asin={asin}
//   #/home → /
// Anything else (e.g. in-page anchors like #pricing) is left alone.
// NOTE: this lives in the root layout so it covers every page, not
// just the homepage.
export default function HashRedirect() {
  useEffect(() => {
    const hash = window.location.hash;
    if (!hash || !hash.startsWith('#/')) return;
    const rest = hash.slice(2); // e.g. "login?plan=free" / "product/B07F8S18D5"
    const [pathPart, queryPart] = rest.split('?');
    const query = queryPart ? `?${queryPart}` : '';
    const clean: Record<string, string> = {
      home: '/',
      login: '/login.html',
      dashboard: '/dashboard.html',
      campaigns: '/campaigns.html',
      analytics: '/analytics.html',
      profile: '/profile.html',
      settings: '/settings.html',
      shop: '/shop.html',
    };
    let target: string | null = null;
    if (Object.prototype.hasOwnProperty.call(clean, pathPart)) {
      target = clean[pathPart] + query;
    } else if (pathPart.startsWith('product/')) {
      const asin = pathPart.slice('product/'.length);
      if (asin) target = `/product.html?asin=${encodeURIComponent(asin)}`;
    }
    if (target) {
      window.location.replace(target);
    }
  }, []);
  return null;
}
