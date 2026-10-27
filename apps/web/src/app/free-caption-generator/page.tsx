import type { Metadata } from 'next';
import CaptionTool from './CaptionTool';

export const metadata: Metadata = {
  title: 'Free AI Caption + Hashtag Generator',
  description:
    'Write a better caption in seconds. Describe your post, pick a platform, and get an AI-written caption with hashtags — free, no signup needed to try.',
  alternates: { canonical: '/free-caption-generator.html' },
  openGraph: { url: 'https://virelloai.online/free-caption-generator.html' },
};

const STEPS = [
  {
    icon: '✎',
    title: '1. Describe your post',
    text: 'Tell the tool what your photo, video or idea is about — a sentence is enough. Add a few keywords if you want them included.',
  },
  {
    icon: '✦',
    title: '2. Pick a platform & tone',
    text: 'Instagram, TikTok or X — and a friendly, professional or playful tone. The caption is shaped for the platform you pick.',
  },
  {
    icon: '⧉',
    title: '3. Copy & post',
    text: 'Copy the caption, the hashtags, or everything at once. Read it once, make it yours, and post it wherever you like.',
  },
];

const FAQS = [
  {
    q: 'Is it really free?',
    a: 'Yes. Generating a caption costs nothing and needs no account. If you want Virello to plan, schedule and grow your posts for you, that is what the free plan and the app are for — but this tool stands on its own.',
  },
  {
    q: 'Will this make my post go viral?',
    a: 'No tool can promise that, and we will not pretend otherwise. A good caption helps real people stop, read and engage — reach still depends on your content, your audience and the platform. What Virello does promise: no fake engagement, ever.',
  },
  {
    q: 'Do I need to sign up to use it?',
    a: 'No. The generator works without an account. Your text stays in your browser — what you type is sent only to the AI writer to generate your caption.',
  },
];

export default function FreeCaptionGeneratorPage() {
  return (
    <main>
      <section className="section">
        <div className="wrap center">
          <span className="kicker">Free Tool · No Signup Needed</span>
          <h1 className="h-xl">
            Free AI Caption <span className="grad-text">+ Hashtag Generator</span>
          </h1>
          <p className="lead" style={{ marginTop: 18 }}>
            Stuck on what to write under your post? Describe it, pick your
            platform, and get an AI-written caption with hashtags in seconds —
            free, no account needed to try.
          </p>
        </div>
      </section>

      <section className="section" style={{ paddingTop: 0 }}>
        <div className="wrap">
          <CaptionTool />
        </div>
      </section>

      <section className="section" style={{ paddingTop: 0 }}>
        <div className="wrap">
          <h2 className="h-md center" style={{ marginBottom: 28 }}>
            How it works
          </h2>
          <div className="grid grid-3">
            {STEPS.map((s) => (
              <div key={s.title} className="card">
                <span className="icon">{s.icon}</span>
                <h3>{s.title}</h3>
                <p>{s.text}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="section" style={{ paddingTop: 0 }}>
        <div className="wrap">
          <h2 className="h-md center" style={{ marginBottom: 28 }}>
            Good to know
          </h2>
          <div className="grid grid-3">
            {FAQS.map((f) => (
              <div key={f.q} className="card">
                <h3>{f.q}</h3>
                <p>{f.a}</p>
              </div>
            ))}
          </div>

          <div className="card center" style={{ marginTop: 44, padding: 48 }}>
            <h2 className="h-md">Want captions that grow with you?</h2>
            <p className="lead" style={{ margin: '12px auto 24px' }}>
              This tool writes one caption at a time. Virello AI plans your
              posts, matches them with real audiences and tracks what actually
              works — starting free.
            </p>
            <a className="btn btn-grad auth-out" href="/login.html">
              Start Growing Free
            </a>
            <a className="btn btn-grad auth-in" href="/dashboard.html">
              Open Your Dashboard
            </a>
            <p className="small" style={{ marginTop: 18 }}>
              See what else Virello does:{' '}
              <a href="/features.html">features</a>
              {' · '}
              <a href="/score.html">score your post</a>
            </p>
          </div>
        </div>
      </section>
    </main>
  );
}
