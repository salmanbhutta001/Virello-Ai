'use client';

/**
 * Product detail page — /product.html?asin=<ASIN>
 *
 * KNOWN LIMITATION (lookup): the catalog API has no guaranteed by-ASIN
 * endpoint, so we cannot fetch one product directly. Instead we scan the
 * trending rail plus the first few catalog pages (3 × 60) and match on
 * `asin`, falling back to the /dp/<ASIN> pattern inside affiliate_url
 * (list responses often carry asin=null). A product deeper in the catalog
 * will honestly show the "not found in the current catalog view" state with
 * a link to the full live shop at /#/shop. When a real by-asin endpoint
 * exists, replace findProduct() with a single fetch.
 */

import { Suspense, useEffect, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import { fetchProducts, type Product } from '@/lib/api';

function matchesAsin(p: Product, asinUpper: string): boolean {
  if (p.asin && p.asin.toUpperCase() === asinUpper) return true;
  return !!p.affiliate_url && p.affiliate_url.toUpperCase().includes(`/DP/${asinUpper}`);
}

async function findProduct(asin: string): Promise<Product | null> {
  const target = asin.toUpperCase();

  // 1) Trending rail first — the most-linked products live there.
  try {
    const trending = await fetchProducts({ limit: 60, trending: true });
    const hit = trending.find((p) => matchesAsin(p, target));
    if (hit) return hit;
  } catch {
    // Fall through to the catalog scan.
  }

  // 2) Scan the first pages of the catalog (newest first).
  for (let skip = 0; skip < 180; skip += 60) {
    const page = await fetchProducts({ limit: 60, skip });
    const hit = page.find((p) => matchesAsin(p, target));
    if (hit) return hit;
    if (page.length < 60) break;
  }
  return null;
}

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
    findProduct(asin)
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
          <h1 className="h-md">Something went wrong</h1>
          <p className="lead" style={{ margin: '14px auto 24px' }}>
            We could not reach the catalog just now. Please try again, or
            browse the full shop.
          </p>
          <a href="/#/shop" className="btn btn-grad">
            Open the Shop
          </a>
        </div>
      </section>
    );
  }

  if (status === 'notfound' || !product) {
    return (
      <section className="section">
        <div className="wrap center">
          <h1 className="h-md">Product not found in the current catalog view</h1>
          <p className="lead" style={{ margin: '14px auto 24px' }}>
            {asin
              ? 'This item is not in the part of the catalog we can show here. It may still be available in the full shop.'
              : 'No product was specified. Browse the full shop to find what you are looking for.'}
          </p>
          <a href="/#/shop" className="btn btn-grad">
            Browse the full Shop
          </a>
        </div>
      </section>
    );
  }

  const images = product.image_urls ?? [];
  const mainImage = images[active] ?? images[0];

  return (
    <section className="section">
      <div className="wrap">
        <p style={{ marginBottom: 20 }}>
          <a href="/shop.html" className="small" style={{ color: 'var(--pink)', fontWeight: 600 }}>
            ← Back to Shop
          </a>
        </p>

        <div className="grid grid-2" style={{ alignItems: 'start', gap: 32 }}>
          <div>
            {mainImage ? (
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
                {product.title.charAt(0)}
              </div>
            )}
            {images.length > 1 && (
              <div style={{ display: 'flex', gap: 10, marginTop: 12, flexWrap: 'wrap' }}>
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
              <span className="chip" style={{ cursor: 'default', marginBottom: 14 }}>
                {product.category.replace(/_/g, ' ')}
              </span>
            )}
            <h1 className="h-md" style={{ marginBottom: 12 }}>
              {product.title}
            </h1>
            <p
              style={{
                fontFamily: 'var(--font-d)',
                fontWeight: 800,
                fontSize: 24,
                marginBottom: 16,
              }}
            >
              {priceLabel(product)}
            </p>
            {product.description && (
              <p className="mut" style={{ marginBottom: 24 }}>
                {product.description}
              </p>
            )}
            {product.affiliate_url ? (
              <>
                <a
                  href={product.affiliate_url}
                  target="_blank"
                  rel="sponsored noopener"
                  className="btn btn-grad"
                >
                  View on Amazon
                </a>
                <p className="small mut" style={{ marginTop: 12 }}>
                  Sponsored — affiliate link. Price and availability are
                  confirmed on Amazon.
                </p>
              </>
            ) : (
              <p className="mut">
                This product is listed in our catalog but has no store link
                right now.
              </p>
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
