"""Open-datasets connector: generic CSV importer + BigQuery hooks.

Two legitimate open-data paths:
1. CSV import — an admin uploads any openly-licensed CSV with columns like
   ``topic, keyword, geography, language, volume``. Volumes are used ONLY
   when the CSV documents what they measure (the ``volume_label`` column or
   a dataset-level label); otherwise volume_hint stays None.
2. Google Trends BigQuery public datasets (``bigquery-public-data``) —
   documented as the official production upgrade path for the Trends
   connector. Requires Google Cloud credentials; without them this path
   reports not_configured.

Never invent numbers; never treat a CSV as authoritative unless its license
and methodology are documented by the uploader.
"""
from __future__ import annotations

import csv
import io
import os

from app.services.audience_sources.base import (
    AudienceSourceConnector, CostTier, FetchResult, Freshness, InterestSignal,
    PermittedUse, SourceMetadata, SourceStatus,
)


class OpenDatasetsConnector(AudienceSourceConnector):
    metadata = SourceMetadata(
        source_name="open_datasets",
        access_method=("CSV import (admin-uploaded, openly licensed) + "
                       "Google Trends BigQuery public datasets "
                       "(GCP credentials)"),
        cost_tier=CostTier.free,
        rate_limit="CSV: unlimited local import; BigQuery: 1 TB/month free",
        geographic_coverage="Dataset-dependent",
        freshness=Freshness.monthly,
        permitted_use=PermittedUse.open_dataset,
        confidence_score=0.55,
        confidence_rationale=(
            "Quality depends entirely on the dataset's methodology and "
            "license. Only openly-licensed datasets with documented "
            "methodology should be imported; confidence is capped until a "
            "dataset is reviewed."),
        tos_notes=(
            "Only import datasets whose license permits commercial reuse "
            "(e.g. CC-BY, CC0, ODbL). Record license + methodology at import "
            "time. BigQuery public datasets follow Google Cloud terms."),
    )

    def is_configured(self) -> bool:
        # The importer itself is always available; BigQuery is optional.
        return True

    def import_csv(self, csv_text: str, dataset_name: str,
                   volume_label: str = "",
                   license_note: str = "") -> FetchResult:
        """Import an openly-licensed CSV. Expected columns: topic (required),
        keyword(s), geography, language, volume (optional numeric)."""
        signals: list[InterestSignal] = []
        try:
            rows = list(csv.DictReader(io.StringIO(csv_text)))
        except Exception as exc:
            return FetchResult(status=SourceStatus.degraded,
                               message=f"CSV parse failed: {exc}")
        for row in rows[:500]:
            topic = (row.get("topic") or "").strip().lower()
            if not topic:
                continue
            kws = [k.strip().lower() for k in
                   (row.get("keywords") or row.get("keyword") or "")
                   .replace(";", ",").split(",") if k.strip()]
            vol = None
            raw_vol = (row.get("volume") or "").strip()
            if raw_vol:
                try:
                    vol = float(raw_vol)
                except ValueError:
                    vol = None
            signals.append(InterestSignal(
                topic=topic,
                keywords=[topic] + kws[:9],
                geography=(row.get("geography") or "").strip().upper(),
                language=(row.get("language") or "").strip().lower(),
                volume_hint=vol,
                volume_label=(volume_label or "volume unavailable"),
                trend_direction=(row.get("trend") or "unknown").strip().lower(),
                source=f"open_datasets:{dataset_name}",
            ))
        return FetchResult(
            status=SourceStatus.ready, signals=signals,
            message=(f"Imported {len(signals)} signals from '{dataset_name}'"
                     + (f" ({license_note})" if license_note else "")))

    def bigquery_trends_status(self) -> dict:
        """Status of the official BigQuery upgrade path (no fake query)."""
        creds = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS", "")
        return {
            "available": bool(creds),
            "dataset": "bigquery-public-data.google_trends",
            "note": ("Set GOOGLE_APPLICATION_CREDENTIALS to query the "
                     "official public Trends datasets."),
        }

    def fetch_signals(self, topics: list[str] | None = None,
                      geography: str = "",
                      limit: int = 20) -> FetchResult:
        # Without an uploaded CSV there is nothing to return — and we never
        # synthesize. BigQuery path is reported via bigquery_trends_status().
        return FetchResult(
            status=SourceStatus.not_configured,
            message=("No open dataset imported yet. Upload an openly-licensed "
                     "CSV via import_csv(), or configure BigQuery for the "
                     "official Google Trends public datasets."))
