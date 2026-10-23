#!/usr/bin/env node
/**
 * Post-build: keep blog articles on the site's established flat URL
 * scheme — /blog-<slug>.html — instead of Next's /blog/<slug>.html.
 *
 * The flat scheme is what is indexed and linked across the site; a raw
 * `next build` export would silently move every article under /blog/
 * and break those URLs. Runs automatically via the `postbuild` script.
 *
 * Steps:
 *  1. Move out/blog/<slug>.html -> out/blog-<slug>.html for every slug
 *     in src/data/articles.json.
 *  2. Rewrite every reference (plain and JSON-escaped) from
 *     /blog/<slug>.html to /blog-<slug>.html across the export.
 *  3. Remove the emptied out/blog directory.
 *  4. Fail the build if any /blog/<slug> reference survives.
 */
import { existsSync, readdirSync, readFileSync, renameSync, rmdirSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const webRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const outDir = join(webRoot, 'out');
const articles = JSON.parse(readFileSync(join(webRoot, 'src/data/articles.json'), 'utf8'));
const slugs = articles.map((a) => a.slug).filter(Boolean);

if (!existsSync(outDir)) {
  console.error('[fix-article-urls] out/ missing — run `next build` first.');
  process.exit(1);
}

// 1) Move article files to the flat scheme.
let moved = 0;
for (const slug of slugs) {
  const from = join(outDir, 'blog', `${slug}.html`);
  const to = join(outDir, `blog-${slug}.html`);
  if (existsSync(from)) {
    renameSync(from, to);
    moved += 1;
  } else if (!existsSync(to)) {
    console.error(`[fix-article-urls] article missing from export: ${slug}`);
    process.exit(1);
  }
}

// 2) Rewrite references everywhere in the export (text files only).
const exts = new Set(['.html', '.xml', '.txt', '.js', '.json', '.css']);
function* walk(dir) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) yield* walk(p);
    else if (exts.has(name.slice(name.lastIndexOf('.')))) yield p;
  }
}
let touched = 0;
for (const file of walk(outDir)) {
  let text = readFileSync(file, 'utf8');
  let next = text;
  for (const slug of slugs) {
    next = next
      .split(`/blog/${slug}.html`).join(`/blog-${slug}.html`)
      .split(`\\/blog\\/${slug}.html`).join(`\\/blog-${slug}.html`);
  }
  if (next !== text) {
    writeFileSync(file, next);
    touched += 1;
  }
}

// 3) Remove the emptied /blog directory (RSC .txt payloads, if any, were
//    rewritten above; move them out first so nothing is lost).
const blogDir = join(outDir, 'blog');
if (existsSync(blogDir)) {
  for (const name of readdirSync(blogDir)) {
    renameSync(join(blogDir, name), join(outDir, `blog-${name}`));
  }
  rmdirSync(blogDir);
}

// 4) Verify: no /blog/<slug> reference may survive anywhere in the export.
for (const file of walk(outDir)) {
  const text = readFileSync(file, 'utf8');
  for (const slug of slugs) {
    if (text.includes(`/blog/${slug}`) || text.includes(`\\/blog\\/${slug}`)) {
      console.error(`[fix-article-urls] stale /blog/${slug} reference in ${file}`);
      process.exit(1);
    }
  }
}
console.log(`[fix-article-urls] ${moved} articles flattened, ${touched} files rewritten, scheme verified.`);
