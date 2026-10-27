import type { Metadata } from 'next';
import PricingClient from './PricingClient';
import { PRICING_FAQS } from './faqs';

export const metadata: Metadata = {
  title: { absolute: 'Pricing — Free $0, Pro $19/mo, Business $49/mo' },
  description:
    'Start free. Upgrade when the AI has earned it. Every plan includes legitimate growth only — no bots, no fake engagement, no surprises.',
  alternates: { canonical: '/pricing.html' },
  openGraph: { url: 'https://virelloai.online/pricing.html' },
};

// Server wrapper: metadata stays here; all interactive wiring
// (billing toggle, $0 checkout modal, talk modal, Pro toast) lives
// in the client island PricingClient.tsx (plan §1.5).
export default function PricingPage() {
  // FAQPage JSON-LD (AEO 2026-10-28). Built from the same PRICING_FAQS
  // array rendered visibly in PricingClient, so schema always matches
  // the visible page text.
  const faqJsonLd = {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: PRICING_FAQS.map((f) => ({
      '@type': 'Question',
      name: f.q,
      acceptedAnswer: { '@type': 'Answer', text: f.a },
    })),
  };
  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(faqJsonLd) }}
      />
      <PricingClient />
    </>
  );
}
