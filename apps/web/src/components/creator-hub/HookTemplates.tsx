'use client';

import { copyText, notify } from '../../lib/creator';
import { PanelShell } from './shared';

/**
 * Hook Templates — 12 hardcoded templates, click-to-copy (legacy
 * TEMPLATES + renderTemplates, index.html:3524-3546). No API call.
 * Copies "{title}\n{text}" exactly like legacy.
 */

export const HOOK_TEMPLATES: { t: string; tag: string; x: string }[] = [
  { t: 'The Mistake Hook', tag: 'Reels', x: 'Stop doing [X] if you want [result]. Here is what actually works...' },
  { t: 'The Number Hook', tag: 'Reels', x: '3 things I wish I knew before [starting X] — #2 changed everything.' },
  { t: 'The Story Opener', tag: 'Story', x: 'Nobody talks about the day I almost quit [X]. Here is what happened...' },
  { t: 'The Myth Buster', tag: 'Reels', x: '[Common advice] is terrible advice. Here is why — and what to do instead.' },
  { t: 'The Quick Win', tag: 'Carousel', x: 'Save this: 5 [niche] tools that do the work of 5 hours in 5 minutes.' },
  { t: 'The Transformation', tag: 'Reels', x: 'POV: You [did X] for 30 days straight. Here is the before and after.' },
  { t: 'The Question Loop', tag: 'Engagement', x: 'Be honest — are you still [doing X the old way]? Comment YES and I will send the fix.' },
  { t: 'The Behind Scenes', tag: 'Story', x: 'What a real [workday / shoot day / packing day] looks like — no filter.' },
  { t: 'The Tutorial', tag: 'Reels', x: 'How to [achieve result] in [time] — step by step, even as a beginner.' },
  { t: 'The Comparison', tag: 'Carousel', x: '[Option A] vs [Option B] — I tested both so you do not have to. Swipe.' },
  { t: 'The Hot Take', tag: 'Thread', x: 'Unpopular opinion: [take]. Here is the data nobody shows you...' },
  { t: 'The Offer Soft', tag: 'Story', x: 'I made something that fixes [pain]. Want the link? Reply LINK.' },
];

export default function HookTemplates(props: { onBack: () => void }) {
  async function copyTemplate(tp: (typeof HOOK_TEMPLATES)[number]) {
    const ok = await copyText(`${tp.t}\n${tp.x}`);
    notify(ok ? 'Template copied' : 'Copy failed');
  }

  return (
    <PanelShell
      title="Hook Templates"
      desc="12 proven templates — kisi par tap karo, copy ho jayega."
      onBack={props.onBack}
    >
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fill,minmax(220px,1fr))',
          gap: 14,
          marginTop: 14,
        }}
      >
        {HOOK_TEMPLATES.map((tp) => (
          <button
            key={tp.t}
            type="button"
            onClick={() => void copyTemplate(tp)}
            style={{
              textAlign: 'left',
              background: 'var(--surface2)',
              border: '1px solid var(--line)',
              borderRadius: 14,
              padding: 16,
              cursor: 'pointer',
              color: 'var(--txt)',
              font: 'inherit',
            }}
          >
            <span className="tag" style={{ marginBottom: 8 }}>
              {tp.tag}
            </span>
            <b style={{ display: 'block', margin: '8px 0 6px' }}>{tp.t}</b>
            <span style={{ fontSize: '0.9rem', color: 'var(--mut)' }}>{tp.x}</span>
          </button>
        ))}
      </div>
    </PanelShell>
  );
}
