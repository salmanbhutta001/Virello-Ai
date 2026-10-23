'use client';

/**
 * Shop page (Next build).
 *
 * NOTE — Phase 2 deployment: the live shop entry point stays at /#/shop on
 * the current static site for now. This page exists so the Next codebase is
 * complete; it reads the same production catalog API as the live shop.
 */

import { useCallback, useEffect, useState } from 'react';
import { fetchProducts, type Product } from '@/lib/api';

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
  return p.asin ?? (p.id != null ? `id-${p.id}` : p.title);
}

function ProductCard({ product }: { product: Product }) {
  const img = product.image_urls?.[0];
  // Prefer the internal product page when we have an ASIN; otherwise send
  // the click straight to the affiliate link.
  const internal = product.asin
    ? `/product.html?asin=${encodeURIComponent(product.asin)}`
    : null;
  const href = internal ?? product.affiliate_url ?? null;
  const external = !internal && !!product.affiliate_url;

  const inner = (
    <>
      {img ? (
        <img
          src={img}
          alt=""
          loading="lazy"
          style={{
            width: '100%',
            aspectRatio: '1 / 1',
            objectFit: 'cover',
            background: 'var(--surface2)',
          }}
        />
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
          {product.title.charAt(0)}
        </div>
      )}
      <div style={{ padding: '18px', display: 'flex', flexDirection: 'column', gap: 6, flex: 1 }}>
        {product.category && (
          <span className="small" style={{ color: 'var(--pink)', fontWeight: 600 }}>
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
      {...(external
        ? { target: '_blank', rel: 'sponsored noopener' }
        : {})}
    >
      {inner}
    </a>
  );
}

export default function ShopPage() {
  const [category, setCategory] = useState('all');
  const [items, setItems] = useState<Product[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [hasMore, setHasMore] = useState(false);

  const loadFirst = useCallback(async (cat: string) => {
    setLoading(true);
    setError(null);
    try {
      const page = await fetchProducts({
        limit: PAGE_SIZE,
        skip: 0,
        category: cat === 'all' ? undefined : cat,
      });
      setItems(page);
      setHasMore(page.length === PAGE_SIZE);
    } catch {
      setItems([]);
      setHasMore(false);
      setError('We could not load the shop right now. Please try again.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadFirst(category);
  }, [category, loadFirst]);

  const loadMore = async () => {
    setLoadingMore(true);
    try {
      const page = await fetchProducts({
        limit: PAGE_SIZE,
        skip: items.length,
        category: category === 'all' ? undefined : category,
      });
      setItems((prev) => {
        const seen = new Set(prev.map(productKey));
        return [...prev, ...page.filter((p) => !seen.has(productKey(p)))];
      });
      setHasMore(page.length === PAGE_SIZE);
    } catch {
      setError('We could not load more products. Please try again.');
    } finally {
      setLoadingMore(false);
    }
  };

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
          <div
            style={{
              display: 'flex',
              flexWrap: 'wrap',
              gap: 8,
              marginBottom: 28,
            }}
          >
            {CATEGORIES.map((c) => (
              <button
                key={c.slug}
                type="button"
                className={`chip${category === c.slug ? ' active' : ''}`}
                onClick={() => setCategory(c.slug)}
              >
                {c.label}
              </button>
            ))}
          </div>

          {loading && <p className="mut center">Loading products…</p>}

          {!loading && error && items.length === 0 && (
            <div className="center">
              <p className="mut" style={{ marginBottom: 16 }}>
                {error}
              </p>
              <button
                type="button"
                className="btn btn-ghost btn-sm"
                onClick={() => void loadFirst(category)}
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
              <div className="grid grid-4">
                {items.map((p) => (
                  <ProductCard key={productKey(p)} product={p} />
                ))}
              </div>

              {error && (
                <p className="mut center" style={{ marginTop: 20 }}>
                  {error}
                </p>
              )}

              {hasMore && (
                <div className="center" style={{ marginTop: 32 }}>
                  <button
                    type="button"
                    className="btn btn-ghost"
                    onClick={() => void loadMore()}
                    disabled={loadingMore}
                  >
                    {loadingMore ? 'Loading…' : 'Load more'}
                  </button>
                </div>
              )}
            </>
          )}

          <p className="small mut center" style={{ marginTop: 36 }}>
            Product links go to Amazon and are affiliate links (Sponsored).
            Virello may earn a commission at no extra cost to you.
          </p>
        </div>
      </section>
    </>
  );
}
