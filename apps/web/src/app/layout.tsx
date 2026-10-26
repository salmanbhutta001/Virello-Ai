import type { Metadata } from 'next';
import Header from '@/components/Header';
import Footer from '@/components/Footer';
import AnalyticsScripts from '@/components/AnalyticsScripts';
import ToastRoot from '@/components/ToastRoot';
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
    url: 'https://virelloai.online/',
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
        <link
          href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Sora:wght@600;700;800&display=swap"
          rel="stylesheet"
        />
        <link rel="icon" href="/favicon-new.png" />
      </head>
      <body>
        <HashRedirect />
        <Header />
        <main>{children}</main>
        <Footer />
        <ToastRoot />
        {/* GA4 + AdSense live in AnalyticsScripts (gated off /rewards-terms);
            P2's inline GA4 snippet was dropped here to avoid double-loading. */}
        <AnalyticsScripts />
      </body>
    </html>
  );
}
