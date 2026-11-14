'use client';

import { useMemo, useState } from 'react';

/**
 * Free Hashtag Generator (client island).
 *
 * 100% client-side: suggestions are built in the browser from the words
 * the user types plus built-in starter sets per niche. No API calls, no
 * network requests, nothing leaves the browser. The tags are labelled
 * honestly as starter ideas — no tool can promise reach, and this one
 * does not pretend to know what is trending.
 */

type Platform = 'instagram' | 'tiktok' | 'x';

const PLATFORMS: { id: Platform; label: string; count: number; note: string }[] = [
  {
    id: 'instagram',
    label: 'Instagram',
    count: 12,
    note: 'Instagram posts usually work well with 8–12 hashtags.',
  },
  {
    id: 'tiktok',
    label: 'TikTok',
    count: 5,
    note: 'TikTok works best with 3–5 hashtags.',
  },
  {
    id: 'x',
    label: 'X',
    count: 3,
    note: 'X posts must stay under 280 characters in total — a few tags go a long way.',
  },
];

const NICHES: { id: string; label: string; tags: string[] }[] = [
  {
    id: 'general',
    label: 'General / creator',
    tags: ['contentcreator', 'creator', 'creatorsupport', 'contentcreation', 'socialmediatips', 'growonsocialmedia', 'creatoreconomy', 'digitalcreator', 'newcreator', 'contentideas'],
  },
  {
    id: 'fitness',
    label: 'Fitness & health',
    tags: ['fitness', 'fitlife', 'workout', 'gymlife', 'healthylifestyle', 'fitnessmotivation', 'homeworkout', 'fitspo', 'wellness', 'strongnotskinny'],
  },
  {
    id: 'food',
    label: 'Food & cooking',
    tags: ['foodie', 'foodlover', 'homecooking', 'recipe', 'foodphotography', 'instafood', 'cooking', 'foodblogger', 'tasty', 'eatwell'],
  },
  {
    id: 'travel',
    label: 'Travel',
    tags: ['travel', 'wanderlust', 'travelgram', 'explore', 'adventure', 'travelphotography', 'vacation', 'travelblogger', 'beautifuldestinations', 'traveldiary'],
  },
  {
    id: 'fashion',
    label: 'Fashion & style',
    tags: ['fashion', 'ootd', 'style', 'streetstyle', 'fashionblogger', 'outfitinspo', 'styleinspo', 'fashionista', 'whatiwore', 'lookoftheday'],
  },
  {
    id: 'photography',
    label: 'Photography',
    tags: ['photography', 'photooftheday', 'photographer', 'photoshoot', 'portrait', 'landscape', 'streetphotography', 'photo', 'capture', 'visualstorytelling'],
  },
  {
    id: 'business',
    label: 'Business & freelancing',
    tags: ['smallbusiness', 'entrepreneur', 'businessowner', 'freelancer', 'sidehustle', 'businesstips', 'startup', 'workfromanywhere', 'solopreneur', 'onlinebusiness'],
  },
  {
    id: 'beauty',
    label: 'Beauty & skincare',
    tags: ['beauty', 'skincare', 'makeup', 'selfcare', 'beautytips', 'glowup', 'skincareroutine', 'beautyblogger', 'naturalbeauty', 'makeuplover'],
  },
  {
    id: 'tech',
    label: 'Tech & gadgets',
    tags: ['tech', 'technology', 'gadgets', 'techtips', 'innovation', 'ai', 'apps', 'technews', 'digitaltools', 'futuretech'],
  },
  {
    id: 'music',
    label: 'Music',
    tags: ['music', 'musician', 'newmusic', 'songwriter', 'musiclover', 'singer', 'producer', 'livemusic', 'indiemusic', 'musically'],
  },
  {
    id: 'education',
    label: 'Education & learning',
    tags: ['learning', 'education', 'studygram', 'studytips', 'knowledge', 'learnsomethingnew', 'studentlife', 'onlinelearning', 'studywithme', 'edutok'],
  },
  {
    id: 'pets',
    label: 'Pets & animals',
    tags: ['pets', 'petlover', 'dogsofinstagram', 'catsofinstagram', 'animallover', 'petlife', 'cute', 'doglover', 'catlover', 'petphotography'],
  },
  {
    id: 'art',
    label: 'Art & design',
    tags: ['art', 'artist', 'design', 'illustration', 'creative', 'artwork', 'digitalart', 'handmade', 'artoftheday', 'creativity'],
  },
];

const BROAD_STARTERS = [
  'explorepage',
  'foryou',
  'trending',
  'instagood',
  'reels',
  'viral',
  'discover',
  'community',
];

function slugify(word: string): string {
  return word
    .toLowerCase()
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]/g, '');
}

function topicTags(topic: string): string[] {
  const words = topic
    .split(/[\s,;|/]+/)
    .map(slugify)
    .filter((w) => w.length >= 3 && w.length <= 20);
  const out: string[] = [];
  const seen = new Set<string>();
  for (const w of words) {
    if (!seen.has(w)) {
      seen.add(w);
      out.push(w);
    }
  }
  // Two-word combos from the topic (e.g. "ceramic mugs" -> ceramicmugs).
  for (let i = 0; i + 1 < words.length && out.length < 10; i += 1) {
    const combo = words[i] + words[i + 1];
    if (combo.length <= 24 && !seen.has(combo)) {
      seen.add(combo);
      out.push(combo);
    }
  }
  return out;
}

async function copyText(text: string): Promise<boolean> {
  try {
    await navigator.clipboard.writeText(text);
    return true;
  } catch {
    try {
      const ta = document.createElement('textarea');
      ta.value = text;
      ta.style.position = 'fixed';
      ta.style.opacity = '0';
      document.body.appendChild(ta);
      ta.select();
      document.execCommand('copy');
      document.body.removeChild(ta);
      return true;
    } catch {
      return false;
    }
  }
}

export default function HashtagTool() {
  const [topic, setTopic] = useState('');
  const [niche, setNiche] = useState('general');
  const [platform, setPlatform] = useState<Platform>('instagram');
  const [error, setError] = useState('');
  const [copied, setCopied] = useState(false);
  const [generated, setGenerated] = useState(false);

  const platformMeta = PLATFORMS.find((p) => p.id === platform) as (typeof PLATFORMS)[number];
  const nicheMeta = NICHES.find((n) => n.id === niche) as (typeof NICHES)[number];

  const result = useMemo(() => {
    if (!generated) return null;
    const fromTopic = topicTags(topic);
    const nicheTags = nicheMeta.tags.filter((t) => !fromTopic.includes(t));
    const broad = BROAD_STARTERS.filter(
      (t) => !fromTopic.includes(t) && !nicheTags.includes(t),
    );
    // Mix: topic words first, then niche starters, then a couple of broad ones.
    const mixed = [...fromTopic, ...nicheTags, ...broad];
    const unique = [...new Set(mixed)];
    return unique.slice(0, platformMeta.count);
  }, [generated, topic, nicheMeta, platformMeta]);

  function generate() {
    if (topic.trim().length < 3) {
      setError('Please describe your post in a few words first.');
      return;
    }
    setError('');
    setCopied(false);
    setGenerated(true);
  }

  async function handleCopy() {
    if (!result || result.length === 0) return;
    const ok = await copyText(result.map((h) => `#${h}`).join(' '));
    setCopied(ok);
    if (ok) window.setTimeout(() => setCopied(false), 2000);
  }

  return (
    <div className="tool-wrap">
      <div className="card tool-card">
        <div className="field">
          <label htmlFor="tool-topic">What is your post about?</label>
          <textarea
            id="tool-topic"
            rows={3}
            value={topic}
            onChange={(e) => {
              setTopic(e.target.value);
              setGenerated(false);
            }}
            placeholder="e.g. My new handmade ceramic mugs, fresh out of the kiln"
            maxLength={500}
          />
        </div>

        <div className="field">
          <label htmlFor="tool-niche">Pick your niche</label>
          <select
            id="tool-niche"
            value={niche}
            onChange={(e) => {
              setNiche(e.target.value);
              setGenerated(false);
            }}
            style={{ width: '100%', padding: '10px 12px', borderRadius: 10, border: '1px solid var(--line)' }}
          >
            {NICHES.map((n) => (
              <option key={n.id} value={n.id}>
                {n.label}
              </option>
            ))}
          </select>
        </div>

        <div className="field">
          <label>Platform</label>
          <div className="chip-row" role="group" aria-label="Platform">
            {PLATFORMS.map((p) => (
              <button
                key={p.id}
                type="button"
                className={`chip${platform === p.id ? ' active' : ''}`}
                onClick={() => {
                  setPlatform(p.id);
                  setGenerated(false);
                }}
                aria-pressed={platform === p.id}
              >
                {p.label}
              </button>
            ))}
          </div>
          <p className="small mut" style={{ marginTop: 8 }}>{platformMeta.note}</p>
        </div>

        <button
          type="button"
          className="btn btn-grad"
          onClick={generate}
          disabled={topic.trim().length < 3}
          style={{ width: '100%' }}
        >
          Generate Hashtags — Free
        </button>
        <p className="small mut center" style={{ marginTop: 10 }}>
          Free to use — no signup, no card. Everything runs in your browser;
          nothing you type is sent anywhere.
        </p>

        {error !== '' && (
          <div className="tool-error" role="alert">
            {error}
          </div>
        )}

        {result && (
          <div className="tool-result">
            <div className="tag-list">
              {result.map((h) => (
                <span key={h} className="tag">#{h}</span>
              ))}
            </div>
            <div className="tool-actions">
              <button
                type="button"
                className="btn btn-ghost btn-sm"
                onClick={handleCopy}
              >
                {copied ? 'Copied ✓' : 'Copy all hashtags'}
              </button>
              <button
                type="button"
                className="btn btn-ghost btn-sm"
                onClick={generate}
              >
                Generate again
              </button>
            </div>
            <p className="small mut" style={{ marginTop: 12 }}>
              Starter ideas built from your own words plus common tags for the{' '}
              {nicheMeta.label.toLowerCase()} niche — not live trend data, and
              not a promise of reach. Pick the ones that genuinely fit your
              post; a few relevant tags beat a long list of random ones.
            </p>
          </div>
        )}
      </div>
    </div>
  );
}
