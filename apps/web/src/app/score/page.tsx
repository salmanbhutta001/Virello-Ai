import type { Metadata } from 'next';
import ScoreTool from './ScoreTool';

export const metadata: Metadata = {
  title: 'Free AI Post Score',
  description:
    'Paste your social media draft and get a free AI content score with actionable tips. No signup. By Virello AI — Your AI Growth Manager.',
};

export default function ScorePage() {
  return (
    <>
      <section className="hero" style={{ paddingBottom: 32 }}>
        <div className="wrap">
          <h1 className="h-xl">
            Free <span className="grad-text">AI Post Score</span>
          </h1>
          <p className="lead">
            Paste your post or caption draft below. Virello&apos;s AI scores
            it on real content-quality signals and gives you 3 concrete ways
            to make it stronger. Free, no signup.
          </p>
        </div>
      </section>
      <section className="section" style={{ paddingTop: 8 }}>
        <div className="wrap">
          <ScoreTool />
        </div>
      </section>
    </>
  );
}
