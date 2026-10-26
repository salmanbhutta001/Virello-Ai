export const API_BASE =
  process.env.NEXT_PUBLIC_API_BASE ??
  'https://virello-api-production.up.railway.app/api/v1';

export type Product = {
  id?: number;
  asin?: string | null;
  title: string;
  description?: string;
  category?: string;
  price_cents?: number;
  currency?: string;
  image_urls?: string[];
  affiliate_url?: string;
  trend_score?: number;
  rating?: number;
};

export type BlogPost = {
  slug: string;
  title: string;
  excerpt?: string;
  category?: string;
  date?: string;
  mins?: number;
  image?: string;
  body?: string;
};

async function getJSON<T>(path: string): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`);
  if (!res.ok) throw new Error(`API ${res.status} for ${path}`);
  return (await res.json()) as T;
}

/**
 * Shop products (paginated). Backend contract (verified from
 * backend/app/routers/commerce.py:298-303): pagination is `limit` (1-60)
 * + `offset` (>=0) — NOT `skip` (FastAPI silently ignores unknown params,
 * so `skip` did nothing and the shop showed page 1 forever). Trending is
 * `sort=trending` — NOT `trending=true` (ignored by the backend's sort
 * pattern). Returns the envelope { products, total } — the shop needs
 * `total` for pagination.
 */
export async function fetchProducts(params: {
  limit?: number;
  offset?: number;
  category?: string;
  q?: string;
  sort?: 'newest' | 'price_asc' | 'price_desc' | 'popular' | 'trending';
} = {}): Promise<{ products: Product[]; total: number }> {
  const q = new URLSearchParams();
  q.set('limit', String(params.limit ?? 24));
  if (params.offset) q.set('offset', String(params.offset));
  if (params.category && params.category !== 'all')
    q.set('category', params.category);
  if (params.q) q.set('q', params.q);
  if (params.sort) q.set('sort', params.sort);
  const data = await getJSON<{
    products?: Product[];
    total?: number;
  } | Product[]>(`/commerce/products?${q.toString()}`);
  if (Array.isArray(data)) return { products: data, total: data.length };
  return { products: data.products ?? [], total: data.total ?? 0 };
}

/**
 * One product by ASIN (backend commerce.py:364+). Returns the flat
 * list-item shape with a populated `asin`; null for a malformed/absent
 * ASIN (backend 404s). Throws on other failures.
 */
export async function fetchProductByAsin(
  asin: string,
): Promise<Product | null> {
  const res = await fetch(
    `${API_BASE}/commerce/products/by-asin/${encodeURIComponent(asin)}`,
  );
  if (res.status === 404) return null;
  if (!res.ok)
    throw new Error(`API ${res.status} for /commerce/products/by-asin`);
  const data = (await res.json()) as Product & { product?: Product };
  return data.product ?? data;
}

/** ASIN of a product: the `asin` field, else the /dp/<ASIN> in its affiliate URL. */
export function asinOf(p: Product): string | null {
  if (p.asin) return p.asin;
  const m = p.affiliate_url?.match(/\/dp\/([A-Z0-9]{10})/i);
  return m ? m[1].toUpperCase() : null;
}

/** Blog posts from the backend blog engine (seeded + generated posts). */
export async function fetchBlogPosts(): Promise<BlogPost[]> {
  const data = await getJSON<{ posts?: BlogPost[] } | BlogPost[]>(
    '/blog/posts',
  );
  return Array.isArray(data) ? data : (data.posts ?? []);
}
