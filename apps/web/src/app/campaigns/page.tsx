import type { Metadata } from 'next';
import CampaignsPage from './CampaignsPage';

export const metadata: Metadata = {
  title: 'Campaigns',
  description:
    'Every campaign Virello’s AI is running for you — reach, engagement, budget and progress in one table.',
  robots: { index: false, follow: true },
};

export default function Campaigns() {
  return <CampaignsPage />;
}
