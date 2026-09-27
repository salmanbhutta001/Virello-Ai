# Virello Backend — Deploy Guide

## What you need (one-time)
1. A VPS (Ubuntu 22.04/24.04, 2 GB RAM minimum). Any provider: Hetzner, DigitalOcean,
   Contabo, AWS Lightsail, etc.
2. Docker + Docker Compose on it:
   ```
   curl -fsSL https://get.docker.com | sh
   ```
3. (Optional, for `https://api.virello.app`) A domain with an A record → your server IP,
   plus Caddy/Nginx as reverse proxy. For testing, plain `http://SERVER_IP:8125` is fine.

## Deploy (on the server)
```bash
# 1. Copy the backend folder to the server
scp -r backend/ user@SERVER_IP:/opt/virello-backend
ssh user@SERVER_IP

# 2. Create the secrets file
cd /opt/virello-backend
cat > .env <<'EOF'
VIRELLO_DB_PASSWORD=<random-32-chars>
VIRELLO_JWT_SECRET=<random-64-chars>
VIRELLO_AI_PROVIDER=dev
# VIRELLO_ANTHROPIC_API_KEY=
# VIRELLO_OPENAI_API_KEY=
# VIRELLO_GOOGLE_API_KEY=
# VIRELLO_PAYPAL_CLIENT_ID=
# VIRELLO_PAYPAL_SECRET=
VIRELLO_PAYPAL_MODE=sandbox
EOF

# 3. Build + run (migrations run automatically)
docker compose up -d --build

# 4. Check health
curl http://localhost:8125/openapi.json -o /dev/null -w "%{http_code}\n"  # → 200
docker compose logs -f api   # watch '[dev] OTP for ...' lines during login tests
```

## Point the mobile app at it
```bash
cd apps/mobile
flutter build apk --debug \
  --dart-define=VIRELLO_API_URL=http://SERVER_IP:8125
# or https://api.virello.app once the domain + TLS is set up
```

## No-server testing alternative (same Wi-Fi, zero deploy)
1. On your laptop: `cd backend && .venv/bin/python -m uvicorn app.main:app --host 0.0.0.0 --port 8125`
   (needs `VIRELLO_DATABASE_URL="sqlite+aiosqlite:///./virello-dev.db"`)
2. Find your laptop's LAN IP (e.g. `192.168.1.5`).
3. Build the APK with `--dart-define=VIRELLO_API_URL=http://192.168.1.5:8125`
4. Phone on the same Wi-Fi → install APK → login works (OTP prints in the laptop terminal).

## Notes
- Dev OTP codes print to the server log (`[dev] OTP for <email>: <code>`).
  Production needs a real email provider (Resend/SMTP) + Redis — swap `issue_otp`.
- Default `VIRELLO_DATABASE_URL` in code targets local Postgres; compose overrides it.
- Admin: set `is_admin=true` on your user row to use `/api/v1/admin/*`.
- Payments supported: PayPal, Payoneer, Google Pay (server-side verification). No Stripe.

## Email (payment receipts) — built-in self-hosted, free forever

Every completed purchase triggers a greeting + receipt email to the buyer.
The **primary** option is built-in: a lightweight Postfix container on your
own VPS — no third party, no account, no cost. A failed email never breaks a
purchase (it is logged and skipped).

### A) Built-in Postfix (recommended)

1. In your `.env` next to `docker-compose.yml`, set your domain:
   ```bash
   POSTFIX_DOMAIN=yourdomain.com
   POSTFIX_HOSTNAME=mail
   POSTFIX_ALLOWED_SENDERS=yourdomain.com
   EMAIL_PROVIDER=smtp
   EMAIL_FROM="Virello <noreply@yourdomain.com>"
   # SMTP_HOST=mail and SMTP_PORT=25 are already the compose defaults
   ```
2. Start it (opt-in profile, keeps the default deploy light):
   ```bash
   docker compose --profile mail up -d
   ```
3. DNS records at your domain registrar (deliverability — do these before
   sending real receipts):
   - **SPF** — TXT record on `yourdomain.com`:
     `v=spf1 ip4:<YOUR-VPS-IP> ~all`
   - **DKIM** — generate a key pair with OpenDKIM (`opendkim-genkey -d
     yourdomain.com -s mail`), publish the public key as a TXT record on
     `mail._domainkey.yourdomain.com`, and mount the private key into the
     container at `./dkim` (uncomment the volume line under the `mail`
     service), then configure OpenDKIM signing inside the container.
   - **DMARC** — TXT record on `_dmarc.yourdomain.com`, start relaxed:
     `v=DMARC1; p=none; rua=mailto:you@yourdomain.com`
     (move to `p=quarantine` once SPF+DKIM pass).
   - **Reverse DNS** — ask your VPS provider to set the PTR record of your
     VPS IP to `mail.yourdomain.com`.
4. Honest note: a brand-new VPS IP has no reputation, so some receipts may
   land in spam for the first days/weeks (IP warmup). Volume here is tiny
   (one email per purchase), so warmup is quick — but if inbox placement
   matters from day one, use the Brevo fallback below while the IP warms up.

Troubleshooting: many VPS providers **block outbound port 25 by default**
(Hetzner, Contabo, some others). If mail doesn't go out, open a support
ticket asking to unblock SMTP, or switch to the Brevo fallback.

### B) Fallback: Brevo free tier (300 emails/day, no credit card)

1. Sign up free at https://www.brevo.com (no card required).
2. Dashboard → SMTP & API → API Keys → create a key.
3. Verify a sender: Settings → Senders → add an email/domain you own.
4. Set on the server:
   ```bash
   EMAIL_PROVIDER=brevo
   BREVO_API_KEY=xkeysib-...
   EMAIL_FROM="Virello <you@yourdomain.com>"   # must be a verified sender
   ```

### Dev default

Without any email env, `EMAIL_PROVIDER` defaults to `console`: emails are
logged, nothing is sent — purchases still work. No real email ever goes out
from a dev machine by accident.

Generic SMTP also works for any other relay:
```bash
EMAIL_PROVIDER=smtp
SMTP_HOST=smtp-relay.brevo.com   # or smtp.gmail.com (App Password), etc.
SMTP_PORT=587
SMTP_USER=your-smtp-login
SMTP_PASS=your-smtp-password
EMAIL_FROM="Virello <you@yourdomain.com>"
```
