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

/** Shop products (paginated, limit <= 60 per backend rule). */
export async function fetchProducts(params: {
  limit?: number;
  skip?: number;
  category?: string;
  trending?: boolean;
} = {}): Promise<Product[]> {
  const q = new URLSearchParams();
  q.set('limit', String(params.limit ?? 24));
  if (params.skip) q.set('skip', String(params.skip));
  if (params.category) q.set('category', params.category);
  if (params.trending) q.set('trending', 'true');
  const data = await getJSON<{ products?: Product[] } | Product[]>(
    `/commerce/products?${q.toString()}`,
  );
  return Array.isArray(data) ? data : (data.products ?? []);
}

/** Blog posts from the backend blog engine (seeded + generated posts). */
export async function fetchBlogPosts(): Promise<BlogPost[]> {
  const data = await getJSON<{ posts?: BlogPost[] } | BlogPost[]>(
    '/blog/posts',
  );
  return Array.isArray(data) ? data : (data.posts ?? []);
}
