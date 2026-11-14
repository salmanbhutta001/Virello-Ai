import type { Metadata } from 'next';

// Shop is a client component ('use client' in page.tsx), so it cannot
// export metadata itself — this segment layout carries the page metadata
// (SEO fixes 2026-11-14: self-referencing canonical + social card).
export const metadata: Metadata = {
  alternates: { canonical: '/shop.html' },
  openGraph: {
    type: 'website',
    url: 'https://virelloai.online/shop.html',
    images: [
      {
        url: '/images/virello-social-card.png',
        width: 1200,
        height: 630,
        alt: 'Virello AI — Your AI Growth Manager',
      },
    ],
  },
};

export default function ShopLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return <>{children}</>;
}
