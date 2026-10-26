/**
 * Download section — same three store links as the legacy download
 * template (AppGallery / APKPure / Uptodown).
 */

const STORES = [
  {
    name: 'Huawei AppGallery',
    note: 'Available Now',
    href: 'https://appgallery.huawei.com/app/C119223219',
  },
  {
    name: 'APKPure',
    note: 'Available Now',
    href: 'https://apkpure.com/p/com.virello.virello',
  },
  {
    name: 'Uptodown',
    note: 'Available Now',
    href: 'https://virello-ai.en.uptodown.com/android',
  },
];

export default function DownloadApp() {
  return (
    <div className="wrap">
      <div className="center">
        <span className="kicker">Get The App</span>
        <h2 className="h-lg">
          Download <span className="grad-text">Virello</span>
        </h2>
        <p className="lead" style={{ marginTop: 14 }}>
          Download Virello and let your AI Growth Manager handle the rest.
        </p>
      </div>
      <div className="dl-grid">
        {STORES.map((s) => (
          <a
            key={s.name}
            href={s.href}
            target="_blank"
            rel="noopener"
            className="card dl-card"
          >
            <h3 style={{ marginBottom: 4 }}>{s.name}</h3>
            <p className="small" style={{ color: 'var(--good)' }}>
              {s.note}
            </p>
          </a>
        ))}
      </div>
    </div>
  );
}
