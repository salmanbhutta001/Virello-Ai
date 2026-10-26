import type { Metadata } from 'next';
import DashboardPage from './DashboardPage';

export const metadata: Metadata = {
  title: 'Dashboard',
  description:
    'Your Virello AI Growth Manager dashboard — grow a post, check your AI Growth Score and open the Creator Hub.',
  robots: { index: false, follow: true },
};

export default function Dashboard() {
  return <DashboardPage />;
}
