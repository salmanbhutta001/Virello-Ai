import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Delete Your Account',
  description:
    'How to delete your Virello AI account and personal data. Step-by-step instructions for in-app deletion and email requests.',
};

export default function DeleteAccountPage() {
  return (
    <>
      <section className="hero">
        <div className="wrap">
          <span className="kicker">Legal</span>
          <h1 className="h-xl">
            Delete Your <span className="grad-text">Account</span>
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
            You can delete your Virello AI account and associated personal data
            at any time. Deletion is <strong>permanent</strong> and cannot be
            undone.
          </p>

          <h2 className="h-md" style={{ marginTop: 36 }}>
            Option 1 — Delete inside the app (fastest)
          </h2>
          <ol>
            <li>Open the Virello AI app and log in.</li>
            <li>
              Go to the <strong>Profile</strong> tab.
            </li>
            <li>
              Tap <strong>Settings</strong> (gear icon).
            </li>
            <li>
              Scroll down and tap <strong>Delete Account</strong>.
            </li>
            <li>
              Read the confirmation screen, then tap{' '}
              <strong>Confirm Delete</strong>.
            </li>
            <li>
              You will be signed out immediately and your account will be
              queued for deletion.
            </li>
          </ol>

          <h2 className="h-md" style={{ marginTop: 36 }}>
            Option 2 — Request deletion by email
          </h2>
          <p>
            If you can&apos;t access the app, send an email to{' '}
            <strong>
              <a href="mailto:support@virelloai.online">
                support@virelloai.online
              </a>
            </strong>{' '}
            from the email address registered to your account with the subject
            line <strong>&ldquo;Delete my Virello AI account&rdquo;</strong>. We
            will verify your identity and process the request within{' '}
            <strong>30 days</strong>.
          </p>

          <h2 className="h-md" style={{ marginTop: 36 }}>
            What gets deleted
          </h2>
          <ul>
            <li>Your account profile (name, email, avatar)</li>
            <li>
              Content you created with AI tools (images, videos, scripts)
              stored on our servers
            </li>
            <li>Campaign data, analytics history, and preferences</li>
            <li>Saved items, Shop history, and Academy progress</li>
            <li>Push notification tokens linked to your account</li>
          </ul>

          <h2 className="h-md" style={{ marginTop: 36 }}>
            What may be retained
          </h2>
          <p>
            Some records may be kept for a limited time where the law requires
            it:
          </p>
          <ul>
            <li>
              <strong>Purchase records:</strong> transaction receipts processed
              by Google Play Billing or the relevant app store may be retained
              up to <strong>7 years</strong> for tax and accounting purposes
              (these live with the payment provider, not in your Virello
              profile).
            </li>
            <li>
              <strong>Fraud &amp; abuse logs:</strong> limited security logs may
              be kept up to <strong>12 months</strong> to protect the platform.
            </li>
            <li>
              <strong>Legal obligations:</strong> data required by applicable
              law or an ongoing legal process.
            </li>
          </ul>
          <p>
            Retained data is never used for marketing and is deleted as soon as
            the retention obligation ends.
          </p>

          <div
            className="card"
            style={{ borderColor: 'rgba(248, 113, 113, 0.4)', marginTop: 28 }}
          >
            <p style={{ margin: 0 }}>
              <strong>⚠️ Before you delete:</strong> cancel any active
              subscription in Google Play (Play Store → Profile → Payments
              &amp; subscriptions) to avoid future charges. Deleting your
              Virello account does not automatically cancel store
              subscriptions.
            </p>
          </div>

          <h2 className="h-md" style={{ marginTop: 36 }}>
            Questions?
          </h2>
          <p>
            Contact us at{' '}
            <strong>
              <a href="mailto:support@virelloai.online">
                support@virelloai.online
              </a>
            </strong>{' '}
            — we respond to deletion and privacy requests within 30 days.
          </p>
          <p>
            See also our <a href="/privacy.html">Privacy Policy</a>.
          </p>
        </div>
      </section>
    </>
  );
}
