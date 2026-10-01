/// Per-feature strings for the Referral screen (EN/UR/AR).
/// Kept next to the feature so the shared ARB catalog is untouched.
class ReferralStrings {
  final String code; // 'en' | 'ur' | 'ar'
  const ReferralStrings(this.code);

  bool get _isUrdu => code == 'ur';
  bool get _isArabic => code == 'ar';

  String _get(String en, String ur, [String? ar]) =>
      _isArabic ? (ar ?? en) : (_isUrdu ? ur : en);

  String get title => _get('Refer & Earn', 'ریفر کریں اور کمائیں', 'أحِل وكسِب');
  String get tagline => _get(
        'Invite friends. You both get free AI credits.',
        'دوستوں کو مدعو کریں۔ آپ دونوں کو مفت AI کریڈٹس ملیں گے۔',
        'ادعُ أصدقاءك. تحصلان معاً على رصيد ذكاء اصطناعي مجاني.',
      );
  String get yourLink => _get('Your referral link', 'آپ کا ریفرل لنک', 'رابط الإحالة الخاص بك');
  String get yourCode => _get('Your code', 'آپ کا کوڈ', 'رمزك');
  String get copyLink => _get('Copy link', 'لنک کاپی کریں', 'نسخ الرابط');
  String get copied => _get('Link copied — share it anywhere!',
      'لنک کاپی ہو گیا — کہیں بھی شیئر کریں!', 'تم نسخ الرابط — شاركه في أي مكان!');
  String get howItWorks => _get('How it works', 'یہ کیسے کام کرتا ہے', 'كيف يعمل');
  String get step1 => _get('1. Share your link with friends',
      '1. اپنا لنک دوستوں کے ساتھ شیئر کریں',
      '1. شارك رابطك مع أصدقائك');
  String get step2 => _get('2. They sign up with your code',
      '2. وہ آپ کے کوڈ سے سائن اپ کرتے ہیں',
      '2. يسجّلون باستخدام رمزك');
  String get step3 => _get('3. You both get 50 free AI credits',
      '3. آپ دونوں کو 50 مفت AI کریڈٹس ملتے ہیں',
      '3. تحصلان معاً على 50 رصيد ذكاء اصطناعي مجاني');
  String get invites => _get('Invites', 'دعوتیں', 'الدعوات');
  String get credited => _get('Joined', 'شامل ہوئے', 'انضموا');
  String get pending => _get('Pending', 'زیر التواء', 'قيد الانتظار');
  String get creditsEarned =>
      _get('Credits earned', 'کمائے گئے کریڈٹس', 'الأرصدة المكتسبة');
  String get noInvitesYet => _get(
        'No invites yet — share your link to start earning.',
        'ابھی کوئی دعوت نہیں — کمانا شروع کرنے کے لیے اپنا لنک شیئر کریں۔',
        'لا دعوات بعد — شارك رابطك لتبدأ الكسب.',
      );
  String get loadFailed => _get('Could not load referrals. Pull to retry.',
      'ریفرلز لوڈ نہیں ہو سکے۔ دوبارہ کوشش کے لیے نیچے کھینچیں۔',
      'تعذّر تحميل الإحالات. اسحب لإعادة المحاولة.');
  String get honestNote => _get(
        'Credits are paid only after your friend’s signup is verified. One account, one invite.',
        'کریڈٹس صرف آپ کے دوست کے سائن اپ کی تصدیق کے بعد ملتے ہیں۔ ایک اکاؤنٹ، ایک دعوت۔',
        'تُدفع الأرصدة فقط بعد التحقق من تسجيل صديقك. حساب واحد، دعوة واحدة.',
      );
  String get shareInvite => _get('Share invite card', 'دعوتی کارڈ شیئر کریں', 'شارك بطاقة الدعوة');
  String get generating => _get('Making your card…', 'آپ کا کارڈ بن رہا ہے…', 'جارٍ إنشاء بطاقتك…');
  String get shareFailed => _get('Could not make the invite card. Try again.',
      'دعوتی کارڈ نہیں بن سکا۔ دوبارہ کوشش کریں۔', 'تعذّر إنشاء بطاقة الدعوة. حاول مجدداً.');
  String shareText(String code, String link) => _get(
        'Join me on Virello — your AI Growth Manager! Use my code $code and we BOTH get 50 free AI credits. $link',
        'Virello پر میرے ساتھ شامل ہوں — آپ کا AI Growth Manager! میرا کوڈ $code استعمال کریں اور ہم دونوں کو 50 مفت AI کریڈٹس ملیں گے۔ $link',
        'انضم إليّ على Virello — مدير النمو بالذكاء الاصطناعي! استخدم رمزي $code وسنحصل معاً على 50 رصيد ذكاء اصطناعي مجاني. $link',
      );
  String get cardOffer => _get('50 FREE AI CREDITS', '50 مفت AI کریڈٹس', '50 رصيد ذكاء اصطناعي مجاني');
  String get cardHeadline => _get(
        'Grow on social media with your AI manager',
        'اپنے AI مینیجر کے ساتھ سوشل میڈیا پر بڑھیں',
        'نَمِّ حساباتك بمساعدة مديرك الذكي',
      );
  String get cardSubline => _get(
        'Scan the code — we both earn free credits when you join.',
        'کوڈ اسکین کریں — آپ کے شامل ہونے پر ہم دونوں کو مفت کریڈٹس ملیں گے۔',
        'امسح الرمز — سنحصل معاً على أرصدة مجانية عند انضمامك.',
      );
  String get cardScan =>
      _get('Scan to download Virello', 'Virello ڈاؤن لوڈ کرنے کے لیے اسکین کریں', 'امسح لتنزيل Virello');
}
