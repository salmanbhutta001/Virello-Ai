export default function Footer() {
  return (
    <footer className="site-footer">
      <div className="wrap">
        <div className="footer-grid">
          <div>
            <div style={{ marginBottom: 14 }}>
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <a href="/" aria-label="Virello AI home">
                <img
                  className="logo-img foot-logo"
                  src="/logo-virello.png"
                  alt="Virello AI"
                  width={560}
                  height={175}
                />
              </a>
            </div>
            <p className="mut" style={{ fontSize: 14.5, maxWidth: 320 }}>
              Your AI Growth Manager. Paste a post, choose a goal, and let AI
              grow it — real audiences, honest analytics, no fake engagement.
            </p>
          </div>
          <div>
            <h4>Product</h4>
            <ul>
              <li><a href="/features.html">Features</a></li>
              <li><a href="/how.html">How It Works</a></li>
              <li><a href="/pricing.html">Pricing</a></li>
              <li><a href="/blog.html">Blog</a></li>
              <li><a href="/#/shop">Shop</a></li>
            </ul>
          </div>
          <div>
            <h4>Company</h4>
            <ul>
              <li><a href="/about.html">About Us</a></li>
              <li><a href="/contact.html">Contact</a></li>
              <li><a href="/help.html">Help Center</a></li>
              <li><a href="/trust.html">Trust &amp; Safety</a></li>
            </ul>
          </div>
          <div>
            <h4>Get the App</h4>
            <ul>
              <li>
                <a href="https://appgallery.huawei.com/app/C119223219" target="_blank" rel="noreferrer">
                  Huawei AppGallery
                </a>
              </li>
              <li>
                <a href="https://apkpure.com/p/com.virello.virello" target="_blank" rel="noreferrer">
                  APKPure
                </a>
              </li>
              <li>
                <a href="https://virello-ai.en.uptodown.com/android" target="_blank" rel="noreferrer">
                  Uptodown
                </a>
              </li>
              <li><a href="/login.html" className="auth-out">Web Dashboard</a><a href="/#/dashboard" className="auth-in">Web Dashboard</a></li>
            </ul>
          </div>
        </div>
        <div className="footer-base">
          <span>© 2026 Virello AI — virelloai.online. All rights reserved.</span>
          <span>
            <a href="/privacy.html">Privacy Policy</a>
            {' · '}
            <a href="/terms.html">Terms</a>
            {' · '}
            <a href="/delete-account.html">Delete Account</a>
          </span>
        </div>
      </div>
    </footer>
  );
}
