/// Per-feature EN/UR/AR strings for Community Seeding.
/// Kept in the feature folder on purpose: lib/l10n/*.arb is owned by the
/// coordinator and must not be touched by feature agents.
class SeedingStrings {
  final String code; // 'en' | 'ur' | 'ar'
  const SeedingStrings(this.code);

  bool get isUrdu => code == 'ur';
  bool get isArabic => code == 'ar';

  String _get(String en, String ur, String ar) =>
      isArabic ? ar : (isUrdu ? ur : en);

  String get title => _get('Community Seeding', 'کمیونٹی سیڈنگ',
      'زرع المجتمعات');
  String get subtitle => _get(
      'Find the right communities for your post. You post manually — Virello only suggests.',
      'اپنی پوسٹ کے لیے درست کمیونٹیز تلاش کریں۔ آپ خود پوسٹ کرتے ہیں — Virello صرف تجویز دیتا ہے۔',
      'اعثر على المجتمعات المناسبة لمنشورك. أنت تنشر بنفسك — فيريلو يقترح فقط.');
  String get contentLabel => _get('Your post content', 'آپ کی پوسٹ کا مواد',
      'محتوى منشورك');
  String get contentHint => _get('Paste your post text or link…',
      'اپنی پوسٹ کا متن یا لنک یہاں پیسٹ کریں…', 'الصق نص منشورك أو رابطه…');
  String get topicsLabel =>
      _get('Topics', 'موضوعات', 'المواضيع');
  String get suggestBtn => _get('Suggest communities', 'کمیونٹیز تجویز کریں',
      'اقترح المجتمعات');
  String get suggesting =>
      _get('Finding communities…', 'کمیونٹیز تلاش ہو رہی ہیں…',
          'جارٍ البحث عن المجتمعات…');
  String get needContent => _get('Enter your post content first.',
      'پہلے اپنی پوسٹ کا مواد درج کریں۔', 'أدخل محتوى منشورك أولاً.');
  String get myPlans =>
      _get('My seeding plans', 'میرے سیڈنگ پلانز', 'خطط الزرع الخاصة بي');
  String get rulesNote => _get('Community rules', 'کمیونٹی کے اصول',
      'قواعد المجتمع');
  String get aiDraft =>
      _get('AI draft', 'AI ڈرافٹ', 'مسودة بالذكاء الاصطناعي');
  String get heuristicDraft => _get(
      'Heuristic draft', 'ہیورسٹک ڈرافٹ', 'مسودة تجريبية');
  String get draftNote => _get(
      'Value-first draft — no spammy call-to-actions. Copy it and post manually in your own account.',
      'ویلیو فرسٹ ڈرافٹ — کوئی اسپیمی کال ٹو ایکشن نہیں۔ اسے کاپی کریں اور اپنے اکاؤنٹ سے خود پوسٹ کریں۔',
      'مسودة تعطي القيمة أولاً — بدون دعوات مزعجة. انسخها وانشرها بنفسك من حسابك.');
  String get copy => _get('Copy', 'کاپی', 'نسخ');
  String get copied =>
      _get('Draft copied', 'ڈرافٹ کاپی ہو گیا', 'تم نسخ المسودة');
  String get approve => _get('Approve', 'منظور کریں', 'اعتماد');
  String get approved => _get('Approved', 'منظور شدہ', 'معتمَدة');
  String get markPosted => _get('Mark as posted', 'پوسٹ شدہ نشان زد کریں',
      'وضع علامة "تم النشر"');
  String get posted => _get('Posted', 'پوسٹ ہو گیا', 'تم النشر');
  String get suggested =>
      _get('Suggested', 'تجویز کردہ', 'مقترَحة');
  String get refresh => _get('Refresh', 'ریفریش', 'تحديث');
  String get manualNote => _get(
      'Virello never auto-posts. Suggestions come from a curated community list — nothing is scraped.',
      'Virello کبھی خودکار پوسٹ نہیں کرتا۔ تجاویز منتخب کمیونٹی فہرست سے آتی ہیں — کچھ بھی اسکریپ نہیں کیا جاتا۔',
      'فيريلو لا ينشر تلقائياً أبداً. الاقتراحات من قائمة مجتمعات مختارة — لا يتم استخراج أي بيانات.');
  String get errorGeneric => _get('Something went wrong. Please try again.',
      'کچھ غلط ہو گیا۔ دوبارہ کوشش کریں۔', 'حدث خطأ ما. حاول مجدداً.');
  String get noPlans => _get(
      'No plans yet. Describe your post above and tap "Suggest communities".',
      'ابھی کوئی پلان نہیں۔ اوپر اپنی پوسٹ لکھیں اور "کمیونٹیز تجویز کریں" دبائیں۔',
      'لا خطط بعد. صِف منشورك أعلاه واضغط "اقترح المجتمعات".');

  /// Topic picker labels (taxonomy slugs → display names).
  String topicName(String slug) {
    const names = {
      'gaming': ['Gaming', 'گیمنگ', 'الألعاب'],
      'fitness': ['Fitness', 'فٹنس', 'اللياقة'],
      'business': ['Business', 'کاروبار', 'الأعمال'],
      'technology': ['Tech', 'ٹیکنالوجی', 'التقنية'],
      'food': ['Food', 'کھانے', 'الطعام'],
      'travel': ['Travel', 'سفر', 'السفر'],
      'fashion': ['Fashion', 'فیشن', 'الموضة'],
      'education': ['Education', 'تعلیم', 'التعليم'],
      'health': ['Health', 'صحت', 'الصحة'],
      'finance': ['Finance', 'مالیات', 'المالية'],
      'marketing': ['Marketing', 'مارکیٹنگ', 'التسويق'],
      'motivation': ['Motivation', 'حوصلہ افزائی', 'التحفيز'],
      'sports': ['Sports', 'کھیل', 'الرياضة'],
      'music': ['Music', 'موسیقی', 'الموسيقى'],
      'art': ['Art', 'فن', 'الفن'],
      'photography': ['Photography', 'فوٹوگرافی', 'التصوير'],
    };
    final n = names[slug] ?? [slug, slug, slug];
    return isArabic ? n[2] : (isUrdu ? n[1] : n[0]);
  }
}

/// Slugs offered in the topic picker (subset of the discovery taxonomy).
const seedingTopicSlugs = [
  'gaming',
  'fitness',
  'business',
  'technology',
  'food',
  'travel',
  'fashion',
  'education',
  'health',
  'finance',
  'marketing',
  'motivation',
  'sports',
  'music',
  'art',
  'photography',
];
