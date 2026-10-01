from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    app_name: str = "Virello API"
    database_url: str = "postgresql+asyncpg://virello:virello@localhost:5432/virello"
    redis_url: str = "redis://localhost:6379/0"
    jwt_secret: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"
    access_token_minutes: int = 30
    refresh_token_days: int = 30
    cors_origins: list[str] = ["*"]
    # --- AI provider layer (provider-agnostic; swap via config, no rewrites) ---
    ai_provider: str = "dev"  # dev | anthropic | openai | google
    anthropic_api_key: str = ""
    anthropic_model: str = "claude-sonnet-4-20250514"
    openai_api_key: str = ""
    openai_model: str = "gpt-5"
    google_api_key: str = ""
    google_model: str = "gemini-2.5-pro"
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
    play_service_account_json: str = ""  # VIRELLO_PLAY_SERVICE_ACCOUNT_JSON (service-account JSON text)
    play_package_name: str = "com.virello.virello"  # VIRELLO_PLAY_PACKAGE_NAME
    # --- AI video generation proxy (Create Hub online mode) ---
    # Key = VIRELLO_AGNES_API_KEY. Never shipped in the APK.
    agnes_api_key: str = ""
    # --- Autonomous gallery publishing: backend pushes new gallery images
    # to GitHub itself (no Termux/phone/Muse needed). Token = fine-grained
    # PAT with Contents: read+write on the repo. Empty -> push skipped.
    github_token: str = ""  # VIRELLO_GITHUB_TOKEN
    github_repo: str = "salmanbhutta001/Virello-Ai"  # VIRELLO_GITHUB_REPO
    # --- Admin panel: hidden PIN entry (profile version tapped 5x -> PIN
    # screen). A correct PIN elevates the signed-in user to admin server-side.
    admin_pin: str = "0000"  # VIRELLO_ADMIN_PIN
    # --- Admin panel access: ONLY these emails (comma-separated, lowercase
    # compared) may unlock/be admin — everyone else gets 403 even with the
    # right PIN. Hafiz 2026-09-30: admin is his alone.
    admin_emails: str = "salman09bhutta@gmail.com,alif01fiverr@gmail.com"  # VIRELLO_ADMIN_EMAILS
    oauth_token_key: str = "change-me-32-bytes-minimum!!"
    celery_eager: bool = True  # dev: run Celery tasks inline, no Redis needed
    dev_noauth: bool = False  # dev only: bypass JWT, use demo user
    stage_delay_seconds: float = 0.2  # simulated agent work per stage (dev)

    class Config:
        env_prefix = "VIRELLO_"


settings = Settings()
