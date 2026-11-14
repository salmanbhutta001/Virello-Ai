import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Virello Rewards — Terms & Conditions',
  description:
    'Virello Rewards terms: earn Points for posting and engaging, and Cash (USD) for sharing products that lead to real shopping clicks.',
  alternates: { canonical: '/rewards-terms.html' },
  openGraph: {
    type: 'website',
    url: 'https://virelloai.online/rewards-terms.html',
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

/**
 * Static port of the legacy standalone rewards-terms.html (content
 * verbatim). NO GA4 / AdSense on this page — see AnalyticsScripts.
 * The legacy page is a plain light page; its look is kept inside the
 * .rewards-terms wrapper (globals.css).
 */
const BODY_HTML = `<h1>Virello Rewards — Terms &amp; Conditions</h1>
<p class="small">Last updated: September 30, 2026 · Contact: <a href="mailto:privacy@virelloai.online">privacy@virelloai.online</a></p>

<div class="note"><strong>Plain-language summary:</strong> Virello lets you earn <strong>Points</strong> for posting and engaging, and <strong>Cash</strong> (USD) for sharing products that lead to real shopping clicks. You never pay anything to participate — there is no wagering, no entry fee, and no purchase necessary. Cash withdrawals are reviewed manually and paid by bank transfer.</div>

<h2>1. Eligibility</h2>
<ul>
<li>Cash rewards and withdrawals require you to be <strong>18 years or older</strong> (or the age of majority in your country).</li>
<li>You must verify your email address, complete your profile, and hold your account for at least <strong>7 days</strong> before your first withdrawal.</li>
<li>One account per person. Duplicate or fake accounts forfeit all rewards.</li>
</ul>

<h2>2. Points</h2>
<p>Points are a non-monetary engagement score. They have no cash value on their own and cannot be sold or transferred.</p>
<table>
<tr><th>Action</th><th>Points</th><th>Limits</th></tr>
<tr><td>Create a post</td><td>10</td><td rowspan="2">Max 5 rewarded posts/day</td></tr>
<tr><td>Post with tagged products</td><td>25</td></tr>
<tr><td>Posting streak (day 2 / 3 / 4 / 5+)</td><td>5 / 10 / 15 / 25</td><td>Consecutive days with ≥1 post</td></tr>
<tr><td>Like received on your post</td><td>1</td><td>Max 50/post/day · no self-likes</td></tr>
<tr><td>Comment received on your post</td><td>2</td><td>Max 20/post/day · no self-comments</td></tr>
<tr><td>Complete your profile</td><td>20</td><td>Once</td></tr>
<tr><td>Daily sign-in</td><td>2</td><td>Once/day</td></tr>
</table>
<p><strong>Using points:</strong> 100 Points = 10 Grow credits (in-app AI features), or convert Points to cash at 500 Points = $1.00 USD into your Cash balance (minimum 1,000 Points per conversion).</p>

<h2>3. Cash rewards</h2>
<p>Cash is earned only for actions that can generate real shopping activity. <strong>Share rewards are proof-based:</strong> after sharing, upload a screenshot of your shared post; your reward is credited only after admin approval.</p>
<ul>
<li><strong>Share rewards need a screenshot proof and admin approval.</strong> The reward amount is shown on each post as a small badge (e.g. "+$0.05"); different posts may carry different amounts, set by Virello.</li>
</ul>
<table>
<tr><th>Action</th><th>Cash (USD)</th><th>Limits</th></tr>
<tr><td>Share a product via your personal link</td><td>$0.05</td><td>Max 20/day · screenshot proof + admin approval required</td></tr>
<tr><td>Verified click on your shared link</td><td>$0.03</td><td>Max 50/day · no self-clicks</td></tr>
<tr><td>Click on a product you tagged in your post</td><td>$0.03</td><td>Max 50/day</td></tr>
<tr><td>Volume bonus — 100 verified clicks / 7 days</td><td>$2.00</td><td rowspan="2">Automatic</td></tr>
<tr><td>Volume bonus — 500 verified clicks / 7 days</td><td>$10.00</td></tr>
</table>
<p>Rates may be adjusted by Virello with notice in the app. Earnings shown are estimates until clicks are verified.</p>

<h2>4. Contests (skill-based)</h2>
<ul>
<li><strong>Weekly Top Seller</strong> (most verified share-clicks, Mon–Sun): $10.00 cash.</li>
<li><strong>Monthly Top Seller</strong> (most verified share-clicks, calendar month): $50.00 cash.</li>
<li><strong>Weekly/Monthly Top Poster</strong> (most Points): 500 / 300 / 150 and 2000 / 1000 / 500 Points.</li>
</ul>
<p>Winners are determined purely by measured activity (skill/effort), never by random draw. In case of a tie, the earlier achiever ranks higher. Winners are announced in the app.</p>

<h2>5. Withdrawals</h2>
<ul>
<li>Minimum withdrawal: <strong>$10.00 USD</strong>.</li>
<li>Withdrawals are paid by <strong>manual bank transfer</strong> to the bank details you provide.</li>
<li>Every withdrawal is <strong>manually reviewed</strong>, usually within 7 days. We may ask for identity verification.</li>
<li>One pending withdrawal at a time.</li>
<li>You are responsible for any taxes on your earnings in your country.</li>
</ul>

<h2>6. Fair play</h2>
<p>Rewards are for <strong>genuine activity only</strong>. The following forfeit earnings and may lead to account suspension:</p>
<ul>
<li>Fake accounts, bots, click farms, or automated clicking/sharing;</li>
<li>Clicking your own links or coordinating reciprocal clicks;</li>
<li>Spam — mass-sharing to uninterested audiences;</li>
<li>Anything that violates Virello's no-fake-engagement rule.</li>
</ul>
<p>We use automated limits and manual review. Decisions on abuse are final.</p>

<h2>7. Changes</h2>
<p>We may change rates, limits, or these terms with reasonable notice in the app. Continued use after changes means you accept them. We may end the rewards program with 30 days' notice; earned Cash balances above the withdrawal minimum will still be payable.</p>

<h2>8. Contact</h2>
<p>Questions about rewards or withdrawals: <a href="mailto:privacy@virelloai.online">privacy@virelloai.online</a>.</p>`;

export default function RewardsTermsPage() {
  return (
    <section className="section">
      <div className="wrap" style={{ maxWidth: 860 }}>
        <div
          className="rewards-terms"
          dangerouslySetInnerHTML={{ __html: BODY_HTML }}
        />
      </div>
    </section>
  );
}
