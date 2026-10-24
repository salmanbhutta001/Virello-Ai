import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Terms of Service',
  description:
    'Terms of Service for Virello AI. Acceptable use, subscriptions and billing, intellectual property, and limitations.',
};

export default function TermsPage() {
  return (
    <>
      <section className="hero">
        <div className="wrap">
          <span className="kicker">Legal</span>
          <h1 className="h-xl">
            Terms of Service — <span className="grad-text">Virello AI</span>
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
            By downloading, installing, or using Virello AI (&ldquo;the
            app&rdquo;), you agree to these Terms of Service
            (&ldquo;Terms&rdquo;). If you do not agree, do not use the app.
          </p>

          <h2 className="h-md" style={{ marginTop: 36 }}>
            1. The Service
          </h2>
          <p>
            Virello AI is an AI-powered social media growth platform. It provides
            AI content analysis, audience insights, content generation (text,
            images, video), campaign tools, analytics, and a curated product
            shop. Features may change or improve over time.
          </p>

          <h2 className="h-md" style={{ marginTop: 36 }}>
            2. Acceptable Use
          </h2>
          <p>
            You agree to use Virello AI only for lawful purposes. You must{' '}
            <strong>not</strong>:
          </p>
          <ul>
            <li>
              Use the app to generate fake engagement — including fake
              followers, likes, views, or reviews — or to operate bots.
            </li>
            <li>
              Upload content you don&apos;t have the right to use, or content
              that is unlawful, hateful, or harassing.
            </li>
            <li>
              Attempt to reverse-engineer, scrape, or disrupt the app or its
              backend services.
            </li>
            <li>
              Misrepresent AI-generated content as human-created where
              disclosure is required by a platform or by law.
            </li>
            <li>
              Resell, sublicense, or redistribute the service without written
              permission.
            </li>
          </ul>
          <p>
            We may suspend or terminate accounts that violate these Terms, with
            or without notice.
          </p>

          <h2 className="h-md" style={{ marginTop: 36 }}>
            3. AI-Generated Content
          </h2>
          <ul>
            <li>
              Content you create with Virello&apos;s AI tools is yours to use,
              subject to these Terms and the terms of the underlying AI
              providers.
            </li>
            <li>
              AI output can be inaccurate or incomplete — you are responsible
              for reviewing content before publishing.
            </li>
            <li>
              Virello AI does not guarantee virality, reach, followers, or
              revenue. Growth depends on many factors outside our control.
            </li>
          </ul>

          <h2 className="h-md" style={{ marginTop: 36 }}>
            4. Subscriptions, Credits &amp; Billing
          </h2>
          <ul>
            <li>
              Paid plans (Starter, Growth, Pro, Scale) and credit packs are sold
              as subscriptions or one-time purchases.
            </li>
            <li>
              All payments are processed securely by{' '}
              <strong>Google Play Billing</strong> (or the app store you
              downloaded from). We never see or store your full payment card
              details.
            </li>
            <li>
              Subscriptions renew automatically until cancelled. Cancel anytime
              via Google Play:{' '}
              <em>
                Play Store → Profile → Payments &amp; subscriptions →
                Subscriptions
              </em>
              .
            </li>
            <li>Refunds are handled under the Google Play refund policy.</li>
            <li>
              Credits are virtual items with no cash value, are
              non-transferable, and expire as described in-app.
            </li>
            <li>
              Prices are shown in USD and may vary by region due to store
              pricing and taxes.
            </li>
          </ul>

          <h2 className="h-md" style={{ marginTop: 36 }}>
            5. Free Plan
          </h2>
          <p>
            The Free plan is free forever with limited features and starter
            credits. We may adjust free-plan limits as the service evolves.
          </p>

          <h2 className="h-md" style={{ marginTop: 36 }}>
            6. Intellectual Property
          </h2>
          <p>
            Virello AI, its logo, design, and software are owned by Hafiz
            Muhmmad Salman. You receive a limited, non-exclusive,
            non-transferable license to use the app for personal or business
            purposes. Nothing in these Terms transfers ownership of our
            intellectual property to you.
          </p>

          <h2 className="h-md" style={{ marginTop: 36 }}>
            7. Third-Party Services
          </h2>
          <p>
            The app integrates third-party services (app stores for billing, AI
            providers for generation, Amazon Associates for shop links,
            Cloudinary for image hosting). Your use of those services is
            governed by their own terms and privacy policies.
          </p>

          <h2 className="h-md" style={{ marginTop: 36 }}>
            8. Account Termination &amp; Data
          </h2>
          <p>
            You may delete your account at any time — see our{' '}
            <a href="/delete-account.html">account deletion page</a> for
            instructions. We may suspend or delete accounts for Terms
            violations, fraud, or extended inactivity. Our{' '}
            <a href="/privacy.html">Privacy Policy</a> explains how your data
            is handled.
          </p>

          <h2 className="h-md" style={{ marginTop: 36 }}>
            9. Disclaimers
          </h2>
          <p>
            The app is provided &ldquo;as is&rdquo; without warranties of any
            kind. We do not warrant that the service will be uninterrupted,
            error-free, or meet your specific growth targets.
          </p>

          <h2 className="h-md" style={{ marginTop: 36 }}>
            10. Limitation of Liability
          </h2>
          <p>
            To the maximum extent permitted by law, we are not liable for
            indirect, incidental, or consequential damages arising from your use
            of the app. Our total liability is limited to the amount you paid
            us in the 12 months before the claim.
          </p>

          <h2 className="h-md" style={{ marginTop: 36 }}>
            11. Changes to These Terms
          </h2>
          <p>
            We may update these Terms; the &ldquo;Last updated&rdquo; date will
            reflect changes. Continued use of the app after changes means you
            accept the updated Terms.
          </p>

          <h2 className="h-md" style={{ marginTop: 36 }}>
            12. Contact
          </h2>
          <p>
            <strong>Developer:</strong> Hafiz Muhmmad Salman
            <br />
            <strong>App:</strong> Virello AI
          </p>
          <p>
            Questions about these Terms:{' '}
            <strong>
              <a href="mailto:alif01fiverr@gmail.com">
                alif01fiverr@gmail.com
              </a>
            </strong>
          </p>
        </div>
      </section>
    </>
  );
}
