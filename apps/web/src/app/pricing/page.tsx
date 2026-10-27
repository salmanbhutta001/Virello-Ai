import type { Metadata } from 'next';
import PricingClient from './PricingClient';

export const metadata: Metadata = {
  title: { absolute: 'Pricing — Free $0, Pro $19/mo, Business $49/mo' },
  description:
    'Start free. Upgrade when the AI has earned it. Every plan includes legitimate growth only — no bots, no fake engagement, no surprises.',
  alternates: { canonical: '/pricing.html' },
};

// Server wrapper: metadata stays here; all interactive wiring
// (billing toggle, $0 checkout modal, talk modal, Pro toast) lives
// in the client island PricingClient.tsx (plan §1.5).
export default function PricingPage() {
  return <PricingClient />;
}
