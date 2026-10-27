// Pricing FAQs (AEO 2026-10-28). Every answer is sourced ONLY from the
// pricing page itself (plan cards, compare table, trust row) or the help
// page's matching answer — no invented claims. Rendered visibly in
// PricingClient.tsx and as FAQPage JSON-LD in page.tsx from this one array,
// so schema always matches the visible text.
export const PRICING_FAQS: { q: string; a: string }[] = [
  {
    q: 'What is the difference between the Free, Pro and Business plans?',
    a: 'Free includes AI content analysis, audience insights and Free Grow AI organic growth up to 1,000 impressions, with 3 active campaigns. Pro adds AI Paid Boost with budget pacing, 25 active campaigns and full analytics. Business adds 100 active campaigns, multiple brands and team seats, priority AI processing and priority support.',
  },
  {
    q: 'How much does Virello Pro cost?',
    a: 'Pro is $19 per month, or $15 per month when billed yearly — yearly billing saves 20%. Business is $49 per month, or $39 per month billed yearly.',
  },
  {
    q: 'What are Boost packages?',
    a: 'Boost packages are one-off paid boosts inside the Pro and Business plans: Starter $10 for 7 days, Growth $25 for 14 days, Pro $50 for 30 days and Scale $100 for 30 days.',
  },
  {
    q: 'Can I cancel anytime?',
    a: 'You can cancel your subscription anytime; it stays active until the end of the billing period. Payments run through Google Play Billing with verified purchase tokens and refund protection.',
  },
  {
    q: 'How do I pay for a plan?',
    a: 'Payments run through Google Play Billing with verified purchase tokens and refund protection. The Free plan needs no payment at all — it is $0 forever.',
  },
];
