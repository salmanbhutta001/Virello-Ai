/// Per-feature EN/UR/AR strings for Creator Collab Match.
///
/// Kept inside the feature (not the generated l10n ARBs) so this screen is
/// self-contained. Follows the same (en, ur, ar) convention as AppStrings.
class CollabStrings {
  final String code; // 'en' | 'ur' | 'ar'
  const CollabStrings(this.code);

  String _t(String en, String ur, [String? ar]) =>
      code == 'ar' ? (ar ?? en) : (code == 'ur' ? ur : en);

  String get title => _t('Creator Collabs', 'کریئیٹر تعاون', 'تعاون المبدعين');
  String get subtitle => _t(
      'Team up with creators who genuinely share your posts. Free, organic, real people.',
      'ایسے کریئیٹرز سے جڑیں جو آپ کی پوسٹس واقعی شیئر کریں۔ مفت، آرگینک، حقیقی لوگ۔',
      'تعاون مع مبدعين يشاركون منشوراتك فعلاً. مجاني، عضوي، أشخاص حقيقيون.');

  String get tabFind => _t('Find Creators', 'کریئیٹر تلاش کریں', 'ابحث عن مبدعين');
  String get tabMine => _t('My Requests', 'میری درخواستیں', 'طلباتي');
  String get tabInbox => _t('Inbox', 'ان باکس', 'الوارد');

  String get becomeCreator => _t('Become a creator', 'کریئیٹر بنیں', 'كن مبدعًا');
  String get becomeCreatorDesc => _t(
      'Opt in and creators like you can find you. Your audience size is self-declared — never shown as verified.',
      'آپٹ اِن کریں تاکہ دوسرے آپ کو تلاش کر سکیں۔ آپ کے فالوورز کی تعداد خود بتائی ہوئی ہوگی — کبھی "تصدیق شدہ" نہیں دکھائی جائے گی۔',
      'اشترك ليتمكن الآخرون من إيجادك. عدد جمهورك مُصرَّح به ذاتيًا — ولن يُعرض أبدًا كموثّق.');
  String get displayName => _t('Display name', 'نام', 'الاسم المعروض');
  String get topicsHint => _t('Topics (comma separated)',
      'موضوعات (کاما سے الگ کریں)', 'المواضيع (مفصولة بفواصل)');
  String get platforms => _t('Platforms', 'پلیٹ فارمز', 'المنصات');
  String get audienceSize => _t('Audience size (self-declared)',
      'فالوورز کی تعداد (خود بتائی ہوئی)', 'حجم الجمهور (مُصرَّح به ذاتيًا)');
  String get bio => _t('Short bio (optional)', 'مختصر تعارف (اختیاری)',
      'نبذة قصيرة (اختياري)');
  String get optIn => _t('Appear in creator matching', 'میچنگ میں ظاہر ہوں',
      'الظهور في مطابقة المبدعين');
  String get saveProfile => _t('Save profile', 'پروفائل محفوظ کریں', 'حفظ الملف');
  String get profileSaved =>
      _t('Profile saved', 'پروفائل محفوظ ہو گیا', 'تم حفظ الملف');
  String get myCreatorProfile => _t('My creator profile', 'میرا کریئیٹر پروفائل',
      'ملفي كمبدع');

  String get pickTopics => _t('Pick topics to find your match',
      'میچ تلاش کرنے کے لیے موضوعات منتخب کریں',
      'اختر المواضيع للعثور على تطابقك');
  String get findMatches =>
      _t('Find matches', 'میچ تلاش کریں', 'ابحث عن التطابقات');
  String get noMatches => _t(
      'No creators match yet. Try fewer topics, or come back later — new creators opt in every day.',
      'ابھی کوئی کریئیٹر میچ نہیں ہوا۔ کم موضوعات آزمائیں، یا بعد میں دیکھیں — نئے کریئیٹر روز شامل ہوتے ہیں۔',
      'لا يوجد مبدعون مطابقون بعد. جرّب مواضيع أقل، أو عُد لاحقًا — ينضم مبدعون جدد كل يوم.');
  String get topicFit => _t('Topic fit', 'موضوع کی مطابقت', 'ملاءمة الموضوع');
  String get topicFitNote => _t(
      'Topic fit is a simple overlap score. It does not predict reach or views.',
      'ٹاپک فٹ صرف موضوعات کی مطابقت کا اسکور ہے۔ یہ ریچ یا ویوز کی ضمانت نہیں دیتا۔',
      'ملاءمة الموضوع مجرد درجة تداخل بسيطة. وهي لا تضمن الوصول أو المشاهدات.');
  String get selfDeclared =>
      _t('self-declared', 'خود بتائی ہوئی', 'مُصرَّح به ذاتيًا');
  String get matchedOn =>
      _t('Matched on', 'مطابقت', 'تطابق في');
  String get sendRequest =>
      _t('Send request', 'درخواست بھیجیں', 'إرسال طلب');
  String get requestSent =>
      _t('Request sent', 'درخواست بھیج دی گئی', 'تم إرسال الطلب');

  String get yourPostLink =>
      _t('Your post link', 'آپ کی پوسٹ کا لنک', 'رابط منشورك');
  String get messageOptional =>
      _t('Message (optional)', 'پیغام (اختیاری)', 'رسالة (اختياري)');
  String get messageHint => _t(
      'Say why this collab makes sense…',
      'بتائیں یہ تعاون کیوں مناسب ہے…',
      'اشرح لماذا يكون هذا التعاون منطقيًا…');

  String get noRequests => _t(
      'No requests yet. Find a creator and send your first collab request.',
      'ابھی کوئی درخواست نہیں۔ کوئی کریئیٹر تلاش کریں اور پہلی درخواست بھیجیں۔',
      'لا طلبات بعد. ابحث عن مبدع وأرسل أول طلب تعاون.');
  String get noInbox => _t(
      'No incoming requests. When link owners request a collab, they appear here.',
      'کوئی نئی درخواست نہیں۔ جب کوئی تعاون کی درخواست کرے گا تو یہیں نظر آئے گی۔',
      'لا طلبات واردة. عندما يطلب أصحاب الروابط تعاونًا، ستظهر هنا.');
  String get accept => _t('Accept', 'قبول کریں', 'قبول');
  String get decline => _t('Decline', 'مسترد کریں', 'رفض');
  String get markShared => _t('Mark as shared', 'شیئر شدہ نشان لگائیں',
      'وضع علامة "تمت المشاركة"');
  String get markSharedHint => _t(
      'Tap only after the creator has genuinely shared your post.',
      'صرف اس وقت دبائیں جب کریئیٹر نے واقعی آپ کی پوسٹ شیئر کر دی ہو۔',
      'اضغط فقط بعد أن يشارك المبدع منشورك فعلاً.');
  String get sharedDone =>
      _t('Marked as shared', 'شیئر شدہ نشان لگا دیا', 'تم وضع العلامة');

  String statusPending(String s) => _status(s, 'Pending', 'زیر التواء', 'قيد الانتظار');
  String statusAccepted(String s) =>
      _status(s, 'Accepted', 'قبول شدہ', 'مقبول');
  String statusDeclined(String s) =>
      _status(s, 'Declined', 'مسترد شدہ', 'مرفوض');
  String statusShared(String s) => _status(s, 'Shared', 'شیئر شدہ', 'تمت المشاركة');
  String _status(String s, String en, String ur, String ar) {
    switch (s) {
      case 'accepted':
        return _t('Accepted', 'قبول شدہ', 'مقبول');
      case 'declined':
        return _t('Declined', 'مسترد شدہ', 'مرفوض');
      case 'shared':
        return _t('Shared', 'شیئر شدہ', 'تمت المشاركة');
      default:
        return _t('Pending', 'زیر التواء', 'قيد الانتظار');
    }
  }

  String get errorGeneric =>
      _t('Something went wrong', 'کچھ غلط ہو گیا', 'حدث خطأ ما');
  String get loading => _t('Loading…', 'لوڈ ہو رہا ہے…', 'جارٍ التحميل…');
}
