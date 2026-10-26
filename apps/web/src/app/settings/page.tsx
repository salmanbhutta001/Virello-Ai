import type { Metadata } from 'next';
import SettingsPage from './SettingsPage';

export const metadata: Metadata = {
  title: 'Settings',
  description:
    'Appearance, language, notifications and privacy — your Virello settings in one place.',
  robots: { index: false, follow: true },
};

export default function Settings() {
  return <SettingsPage />;
}
