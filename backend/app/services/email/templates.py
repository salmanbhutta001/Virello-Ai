"""Payment receipt templates in EN/UR/AR.

Warm greeting + clean receipt table. No marketing fluff, no banned claims
(no promised virality/followers/sales — honesty is non-negotiable).
"""
from html import escape

_T = {
    "en": {
        "greeting": "Thank you, {name}!",
        "intro": "Your payment was successful. Here is your receipt.",
        "subject": "Your Virello receipt — {item}",
        "item": "Item",
        "amount": "Amount",
        "method": "Payment method",
        "reference": "Transaction reference",
        "date": "Date",
        "footer": "This is an automated receipt from Virello. "
                  "If you did not make this purchase, please contact support.",
        "dir": "ltr",
    },
    "ur": {
        "greeting": "شکریہ، {name}!",
        "intro": "آپ کی ادائیگی کامیاب ہو گئی ہے۔ یہ رہی آپ کی رسید۔",
        "subject": "آپ کی Virello رسید — {item}",
        "item": "آئٹم",
        "amount": "رقم",
        "method": "ادائیگی کا طریقہ",
        "reference": "ٹرانزیکشن ریفرنس",
        "date": "تاریخ",
        "footer": "یہ Virello کی جانب سے ایک خودکار رسید ہے۔ "
                  "اگر آپ نے یہ خریداری نہیں کی تو براہ کرم سپورٹ سے رابطہ کریں۔",
        "dir": "rtl",
    },
    "ar": {
        "greeting": "شكراً لك، {name}!",
        "intro": "تم الدفع بنجاح. إليك الإيصال الخاص بك.",
        "subject": "إيصال Virello الخاص بك — {item}",
        "item": "العنصر",
        "amount": "المبلغ",
        "method": "طريقة الدفع",
        "reference": "مرجع المعاملة",
        "date": "التاريخ",
        "footer": "هذا إيصال آلي من Virello. "
                  "إذا لم تقم بهذا الشراء، يرجى التواصل مع الدعم.",
        "dir": "rtl",
    },
}

_PROVIDER_LABELS = {
    "paypal": "PayPal",
    "payoneer": "Payoneer",
    "google_pay": "Google Pay",
}


def provider_label(provider: str) -> str:
    return _PROVIDER_LABELS.get((provider or "").lower(), provider or "—")


def payment_receipt(user_name: str, language: str, item_name: str,
                    amount: float, currency: str, provider: str,
                    txn_ref: str, date_str: str) -> tuple[str, str, str]:
    """Return (subject, html, text) for a payment receipt email."""
    lang = language if language in _T else "en"
    t = _T[lang]
    name = (user_name or "").strip() or "there"
    amount_str = f"{amount:,.2f} {currency}"
    subject = t["subject"].format(item=item_name)

    rows = [
        (t["item"], item_name),
        (t["amount"], amount_str),
        (t["method"], provider_label(provider)),
        (t["reference"], txn_ref),
        (t["date"], date_str),
    ]
    row_html = "".join(
        f'<tr><td style="padding:8px 12px;color:#666;">{escape(k)}</td>'
        f'<td style="padding:8px 12px;font-weight:600;">{escape(v)}</td></tr>'
        for k, v in rows
    )
    row_text = "\n".join(f"{k}: {v}" for k, v in rows)

    html = f"""<html><body dir="{t['dir']}" style="font-family:sans-serif;color:#1c1d33;">
<h2 style="color:#6c3df5;">{escape(t['greeting'].format(name=name))}</h2>
<p>{escape(t['intro'])}</p>
<table style="border-collapse:collapse;margin:16px 0;border:1px solid #eee;">
{row_html}
</table>
<p style="font-size:12px;color:#888;">{escape(t['footer'])}</p>
</body></html>"""

    text = (f"{t['greeting'].format(name=name)}\n\n{t['intro']}\n\n"
            f"{row_text}\n\n{t['footer']}")
    return subject, html, text
