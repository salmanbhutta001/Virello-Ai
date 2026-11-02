import type { Metadata } from 'next';
import Header from '@/components/Header';
import Footer from '@/components/Footer';
import AnalyticsScripts from '@/components/AnalyticsScripts';
import ToastRoot from '@/components/ToastRoot';
import TourRunner from '@/components/TourRunner';
import HashRedirect from '@/components/HashRedirect';
import './globals.css';

export const metadata: Metadata = {
  metadataBase: new URL('https://virelloai.online'),
  title: {
    default: 'Virello AI — Your AI Growth Manager',
    template: '%s — Virello AI',
  },
  description:
    'Virello AI is your AI Growth Manager: paste a post, choose a goal, set an optional budget, and let AI grow it. Real audiences, honest analytics, no fake engagement.',
  openGraph: {
    siteName: 'Virello AI',
    type: 'website',
    // NOTE: no `url` here on purpose — every public page declares its own
    // openGraph.url matching its canonical (Ahrefs 2026-10-27: the shared
    // homepage URL on all pages read as "OG URL not matching canonical").
    images: [
      {
        url: '/logo-virello.png',
        width: 560,
        height: 175,
        alt: 'Virello AI — Your AI Growth Manager',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Virello AI — Your AI Growth Manager',
    description:
      'Virello AI is your AI Growth Manager: paste a post, choose a goal, set an optional budget, and let AI grow it. Real audiences, honest analytics, no fake engagement.',
    images: ['/logo-virello.png'],
  },
};

// Organization + WebSite graph (AEO/GEO 2026-10-28). sameAs lists only
// real, verifiable profiles — Instagram/TikTok/YouTube/Facebook plus the
// directory listings (ProvenExpert live; GoodFirms + AlternativeTo pending
// review; Product Hunt maker profile). No X: @virelloai is suspended.
// Keep identical to the legacy homepage's graph in
// ~/workspace/your_files/virello-official-website/index.html.
const orgJsonLd = {
  '@context': 'https://schema.org',
  '@graph': [
    {
      '@type': 'Organization',
      '@id': 'https://virelloai.online/#organization',
      name: 'Virello AI',
      url: 'https://virelloai.online/',
      logo: 'https://virelloai.online/logo-virello.png',
      description:
        "Virello AI is your AI Growth Manager: paste a post, choose a goal, set an optional budget, and let AI grow it. Real audiences, honest analytics, no fake engagement.",
      foundingDate: '2026-01-10',
      foundingLocation: 'Multan, Punjab, Pakistan',
      address: {
        '@type': 'PostalAddress',
        addressLocality: 'Multan',
        addressRegion: 'Punjab',
        addressCountry: 'PK',
      },
      email: 'support@virelloai.online',
      sameAs: [
        'https://www.instagram.com/virelloai.online/',
        'https://www.youtube.com/@virelloai.online',
        'https://www.tiktok.com/@virelloai.online',
        'https://www.facebook.com/61595418210450',
        'https://www.provenexpert.com/virello-ai/',
        'https://goodfirms.co/software/virello-ai',
        'https://alternativeto.net/software/virello-ai/',
        'https://www.producthunt.com/@hafiz_muhammad_salman',
      ],
    },
    {
      '@type': 'WebSite',
      '@id': 'https://virelloai.online/#website',
      url: 'https://virelloai.online/',
      name: 'Virello AI',
      publisher: { '@id': 'https://virelloai.online/#organization' },
      inLanguage: 'en',
    },
  ],
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        {/* Organization + WebSite JSON-LD (AEO/GEO 2026-10-28). Same block
            as the legacy homepage's graph — keep the two in sync. */}
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(orgJsonLd) }}
        />
        {/* Pre-paint: apply the shared site theme + login state before
            first paint (same localStorage keys as the main site), so
            these pages never flash the wrong theme or auth buttons. */}
        <script
          dangerouslySetInnerHTML={{
            __html: `(function(){try{var t=localStorage.getItem('virello-theme');document.documentElement.setAttribute('data-theme',t==='light'?'light':'dark');document.documentElement.setAttribute('data-auth',localStorage.getItem('virello_token')?'in':'out');}catch(e){document.documentElement.setAttribute('data-theme','dark');document.documentElement.setAttribute('data-auth','out');}})();`,
          }}
        />
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link
          rel="preconnect"
          href="https://fonts.gstatic.com"
          crossOrigin="anonymous"
        />
        {/* Fonts: load the Google Fonts CSS without blocking first paint.
            The loader script runs during parse and attaches a real onload
            handler before inserting the link, so there is no React
            hydration race (a JSX onLoad prop could miss the event if the
            stylesheet loads first). display=swap keeps text visible in
            fallback fonts until the webfonts arrive. */}
        <script
          dangerouslySetInnerHTML={{
            __html: `(function(){var l=document.createElement('link');l.rel='stylesheet';l.href='https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Sora:wght@600;700;800&display=swap';l.media='print';l.onload=function(){this.media='all'};document.head.appendChild(l);})();`,
          }}
        />
        <noscript>
          <link
            href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Sora:wght@600;700;800&display=swap"
            rel="stylesheet"
          />
        </noscript>
        {/* Microsoft Clarity (heatmaps) — SEO fixes 2026-10-27.
            Project "Virello" created 2026-10-27 14:01, ID z474d70ks5. */}
        <script
          dangerouslySetInnerHTML={{
            __html: `(function(c,l,a,r,i,t,y){c[a]=c[a]||function(){(c[a].q=c[a].q||[]).push(arguments)};t=l.createElement(r);t.async=1;t.src="https://www.clarity.ms/tag/"+i;y=l.getElementsByTagName(r)[0];y.parentNode.insertBefore(t,y);})(window, document, "clarity", "script", "z474d70ks5");`,
          }}
        />
        <link rel="icon" href="/favicon-new.png" />
        {/* Google Preferred Sources button (2026-11-02) */}
        <script async src="https://news.google.com/swg/js/v1/publisher.js" />
      </head>
      <body>
        <HashRedirect />
        <Header />
        <main>{children}</main>
        <Footer />
        <ToastRoot />
        {/* Website tour overlay (P3): mounted once, walks across pages. */}
        <TourRunner />
        {/* GA4 + AdSense live in AnalyticsScripts (gated off /rewards-terms);
            P2's inline GA4 snippet was dropped here to avoid double-loading. */}
        <AnalyticsScripts />
      </body>
    </html>
  );
}
