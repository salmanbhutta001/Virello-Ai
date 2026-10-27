import type { Metadata } from 'next';
import Script from 'next/script';
import Header from '@/components/Header';
import Footer from '@/components/Footer';
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
    url: 'https://virelloai.online/',
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

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
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
      </head>
      <body>
        <Header />
        <main>{children}</main>
        <Footer />
        {/* GA4 — virelloai.online web stream */}
        <Script
          src="https://www.googletagmanager.com/gtag/js?id=G-X3T458F82Y"
          strategy="afterInteractive"
        />
        <Script id="ga4" strategy="afterInteractive">
          {`window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments);}gtag('js',new Date());gtag('config','G-X3T458F82Y');`}
        </Script>
      </body>
    </html>
  );
}
