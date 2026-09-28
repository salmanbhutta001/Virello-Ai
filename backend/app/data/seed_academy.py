"""AI Academy seed lessons — Phase 5.

Real educational content (never lorem ipsum). 6 English lessons + Urdu
versions of 2 of them = 8 rows. Each lesson: 4-5 sections of actionable
advice (3-6 sentences each) + a 4-question quiz with explanations.

Honesty rules baked into the content: no bought followers, no bots,
no fake engagement, no guaranteed virality, estimates labeled as estimates.
"""
from __future__ import annotations

SEED_LESSONS: list[dict] = [
    # ------------------------------------------------------------------ 1
    {
        "title": "Writing Hooks That Stop the Scroll",
        "description": (
            "The first three seconds decide whether anyone watches. Learn "
            "hook formulas, how to open on camera, and 5 reusable hook "
            "templates you can steal for any niche."
        ),
        "category": "content",
        "level": "beginner",
        "language": "en",
        "order_index": 1,
        "is_published": True,
        "content_json": {
            "sections": [
                {
                    "heading": "Why the hook is 80% of the video",
                    "body": (
                        "Every platform shows your video to a small test audience "
                        "first. If most of them swipe away in the first 3 seconds, "
                        "the algorithm stops pushing it — your editing and ideas "
                        "never get a chance. The hook is simply the promise you "
                        "make at the start: what will the viewer get, and why now? "
                        "A strong hook doesn't mean clickbait; it means matching "
                        "the first frame and sentence to the curiosity you want "
                        "to create. Think of it as a headline for a newspaper — "
                        "nobody reads a story with a boring headline."
                    ),
                },
                {
                    "heading": "Hook formula 1: the open loop",
                    "body": (
                        "An open loop starts a thought and delays the payoff. "
                        "'I lost 200 followers in one day — here's what the "
                        "analytics showed me' makes the viewer wait for the "
                        "answer. The loop works because the brain dislikes "
                        "unfinished stories and keeps watching to close it. "
                        "Close every loop before the video ends, or viewers "
                        "will feel tricked and won't return. Use one loop per "
                        "short video; stacking three at once feels chaotic. "
                        "Examples: 'Nobody talks about the second week of...', "
                        "'This one setting doubled my reach...'"
                    ),
                },
                {
                    "heading": "Hook formula 2: the specific number",
                    "body": (
                        "Specific numbers beat vague claims because they feel "
                        "measured and real. Compare 'Tips to grow faster' with "
                        "'3 posting mistakes that cost me 40% of my reach'. "
                        "The second hook names the topic, the cost, and the "
                        "promise in one breath. Pick numbers from your real "
                        "experience — never invent statistics, because your "
                        "audience will eventually check. Small specific numbers "
                        "work as well as big ones: 'I filmed this in 11 minutes' "
                        "is honest and relatable. Odd numbers tend to outperform "
                        "round ones in headlines — '7 ideas' beats '10 tips' "
                        "more often than not."
                    ),
                },
                {
                    "heading": "The first 3 seconds on camera",
                    "body": (
                        "Say the hook out loud in the first sentence — never open "
                        "with 'hey guys welcome back to my channel'. Start "
                        "mid-action instead: on the result, the mistake, or the "
                        "question. Put on-screen text that repeats the hook for "
                        "sound-off viewers, because most feeds start muted. "
                        "Cut any throat-clearing from your script; your first "
                        "draft's third sentence is usually the real hook. "
                        "Record the hook last if you like — read it cold and "
                        "pick the take with the most energy."
                    ),
                },
                {
                    "heading": "5 hook templates to reuse",
                    "body": (
                        "One: 'Stop doing X — do Y instead.' (authority + "
                        "contrarian). Two: 'I tried X for 30 days. Here's what "
                        "happened.' (experiment + payoff). Three: 'The X nobody "
                        "tells beginners.' (insider knowledge). Four: 'How to X "
                        "without Y.' (removes the objection). Five: 'POV: you "
                        "finally X.' (relatable moment). Rotate templates so "
                        "your feed doesn't look repetitive, and track which "
                        "ones get the best average watch time. A template is a "
                        "starting point, not a script — fill it with your real "
                        "experience and voice."
                    ),
                },
            ]
        },
        "quiz_json": {
            "questions": [
                {
                    "q": "Why do the first 3 seconds matter so much?",
                    "options": [
                        "The algorithm tests your video on a small audience first",
                        "Viewers decide video quality by the thumbnail alone",
                        "Longer intros get more ad revenue",
                        "The first seconds don't matter, only the ending does",
                    ],
                    "answer": 0,
                    "explanation": (
                        "Platforms show your video to a small test audience first. "
                        "If most swipe away immediately, the algorithm stops pushing it."
                    ),
                },
                {
                    "q": "What is an 'open loop' hook?",
                    "options": [
                        "Repeating your intro twice for emphasis",
                        "Starting a thought and delaying the payoff to create curiosity",
                        "Asking viewers to comment before watching",
                        "Ending the video without a conclusion",
                    ],
                    "answer": 1,
                    "explanation": (
                        "An open loop starts a story or claim and delays the payoff, "
                        "which makes viewers keep watching to close the loop."
                    ),
                },
                {
                    "q": "Which hook is strongest?",
                    "options": [
                        "Tips to grow faster",
                        "Hey guys welcome back to my channel",
                        "3 posting mistakes that cost me 40% of my reach",
                        "Please watch till the end",
                    ],
                    "answer": 2,
                    "explanation": (
                        "Specific numbers ('3 mistakes', '40%') feel measured and real, "
                        "and the hook names the topic, cost, and promise in one breath."
                    ),
                },
                {
                    "q": "What's a good on-camera opening practice?",
                    "options": [
                        "Greet the audience and introduce yourself every time",
                        "Start mid-action and put the hook as on-screen text",
                        "Read your full script word by word",
                        "Begin with background music and no talking",
                    ],
                    "answer": 1,
                    "explanation": (
                        "Start mid-action on the result or question, and repeat the hook "
                        "as on-screen text for sound-off viewers."
                    ),
                },
            ]
        },
    },
    # ------------------------------------------------------------------ 2
    {
        "title": "Hashtags That Actually Work",
        "description": (
            "Hashtags are labels, not lottery tickets. Learn the 5-10 mix "
            "strategy, where to place them, and how to measure which tags "
            "bring real viewers."
        ),
        "category": "content",
        "level": "beginner",
        "language": "en",
        "order_index": 2,
        "is_published": True,
        "content_json": {
            "sections": [
                {
                    "heading": "What hashtags really do",
                    "body": (
                        "Hashtags tell the platform what your post is about so it "
                        "can be shown on topic pages and to interested viewers. "
                        "They are categorization, not promotion — a hashtag alone "
                        "has never made a bad post go viral. Think of them as "
                        "library labels: they help the right reader find the "
                        "right shelf. Niche tags (50K–500K posts) usually "
                        "outperform giant tags like #love because your post can "
                        "actually rank on a smaller page. Relevance beats size "
                        "every time."
                    ),
                },
                {
                    "heading": "The 5-10 mix strategy",
                    "body": (
                        "Use 5 to 10 hashtags per post, split across three sizes: "
                        "2-3 broad tags for the topic (#digitalmarketing), 3-4 "
                        "niche tags for your specific angle (#reelstips), and 1-2 "
                        "branded or community tags you own (#virellogrow). Broad "
                        "tags give reach potential, niche tags give you a real "
                        "chance to rank, and branded tags build a collection of "
                        "your work. Never copy-paste the same 30-tag block on "
                        "every post — platforms read repetition as spammy. Write "
                        "the tags fresh for each post and make sure every one "
                        "describes what is actually in the video."
                    ),
                },
                {
                    "heading": "Where to place them",
                    "body": (
                        "On Instagram and Facebook, put hashtags at the end of "
                        "the caption or in the first comment — both are indexed "
                        "the same. On TikTok, weave 3-5 into or right after the "
                        "caption text. On YouTube, the first 3 tags appear above "
                        "your title, so choose them carefully, and use the tags "
                        "box for the rest. Never hide tags in a color that "
                        "matches the background; it looks deceptive and some "
                        "platforms penalize it. Keywords in the caption itself "
                        "often matter as much as the hashtags — write naturally "
                        "about your topic first, tags second."
                    ),
                },
                {
                    "heading": "Banned and broken tags",
                    "body": (
                        "Some tags get restricted when they are flooded with spam "
                        "— check a tag's page before using it; if recent posts "
                        "look empty or the page shows a warning, skip it. Avoid "
                        "tags unrelated to your content just because they are "
                        "trending; mismatched tags attract the wrong audience, "
                        "who leave fast and hurt your watch time. Rotate your "
                        "tag sets and audit them monthly: drop tags whose pages "
                        "have gone quiet. One banned tag in a block can drag the "
                        "whole post's discovery down, so check, don't guess."
                    ),
                },
                {
                    "heading": "Measuring what works",
                    "body": (
                        "After 2-3 weeks, compare posts: group them by tag set "
                        "and look at reach from non-followers and profile visits "
                        "in your analytics. If a tag set consistently brings "
                        "new viewers who actually watch, keep it; if it brings "
                        "views with zero follows or comments, the audience is "
                        "wrong. Change only one variable at a time — the tags — "
                        "while keeping posting time and format similar. Keep a "
                        "simple note of your 3 best-performing tag sets and "
                        "reuse their structure, not their exact text."
                    ),
                },
            ]
        },
        "quiz_json": {
            "questions": [
                {
                    "q": "What do hashtags primarily do?",
                    "options": [
                        "Guarantee a post goes viral",
                        "Categorize content so interested viewers can find it",
                        "Replace the need for a good caption",
                        "Increase follower count automatically",
                    ],
                    "answer": 1,
                    "explanation": (
                        "Hashtags are labels for categorization — they help the right "
                        "viewers find the right content, but can't make a bad post viral."
                    ),
                },
                {
                    "q": "Which tag set follows the 5-10 mix strategy?",
                    "options": [
                        "30 identical broad tags on every post",
                        "2 broad + 3 niche + 1 branded, written fresh per post",
                        "Only trending tags, even if unrelated",
                        "No hashtags at all",
                    ],
                    "answer": 1,
                    "explanation": (
                        "The mix uses a few broad tags for reach potential, several niche "
                        "tags for ranking chances, and branded tags — written fresh each time."
                    ),
                },
                {
                    "q": "Why should you avoid unrelated trending tags?",
                    "options": [
                        "Trending tags are always banned",
                        "They attract the wrong audience, who leave fast and hurt watch time",
                        "They cost money to use",
                        "They only work on YouTube",
                    ],
                    "answer": 1,
                    "explanation": (
                        "Mismatched tags bring viewers who aren't interested; they leave "
                        "quickly, which signals low quality to the algorithm."
                    ),
                },
                {
                    "q": "How do you know which tags work?",
                    "options": [
                        "Guess based on how popular the tag looks",
                        "Compare non-follower reach and profile visits across tag sets over weeks",
                        "Count total hashtags used",
                        "Ask friends which tags they like",
                    ],
                    "answer": 1,
                    "explanation": (
                        "Group posts by tag set and compare reach from non-followers and "
                        "profile visits over 2-3 weeks — real data, not guesses."
                    ),
                },
            ]
        },
    },
    # ------------------------------------------------------------------ 3
    {
        "title": "Finding Your First 1,000 Real Followers",
        "description": (
            "Slow, honest growth beats fake numbers. Learn to pick a niche, "
            "post consistently, and turn comments into community — without "
            "ever buying followers or using bots."
        ),
        "category": "growth",
        "level": "beginner",
        "language": "en",
        "order_index": 3,
        "is_published": True,
        "content_json": {
            "sections": [
                {
                    "heading": "Why real beats big",
                    "body": (
                        "A thousand followers who care about your topic will "
                        "comment, share, and eventually buy — ten thousand "
                        "bought or uninterested followers will do none of that. "
                        "Platforms measure the ratio of engagement to audience, "
                        "so a dead audience actively suppresses your reach. "
                        "Worse, bought followers and engagement pods violate "
                        "platform rules and can get your account restricted or "
                        "banned. Every tactic in this lesson builds a real "
                        "audience slowly; there are no shortcuts here, and "
                        "anyone selling you one is selling you damage."
                    ),
                },
                {
                    "heading": "Pick a niche you can sustain",
                    "body": (
                        "Your niche is the intersection of what you know, what "
                        "you enjoy, and what a specific group of people wants. "
                        "'Fitness' is too broad to stand out; 'home workouts for "
                        "busy parents' is a niche you can own. Write down 20 "
                        "video ideas right now — if you can't, the niche is too "
                        "narrow or too boring for you. Stay in one niche for at "
                        "least 90 days before judging it; the algorithm needs "
                        "time to learn who likes you. You can broaden later, but "
                        "early focus is what makes you recommendable."
                    ),
                },
                {
                    "heading": "The consistency that actually matters",
                    "body": (
                        "Consistency means a schedule you can keep for a year, "
                        "not a heroic month followed by silence. Three posts a "
                        "week for 12 months beats daily posting for 3 weeks and "
                        "then burnout. Batch your work: film 4 videos in one "
                        "session, edit in another, schedule ahead. Treat the "
                        "calendar like an appointment with your future audience. "
                        "Missing one week won't kill your account, but "
                        "disappearing for two months resets the algorithm's "
                        "memory of you — plan rest, don't just collapse."
                    ),
                },
                {
                    "heading": "Turn comments into community",
                    "body": (
                        "Reply to every genuine comment in your first months — "
                        "each reply doubles the comment count and tells the "
                        "algorithm the post is alive. Ask one real question per "
                        "post so people have something easy to answer. Go "
                        "comment thoughtfully on 5-10 creators in your niche "
                        "daily; their audiences will discover you through value, "
                        "not spam. Never drop 'nice post, check my page' — "
                        "write something that proves you watched. The first "
                        "1,000 followers are won one conversation at a time."
                    ),
                },
                {
                    "heading": "What to do at milestones",
                    "body": (
                        "At 100 followers: find which 3 posts brought them and "
                        "make more of that type. At 500: start a simple series "
                        "so viewers have a reason to follow, not just like. At "
                        "1,000: ask your audience what they want next — a poll "
                        "or question sticker gives you a content calendar. "
                        "Track follower growth weekly, not hourly; daily noise "
                        "will drive you crazy. Celebrate honestly — your early "
                        "followers are your founding community, treat them like "
                        "it and many will stay for years."
                    ),
                },
            ]
        },
        "quiz_json": {
            "questions": [
                {
                    "q": "Why are bought followers harmful?",
                    "options": [
                        "They cost too much money",
                        "They don't engage, which suppresses reach, and they violate platform rules",
                        "They unfollow too quickly",
                        "They only hurt large accounts",
                    ],
                    "answer": 1,
                    "explanation": (
                        "Dead audiences lower your engagement ratio (suppressing reach) and "
                        "buying followers violates platform rules — risking restriction or bans."
                    ),
                },
                {
                    "q": "What makes a good niche?",
                    "options": [
                        "The broadest topic possible to reach everyone",
                        "The intersection of your knowledge, enjoyment, and a specific audience's wants",
                        "Whatever is trending this week",
                        "A topic you know nothing about but seems profitable",
                    ],
                    "answer": 1,
                    "explanation": (
                        "A sustainable niche sits where what you know and enjoy meets what a "
                        "specific group wants — broad enough for 20+ ideas, narrow enough to own."
                    ),
                },
                {
                    "q": "What does real consistency mean?",
                    "options": [
                        "Posting daily for a month no matter what",
                        "A schedule you can keep for a year, like 3 posts a week",
                        "Posting only when you feel inspired",
                        "Posting 10 times a day",
                    ],
                    "answer": 1,
                    "explanation": (
                        "Three posts a week for 12 months beats a heroic daily month followed "
                        "by burnout and silence."
                    ),
                },
                {
                    "q": "What's the best way to turn comments into community?",
                    "options": [
                        "Reply to every genuine comment and ask one real question per post",
                        "Buy comments from engagement pods",
                        "Delete negative comments immediately",
                        "Never reply — it looks desperate",
                    ],
                    "answer": 0,
                    "explanation": (
                        "Replying doubles comment counts and signals an alive post; a real "
                        "question gives people something easy to answer."
                    ),
                },
            ]
        },
    },
    # ------------------------------------------------------------------ 4
    {
        "title": "Selling Your First Product Online",
        "description": (
            "From offer to first sale: how to package what you sell, build "
            "trust with strangers, and accept payments safely with PayPal "
            "or Payoneer."
        ),
        "category": "commerce",
        "level": "beginner",
        "language": "en",
        "order_index": 4,
        "is_published": True,
        "content_json": {
            "sections": [
                {
                    "heading": "Start with one clear offer",
                    "body": (
                        "Your first product should solve one painful problem for "
                        "one type of person — 'a 30-day home workout plan for "
                        "beginners' sells, 'fitness stuff' doesn't. Digital "
                        "products (guides, templates, presets) are the easiest "
                        "start: no inventory, no shipping, instant delivery. "
                        "Price it by the value of the outcome, not your hours — "
                        "a plan that saves someone months of confusion is worth "
                        "more than the weekend it took you to write. Write the "
                        "offer in one sentence before building anything; if you "
                        "can't explain it in one sentence, it's not ready."
                    ),
                },
                {
                    "heading": "Build trust before the sale",
                    "body": (
                        "Strangers don't buy from strangers — they buy from "
                        "people whose free content already helped them. Share "
                        "genuinely useful posts about your product's topic for "
                        "weeks before you launch. Show your face, your process, "
                        "and your real results (with honest caveats, never "
                        "guaranteed outcomes). Collect every kind word as a "
                        "testimonial screenshot from day one. A simple 'about' "
                        "page with your real name and photo converts better "
                        "than an anonymous polished brand."
                    ),
                },
                {
                    "heading": "Accepting payments safely",
                    "body": (
                        "Use established payment providers — PayPal and Payoneer "
                        "both support receiving payments in many countries and "
                        "handle buyer protection for you. Never ask customers to "
                        "send money through informal channels or gift transfers; "
                        "you lose all dispute protection. Set clear refund terms "
                        "before you sell: digital products often offer 7-14 day "
                        "refunds, which actually increases sales by lowering "
                        "risk. Keep a simple ledger of every sale (date, "
                        "amount, buyer email, transaction ID) — you'll need it "
                        "for taxes and for handling disputes calmly."
                    ),
                },
                {
                    "heading": "Your minimum viable sales page",
                    "body": (
                        "You don't need a fancy website: a single page with "
                        "five blocks converts fine. One: the outcome in a "
                        "headline ('Lose the guesswork: 30 days of home "
                        "workouts'). Two: who it's for and not for. Three: "
                        "what's inside, as a simple list. Four: price with the "
                        "refund promise. Five: one clear buy button. Add one "
                        "photo or screenshot of the actual product — mockups "
                        "of things that don't exist destroy trust instantly. "
                        "Test the full purchase flow yourself before sharing "
                        "the link with anyone."
                    ),
                },
                {
                    "heading": "After the first sale",
                    "body": (
                        "Deliver instantly and follow up within 48 hours asking "
                        "how it's going — this is where testimonials and repeat "
                        "buyers come from. Ask happy buyers for a review with "
                        "one specific question ('What changed for you in week "
                        "2?') instead of a generic 'leave a review'. Fix the "
                        "first complaint you hear twice; early feedback is your "
                        "free product team. Don't scale ads or affiliates until "
                        "10+ strangers have bought and at least a few rave "
                        "about it — premature scaling multiplies problems, not "
                        "just revenue."
                    ),
                },
            ]
        },
        "quiz_json": {
            "questions": [
                {
                    "q": "What's the best first product?",
                    "options": [
                        "A broad bundle covering many topics",
                        "One clear offer solving one painful problem for one type of person",
                        "The most expensive thing you can imagine",
                        "Whatever a competitor sells, copied exactly",
                    ],
                    "answer": 1,
                    "explanation": (
                        "One clear offer ('30-day home workout plan for beginners') is "
                        "explainable in one sentence and sellable; vague bundles aren't."
                    ),
                },
                {
                    "q": "How do you build trust before launching?",
                    "options": [
                        "Keep everything secret until launch day",
                        "Share genuinely useful free content on the topic for weeks",
                        "Promise guaranteed results",
                        "Hide your identity for a professional look",
                    ],
                    "answer": 1,
                    "explanation": (
                        "Strangers buy from people whose free content already helped them — "
                        "plus your real name/face and honest results."
                    ),
                },
                {
                    "q": "What's the safe way to accept payments?",
                    "options": [
                        "Ask buyers to send money via informal gift transfers",
                        "Use established providers like PayPal/Payoneer with clear refund terms",
                        "Accept only cash on delivery worldwide",
                        "Skip receipts to save time",
                    ],
                    "answer": 1,
                    "explanation": (
                        "Established providers give buyer protection and dispute handling; "
                        "informal transfers lose all protection. Keep a ledger of every sale."
                    ),
                },
                {
                    "q": "When should you scale with ads or affiliates?",
                    "options": [
                        "Immediately at launch for maximum speed",
                        "After 10+ strangers bought and several rave about it",
                        "Never — scaling is always bad",
                        "Only after 10,000 followers",
                    ],
                    "answer": 1,
                    "explanation": (
                        "Premature scaling multiplies problems, not just revenue — validate "
                        "with real buyers and testimonials first."
                    ),
                },
            ]
        },
    },
    # ------------------------------------------------------------------ 5
    {
        "title": "Consistent Posting Without Burnout",
        "description": (
            "Content batching, a realistic weekly schedule, and planned rest — "
            "how to stay visible for a year without burning out in month two."
        ),
        "category": "growth",
        "level": "beginner",
        "language": "en",
        "order_index": 5,
        "is_published": True,
        "content_json": {
            "sections": [
                {
                    "heading": "Burnout is a strategy problem",
                    "body": (
                        "Most creator burnout isn't caused by lack of passion — "
                        "it's caused by deciding what to post every single day. "
                        "Decision fatigue plus filming, editing, and posting "
                        "daily is a recipe for quitting by week six. The fix is "
                        "structural: separate idea generation, filming, and "
                        "editing into different days so no single day does "
                        "everything. A creator who posts 3 times a week for a "
                        "year will always beat the one who posts daily for a "
                        "month and vanishes."
                    ),
                },
                {
                    "heading": "Batching: film once, post all week",
                    "body": (
                        "Pick one filming day per week and shoot 3-4 videos back "
                        "to back in the same setup — same lighting, same shirt, "
                        "no one can tell. Keep a running list of ideas in your "
                        "phone notes so filming day never starts with a blank "
                        "page. Edit in one sitting the next day while you're in "
                        "'editor mode' instead of switching contexts daily. "
                        "Schedule everything ahead using the platform's built-in "
                        "scheduler or a simple calendar reminder. Batching turns "
                        "content from a daily emergency into a weekly appointment."
                    ),
                },
                {
                    "heading": "A realistic weekly schedule",
                    "body": (
                        "Here's a template that works for most beginners: Monday "
                        "30 minutes of idea capture, Wednesday 2 hours filming "
                        "3 videos, Thursday 2 hours editing, and posts go live "
                        "Tuesday/Thursday/Saturday on a scheduler. Total: about "
                        "5 hours a week — a serious side project, not a second "
                        "job. Adjust the days to your life, but protect the "
                        "filming block like a meeting you can't cancel. If a "
                        "week explodes, post twice instead of zero — the streak "
                        "of showing up matters more than the count."
                    ),
                },
                {
                    "heading": "Rest is part of the schedule",
                    "body": (
                        "Plan one full week off per quarter and announce it — "
                        "'I'm taking next week off, back with a series on the "
                        "15th' builds anticipation instead of worry. Keep 2-3 "
                        "evergreen posts banked for emergencies: a repost of "
                        "your best performer with a fresh caption counts. "
                        "Watch for warning signs: dreading filming, snapping at "
                        "comments, or refreshing analytics at midnight. When "
                        "those appear, take 3 days off immediately — the "
                        "algorithm forgives a short break, but it can't fix a "
                        "creator who quits."
                    ),
                },
            ]
        },
        "quiz_json": {
            "questions": [
                {
                    "q": "What usually causes creator burnout?",
                    "options": [
                        "Lack of talent",
                        "Deciding what to post every day plus doing everything daily",
                        "Having too many followers",
                        "Posting only once a week",
                    ],
                    "answer": 1,
                    "explanation": (
                        "Burnout is structural: daily decision fatigue plus filming, editing "
                        "and posting every day leads to quitting — not lack of passion."
                    ),
                },
                {
                    "q": "What is content batching?",
                    "options": [
                        "Posting 10 times in one day",
                        "Filming several videos in one session and editing/scheduling separately",
                        "Copying other creators' content",
                        "Deleting old posts in bulk",
                    ],
                    "answer": 1,
                    "explanation": (
                        "Batching separates filming, editing, and scheduling into different "
                        "blocks — e.g. film 3-4 videos in one session, schedule them for the week."
                    ),
                },
                {
                    "q": "What should you do when a week gets chaotic?",
                    "options": [
                        "Quit for a month to recover",
                        "Post twice instead of zero — keep the streak of showing up",
                        "Post 10 low-effort videos to catch up",
                        "Delete the schedule entirely",
                    ],
                    "answer": 1,
                    "explanation": (
                        "The streak of showing up matters more than the count; two real posts "
                        "beat a heroic catch-up or total silence."
                    ),
                },
                {
                    "q": "How should you handle planned rest?",
                    "options": [
                        "Disappear silently and hope nobody notices",
                        "Announce a week off per quarter and keep 2-3 evergreen posts banked",
                        "Never rest — the algorithm punishes any break",
                        "Rest only after hitting 100K followers",
                    ],
                    "answer": 1,
                    "explanation": (
                        "Announced rest builds anticipation; banked evergreen posts cover "
                        "emergencies; short breaks are forgiven, quitting isn't."
                    ),
                },
            ]
        },
    },
    # ------------------------------------------------------------------ 6
    {
        "title": "Reading Analytics Like a Pro",
        "description": (
            "Reach vs engagement, retention graphs, and the 3 numbers to check "
            "weekly — how to turn your analytics page from anxiety into a "
            "content plan."
        ),
        "category": "marketing",
        "level": "beginner",
        "language": "en",
        "order_index": 6,
        "is_published": True,
        "content_json": {
            "sections": [
                {
                    "heading": "Reach is not the scoreboard",
                    "body": (
                        "Reach counts how many screens saw your post — it says "
                        "nothing about whether anyone cared. A post with 10,000 "
                        "reach and 50 likes underperformed a post with 2,000 "
                        "reach and 300 likes, because the second one actually "
                        "moved people. Beginners obsess over reach because it's "
                        "the biggest number; professionals watch what happened "
                        "after the view. High reach with low engagement means "
                        "your hook worked but the content didn't deliver — fix "
                        "the middle, not the thumbnail."
                    ),
                },
                {
                    "heading": "The 3 numbers to check weekly",
                    "body": (
                        "One: average watch time (or retention) — the percentage "
                        "of the video people actually watched. Above 50% on "
                        "short video is strong; under 30% means rework your "
                        "openings. Two: engagement rate — likes plus comments "
                        "plus shares divided by reach. Three: follows per post "
                        "— how many viewers converted into followers, which is "
                        "the real growth signal. Check these once a week as "
                        "averages across posts, never judge a single post in "
                        "isolation. Write the three numbers in a simple note "
                        "every Sunday; trends over a month tell you everything."
                    ),
                },
                {
                    "heading": "Reading the retention graph",
                    "body": (
                        "Open any video's retention graph: the line shows what "
                        "fraction of viewers is still watching at each second. "
                        "A steep drop in the first 3 seconds is a hook problem "
                        "— rewrite your openings. A gradual slide means the "
                        "pacing drags — cut ruthlessly in the middle. A sudden "
                        "cliff at one timestamp means something specific lost "
                        "them (a tangent, a slow demo); find it and don't repeat "
                        "it. A bump upward means replays — that moment is gold, "
                        "make more content around it."
                    ),
                },
                {
                    "heading": "From numbers to next week's plan",
                    "body": (
                        "Sort last month's posts by follows-per-post and list "
                        "the top 3 topics — that's your content calendar for "
                        "next month, with variations. For the bottom 3, write "
                        "one sentence each on what probably failed (hook? "
                        "pacing? wrong audience?) and change one variable at a "
                        "time. If a format works twice, make it a series — "
                        "series give viewers a reason to follow instead of just "
                        "like. Review monthly, adjust quarterly; changing "
                        "strategy every three days based on daily noise is how "
                        "accounts drift into randomness."
                    ),
                },
            ]
        },
        "quiz_json": {
            "questions": [
                {
                    "q": "A post has 10,000 reach and 50 likes. Another has 2,000 reach and 300 likes. Which performed better?",
                    "options": [
                        "The first — reach is everything",
                        "The second — it moved people, shown by far higher engagement",
                        "They performed equally",
                        "Neither — only follower count matters",
                    ],
                    "answer": 1,
                    "explanation": (
                        "Reach only counts screens; engagement shows people cared. The "
                        "second post's engagement rate is dramatically higher."
                    ),
                },
                {
                    "q": "What does a steep retention drop in the first 3 seconds mean?",
                    "options": [
                        "The video is too short",
                        "A hook problem — rewrite your openings",
                        "The topic is wrong for everyone",
                        "You should post at a different time",
                    ],
                    "answer": 1,
                    "explanation": (
                        "Early drop-offs mean viewers never got past the opening — the "
                        "hook, not the topic or timing, is the first suspect."
                    ),
                },
                {
                    "q": "Which three numbers should you track weekly?",
                    "options": [
                        "Followers, following, post count",
                        "Average watch time, engagement rate, follows per post",
                        "Likes, views, shares only",
                        "Profile visits, website clicks, email signups",
                    ],
                    "answer": 1,
                    "explanation": (
                        "Watch time, engagement rate, and follows-per-post together show "
                        "whether content holds attention, moves people, and converts."
                    ),
                },
                {
                    "q": "How should you turn analytics into a plan?",
                    "options": [
                        "Change strategy every day based on the latest post",
                        "Sort by follows-per-post, double down on top topics, fix one variable at a time",
                        "Delete all low-performing posts immediately",
                        "Copy whatever is trending regardless of your niche",
                    ],
                    "answer": 1,
                    "explanation": (
                        "Top topics by follows-per-post become next month's calendar; diagnose "
                        "failures one variable at a time; review monthly, not daily."
                    ),
                },
            ]
        },
    },
    # ------------------------------------------------------------------ 7
    {
        "title": "Mustaqil Posting Baghair Burnout Ke",
        "description": (
            "Content batching, haftay ka realistic schedule aur planned rest — "
            "aik saal tak nazar me rehne ka tareeqa, doosre mahine thakay "
            "baghair."
        ),
        "category": "growth",
        "level": "beginner",
        "language": "ur",
        "order_index": 7,
        "is_published": True,
        "content_json": {
            "sections": [
                {
                    "heading": "Burnout strategy ka masla hai",
                    "body": (
                        "Zyada tar creators ka burnout passion ki kami se nahi "
                        "hota — roz ye faisla karne se hota hai ke aaj kya post "
                        "karna hai. Roz faisla, filming, editing aur posting "
                        "aik saath karna chhatay haftay tak haar manwane ka "
                        "nuskha hai. Hal structural hai: idea banana, filming "
                        "aur editing ko alag alag dinon me baant do taake koi "
                        "aik din sab kuch na kare. Jo creator haftay me 3 baar "
                        "aik saal tak post kare, wo hamesha us se jeet ta hai jo "
                        "roz post karke aik mahine me ghaib ho jaye."
                    ),
                },
                {
                    "heading": "Batching: aik din shoot, poora hafta post",
                    "body": (
                        "Haftay me aik filming day rakho aur aik hi setup me "
                        "lagatar 3-4 videos bana lo — same lighting, same kapray, "
                        "kisi ko farq nahi parega. Phone ke notes me ideas ki "
                        "list hamesha chalti rakho taake filming day kabhi "
                        "khaali zehen se shuru na ho. Agle din aik hi baar me "
                        "editing kar lo, roz context switch karne ke bajaye. "
                        "Sab kuch pehle se schedule kar do. Batching content ko "
                        "roz ki emergency se haftay ki appointment bana deti hai."
                    ),
                },
                {
                    "heading": "Haftay ka realistic schedule",
                    "body": (
                        "Ye template aksar beginners ke liye kaam karta hai: "
                        "Peer ko 30 minute idea capture, Budh ko 2 ghante me "
                        "3 videos ki filming, Jumeraat ko 2 ghante editing, aur "
                        "posts Mangal/Jumeraat/Hafta ko scheduler se live. "
                        "Kul: haftay me taqreeban 5 ghante — aik serious side "
                        "project, doosri naukri nahi. Din apni zindagi ke "
                        "mutabiq badal lo, lekin filming block ko aisi meeting "
                        "samjho jo cancel nahi ho sakti. Agar koi hafta kharab "
                        "ho jaye to zero ke bajaye do posts kar do — hazir "
                        "rehne ki streak tadaad se zyada ahem hai."
                    ),
                },
                {
                    "heading": "Aaraam schedule ka hissa hai",
                    "body": (
                        "Har quarter me aik poora hafta chhutti plan karo aur "
                        "elaan kar do — 'Agla hafta chhutti, 15 ko nayi series "
                        "ke saath wapas' fikar ke bajaye intezar paida karta "
                        "hai. Emergency ke liye 2-3 evergreen posts bank me "
                        "rakho: apni best post ko naye caption ke saath repost "
                        "karna bhi chalta hai. Warning signs pehchano: filming "
                        "se dil ujarrna, comments pe chirchirahat, ya aadhi raat "
                        "ko analytics refresh karna. Ye nazar aaye to foran 3 "
                        "din ki chhutti lo — chhoti break algorithm maaf kar "
                        "deta hai, lekin haar manne wale creator ko koi theek "
                        "nahi kar sakta."
                    ),
                },
            ]
        },
        "quiz_json": {
            "questions": [
                {
                    "q": "Creator burnout aksar kis wajah se hota hai?",
                    "options": [
                        "Talent ki kami se",
                        "Roz post ka faisla plus roz sab kaam aik saath karne se",
                        "Zyada followers hone se",
                        "Haftay me aik baar post karne se",
                    ],
                    "answer": 1,
                    "explanation": (
                        "Burnout structural hai: roz ka faisla-thakaan plus filming, "
                        "editing aur posting — passion ki kami nahi."
                    ),
                },
                {
                    "q": "Content batching kya hai?",
                    "options": [
                        "Aik din me 10 posts karna",
                        "Aik session me kayi videos banana, editing/scheduling alag din",
                        "Doosron ka content copy karna",
                        "Purani posts aik saath delete karna",
                    ],
                    "answer": 1,
                    "explanation": (
                        "Batching me filming, editing aur scheduling alag blocks me hoti "
                        "hai — masalan aik din 3-4 videos, phir haftay bhar schedule."
                    ),
                },
                {
                    "q": "Jab hafta kharab ho jaye to kya karna chahiye?",
                    "options": [
                        "Aik mahine ke liye chhor do",
                        "Zero ke bajaye do posts kar do — hazir rehne ki streak rakho",
                        "Catch up ke liye 10 halki videos post kar do",
                        "Schedule hi khatam kar do",
                    ],
                    "answer": 1,
                    "explanation": (
                        "Hazir rehne ki streak tadaad se ahem hai; do asli posts "
                        "heroic catch-up ya khamoshi se behtar hain."
                    ),
                },
                {
                    "q": "Planned rest kaise handle karein?",
                    "options": [
                        "Chup chaap ghaib ho jao",
                        "Har quarter aik haftay ki chhutti ka elaan karo aur 2-3 evergreen posts bank me rakho",
                        "Kabhi aaraam na karo — algorithm break ki saza deta hai",
                        "Sirf 100K followers ke baad aaraam karo",
                    ],
                    "answer": 1,
                    "explanation": (
                        "Elaan shuda chhutti intezar paida karti hai; bank ki posts "
                        "emergency sambhalti hain; chhoti break maaf, haar nahi."
                    ),
                },
            ]
        },
    },
    # ------------------------------------------------------------------ 8
    {
        "title": "Analytics Ko Pro Ki Tarah Parhna",
        "description": (
            "Reach vs engagement, retention graph, aur haftay me check karne "
            "wale 3 numbers — analytics page ko pareshani se content plan me "
            "badlo."
        ),
        "category": "marketing",
        "level": "beginner",
        "language": "ur",
        "order_index": 8,
        "is_published": True,
        "content_json": {
            "sections": [
                {
                    "heading": "Reach scoreboard nahi hai",
                    "body": (
                        "Reach batata hai ke kitni screens ne post dekhi — ye "
                        "nahi batata ke kisi ne parwah ki ya nahi. 10,000 reach "
                        "aur 50 likes wali post, 2,000 reach aur 300 likes wali "
                        "post se kamzor hai, kyunke doosri ne logon ko harkat "
                        "me laya. Beginners reach ke peeche bhagte hain kyunke "
                        "ye sab se bara number hai; professionals dekhte hain ke "
                        "view ke baad kya hua. Zyada reach kam engagement ke "
                        "saath matlab hook kaam kar gaya lekin content deliver "
                        "na kar saka — darmiyan theek karo, thumbnail nahi."
                    ),
                },
                {
                    "heading": "Haftay me check karne wale 3 numbers",
                    "body": (
                        "Aik: average watch time (retention) — logon ne video "
                        "ka kitna hissa dekha. Short video me 50% se upar "
                        "mazboot hai; 30% se neeche matlab openings dobara "
                        "banao. Do: engagement rate — likes plus comments plus "
                        "shares taqseem reach. Teen: har post pe kitne follows — "
                        "ye asal growth signal hai. Inhe haftay me aik baar "
                        "average ke tor pe dekho, kabhi aik post ko akela judge "
                        "na karo. Har Itwar ye teen numbers aik note me likh lo; "
                        "mahine bhar ka trend sab kuch bata deta hai."
                    ),
                },
                {
                    "heading": "Retention graph parhna",
                    "body": (
                        "Kisi video ka retention graph kholo: line batati hai ke "
                        "har second pe kitne viewers baqi hain. Pehle 3 second "
                        "me tez girawat hook ka masla hai — openings dobara "
                        "likho. Dheemi girawat matlab pacing sust hai — "
                        "darmiyan ko berahmi se kato. Aik waqt pe achanak "
                        "girawat matlab kisi khaas cheez ne viewers khoye "
                        "(ghair zaroori baat, slow demo); usay dhoondo aur "
                        "dohrao nahi. Upar ki taraf uchhal matlab replays — wo "
                        "lamha sona hai, usi pe mazeed content banao."
                    ),
                },
                {
                    "heading": "Numbers se agle haftay ka plan",
                    "body": (
                        "Pichle mahine ki posts ko follows-per-post ke hisab se "
                        "tartib do aur top 3 topics nikalo — ye agle mahine ka "
                        "content calendar hai, variations ke saath. Neechay ki "
                        "3 posts ke liye aik aik jumla likho ke kya fail hua "
                        "(hook? pacing? ghalat audience?) aur aik waqt me aik "
                        "variable badlo. Agar koi format do baar chale to usay "
                        "series bana do — series viewers ko follow karne ki "
                        "wajah deti hai, sirf like ki nahi. Mahana review karo, "
                        "quarterly adjust karo; roz ke shor pe har teen din me "
                        "strategy badalna accounts ko be-tarteebi me dhakel deta "
                        "hai."
                    ),
                },
            ]
        },
        "quiz_json": {
            "questions": [
                {
                    "q": "10,000 reach/50 likes wali post vs 2,000 reach/300 likes wali — kaunsi behtar?",
                    "options": [
                        "Pehli — reach sab kuch hai",
                        "Doosri — is ne logon ko harkat me laya, engagement kai guna zyada",
                        "Dono barabar hain",
                        "Koi nahi — sirf follower count ahem hai",
                    ],
                    "answer": 1,
                    "explanation": (
                        "Reach sirf screens ginta hai; engagement batata hai ke logon ne "
                        "parwah ki. Doosri post ka engagement rate kai guna zyada hai."
                    ),
                },
                {
                    "q": "Pehle 3 second me retention ki tez girawat ka kya matlab hai?",
                    "options": [
                        "Video bohat chhoti hai",
                        "Hook ka masla — openings dobara likho",
                        "Topic sab ke liye ghalat hai",
                        "Ghalat waqt pe post ki",
                    ],
                    "answer": 1,
                    "explanation": (
                        "Shuru me girawat matlab viewers opening se aage nahi barhe — "
                        "pehla shak hook pe, topic ya timing pe nahi."
                    ),
                },
                {
                    "q": "Haftay me kaunse 3 numbers track karne chahiye?",
                    "options": [
                        "Followers, following, post count",
                        "Average watch time, engagement rate, follows per post",
                        "Sirf likes, views, shares",
                        "Profile visits, website clicks, email signups",
                    ],
                    "answer": 1,
                    "explanation": (
                        "Watch time, engagement rate aur follows-per-post mil kar batate "
                        "hain ke content rokta hai, harkat me lata hai, aur convert karta hai."
                    ),
                },
                {
                    "q": "Analytics se plan kaise banayein?",
                    "options": [
                        "Roz latest post dekh kar strategy badal do",
                        "Follows-per-post se tartib do, top topics pe double down karo, aik waqt me aik variable badlo",
                        "Kamzor posts foran delete kar do",
                        "Trending copy karo chahe niche se match na kare",
                    ],
                    "answer": 1,
                    "explanation": (
                        "Top topics agle mahine ka calendar bante hain; failures ka aik aik "
                        "variable se tajziya karo; mahana review, roz nahi."
                    ),
                },
            ]
        },
    },
]
