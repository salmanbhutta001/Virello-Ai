import type { Metadata } from 'next';
import { Suspense } from 'react';
import LoginForm from './LoginForm';

export const metadata: Metadata = {
  title: 'Log In',
  description:
    'Log in to your Virello dashboard or create your free account — no credit card required.',
  robots: { index: false, follow: true },
};

export default function LoginPage() {
  return (
    <Suspense
      fallback={
        <div className="auth-wrap">
          <div className="auth-form-side">
            <div className="auth-card">
              <p className="mut">Loading…</p>
            </div>
          </div>
        </div>
      }
    >
      <LoginForm />
    </Suspense>
  );
}
