'use client';

/**
 * Product detail page — /product.html?asin=<ASIN>
 *
 * Lookup is a single call to GET /api/v1/commerce/products/by-asin/{asin}
 * (backend commerce.py:364+; returns a flat item with a populated `asin`,
 * 404 for malformed/absent ASIN). No catalog scan.
 */

import { Suspense, useEffect, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import { asinOf, fetchProductByAsin, type Product } from '@/lib/api';

function priceLabel(p: Product): string {
  return p.price_cents && p.price_cents > 0
    ? `$${(p.price_cents / 100).toFixed(2)}`
    : 'Check price on Amazon';
}

type Status = 'loading' | 'found' | 'notfound' | 'error';

function ProductDetail() {
  const searchParams = useSearchParams();
  const asin = searchParams.get('asin');
  const [status, setStatus] = useState<Status>('loading');
  const [product, setProduct] = useState<Product | null>(null);
  const [active, setActive] = useState(0);

  useEffect(() => {
    if (!asin) {
      setStatus('notfound');
      return;
    }
    let cancelled = false;
    setStatus('loading');
    fetchProductByAsin(asin)
      .then((found) => {
        if (cancelled) return;
        if (found) {
          setProduct(found);
          setActive(0);
          setStatus('found');
        } else {
          setStatus('notfound');
        }
      })
      .catch(() => {
        if (!cancelled) setStatus('error');
      });
    return () => {
      cancelled = true;
    };
  }, [asin]);

  if (status === 'loading') {
    return (
      <section className="section">
        <div className="wrap center">
          <p className="mut">Loading product…</p>
        </div>
      </section>
    );
  }

  if (status === 'error') {
    return (
      <section className="section">
        <div className="wrap center">
          <h1 className="h-md">Could not load product</h1>
          <p className="lead" style={{ margin: '14px auto 24px' }}>
            We could not reach the catalog just now. Please try again, or
            browse the full shop.
          </p>
          <a href="/shop.html" className="btn btn-grad">
            Back to Shop
          </a>
        </div>
      </section>
    );
  }

  if (status === 'notfound' || !product) {
    return (
      <section className="section">
        <div className="wrap center">
          <h1 className="h-md">Product not found</h1>
          <p className="lead" style={{ margin: '14px auto 24px' }}>
            This product is not in the Virello catalog.
          </p>
          <a href="/shop.html" className="btn btn-grad">
            Back to Shop
          </a>
        </div>
      </section>
    );
  }

  const images = (product.image_urls ?? []).slice(0, 3);
  const mainImage = images[active] ?? images[0];
  const buyUrl =
    product.affiliate_url ??
    (asinOf(product)
      ? `https://www.amazon.com/dp/${asinOf(product)}?tag=topitems0c1-20`
      : null);
  const rating =
    typeof product.rating === 'number' && product.rating > 0
      ? product.rating
      : null;

  return (
    <section className="section">
      <div className="wrap">
        <p style={{ marginBottom: 20 }}>
          <a
            href="/shop.html"
            className="small"
            style={{ color: 'var(--pink)', fontWeight: 600 }}
          >
            ← Back to Shop
          </a>
        </p>

        <div
          className="grid grid-2"
          style={{ alignItems: 'start', gap: 32 }}
        >
          <div>
            {mainImage ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={mainImage}
                alt={product.title}
                style={{
                  width: '100%',
                  aspectRatio: '1 / 1',
                  objectFit: 'contain',
                  background: 'var(--surface)',
                  border: '1px solid var(--line)',
                  borderRadius: 'var(--r-lg)',
                }}
              />
            ) : (
              <div
                style={{
                  width: '100%',
                  aspectRatio: '1 / 1',
                  background: 'var(--surface)',
                  border: '1px solid var(--line)',
                  borderRadius: 'var(--r-lg)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  color: 'var(--mut)',
                  fontFamily: 'var(--font-d)',
                  fontSize: 44,
                  fontWeight: 800,
                }}
              >
                Virello Pick
              </div>
            )}
            {images.length > 1 && (
              <div
                style={{
                  display: 'flex',
                  gap: 10,
                  marginTop: 12,
                  flexWrap: 'wrap',
                }}
              >
                {images.map((url, i) => (
                  <button
                    key={url}
                    type="button"
                    onClick={() => setActive(i)}
                    aria-label={`View image ${i + 1}`}
                    style={{
                      padding: 0,
                      border:
                        i === active
                          ? '2px solid var(--pink)'
                          : '1px solid var(--line2)',
                      borderRadius: 'var(--r-sm)',
                      overflow: 'hidden',
                      background: 'var(--surface)',
                      cursor: 'pointer',
                    }}
                  >
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img
                      src={url}
                      alt=""
                      style={{ width: 68, height: 68, objectFit: 'cover' }}
                    />
                  </button>
                ))}
              </div>
            )}
          </div>

          <div>
            {product.category && (
              <span
                className="chip"
                style={{ cursor: 'default', marginBottom: 14 }}
              >
                {product.category.replace(/_/g, ' ')}
              </span>
            )}
            {typeof product.trend_score === 'number' && (
              <span
                className="chip"
                style={{ cursor: 'default', marginBottom: 14, marginLeft: 8 }}
              >
                🔥 Trending {product.trend_score}
              </span>
            )}
            <h1 className="h-md" style={{ marginBottom: 12 }}>
              {product.title}
            </h1>
            {rating !== null && (
              <p style={{ marginBottom: 12, color: 'var(--warn)' }}>
                {'★'.repeat(Math.round(rating))}
                <span className="mut" style={{ marginLeft: 8 }}>
                  {rating.toFixed(1)}
                </span>
              </p>
            )}
            <p
              style={{
                fontFamily: 'var(--font-d)',
                fontWeight: 800,
                fontSize: 24,
                marginBottom: 8,
              }}
            >
              {priceLabel(product)}
            </p>
            <p className="small mut" style={{ marginBottom: 20 }}>
              Price checked on Amazon
            </p>
            {buyUrl ? (
              <>
                <a
                  href={buyUrl}
                  target="_blank"
                  rel="sponsored noopener"
                  className="btn btn-grad"
                >
                  Buy Now on Amazon
                </a>
                <p className="small mut" style={{ marginTop: 12 }}>
                  As an Amazon Associate, Virello earns from qualifying
                  purchases.
                </p>
              </>
            ) : (
              <p className="mut">
                This product is listed in our catalog but has no store link
                right now.
              </p>
            )}
            <ul style={{ marginTop: 24, marginLeft: 18, color: 'var(--mut)' }}>
              <li>Curated by Virello AI</li>
              <li>Secure checkout on Amazon</li>
              <li>Fast Amazon delivery</li>
            </ul>
            {product.description && (
              <div style={{ marginTop: 28 }}>
                <h2 style={{ fontSize: 18, marginBottom: 10 }}>
                  About this product
                </h2>
                <p className="mut">{product.description}</p>
              </div>
            )}
          </div>
        </div>
      </div>
    </section>
  );
}

export default function ProductPage() {
  // useSearchParams() must sit inside a Suspense boundary for static export.
  return (
    <Suspense
      fallback={
        <section className="section">
          <div className="wrap center">
            <p className="mut">Loading product…</p>
          </div>
        </section>
      }
    >
      <ProductDetail />
    </Suspense>
  );
}
