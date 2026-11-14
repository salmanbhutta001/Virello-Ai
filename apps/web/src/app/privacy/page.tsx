import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Privacy Policy',
  description:
    'Privacy Policy for Virello AI. Learn what data we collect, how we use it, how we protect it, and your rights — including access, correction and deletion.',
  alternates: { canonical: '/privacy.html' },
  openGraph: {
    type: 'website',
    url: 'https://virelloai.online/privacy.html',
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

export default function PrivacyPage() {
  return (
    <>
      <section className="hero">
        <div className="wrap">
          <span className="kicker">Legal</span>
          <h1 className="h-xl">
            Privacy Policy — <span className="grad-text">Virello AI</span>
          </h1>
          <p className="mut" style={{ marginTop: 14 }}>
            Last updated: October 13, 2026
            <br />
            <strong>App:</strong> Virello AI &nbsp;|&nbsp;{' '}
            <strong>Developer:</strong> Hafiz Muhmmad Salman
          </p>
        </div>
      </section>

      <section className="section" style={{ paddingTop: 20 }}>
        <div className="wrap" style={{ maxWidth: 820 }}>
          <p>
            Virello AI (&ldquo;we&rdquo;, &ldquo;our&rdquo;, &ldquo;us&rdquo;) is an
            AI-powered social media growth platform. This Privacy Policy explains
            what data we collect, how we use it, and your rights.
          </p>

          <h2 className="h-md" style={{ marginTop: 36 }}>
            1. Data We Collect
          </h2>
          <ul>
            <li>
              <strong>Account data:</strong> email address and name when you sign
              up or log in (including via Google or Apple sign-in).
            </li>
            <li>
              <strong>Content you create:</strong> text prompts, images, and
              videos you generate with our AI tools.
            </li>
            <li>
              <strong>Usage data:</strong> app interactions, feature usage, and
              campaign performance analytics to improve the service.
            </li>
            <li>
              <strong>Device data:</strong> device model, OS version, and app
              version for compatibility and crash diagnostics.
            </li>
            <li>
              <strong>Purchase data:</strong> subscription and in-app purchase
              records processed securely by Google Play Billing or the relevant
              app store (we never see your full payment card details).
            </li>
          </ul>

          <h2 className="h-md" style={{ marginTop: 36 }}>
            2. How We Use Data
          </h2>
          <ul>
            <li>
              To provide and improve the app&apos;s features (AI generation,
              campaigns, shop, academy).
            </li>
            <li>To process subscriptions and credits.</li>
            <li>To send important service notifications.</li>
            <li>To detect fraud and keep the platform safe.</li>
          </ul>
          <p>
            We do <strong>not</strong> sell your personal data. We do not use
            fake engagement, bots, or resold traffic.
          </p>

          <h2 className="h-md" style={{ marginTop: 36 }}>
            3. Third-Party Services
          </h2>
          <ul>
            <li>
              <strong>Google Play Billing / app stores:</strong> process
              payments under their own privacy policies.
            </li>
            <li>
              <strong>Amazon Associates:</strong> product links in the Shop carry
              our affiliate tag; Amazon handles any purchase under its own
              policy.
            </li>
            <li>
              <strong>AI providers:</strong> prompts you submit may be processed
              by our AI service providers to generate content.
            </li>
            <li>
              <strong>Cloudinary:</strong> hosts product and user-uploaded
              images.
            </li>
          </ul>

          <h2 className="h-md" style={{ marginTop: 36 }}>
            4. Data Storage &amp; Security
          </h2>
          <p>
            Data is stored on secure servers with encryption in transit (HTTPS).
            Access is limited to authorized personnel only.
          </p>

          <h2 className="h-md" style={{ marginTop: 36 }}>
            5. Your Rights
          </h2>
          <p>
            You may request access, correction, or deletion of your personal
            data at any time by contacting us at the email below. Deleting your
            account removes your personal data from our active systems. See our{' '}
            <a href="/delete-account.html">account deletion page</a> for
            step-by-step instructions.
          </p>

          <h2 className="h-md" style={{ marginTop: 36 }}>
            6. Children&apos;s Privacy
          </h2>
          <p>
            Virello AI is not directed at children under 13. We do not knowingly
            collect data from children under 13.
          </p>

          <h2 className="h-md" style={{ marginTop: 36 }}>
            7. Changes
          </h2>
          <p>
            We may update this policy; the &ldquo;Last updated&rdquo; date will
            reflect changes. Continued use of the app after changes means you
            accept the updated policy.
          </p>

          <h2 className="h-md" style={{ marginTop: 36 }}>
            8. Contact
          </h2>
          <p>
            <strong>Developer:</strong> Hafiz Muhmmad Salman
            <br />
            <strong>App:</strong> Virello AI
          </p>
          <p>
            For privacy questions or data requests:{' '}
            <strong>
              <a href="mailto:support@virelloai.online">
                support@virelloai.online
              </a>
            </strong>
          </p>
        </div>
      </section>
    </>
  );
}
