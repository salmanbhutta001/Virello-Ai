'use client';

/**
 * Shop page — /shop.html.
 *
 * Legacy parity (legacy SPA #page-shop): 26 categories in legacy order,
 * category tabs + mobile <select>, debounced text search (400 ms), page
 * size 24, smart-window pagination, card image strip (up to 8 images,
 * swipe cycles them), "Page X of Y · N products total" count line.
 * No all/men/women/sale/best_sellers filters — they do not exist in legacy.
 */

import { useCallback, useEffect, useRef, useState } from 'react';
import { asinOf, fetchProducts, type Product } from '@/lib/api';

const PAGE_SIZE = 24;

const CATEGORIES: { slug: string; label: string }[] = [
  { slug: 'all', label: 'All' },
  { slug: 'tech', label: 'Tech' },
  { slug: 'fashion', label: 'Fashion' },
  { slug: 'home', label: 'Home' },
  { slug: 'fitness', label: 'Fitness' },
  { slug: 'beauty', label: 'Beauty' },
  { slug: 'computers', label: 'Computers' },
  { slug: 'smart_home', label: 'Smart Home' },
  { slug: 'arts_crafts', label: 'Arts & Crafts' },
  { slug: 'automotive', label: 'Automotive' },
  { slug: 'baby', label: 'Baby' },
  { slug: 'health', label: 'Health' },
  { slug: 'industrial', label: 'Industrial' },
  { slug: 'luggage', label: 'Luggage' },
  { slug: 'movies_tv', label: 'Movies & TV' },
  { slug: 'pet_supplies', label: 'Pet Supplies' },
  { slug: 'software', label: 'Software' },
  { slug: 'sports', label: 'Sports' },
  { slug: 'tools', label: 'Tools' },
  { slug: 'toys', label: 'Toys' },
  { slug: 'video_games', label: 'Video Games' },
  { slug: 'grocery', label: 'Grocery' },
  { slug: 'handmade', label: 'Handmade' },
  { slug: 'books', label: 'Books' },
  { slug: 'office', label: 'Office' },
  { slug: 'phones', label: 'Phones' },
  { slug: 'collectibles', label: 'Collectibles' },
];

function categoryLabel(slug?: string): string {
  if (!slug) return '';
  return CATEGORIES.find((c) => c.slug === slug)?.label ?? slug;
}

function priceLabel(p: Product): string {
  return p.price_cents && p.price_cents > 0
    ? `$${(p.price_cents / 100).toFixed(2)}`
    : 'Check price on Amazon';
}

function productKey(p: Product): string {
  return asinOf(p) ?? (p.id != null ? `id-${p.id}` : p.title);
}

function ProductCard({ product }: { product: Product }) {
  const images = (product.image_urls ?? []).slice(0, 8);
  const [imgIdx, setImgIdx] = useState(0);
  const swipeRef = useRef<{ x: number; swipedAt: number } | null>(null);

  const cycle = (dir: 1 | -1) => {
    if (images.length < 2) return;
    setImgIdx((i) => (i + dir + images.length) % images.length);
  };

  const onPointerDown = (e: React.PointerEvent) => {
    swipeRef.current = { x: e.clientX, swipedAt: 0 };
  };
  const onPointerUp = (e: React.PointerEvent) => {
    const s = swipeRef.current;
    swipeRef.current = null;
    if (!s) return;
    const dx = e.clientX - s.x;
    if (Math.abs(dx) > 40) {
      cycle(dx < 0 ? 1 : -1);
      // Suppress the click that follows a swipe, like legacy (350 ms).
      swipeRef.current = { x: 0, swipedAt: Date.now() };
      window.setTimeout(() => {
        swipeRef.current = null;
      }, 350);
    }
  };
  const onClickCapture = (e: React.MouseEvent) => {
    if (swipeRef.current?.swipedAt) e.preventDefault();
  };

  // Prefer the internal product page when we have an ASIN; otherwise send
  // the click straight to the affiliate link.
  const asin = asinOf(product);
  const internal = asin
    ? `/product.html?asin=${encodeURIComponent(asin)}`
    : null;
  const href = internal ?? product.affiliate_url ?? null;
  const external = !internal && !!product.affiliate_url;

  const inner = (
    <>
      <div
        className="shop-imgstrip"
        onPointerDown={onPointerDown}
        onPointerUp={onPointerUp}
        onClickCapture={onClickCapture}
        style={{ touchAction: 'pan-y', userSelect: 'none' }}
      >
        {images.length > 0 ? (
          images.map((src, i) => (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              key={src}
              src={src}
              alt=""
              loading="lazy"
              draggable={false}
              style={{
                display: i === imgIdx ? 'block' : 'none',
                width: '100%',
                aspectRatio: '1 / 1',
                objectFit: 'cover',
                background: 'var(--surface2)',
              }}
            />
          ))
        ) : (
          <div
            style={{
              width: '100%',
              aspectRatio: '1 / 1',
              background: 'var(--surface2)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: 'var(--mut)',
              fontFamily: 'var(--font-d)',
              fontSize: 34,
              fontWeight: 800,
            }}
          >
            Virello Pick
          </div>
        )}
        {images.length > 1 && (
          <>
            <span className="shop-swipe-hint">↔ swipe</span>
            <span className="shop-dots">
              {images.map((src, i) => (
                <i key={src} className={i === imgIdx ? 'on' : undefined} />
              ))}
            </span>
          </>
        )}
      </div>
      <div
        style={{
          padding: '18px',
          display: 'flex',
          flexDirection: 'column',
          gap: 6,
          flex: 1,
        }}
      >
        {product.category && (
          <span
            className="small"
            style={{ color: 'var(--pink)', fontWeight: 600 }}
          >
            {categoryLabel(product.category)}
          </span>
        )}
        <h3 style={{ marginBottom: 0, fontSize: 16.5, lineHeight: 1.35 }}>
          {product.title}
        </h3>
        <span
          style={{
            marginTop: 'auto',
            fontFamily: 'var(--font-d)',
            fontWeight: 700,
            fontSize: 15,
          }}
        >
          {priceLabel(product)}
        </span>
      </div>
    </>
  );

  const cardStyle: React.CSSProperties = {
    padding: 0,
    overflow: 'hidden',
    display: 'flex',
    flexDirection: 'column',
  };

  if (!href) {
    return (
      <div className="card" style={cardStyle}>
        {inner}
      </div>
    );
  }
  return (
    <a
      href={href}
      className="card"
      style={cardStyle}
      {...(external ? { target: '_blank', rel: 'sponsored noopener' } : {})}
    >
      {inner}
    </a>
  );
}

/** Smart window: page 1, last page, and current ±1, with "…" gaps. */
function pageWindow(page: number, totalPages: number): (number | '…')[] {
  if (totalPages <= 7)
    return Array.from({ length: totalPages }, (_, i) => i + 1);
  const pages = new Set<number>([1, totalPages, page - 1, page, page + 1]);
  const sorted = [...pages].filter((p) => p >= 1 && p <= totalPages).sort((a, b) => a - b);
  const out: (number | '…')[] = [];
  let prev = 0;
  for (const p of sorted) {
    if (p - prev > 1) out.push('…');
    out.push(p);
    prev = p;
  }
  return out;
}

export default function ShopPage() {
  const [category, setCategory] = useState('all');
  const [query, setQuery] = useState('');
  const [debouncedQ, setDebouncedQ] = useState('');
  const [page, setPage] = useState(1);
  const [items, setItems] = useState<Product[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Debounced text search (400 ms), like legacy filterShop().
  useEffect(() => {
    const t = window.setTimeout(() => setDebouncedQ(query.trim()), 400);
    return () => window.clearTimeout(t);
  }, [query]);

  const goToPage = useCallback(
    async (p: number, cat: string, q: string) => {
      setLoading(true);
      setError(null);
      try {
        const { products, total: t } = await fetchProducts({
          limit: PAGE_SIZE,
          offset: (p - 1) * PAGE_SIZE,
          category: cat === 'all' ? undefined : cat,
          q: q || undefined,
        });
        setItems(products);
        setTotal(t);
        setPage(p);
        window.scrollTo({ top: 0, behavior: 'smooth' });
      } catch {
        setItems([]);
        setTotal(0);
        setError('Could not load products. Check connection and retry.');
      } finally {
        setLoading(false);
      }
    },
    [],
  );

  // Category or search change resets to page 1.
  useEffect(() => {
    void goToPage(1, category, debouncedQ);
  }, [category, debouncedQ, goToPage]);

  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));

  const setCat = (cat: string) => setCategory(cat);

  return (
    <>
      <section className="hero" style={{ paddingBottom: 36 }}>
        <div className="wrap">
          <span className="kicker">Virello Shop</span>
          <h1 className="h-xl">
            Trending products, <span className="grad-text">honestly curated</span>
          </h1>
          <p className="lead">
            Products our team researches and adds to the catalog — real items,
            real listings. Prices are confirmed on Amazon.
          </p>
        </div>
      </section>

      <section className="section" style={{ paddingTop: 8 }}>
        <div className="wrap">
          <div className="shop-cat-tabs" style={{ marginBottom: 16 }}>
            {CATEGORIES.map((c) => (
              <button
                key={c.slug}
                type="button"
                className={`chip${category === c.slug ? ' active' : ''}`}
                onClick={() => setCat(c.slug)}
              >
                {c.label}
              </button>
            ))}
          </div>
          <div className="field shop-cat-select" style={{ marginBottom: 16 }}>
            <select
              aria-label="Category"
              value={category}
              onChange={(e) => setCat(e.target.value)}
            >
              {CATEGORIES.map((c) => (
                <option key={c.slug} value={c.slug}>
                  {c.label}
                </option>
              ))}
            </select>
          </div>
          <div className="field" style={{ maxWidth: 420 }}>
            <input
              type="search"
              placeholder="Search products…"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              aria-label="Search products"
            />
          </div>

          {loading && <p className="mut center">Products loading…</p>}

          {!loading && error && (
            <div className="center">
              <p className="mut" style={{ marginBottom: 16 }}>
                {error}
              </p>
              <button
                type="button"
                className="btn btn-ghost btn-sm"
                onClick={() => void goToPage(page, category, debouncedQ)}
              >
                Try again
              </button>
            </div>
          )}

          {!loading && !error && items.length === 0 && (
            <p className="mut center">
              No products in this category yet — check back soon.
            </p>
          )}

          {items.length > 0 && (
            <>
              <p className="small mut" style={{ marginBottom: 16 }}>
                Page {page} of {totalPages} · {total} products total
              </p>
              <div className="grid grid-4">
                {items.map((p) => (
                  <ProductCard key={productKey(p)} product={p} />
                ))}
              </div>

              {totalPages > 1 && (
                <nav
                  aria-label="Shop pages"
                  className="shop-pager"
                  style={{
                    display: 'flex',
                    gap: 8,
                    justifyContent: 'center',
                    flexWrap: 'wrap',
                    marginTop: 32,
                  }}
                >
                  <button
                    type="button"
                    className="btn btn-ghost btn-sm"
                    disabled={page <= 1}
                    onClick={() => void goToPage(page - 1, category, debouncedQ)}
                  >
                    ← Prev
                  </button>
                  {pageWindow(page, totalPages).map((p, i) =>
                    p === '…' ? (
                      <span key={`gap-${i}`} className="mut" style={{ alignSelf: 'center' }}>
                        …
                      </span>
                    ) : (
                      <button
                        key={p}
                        type="button"
                        className={`chip${p === page ? ' active' : ''}`}
                        style={{ cursor: 'pointer' }}
                        onClick={() => void goToPage(p, category, debouncedQ)}
                      >
                        {p}
                      </button>
                    ),
                  )}
                  <button
                    type="button"
                    className="btn btn-ghost btn-sm"
                    disabled={page >= totalPages}
                    onClick={() => void goToPage(page + 1, category, debouncedQ)}
                  >
                    Next →
                  </button>
                </nav>
              )}
            </>
          )}

          <p className="small mut center" style={{ marginTop: 36 }}>
            As an Amazon Associate, Virello earns from qualifying purchases.
            Product links go to Amazon and are affiliate links (Sponsored).
          </p>
        </div>
      </section>
    </>
  );
}
