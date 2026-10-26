import type { Metadata } from 'next';
import AnalyticsPage from './AnalyticsPage';

export const metadata: Metadata = {
  title: 'Analytics',
  description:
    'Your performance across all connected platforms — reach, engagement, followers and AI recommendations.',
  robots: { index: false, follow: true },
};

export default function Analytics() {
  return <AnalyticsPage />;
}
