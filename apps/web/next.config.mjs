/** @type {import('next').NextConfig} */
const nextConfig = {
  // Static export: the public site is deployed as static files on Hostinger.
  // The codebase is standard Next.js App Router — removing `output: 'export'`
  // and deploying to a Node host (e.g. a Railway service) enables full SSR
  // with no page-code changes.
  output: 'export',
  trailingSlash: false,
  images: { unoptimized: true },
};

export default nextConfig;
