import type { Metadata } from 'next';
import ProfilePage from './ProfilePage';

export const metadata: Metadata = {
  title: 'Profile',
  description:
    'Your account, platforms, subscription and preferences — manage your Virello profile.',
  robots: { index: false, follow: true },
};

export default function Profile() {
  return <ProfilePage />;
}
