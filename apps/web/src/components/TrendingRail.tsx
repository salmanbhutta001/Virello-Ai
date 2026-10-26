'use client';

/**
 * Live trending rail — GET /commerce/products?sort=trending&limit=10.
 * Legacy parity (loadTrendingProducts): loading / empty / failure states
 * match the legacy copy; one .tprod-card per item (image, title, price or
 * "Check price on Amazon", "{trend_score} trending" line when present);
 * card click → /product.html?asin=…
 */

import { useEffect, useState } from 'react';
import { asinOf, fetchProducts, type Product } from '@/lib/api';

type State = 'loading' | 'ready' | 'empty' | 'error';

export default function TrendingRail() {
  const [state, setState] = useState<State>('loading');
  const [items, setItems] = useState<Product[]>([]);

  useEffect(() => {
    let cancelled = false;
    fetchProducts({ sort: 'trending', limit: 10 })
      .then(({ products }) => {
        if (cancelled) return;
        if (products.length === 0) {
          setState('empty');
        } else {
          setItems(products);
          setState('ready');
        }
      })
      .catch(() => {
        if (!cancelled) setState('error');
      });
    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <div className="tprod-box">
      <div className="tprod-head">
        <div>
          <span className="tprod-badge">🔥 Trending Products</span>
          <h2 id="tprodTitle">
            Hot in the <span className="grad-text">Shop</span> right now
          </h2>
          <p className="mut" style={{ margin: 0 }}>
            Live trending picks from the Virello Shop — refreshed around the
            clock.
          </p>
        </div>
        <a href="/shop.html" className="btn btn-ghost btn-sm">
          View all →
        </a>
      </div>

      {state === 'loading' && (
        <p className="mut" style={{ padding: 20 }}>
          Loading trending products…
        </p>
      )}
      {state === 'empty' && (
        <p className="mut" style={{ padding: 20 }}>
          No trending products right now.
        </p>
      )}
      {state === 'error' && (
        <p className="mut" style={{ padding: 20 }}>
          Could not load trending products.{' '}
          <a href="/shop.html" style={{ color: 'var(--pink)' }}>
            Visit the Shop →
          </a>
        </p>
      )}
      {state === 'ready' && (
        <div className="tprod-rail">
          {items.map((p) => {
            const asin = asinOf(p);
            const href = asin
              ? `/product.html?asin=${encodeURIComponent(asin)}`
              : (p.affiliate_url ?? '/shop.html');
            const external = !asin && !!p.affiliate_url;
            return (
              <a
                key={asinOf(p) ?? p.id ?? p.title}
                href={href}
                className="tprod-card"
                {...(external
                  ? { target: '_blank', rel: 'sponsored noopener' }
                  : {})}
              >
                {p.image_urls?.[0] ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={p.image_urls[0]}
                    alt=""
                    loading="lazy"
                    onError={(e) => {
                      (e.target as HTMLImageElement).style.display = 'none';
                    }}
                  />
                ) : (
                  <div className="tprod-fallback">Virello Pick</div>
                )}
                <span className="tprod-title">{p.title}</span>
                <span className="tprod-price">
                  {p.price_cents && p.price_cents > 0
                    ? `$${(p.price_cents / 100).toFixed(2)}`
                    : 'Check price on Amazon'}
                </span>
                {typeof p.trend_score === 'number' && (
                  <span className="tprod-trend">
                    🔥 {p.trend_score} trending
                  </span>
                )}
              </a>
            );
          })}
        </div>
      )}
    </div>
  );
}
