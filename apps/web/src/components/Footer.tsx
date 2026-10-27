'use client';

import { usePathname } from 'next/navigation';
import SubscribeForm from '@/components/SubscribeForm';

/** Social icons — legacy SOCIALS minus X (@virelloai suspended 2026-10-26). */
const SOCIALS: { name: string; href: string; path: string }[] = [
  {
    name: 'Instagram',
    href: 'https://www.instagram.com/virelloai.online/',
    path: 'M12 2.2c3.2 0 3.6 0 4.9.1 3.3.1 4.8 1.7 4.9 4.9.1 1.3.1 1.6.1 4.8s0 3.6-.1 4.8c-.1 3.2-1.7 4.8-4.9 4.9-1.3.1-1.6.1-4.9.1-3.2 0-3.6 0-4.8-.1-3.3-.1-4.8-1.7-4.9-4.9-.1-1.3-.1-1.6-.1-4.8s0-3.6.1-4.8C2.4 4 4 2.4 7.2 2.3 8.4 2.2 8.8 2.2 12 2.2zM12 0C8.7 0 8.3 0 7.1.1 2.7.3.3 2.7.1 7.1 0 8.3 0 8.7 0 12s0 3.7.1 4.9c.2 4.4 2.6 6.8 7 7 1.2.1 1.6.1 4.9.1s3.7 0 4.9-.1c4.4-.2 6.8-2.6 7-7 .1-1.2.1-1.6.1-4.9s0-3.7-.1-4.9c-.2-4.4-2.6-6.8-7-7C15.7 0 15.3 0 12 0zm0 5.9A6.1 6.1 0 1 0 18.1 12 6.1 6.1 0 0 0 12 5.9zm0 10.1A4 4 0 1 1 16 12a4 4 0 0 1-4 4zm6.4-11.8a1.4 1.4 0 1 1-1.4 1.4 1.4 1.4 0 0 1 1.4-1.4z',
  },
  {
    name: 'YouTube',
    href: 'https://www.youtube.com/@virelloai.online/',
    path: 'M19.6 6.7a4.8 4.8 0 0 1-3.4-3.4C15.9 3 13 3 12 3s-3.9 0-4.2.3A4.8 4.8 0 0 0 4.4 6.7 50 50 0 0 0 4 12a50 50 0 0 0 .4 5.3 4.8 4.8 0 0 0 3.4 3.4c.3.3 3.2.3 4.2.3s3.9 0 4.2-.3a4.8 4.8 0 0 0 3.4-3.4A50 50 0 0 0 20 12a50 50 0 0 0-.4-5.3zM10 15.5v-7l6 3.5z',
  },
  {
    name: 'TikTok',
    href: 'https://www.tiktok.com/@virelloai.online/',
    path: 'M16.6 3c.4 2.2 1.8 3.6 4 3.9v3c-1.6 0-3-.5-4-1.3v6.6c0 3.5-2.3 5.8-5.5 5.8A5.4 5.4 0 0 1 5.6 15c0-3.3 2.7-5.7 6.1-5.4v3.1c-1.6-.4-3 .7-3 2.2 0 1.3 1 2.3 2.3 2.3 1.5 0 2.5-1.1 2.5-2.9V3h3.1z',
  },
  {
    name: 'Facebook',
    href: 'https://www.facebook.com/profile.php?id=61595418210450',
    path: 'M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z',
  },
];

export default function Footer() {
  // App routes hide the public footer (legacy body.app-mode) — the
  // AppShell sidebar replaces the whole public chrome there.
  const pathname = usePathname();
  const appPath = pathname?.replace(/\.html$/, '') ?? '';
  if (
    ['/dashboard', '/campaigns', '/analytics', '/profile', '/settings'].includes(
      appPath,
    )
  ) {
    return null;
  }
  return (
    <footer className="site-footer">
      <div className="wrap">
        <div className="footer-grid">
          <div>
            <div style={{ marginBottom: 14 }}>
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <a href="/" aria-label="Virello AI home">
                <img
                  className="logo-img foot-logo"
                  src="/logo-virello.png"
                  alt="Virello AI"
                  width={560}
                  height={175}
                />
              </a>
            </div>
            <p className="mut" style={{ fontSize: 14.5, maxWidth: 320 }}>
              Your AI Growth Manager. Paste a post, choose a goal, and let AI
              grow it — real audiences, honest analytics, no fake engagement.
            </p>
            <div className="foot-socials">
              {SOCIALS.map((s) => (
                <a
                  key={s.name}
                  href={s.href}
                  target="_blank"
                  rel="noopener"
                  aria-label={`Virello on ${s.name}`}
                >
                  <svg viewBox="0 0 24 24" aria-hidden="true">
                    <path d={s.path} />
                  </svg>
                </a>
              ))}
            </div>
            <div style={{ marginTop: 20 }}>
              <h4 style={{ marginBottom: 4 }}>Growth tips, monthly</h4>
              <SubscribeForm />
            </div>
          </div>
          <div>
            <h4>Product</h4>
            <ul>
              <li><a href="/features.html">Features</a></li>
              <li><a href="/how.html">How It Works</a></li>
              <li><a href="/pricing.html">Pricing</a></li>
              <li><a href="/blog.html">Blog</a></li>
              <li><a href="/free-caption-generator.html">Free Caption Generator</a></li>
              <li><a href="/shop.html">Shop</a></li>
            </ul>
          </div>
          <div>
            <h4>Company</h4>
            <ul>
              <li><a href="/about.html">About Us</a></li>
              <li><a href="/contact.html">Contact</a></li>
              <li><a href="/help.html">Help Center</a></li>
              <li><a href="/trust.html">Trust &amp; Safety</a></li>
            </ul>
          </div>
          <div>
            <h4>Get the App</h4>
            <ul>
              <li>
                <a href="https://appgallery.huawei.com/app/C119223219" target="_blank" rel="noreferrer">
                  Huawei AppGallery
                </a>
              </li>
              <li>
                <a href="https://apkpure.com/p/com.virello.virello" target="_blank" rel="noreferrer">
                  APKPure
                </a>
              </li>
              <li>
                <a href="https://virello-ai.en.uptodown.com/android" target="_blank" rel="noreferrer">
                  Uptodown
                </a>
              </li>
              <li><a href="/login.html" className="auth-out">Web Dashboard</a><a href="/dashboard.html" className="auth-in">Web Dashboard</a></li>
            </ul>
          </div>
        </div>
        <div style={{ marginTop: 18, display: 'flex', gap: 20, alignItems: 'center', flexWrap: 'wrap' }}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <a href="https://showmebest.ai" target="_blank" rel="noreferrer">
            <img src="https://showmebest.ai/badge/feature-badge-white.webp" alt="Featured on ShowMeBestAI" width={220} height={60} loading="lazy" />
          </a>
          <a href="https://fazier.com" target="_blank" rel="noreferrer">Listed on Fazier</a>
        </div>
        <div className="footer-base">
          <span>© 2026 Virello AI — virelloai.online. All rights reserved.</span>
          <span>
            <a href="/privacy.html">Privacy Policy</a>
            {' · '}
            <a href="/terms.html">Terms</a>
            {' · '}
            <a href="/delete-account.html">Delete Account</a>
          </span>
        </div>
      </div>
    </footer>
  );
}
