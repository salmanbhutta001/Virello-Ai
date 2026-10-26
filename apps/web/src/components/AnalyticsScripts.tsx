'use client';

/**
 * Site-wide analytics scripts (GA4 + AdSense), gated by pathname.
 * /rewards-terms ships with NO GA4 and NO AdSense (legacy parity — it is
 * the only legacy page without them). During static prerender each page
 * renders with its own pathname, so rewards-terms.html exports clean.
 * Note: on client-side navigation TO rewards-terms the tags are removed
 * from the DOM, but a script already loaded on the previous page stays
 * loaded in that tab — the exported file itself carries no tracking.
 */

import Script from 'next/script';
import { usePathname } from 'next/navigation';

export default function AnalyticsScripts() {
  const pathname = usePathname();
  if (pathname === '/rewards-terms') return null;
  return (
    <>
      {/* AdSense — script tag only, no ad units (legacy parity) */}
      <Script
        src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-9465259914673995"
        strategy="afterInteractive"
        crossOrigin="anonymous"
      />
      {/* GA4 — virelloai.online web stream */}
      <Script
        src="https://www.googletagmanager.com/gtag/js?id=G-X3T458F82Y"
        strategy="afterInteractive"
      />
      <Script id="ga4" strategy="afterInteractive">
        {`window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments);}gtag('js',new Date());gtag('config','G-X3T458F82Y');`}
      </Script>
    </>
  );
}
