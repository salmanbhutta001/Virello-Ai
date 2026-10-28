from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    app_name: str = "Virello API"
    database_url: str = "postgresql+asyncpg://virello:virello@localhost:5432/virello"
    redis_url: str = "redis://localhost:6379/0"
    jwt_secret: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"
    access_token_minutes: int = 30
    refresh_token_days: int = 30
    # CORS: explicit allowlist only (security fix 2026-10-27). A wildcard here
    # with allow_credentials=True made the API reflect ANY Origin (verified
    # live: evil.example.com got access-control-allow-credentials: true).
    # Website + admin panel + Vercel website + local dev only. Override via
    # VIRELLO_CORS_ORIGINS (JSON list) if a new first-party origin is added.
    cors_origins: list[str] = [
        "https://virelloai.online",
        "https://www.virelloai.online",
        "https://admin.virelloai.online",
        "https://virello-website.vercel.app",
        "http://localhost:3000",
        "http://localhost:8000",
    ]
    # Set VIRELLO_ENVIRONMENT=development for local dev (enables /docs).
    # Production keeps the API docs disabled.
    environment: str = "production"
    # --- AI provider layer (provider-agnostic; swap via config, no rewrites) ---
    ai_provider: str = "dev"  # dev | anthropic | openai | google | groq
    image_provider: str = "pollinations"  # pollinations | none (modular, optional)
    image_engine: str = "robot"  # robot (local, no API) | agnes — Image Studio jobs
    studio_ai_director: bool = True  # Muse AI art-directs before the robot renders
    anthropic_api_key: str = ""
    anthropic_model: str = "claude-sonnet-4-20250514"
    openai_api_key: str = ""
    openai_model: str = "gpt-5"
    google_api_key: str = ""
    google_model: str = "gemini-2.5-pro"
    groq_api_key: str = ""
    groq_model: str = "llama-3.3-70b-versatile"
    # --- Payments: PayPal / Payoneer / Google Pay (no Stripe) ---
    billing_currency: str = "USD"
    paypal_client_id: str = ""
    paypal_secret: str = ""
    paypal_mode: str = "sandbox"  # sandbox | live
    paypal_webhook_id: str = ""
    payoneer_api_base: str = ""  # from Payoneer partner docs
    payoneer_api_key: str = ""
    payoneer_api_secret: str = ""
    google_pay_merchant_id: str = ""
    google_pay_gateway: str = ""  # operator's payment processor for capture
    google_pay_gateway_merchant_id: str = ""
    # --- Google Play Billing (in-app purchases; service-account JSON) ---
    play_service_account_json: str = ""  # VIRELLO_PLAY_SERVICE_ACCOUNT_JSON
    play_package_name: str = "com.virello.virello"  # VIRELLO_PLAY_PACKAGE_NAME
    oauth_token_key: str = "change-me-32-bytes-minimum!!"
    # --- Admin Panel allowlist (Hafiz, 2026-09-30: only these two accounts).
    # This field MUST exist: app/routers/admin.py reads settings.admin_emails
    # and a missing field raises AttributeError (the 2026-10-15/16 lesson).
    # VIRELLO_ADMIN_EMAILS overrides it.
    admin_emails: str = "salman09bhutta@gmail.com,alif01fiverr@gmail.com"
    # Hafiz's chosen admin PIN (2026-09-30). Was "" until 2026-10-22, which
    # made /admin/unlock refuse EVERY PIN in production (and before the field
    # existed at all, the endpoint 500'd on AttributeError — the panel never
    # opened). VIRELLO_ADMIN_PIN overrides this default.
    admin_pin: str = "0000"
    # --- Amazon IAP (legacy; Amazon Appstore account terminated 2026-10-06).
    # Fields exist so the dormant module can never AttributeError.
    amazon_developer_secret: str = ""
    amazon_sandbox: bool = True
    # --- Metrics agent (social-metrics data worker; service-token auth) ---
    metrics_agent_token: str = ""  # VIRELLO_METRICS_AGENT_TOKEN
    # --- Cloudinary (product gallery image store; Hafiz's free-tier account) ---
    cloudinary_url: str = ""  # VIRELLO_CLOUDINARY_URL (cloudinary://key:secret@cloud)
    # --- Agnes AI (AI image + video generation; key in Secure Vault) ---
    agnes_api_key: str = ""  # VIRELLO_AGNES_API_KEY
    celery_eager: bool = True  # dev: run Celery tasks inline, no Redis needed
    dev_noauth: bool = False  # dev only: bypass JWT, use demo user
    stage_delay_seconds: float = 0.2  # simulated agent work per stage (dev)

    class Config:
        env_prefix = "VIRELLO_"


settings = Settings()
