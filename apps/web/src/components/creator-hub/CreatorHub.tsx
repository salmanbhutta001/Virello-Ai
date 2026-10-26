'use client';

import { useState } from 'react';
import type { ReactNode } from 'react';
import type { Draft } from '../../lib/creator';
import { notify } from '../../lib/creator';
import Workspace from './Workspace';
import type { MainTool } from './Workspace';
import TextTools from './TextTools';
import HookTemplates from './HookTemplates';
import ImageTools from './ImageTools';
import Teleprompter from './Teleprompter';
import VoiceoverStudio from './VoiceoverStudio';
import StoryVideo from './StoryVideo';
import UploadAnalyze from './UploadAnalyze';
import DistributionEngine from './DistributionEngine';
import Spotlight from './Spotlight';

/**
 * <CreatorHub /> — the whole Creator Hub, self-contained, no props.
 * Mounted by P3 in the dashboard page. Legacy parity (inventory §12.1a,
 * index.html:1600-1868 + 3255-3760):
 * - 14 tool cards under a "FREE · No credit charge" label; the 3 main
 *   generators share one workspace, the other 9 open their own panel.
 * - Drafts are in-memory only (lost on reload) — same as legacy.
 * - Panels hide the workspace while open (legacy openToolPanel); picking
 *   a main tool shows the workspace again (legacy setCreatorTool).
 *
 * Small deliberate additions vs legacy (flagged for the coordinator):
 * - Each panel has a "← Back to Creator Hub" button. Legacy had no
 *   visible back control (toolBackToMain existed but was never wired to
 *   a button); without one, a panel could only be left by picking
 *   another card.
 * - Toasts go through notify() in src/lib/creator.ts (DOM toast fallback
 *   until P2's src/lib/toast.ts lands — see that file's header).
 */

type PanelId =
  | 'script'
  | 'story'
  | 'convert'
  | 'templates'
  | 'imgtools'
  | 'prompter'
  | 'voice'
  | 'storyvideo'
  | 'analyze'
  | 'distribute'
  | 'spotlight';

type Card = {
  id: MainTool | PanelId;
  title: string;
  desc: string;
  go: string;
  grad: string;
  icon: ReactNode;
};

function icon(paths: ReactNode) {
  return (
    <svg
      viewBox="0 0 24 24"
      width={22}
      height={22}
      fill="none"
      stroke="currentColor"
      strokeWidth={1.9}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {paths}
    </svg>
  );
}

const CARDS: Card[] = [
  {
    id: 'image',
    title: 'AI Image Studio',
    desc: 'Generate scroll-stopping post images and thumbnails from a prompt.',
    go: 'Open Image Studio →',
    grad: 'linear-gradient(135deg,#7c3aed,#d81b4a)',
    icon: icon(
      <>
        <rect x="3" y="3" width="18" height="18" rx="3" />
        <circle cx="9" cy="9" r="2" />
        <path d="M21 15l-5-5L5 21" />
      </>,
    ),
  },
  {
    id: 'video',
    title: 'AI Video Creator',
    desc: 'Turn an idea into a short vertical video with captions and music cues.',
    go: 'Open Video Creator →',
    grad: 'linear-gradient(135deg,#0ea5e9,#7c3aed)',
    icon: icon(
      <>
        <rect x="2" y="5" width="15" height="14" rx="3" />
        <path d="M17 10l5-3v10l-5-3z" />
      </>,
    ),
  },
  {
    id: 'caption',
    title: 'Caption & Hook Writer',
    desc: 'Viral hooks, captions and hashtag sets tuned to your niche and goal.',
    go: 'Write a Caption →',
    grad: 'linear-gradient(135deg,#f59e0b,#e91e55)',
    icon: icon(
      <>
        <path d="M12 20h9" />
        <path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z" />
      </>,
    ),
  },
  {
    id: 'script',
    title: 'Script Writer',
    desc: 'Full video scripts with hook, timed beats and CTA — ready to shoot.',
    go: 'Write a Script →',
    grad: 'linear-gradient(135deg,#8b5cf6,#ec4899)',
    icon: icon(
      <>
        <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
        <path d="M14 2v6h6M9 13h6M9 17h6" />
      </>,
    ),
  },
  {
    id: 'story',
    title: 'Story Writer',
    desc: 'Engaging stories in your length and language, written by AI.',
    go: 'Write a Story →',
    grad: 'linear-gradient(135deg,#f97316,#ef4444)',
    icon: icon(
      <>
        <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20" />
        <path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z" />
      </>,
    ),
  },
  {
    id: 'convert',
    title: 'Content Converter',
    desc: 'Turn any text into a video script, carousel, thread or story caption.',
    go: 'Convert Content →',
    grad: 'linear-gradient(135deg,#06b6d4,#3b82f6)',
    icon: icon(
      <>
        <path d="M17 3l4 4-4 4" />
        <path d="M21 7H8" />
        <path d="M7 21l-4-4 4-4" />
        <path d="M3 17h13" />
      </>,
    ),
  },
  {
    id: 'templates',
    title: 'Hook Templates',
    desc: '12 proven content templates — tap any to copy and use.',
    go: 'Browse Templates →',
    grad: 'linear-gradient(135deg,#10b981,#84cc16)',
    icon: icon(
      <>
        <rect x="3" y="3" width="7" height="7" rx="1.5" />
        <rect x="14" y="3" width="7" height="7" rx="1.5" />
        <rect x="3" y="14" width="7" height="7" rx="1.5" />
        <rect x="14" y="14" width="7" height="7" rx="1.5" />
      </>,
    ),
  },
  {
    id: 'imgtools',
    title: 'Image Tools',
    desc: 'Crop, rotate, filters, text overlay and 9:16 frames — right here.',
    go: 'Edit an Image →',
    grad: 'linear-gradient(135deg,#6366f1,#a855f7)',
    icon: icon(
      <>
        <circle cx="12" cy="12" r="3" />
        <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z" />
      </>,
    ),
  },
  {
    id: 'prompter',
    title: 'Teleprompter',
    desc: 'Auto-scrolling script reader for smooth, hands-free recording.',
    go: 'Open Teleprompter →',
    grad: 'linear-gradient(135deg,#0ea5e9,#22d3ee)',
    icon: icon(
      <>
        <rect x="2" y="4" width="20" height="14" rx="2" />
        <path d="M8 22h8M12 18v4" />
      </>,
    ),
  },
  {
    id: 'voice',
    title: 'Voiceover Studio',
    desc: 'Turn typed text into speech — pick a voice, speed and pitch.',
    go: 'Create Voiceover →',
    grad: 'linear-gradient(135deg,#eab308,#f97316)',
    icon: icon(
      <>
        <path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z" />
        <path d="M19 10v2a7 7 0 0 1-14 0v-2M12 19v4M8 23h8" />
      </>,
    ),
  },
  {
    id: 'storyvideo',
    title: 'Story Video',
    desc: 'Turn your photos into a finished 9:16 MP4 video — free.',
    go: 'Make a Video →',
    grad: 'linear-gradient(135deg,#d946ef,#8b5cf6)',
    icon: icon(
      <>
        <rect x="3" y="5" width="18" height="14" rx="2" />
        <path d="M10 9.5l5 2.5-5 2.5z" />
      </>,
    ),
  },
  {
    id: 'analyze',
    title: 'Upload & Analyze',
    desc: 'Upload a photo and get an honest readiness report before posting.',
    go: 'Analyze a Photo →',
    grad: 'linear-gradient(135deg,#14b8a6,#0ea5e9)',
    icon: icon(
      <>
        <path d="M4 20V10M10 20V4M16 20v-8M22 20H2" />
      </>,
    ),
  },
  {
    id: 'distribute',
    title: 'Distribution Engine',
    desc: 'Repurpose one post for Instagram, TikTok, YouTube, X & Facebook — with your link.',
    go: 'Distribute Content →',
    grad: 'linear-gradient(135deg,#7c3aed,#06b6d4)',
    icon: icon(
      <>
        <circle cx="6" cy="6" r="2.5" />
        <circle cx="18" cy="6" r="2.5" />
        <circle cx="12" cy="18" r="2.5" />
        <path d="M8 7.5l3 8M16 7.5l-3 8M8.5 6h7" />
      </>,
    ),
  },
  {
    id: 'spotlight',
    title: 'Get Featured',
    desc: 'Submit your post for Virello Spotlight — featured on our accounts, with credit to you.',
    go: 'Submit for Spotlight →',
    grad: 'linear-gradient(135deg,#f59e0b,#ef4444)',
    icon: icon(
      <path d="M12 2l2.9 6.3 6.9.8-5.1 4.7 1.4 6.8L12 17.2 5.9 20.6l1.4-6.8L2.2 9.1l6.9-.8z" />,
    ),
  },
];

const MAIN_TOOLS: MainTool[] = ['image', 'video', 'caption'];

export default function CreatorHub() {
  const [tool, setTool] = useState<MainTool>('image');
  const [panel, setPanel] = useState<PanelId | null>(null);
  const [drafts, setDrafts] = useState<Draft[]>([]);

  function pickMain(t: MainTool) {
    setTool(t);
    setPanel(null);
  }

  function openPanel(id: PanelId) {
    setPanel(id);
  }

  function backToMain() {
    setPanel(null);
  }

  function addDraft(d: Draft) {
    setDrafts((prev) => [d, ...prev]);
  }

  function deleteDraft(i: number) {
    setDrafts((prev) => prev.filter((_, idx) => idx !== i));
    notify('Draft deleted');
  }

  return (
    <section aria-label="Creator Hub">
      <style>{`@keyframes creator-spin{to{transform:rotate(360deg)}}`}</style>
      <div
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          flexWrap: 'wrap',
          gap: 10,
          marginBottom: 14,
        }}
      >
        <div>
          <h3 style={{ fontSize: '1.25rem', margin: 0 }}>Creator Hub</h3>
          <p className="small" style={{ margin: '4px 0 0', color: 'var(--mut)' }}>
            AI creation tools — make something worth growing.
          </p>
        </div>
        <span
          style={{
            display: 'inline-block',
            padding: '6px 14px',
            borderRadius: 999,
            fontSize: 12,
            fontWeight: 800,
            letterSpacing: '.04em',
            color: '#fff',
            background: 'var(--grad)',
          }}
        >
          FREE · No credit charge
        </span>
      </div>

      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fill,minmax(220px,1fr))',
          gap: 18,
        }}
      >
        {CARDS.map((c) => {
          const active =
            (MAIN_TOOLS.includes(c.id as MainTool) && panel === null && tool === c.id) ||
            panel === c.id;
          return (
            <button
              key={c.id}
              type="button"
              onClick={() =>
                MAIN_TOOLS.includes(c.id as MainTool)
                  ? pickMain(c.id as MainTool)
                  : openPanel(c.id as PanelId)
              }
              style={{
                textAlign: 'left',
                background: 'var(--surface)',
                border: `1px solid ${active ? 'rgba(249,81,119,.55)' : 'var(--line)'}`,
                borderRadius: 16,
                padding: 18,
                cursor: 'pointer',
                color: 'var(--txt)',
                font: 'inherit',
                boxShadow: active ? '0 8px 24px rgba(249,81,119,.12)' : undefined,
              }}
            >
              <span
                style={{
                  display: 'inline-flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  width: 44,
                  height: 44,
                  borderRadius: 12,
                  background: c.grad,
                  color: '#fff',
                  marginBottom: 12,
                }}
              >
                {c.icon}
              </span>
              <h4 style={{ margin: '0 0 6px', fontSize: '1.02rem' }}>{c.title}</h4>
              <p style={{ margin: '0 0 12px', fontSize: '0.9rem', color: 'var(--mut)' }}>
                {c.desc}
              </p>
              <span style={{ fontSize: '0.9rem', fontWeight: 700, color: 'var(--pink)' }}>
                {c.go}
              </span>
            </button>
          );
        })}
      </div>

      {panel === null && (
        <Workspace
          tool={tool}
          drafts={drafts}
          onAddDraft={addDraft}
          onDeleteDraft={deleteDraft}
        />
      )}

      {panel === 'script' && <TextTools kind="script" onBack={backToMain} />}
      {panel === 'story' && <TextTools kind="story" onBack={backToMain} />}
      {panel === 'convert' && <TextTools kind="convert" onBack={backToMain} />}
      {panel === 'templates' && <HookTemplates onBack={backToMain} />}
      {panel === 'imgtools' && <ImageTools onBack={backToMain} />}
      {panel === 'prompter' && <Teleprompter onBack={backToMain} />}
      {panel === 'voice' && <VoiceoverStudio onBack={backToMain} />}
      {panel === 'storyvideo' && <StoryVideo onBack={backToMain} />}
      {panel === 'analyze' && <UploadAnalyze onBack={backToMain} />}
      {panel === 'distribute' && <DistributionEngine onBack={backToMain} />}
      {panel === 'spotlight' && <Spotlight onBack={backToMain} />}
    </section>
  );
}
