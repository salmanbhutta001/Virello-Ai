/// Hand-rolled EN/UR strings for the scaffold (keeps pubspec dependency-light).
/// Production path: flutter_intl + ARB codegen (see lib/l10n/*.arb).
class AppStrings {
  final String code; // 'en' | 'ur' | 'ar'
  bool get isArabic => code == 'ar';
  const AppStrings(this.code);
  bool get isUrdu => code == 'ur';
  String _get(String en, String ur, [String? ar]) =>
      isArabic ? (ar ?? en) : (isUrdu ? ur : en);

  String get appTagline => _get(
    'Your AI Growth Manager',
    'آپ کا AI گروتھ مینیجر',
    'مدير النمو بالذكاء الاصطناعي',
  );
  String get home => _get('Home', 'ہوم', 'الرئيسية');
  String get grow => _get('Grow', 'گرو', 'نمِّ');
  String get campaigns => _get('Campaigns', 'مہمات', 'الحملات');
  String get analytics => _get('Analytics', 'تجزیات', 'التحليلات');
  String get profile => _get('Profile', 'پروفائل', 'الملف الشخصي');
  String get letAiGrow =>
      _get('LET AI GROW', 'AI سے گرو کریں', 'دَع الذكاء الاصطناعي ينمِّي');
  String get pasteYourPost =>
      _get('Paste your post', 'اپنی پوسٹ کا لنک پیسٹ کریں', 'الصق منشورك');
  String get pasteHint => _get(
    'Paste a public post or video link…',
    'عوامی پوسٹ یا ویڈیو کا لنک یہاں پیسٹ کریں…',
    'الصق رابط منشور عام أو فيديو…',
  );
  String get chooseYourGoal =>
      _get('Choose your goal', 'اپنا ہدف منتخب کریں', 'اختر هدفك');
  String get setBudget =>
      _get('Markets & budget', 'مارکیٹس اور بجٹ', 'الأسواق والميزانية');
  String get review => _get('Review', 'جائزہ', 'مراجعة');
  String get continueBtn => _get('Continue', 'جاری رکھیں', 'متابعة');
  String get back => _get('Back', 'پیچھے', 'رجوع');
  String get organic => _get(
    'AI Organic Growth',
    'AI آرگینک گروتھ',
    'النمو العضوي بالذكاء الاصطناعي',
  );
  String get organicDesc => _get(
    'No ad budget. AI optimizes content & discovery.',
    'بغیر اشتہاری بجٹ — AI مواد اور دریافت کو بہتر بناتا ہے۔',
    'بدون ميزانية إعلانية. يحسِّن الذكاء الاصطناعي المحتوى والاكتشاف.',
  );
  String get paid =>
      _get('AI Paid Boost', 'AI پیڈ بوسٹ', 'التعزيز المدفوع بالذكاء الاصطناعي');
  String get paidDesc => _get(
    'AI manages ads within your approved budget.',
    'AI آپ کے منظور شدہ بجٹ میں اشتہارات چلاتا ہے۔',
    'يدير الذكاء الاصطناعي الإعلانات ضمن ميزانيتك المعتمدة.',
  );
  String get trustTitle => _get('Trust Center', 'ٹرسٹ سینٹر', 'مركز الثقة');
  String get neverFake => _get(
    'We never use fake engagement',
    'ہم کبھی جعلی انگیجمنٹ استعمال نہیں کرتے',
    'لا نستخدم التفاعل المزيَّف أبداً',
  );
  String get noGuarantees => _get(
    'No guaranteed virality — honest optimization & reporting.',
    'وائرل ہونے کی ضمانت نہیں — ایماندارانہ اصلاح اور رپورٹنگ۔',
    'لا ضمان للانتشار — تحسين وتقارير صادقة.',
  );
  String get freePlan => _get('Free Plan', 'مفت پلان', 'الخطة المجانية');
  String get goPremium =>
      _get('Go Premium', 'پریمیم لیں', 'الترقية إلى المميز');

  // Discovery → Analyze → Result → Save journey
  String get discover => _get('Discover', 'دریافت کریں', 'اكتشف');
  String get discoverTagline => _get(
    'Content matched to your interests — by real interest, never fake engagement.',
    'آپ کی دلچسپیوں کے مطابق مواد — حقیقی دلچسپی سے، کبھی جعلی انگیجمنٹ نہیں۔',
    'محتوى يطابق اهتماماتك — باهتمام حقيقي، لا تفاعل مزيَّف أبداً.',
  );
  String get analyze => _get('Analyze', 'تجزیہ کریں', 'حلِّل');
  String get analyzing =>
      _get('Analyzing…', 'تجزیہ ہو رہا ہے…', 'جارٍ التحليل…');
  String get analyzingSub => _get(
    'Fetching the post and scoring its packaging.',
    'پوسٹ حاصل کر کے اس کی پیشکش کا اسکور بنایا جا رہا ہے۔',
    'جارٍ جلب المنشور وتقييم عرضه.',
  );
  String get yourInterests =>
      _get('Your interests', 'آپ کی دلچسپیاں', 'اهتماماتك');
  String get recommendedForYou =>
      _get('Recommended for you', 'آپ کے لیے تجاویز', 'مُقترح لك');
  String get whyThis => _get('Why this?', 'یہ کیوں؟', 'لماذا هذا؟');
  String get tapToAnalyze =>
      _get('Tap to analyze', 'تجزیے کے لیے تھپتھپائیں', 'اضغط للتحليل');
  String get contentScore =>
      _get('Content score', 'مواد کا اسکور', 'درجة المحتوى');
  String get save => _get('Save', 'محفوظ کریں', 'حفظ');
  String get saved => _get('Saved', 'محفوظ شدہ', 'محفوظ');
  String get savedDone => _get('Saved ✓', 'محفوظ ہو گیا ✓', 'تم الحفظ ✓');
  String get alreadySaved => _get(
    'Already in your saved list',
    'پہلے سے محفوظ شدہ فہرست میں ہے',
    'موجود مسبقاً في قائمتك المحفوظة',
  );
  String get growThisPost =>
      _get('Grow this post', 'اس پوسٹ کو گرو کریں', 'نمِّ هذا المنشور');
  String get nothingHere =>
      _get('Nothing here yet.', 'ابھی یہاں کچھ نہیں۔', 'لا يوجد شيء هنا بعد.');
  String get pickInterestsHint => _get(
    'Pick a few interests to get recommendations.',
    'تجاویز کے لیے چند دلچسپیاں منتخب کریں۔',
    'اختر بعض الاهتمامات للحصول على توصيات.',
  );
  String get invalidUrl => _get(
    'Please enter a valid http(s) link.',
    'براہ کرم درست لنک درج کریں۔',
    'يُرجى إدخال رابط http(s) صالح.',
  );
  String get analyzeFailed => _get(
    'Analysis failed. Check your connection and try again.',
    'تجزیہ ناکام ہوا۔ کنکشن چیک کر کے دوبارہ کوشش کریں۔',
    'فشل التحليل. تحقق من اتصالك وحاول مجدداً.',
  );
  String get noTitle =>
      _get('Untitled post', 'بغیر عنوان پوسٹ', 'منشور بلا عنوان');
  String get fetchLevelOembed => _get(
    'Rich preview fetched',
    'مکمل پیش نظارہ حاصل ہوا',
    'تم جلب معاينة غنية',
  );
  String get fetchLevelOpengraph =>
      _get('Preview fetched', 'پیش نظارہ حاصل ہوا', 'تم جلب المعاينة');
  String get fetchLevelMinimal => _get(
    'Link only — site blocked previews',
    'صرف لنک — سائٹ نے پیش نظارہ روکا',
    'الرابط فقط — الموقع حظر المعاينات',
  );
  String get estimatedNote => _get(
    'Heuristic estimate — not a prediction or guarantee of reach.',
    'اندازاً جائزہ — رسائی کی پیشگوئی یا ضمانت نہیں۔',
    'تقدير تقريبي — ليس توقعاً أو ضماناً للوصول.',
  );

  // Auth (email OTP — never social passwords)
  String get signInTitle => _get(
    'Sign in with email',
    'ای میل سے سائن ان کریں',
    'تسجيل الدخول بالبريد الإلكتروني',
  );
  String get emailHint =>
      _get('you@example.com', 'you@example.com', 'you@example.com');
  String get enterCode => _get(
    'Enter the code we emailed you',
    'ای میل پر بھیجا گیا کوڈ درج کریں',
    'أدخل الرمز الذي أرسلناه إلى بريدك',
  );
  String get codeHint =>
      _get('6-digit code', '6 ہندسوں کا کوڈ', 'رمز من 6 أرقام');
  String get useDifferentEmail => _get(
    'Use a different email',
    'مختلف ای میل استعمال کریں',
    'استخدام بريد إلكتروني مختلف',
  );
  String get verify => _get('Verify', 'تصدیق کریں', 'تحقق');
  String get invalidEmail => _get(
    'Please enter a valid email address.',
    'براہ کرم درست ای میل درج کریں۔',
    'يُرجى إدخال بريد إلكتروني صالح.',
  );
  String get invalidCode => _get(
    'Invalid or expired code. Try again.',
    'غلط یا پرانا کوڈ۔ دوبارہ کوشش کریں۔',
    'رمز غير صالح أو منتهٍ. حاول مجدداً.',
  );
  String get signInFailed => _get(
    'Sign-in failed. Check your connection and try again.',
    'سائن ان ناکام۔ کنکشن چیک کر کے دوبارہ کوشش کریں۔',
    'فشل تسجيل الدخول. تحقق من اتصالك وحاول مجدداً.',
  );
  String get sessionExpired => _get(
    'Session expired. Please sign in again.',
    'سیشن ختم۔ دوبارہ سائن ان کریں۔',
    'انتهت الجلسة. يُرجى تسجيل الدخول مجدداً.',
  );
  // --- Social sign-in (Google / Apple) ---
  String get orContinueWith =>
      _get('or continue with', 'یا جاری رکھیں', 'أو تابع باستخدام');
  String get continueWithGoogle => _get(
    'Continue with Google',
    'Google سے جاری رکھیں',
    'المتابعة باستخدام Google',
  );
  String get socialSignInFailed => _get(
    'Social sign-in failed. Try email code instead.',
    'سوشل سائن ان ناکام۔ ای میل کوڈ استعمال کریں۔',
    'فشل تسجيل الدخول الاجتماعي. جرّب رمز البريد الإلكتروني.',
  );
  String get noPasswordsNote => _get(
    'We never ask for your social-media passwords.',
    'ہم کبھی آپ کے سوشل میڈیا پاس ورڈ نہیں مانگتے۔',
    'لا نطلب كلمات مرور حساباتك الاجتماعية أبداً.',
  );
  // --- Reddit-style login redesign ---
  String get logInTitle => _get('Log In', 'لاگ ان', 'تسجيل الدخول');
  String get loginAgreementLead => _get(
    'By continuing, you agree to our ',
    'جاری رکھ کر آپ ہماری ',
    'بالمتابعة، أنت توافق على ',
  );
  String get userAgreement =>
      _get('User Agreement', 'یوزر ایگریمنٹ', 'اتفاقية المستخدم');
  String get loginAgreementMid => _get(
    ' and acknowledge that you understand the ',
    ' سے اتفاق کرتے ہیں اور تسلیم کرتے ہیں کہ آپ نے ',
    ' وتقر بأنك تفهم ',
  );
  String get privacyPolicy =>
      _get('Privacy Policy', 'پرائیویسی پالیسی', 'سياسة الخصوصية');
  String get policySoon => _get(
    'Available after production setup.',
    'پروڈکشن سیٹ اپ کے بعد دستیاب ہوگا۔',
    'متاح بعد إعداد الإنتاج.',
  );
  String get continueWithApple => _get(
    'Continue with Apple',
    'Apple سے جاری رکھیں',
    'المتابعة باستخدام Apple',
  );
  String get emailMeCode => _get(
    'Email me a one-time code',
    'مجھے ون ٹائم کوڈ ای میل کریں',
    'أرسل لي رمز تحقق لمرة واحدة',
  );
  String get orDivider => _get('OR', 'یا', 'أو');
  String get emailLabel => _get('Email', 'ای میل', 'البريد الإلكتروني');
  String get newToVirello =>
      _get('New to Virello?', 'Virello میں نئے ہیں؟', 'جديد على Virello؟');
  String get signUpLink => _get('Sign Up', 'سائن اپ کریں', 'سجّل');
  String get signOut => _get('Sign out', 'سائن آؤٹ', 'تسجيل الخروج');
  // --- Email + password auth ---
  String get logInBtn => _get('Log In', 'لاگ ان کریں', 'تسجيل الدخول');
  String get passwordLabel => _get('Password', 'پاس ورڈ', 'كلمة المرور');
  String get passwordHint =>
      _get('Enter your password', 'اپنا پاس ورڈ لکھیں', 'أدخل كلمة المرور');
  String get forgotPassword =>
      _get('Forgot password?', 'پاس ورڈ بھول گئے؟', 'نسيت كلمة المرور؟');
  String get signUpTitle =>
      _get('Create your account', 'اپنا اکاؤنٹ بنائیں', 'أنشئ حسابك');
  String get nameLabelOptional => _get(
    'Full name (optional)',
    'پورا نام (اختیاری)',
    'الاسم الكامل (اختياري)',
  );
  String get confirmPasswordLabel =>
      _get('Confirm password', 'پاس ورڈ کی تصدیق', 'تأكيد كلمة المرور');
  String get signUpBtn => _get('Sign Up', 'سائن اپ کریں', 'إنشاء الحساب');
  String get alreadyHaveAccountQ => _get(
    'Already have an account?',
    'پہلے سے اکاؤنٹ ہے؟',
    'لديك حساب بالفعل؟',
  );
  String get logInLink => _get('Log In', 'لاگ ان', 'تسجيل الدخول');
  String get resetPasswordTitle =>
      _get('Reset password', 'پاس ورڈ ری سیٹ کریں', 'إعادة تعيين كلمة المرور');
  String get sendCodeBtn => _get('Send code', 'کوڈ بھیجیں', 'إرسال الرمز');
  String get codeSentTo =>
      _get('Code sent to', 'کوڈ بھیجا گیا', 'تم إرسال الرمز إلى');
  String get newPasswordLabel =>
      _get('New password', 'نیا پاس ورڈ', 'كلمة مرور جديدة');
  String get resetPasswordBtn =>
      _get('Reset password', 'پاس ورڈ ری سیٹ کریں', 'إعادة تعيين كلمة المرور');
  String get passwordTooShort => _get(
    'Password must be at least 8 characters.',
    'پاس ورڈ کم از کم 8 حروف کا ہو۔',
    'يجب أن تتكون كلمة المرور من 8 أحرف على الأقل.',
  );
  String get passwordsDontMatch => _get(
    "Passwords don't match.",
    'پاس ورڈ آپس میں نہیں ملتے۔',
    'كلمتا المرور غير متطابقتين.',
  );
  String get accountExistsSignIn => _get(
    'An account with this email already exists. Sign in instead, or use Forgot password to set a password.',
    'اس ای میل سے اکاؤنٹ پہلے سے موجود ہے۔ لاگ ان کریں یا پاس ورڈ سیٹ کرنے کے لیے Forgot password استعمال کریں۔',
    'يوجد حساب بهذا البريد بالفعل. سجّل الدخول أو استخدم "نسيت كلمة المرور" لتعيين كلمة مرور.',
  );
  String get invalidEmailOrPassword => _get(
    'Invalid email or password.',
    'ای میل یا پاس ورڈ غلط ہے۔',
    'البريد الإلكتروني أو كلمة المرور غير صحيحة.',
  );
  String get tooManyAttempts => _get(
    'Too many attempts. Try again in a few minutes.',
    'بہت سی کوششیں۔ چند منٹ بعد دوبارہ کوشش کریں۔',
    'محاولات كثيرة. حاول مجدداً بعد بضع دقائق.',
  );
  // --- Settings page ---
  String get settingsTitle => _get('Settings', 'سیٹنگز', 'الإعدادات');
  String get accountSection => _get('Account', 'اکاؤنٹ', 'الحساب');
  String get preferencesSection => _get('Preferences', 'ترجیحات', 'التفضيلات');
  String get planBillingSection =>
      _get('Plan & Billing', 'پلان اور بلنگ', 'الخطة والفوترة');
  String get trustLegalSection =>
      _get('Trust & Legal', 'اعتماد اور قانونی', 'الثقة والقانون');
  String get supportSection => _get('Support', 'سپورٹ', 'الدعم');
  String get aboutSection => _get('About', 'کے بارے میں', 'حول');
  String get changePasswordTitle =>
      _get('Change password', 'پاس ورڈ تبدیل کریں', 'تغيير كلمة المرور');
  String get currentPasswordLabel =>
      _get('Current password', 'موجودہ پاس ورڈ', 'كلمة المرور الحالية');
  String get passwordChangedOk => _get(
    'Password changed successfully.',
    'پاس ورڈ کامیابی سے تبدیل ہو گیا۔',
    'تم تغيير كلمة المرور بنجاح.',
  );
  String get currentPasswordWrong => _get(
    'Current password is incorrect.',
    'موجودہ پاس ورڈ غلط ہے۔',
    'كلمة المرور الحالية غير صحيحة.',
  );
  String get noPasswordYet => _get(
    'This account has no password yet. Use "Forgot password?" on the login screen to set one.',
    'اس اکاؤنٹ کا ابھی کوئی پاس ورڈ نہیں۔ سیٹ کرنے کے لیے لاگ ان اسکرین پر "Forgot password?" استعمال کریں۔',
    'لا توجد كلمة مرور لهذا الحساب بعد. استخدم "نسيت كلمة المرور؟" في شاشة الدخول لتعيين واحدة.',
  );
  String get appVersion => _get('Version', 'ورژن', 'الإصدار');
  String get signOutConfirm => _get(
    'Sign out of Virello?',
    'Virello سے سائن آؤٹ کریں؟',
    'تسجيل الخروج من Virello؟',
  );
  String get cancelBtn => _get('Cancel', 'منسوخ کریں', 'إلغاء');
  String get appearanceLabel =>
      _get('Dark theme', 'ڈارک تھیم', 'المظهر الداكن');

  // Campaigns (real backend data)
  String get noCampaigns =>
      _get('No campaigns yet', 'ابھی کوئی مہم نہیں', 'لا حملات بعد');
  String get noCampaignsHint => _get(
    'Tap LET AI GROW to launch your first one.',
    'پہلی مہم کے لیے LET AI GROW دبائیں۔',
    'اضغط «دَع الذكاء الاصطناعي ينمِّي» لإطلاق أول حملة.',
  );
  String get metricsSoon => _get(
    'Metrics will appear once your campaign is live.',
    'مہم لائیو ہوتے ہی اعداد و شمار یہاں آئیں گے۔',
    'ستظهر المقاييس عندما تصبح حملتك نشطة.',
  );
  String get pause => _get('Pause', 'روکیں', 'إيقاف مؤقت');
  String get pausedToast =>
      _get('Campaign paused', 'مہم روک دی گئی', 'تم إيقاف الحملة مؤقتاً');
  String get growFailed => _get(
    'Could not launch. Check your connection and try again.',
    'لانچ ناکام۔ کنکشن چیک کر کے دوبارہ کوشش کریں۔',
    'تعذَّر الإطلاق. تحقق من اتصالك وحاول مجدداً.',
  );
  String get launching =>
      _get('Launching…', 'لانچ ہو رہا ہے…', 'جارٍ الإطلاق…');
  String get campaignLive => _get(
    'Your campaign is live. AI is optimizing within your approved limits.',
    'آپ کی مہم لائیو ہے۔ AI آپ کی منظور شدہ حدود میں بہتر بنا رہا ہے۔',
    'حملتك نشطة. يحسِّن الذكاء الاصطناعي ضمن حدودك المعتمدة.',
  );

  // Admin Dashboard
  String get adminDashboard =>
      _get('Admin Dashboard', 'ایڈمن ڈیش بورڈ', 'لوحة الإدارة');
  String get adminOverview => _get('Overview', 'جائزہ', 'نظرة عامة');
  String get adminUsers => _get('Users', 'صارفین', 'المستخدمون');
  // --- Admin user-visit analytics ---
  String get adminAnalytics => _get('Analytics', 'اینالٹکس', 'التحليلات');
  String get rangeDaily => _get('Daily', 'روزانہ', 'يومي');
  String get rangeWeekly => _get('Weekly', 'ہفتہ وار', 'أسبوعي');
  String get rangeMonthly => _get('Monthly', 'ماہانہ', 'شهري');
  String get statDau => _get('Daily active', 'روزانہ فعال', 'نشط يومياً');
  String get statWau => _get('Weekly active', 'ہفتہ وار فعال', 'نشط أسبوعياً');
  String get statMau => _get('Monthly active', 'ماہانہ فعال', 'نشط شهرياً');
  String get statSignups => _get('New signups', 'نئے سائن اپ', 'تسجيلات جديدة');
  String get statVisits => _get('Visits', 'وزٹس', 'الزيارات');
  String get statTotalUsers =>
      _get('Total users', 'کل صارفین', 'إجمالي المستخدمين');
  String get salesTitle => _get('Sales', 'فروخت', 'المبيعات');
  String get salesTotalRevenue =>
      _get('Total revenue', 'کل آمدنی', 'إجمالي الإيرادات');
  String get salesNetRevenue =>
      _get('Net revenue', 'خالص آمدنی', 'صافي الإيرادات');
  String get salesOrders => _get('Orders', 'آرڈرز', 'الطلبات');
  String get salesSubscriptions =>
      _get('Subscriptions', 'سبسکرپشنز', 'الاشتراكات');
  String get salesCredits => _get('Credits', 'کریڈٹس', 'الأرصدة');
  String get salesRefunds => _get('Refunds', 'ریفنڈز', 'المبالغ المستردة');
  String get lastActive => _get('Last active', 'آخری سرگرمی', 'آخر نشاط');
  String get neverActive => _get('Never', 'کبھی نہیں', 'أبداً');
  String get adminPayments => _get('Payments', 'ادائیگیاں', 'المدفوعات');
  String get adminFraud =>
      _get('Fraud flags', 'فراڈ الرٹس', 'تنبيهات الاحتيال');
  String get adminDiscovery =>
      _get('Discovery queue', 'ڈسکوری قطار', 'قائمة الاكتشاف');
  String get adminPlans => _get('Plans', 'پلانز', 'الخطط');
  String get adminBroadcasts => _get('Broadcasts', 'اعلانات', 'البثّ');
  String get adminSettings => _get('Settings', 'ترتیبات', 'الإعدادات');
  String get adminAudit => _get('Audit log', 'آڈٹ لاگ', 'سجل التدقيق');
  String get adminAiUsage =>
      _get('AI usage', 'AI استعمال', 'استخدام الذكاء الاصطناعي');
  String get totalUsers => _get('Users', 'صارفین', 'المستخدمون');
  String get totalCampaigns => _get('Campaigns', 'مہمات', 'الحملات');
  String get liveCampaigns => _get('Live now', 'ابھی لائیو', 'نشطة الآن');
  String get revenueUsd =>
      _get('Revenue (USD)', 'آمدنی (USD)', 'الإيرادات (دولار)');
  String get openFlags =>
      _get('Open fraud flags', 'کھلے فراڈ الرٹس', 'تنبيهات احتيال مفتوحة');
  String get byStatus => _get('By status', 'حیثیت کے لحاظ سے', 'حسب الحالة');
  String get byGoal => _get('By goal', 'ہدف کے لحاظ سے', 'حسب الهدف');
  String get suspend => _get('Suspend', 'معطل کریں', 'تعليق');
  String get unsuspend => _get('Unsuspend', 'بحال کریں', 'إلغاء التعليق');
  String get makeAdmin => _get('Make admin', 'ایڈمن بنائیں', 'جعله مديراً');
  String get adjustCredits =>
      _get('Adjust credits', 'کریڈٹ ایڈجسٹ کریں', 'تعديل الرصيد');
  String get creditsDelta =>
      _get('Credit change (+/-)', 'کریڈٹ تبدیلی (+/-)', 'تغيير الرصيد (+/-)');
  String get reason => _get('Reason', 'وجہ', 'السبب');
  String get resolve => _get('Resolve', 'حل کریں', 'حلّ');
  String get approve => _get('Approve', 'منظور کریں', 'اعتماد');
  String get reject => _get('Reject', 'مسترد کریں', 'رفض');
  String get noteOptional =>
      _get('Note (optional)', 'نوٹ (اختیاری)', 'ملاحظة (اختياري)');
  String get searchUsers => _get(
    'Search by email…',
    'ای میل سے تلاش کریں…',
    'البحث بالبريد الإلكتروني…',
  );
  String get noItems =>
      _get('Nothing here yet.', 'یہاں ابھی کچھ نہیں۔', 'لا يوجد شيء هنا بعد.');
  String get adminOnly => _get(
    'Admin access required.',
    'ایڈمن رسائی درکار ہے۔',
    'يتطلب صلاحية المدير.',
  );
  String get composeBroadcast => _get('New broadcast', 'نیا اعلان', 'بثّ جديد');
  String get sendBroadcast => _get('Send', 'بھیجیں', 'إرسال');
  String get broadcastTitle => _get('Title', 'عنوان', 'العنوان');
  String get broadcastBody => _get('Message', 'پیغام', 'الرسالة');
  String get audience => _get('Audience', 'سامعین', 'الجمهور');
  String get audienceAll => _get('All users', 'تمام صارفین', 'كل المستخدمين');
  String get audienceFree => _get('Free plan', 'مفت پلان', 'الخطة المجانية');
  String get audiencePaid => _get('Paid plans', 'پیڈ پلانز', 'الخطط المدفوعة');
  String get editPlan => _get('Edit plan', 'پلان ایڈٹ کریں', 'تعديل الخطة');
  String get planName => _get('Name', 'نام', 'الاسم');
  String get priceUsd => _get('Price (USD)', 'قیمت (USD)', 'السعر (دولار)');
  String get creditsMonthly => _get(
    'Monthly AI credits',
    'ماہانہ AI کریڈٹ',
    'رصيد الذكاء الاصطناعي الشهري',
  );
  String get campaignsLimit =>
      _get('Campaign limit', 'مہم کی حد', 'حد الحملات');
  String get planActive => _get('Active', 'فعال', 'نشطة');
  String get sortOrder => _get('Sort order', 'ترتیب', 'ترتيب الفرز');
  String get editSetting =>
      _get('Edit setting', 'ترتیب ایڈٹ کریں', 'تعديل الإعداد');
  String get settingValueJson =>
      _get('Value (JSON)', 'ویلیو (JSON)', 'القيمة (JSON)');
  String get saveChanges => _get('Save', 'محفوظ کریں', 'حفظ');
  String get cancel => _get('Cancel', 'منسوخ کریں', 'إلغاء');
  String get done => _get('Done', 'ہو گیا', 'تم');
  String get actionDone => _get('Done', 'ہو گیا', 'تم');
  String get invalidJson => _get(
    'Invalid JSON. Check the syntax and try again.',
    'غلط JSON۔ سِنٹیکس چیک کر کے دوبارہ کوشش کریں۔',
    'JSON غير صالح. تحقق من الصياغة وحاول مجدداً.',
  );

  String componentLabel(String key) => _get(
    const {
          'hook': 'Hook',
          'clarity': 'Clarity',
          'hashtag_hygiene': 'Hashtags',
          'media': 'Media',
          'cta': 'Call to action',
          'language_fit': 'Language fit',
        }[key] ??
        key,
    const {
          'hook': 'ہک',
          'clarity': 'وضاحت',
          'hashtag_hygiene': 'ہیش ٹیگز',
          'media': 'میڈیا',
          'cta': 'کال ٹو ایکشن',
          'language_fit': 'زبان کی مطابقت',
        }[key] ??
        key,
  );

  String get growthEngine =>
      _get('AI Growth Engine', 'AI گروتھ انجن', 'محرك النمو بالذكاء الاصطناعي');
  String get engineTagline => _get(
    'Autonomous analyze → distribute → learn → optimize loop',
    'خودکار تجزیہ → تقسیم → سیکھنے → بہتری کا سلسلہ',
    'حلقة مستقلة: تحليل ← توزيع ← تعلُّم ← تحسين',
  );
  String get engineWhatItDoes => _get(
    'Let the AI grow this post on autopilot',
    'AI کو اس پوسٹ کو خودکار طریقے سے بڑھانے دیں',
    'دع الذكاء الاصطناعي ينمِّي هذا المنشور تلقائياً',
  );
  String get engineWhatItDoesBody => _get(
    'The Growth Engine finds the right audience segments in the Discovery Platform, tries content variations, measures genuine views, saves and dismissals, and shifts distribution toward what real people respond to. Every decision is explained and logged. No fake engagement, ever.',
    'گروتھ انجن ڈسکوری پلیٹ فارم میں صحیح آڈینس تلاش کرتا ہے، مواد کی مختلف صورتیں آزماتا ہے، حقیقی ویوز، سیوز اور مستردیوں کی پیمائش کرتا ہے، اور تقسیم کو اسی طرف موڑتا ہے جس کا حقیقی لوگ جواب دیں۔ ہر فیصلہ واضح اور محفوظ ہوتا ہے۔ کبھی جعلی انگیجمنٹ نہیں۔',
    'يجد محرك النمو شرائح الجمهور المناسبة، ويجرِّب نسخ المحتوى، ويقيس التفاعلات الحقيقية، ويعيد التوزيع نحو الأفضل.',
  );
  String get engineStart => _get(
    'Start AI Growth Engine',
    'AI گروتھ انجن شروع کریں',
    'بدء محرك النمو',
  );
  String get engineStarted =>
      _get('Growth Engine started', 'گروتھ انجن شروع ہو گیا', 'بدأ محرك النمو');
  String get engineSegments =>
      _get('Audience segments', 'آڈینس سیگمنٹس', 'شرائح الجمهور');
  String get engineVariants =>
      _get('Content variants', 'مواد کی مختلف صورتیں', 'نسخ المحتوى');
  String get engineLearnings => _get(
    'What the AI learned',
    'AI نے کیا سیکھا',
    'ما تعلَّمه الذكاء الاصطناعي',
  );
  String get engineAuditTrail => _get('Audit trail', 'آڈٹ ٹریل', 'سجل التدقيق');
  String get engineRound => _get('Round', 'راؤنڈ', 'الجولة');
  String get enginePlacement => _get('Placement', 'پلیسمنٹ', 'الموضع');
  String get engineResume => _get('Resume', 'بحال کریں', 'استئناف');
  String get engineRunRound =>
      _get('Run round now', 'ابھی راؤنڈ چلائیں', 'تشغيل جولة الآن');
  String get engineStop => _get('Stop', 'روکیں', 'إيقاف');
  String get engineStopConfirm => _get(
    'Stop the Growth Engine for this campaign? Distribution and learning will halt.',
    'اس مہم کے لیے گروتھ انجن روک دیں؟ تقسیم اور سیکھنا رک جائے گا۔',
    'إيقاف محرك النمو لهذه الحملة؟ سيتوقف التوزيع والتعلُّم.',
  );
  String get engineStopped =>
      _get('Growth Engine stopped', 'گروتھ انجن رک گیا', 'توقف محرك النمو');
  String get enginePaused => _get(
    'Growth Engine paused',
    'گروتھ انجن موقوف',
    'تم إيقاف محرك النمو مؤقتاً',
  );
  String get engineResumed =>
      _get('Growth Engine resumed', 'گروتھ انجن بحال', 'تم استئناف محرك النمو');
  String get engineRoundDone =>
      _get('Round completed', 'راؤنڈ مکمل', 'اكتملت الجولة');
  String get engineWeight => _get('Weight', 'وزن', 'الوزن');
  String get engineRotation => _get('rotation', 'گردش', 'التناوب');
  String get engineWhy => _get('Why', 'کیوں', 'لماذا');
  String get engineNoLearningsYet => _get(
    'No learnings yet — the first round is still collecting genuine interactions.',
    'ابھی کوئی سیکھ نہیں — پہلا راؤنڈ حقیقی تعاملات جمع کر رہا ہے۔',
    'لا نتائج تعلُّم بعد — الجولة الأولى ما زالت تجمع تفاعلات حقيقية.',
  );
  String get engineDisclaimer => _get(
    'The Growth Engine only measures genuine interactions from real users in the Discovery Platform. Weights and suggestions are heuristic estimates — Virello never guarantees virality, reach, or sales.',
    'گروتھ انجن صرف ڈسکوری پلیٹ فارم کے حقیقی صارفین کے تعاملات کی پیمائش کرتا ہے۔ وزن اور تجاویز تخمینی ہیں — وائرلو کبھی وائرل ہونے، رسائی یا فروخت کی ضمانت نہیں دیتا۔',
    'يقيس محرك النمو التفاعلات الحقيقية فقط من مستخدمين حقيقيين. الأوزان والاقتراحات تقديرات، لا ضمانات.',
  );
  String get aiOptimizedCaption => _get(
    'AI-optimized presentation',
    'AI سے بہتر پیشکش',
    'عرض محسَّن بالذكاء الاصطناعي',
  );

  // AI Ad Builder (Phase 1)
  String get adBuilder => _get(
    'AI Ad Builder',
    'AI اشتہار بلڈر',
    'منشئ الإعلانات بالذكاء الاصطناعي',
  );
  String get adBuilderTagline => _get(
    'Paste a post or link — AI analyzes it, proposes a campaign, and waits for your approval. Nothing launches without you.',
    'پوسٹ یا لنک پیسٹ کریں — AI اس کا تجزیہ کرے گا، مہم تجویز کرے گا اور آپ کی منظوری کا انتظار کرے گا۔ آپ کے بغیر کچھ شروع نہیں ہوگا۔',
    'الصق منشوراً أو رابطاً — يحلِّله الذكاء الاصطناعي ويقترح حملة وينتظر موافقتك. لا يُطلَق شيء بدونك.',
  );
  String get adPasteLabel =>
      _get('Post text or link', 'پوسٹ کا متن یا لنک', 'نص المنشور أو الرابط');
  String get adPasteHint => _get(
    'Paste post text or a public link…',
    'پوسٹ کا متن یا عوامی لنک پیسٹ کریں…',
    'الصق نص المنشور أو رابطاً عاماً…',
  );
  String get adBudgetCap => _get(
    'Budget cap (USD, optional)',
    'بجٹ کی حد (USD، اختیاری)',
    'الحد الأقصى للميزانية (دولار، اختياري)',
  );
  String get adAnalyzeBuild => _get(
    'Analyze & build proposal',
    'تجزیہ کریں اور تجویز بنائیں',
    'حلِّل وابنِ المقترح',
  );
  String get adBuilding => _get(
    'AI is analyzing your content…',
    'AI آپ کے مواد کا تجزیہ کر رہا ہے…',
    'يحلِّل الذكاء الاصطناعي محتواك…',
  );
  String get adAnalysis =>
      _get('AI analysis', 'AI تجزیہ', 'تحليل الذكاء الاصطناعي');
  String get adProposal =>
      _get('Campaign proposal', 'مہم کی تجویز', 'مقترح الحملة');
  String get adSegments =>
      _get('Audience segments', 'سامعین کے حصے', 'شرائح الجمهور');
  String get adReachEstimate =>
      _get('Estimated reach', 'متوقع رسائی', 'الوصول المقدَّر');
  String get adEstimateNote => _get(
    'Estimate — not a guarantee. Real results depend on content, delivery, and budget.',
    'تخمینہ — ضمانت نہیں۔ اصل نتائج مواد، ترسیل اور بجٹ پر منحصر ہیں۔',
    'تقدير — ليس ضماناً. تعتمد النتائج الحقيقية على المحتوى والتوزيع والميزانية.',
  );
  String get adObjective => _get('Objective', 'مقصد', 'الهدف');
  String get adDuration => _get('Duration (days)', 'مدت (دن)', 'المدة (أيام)');
  String get adBudget => _get('Budget (USD)', 'بجٹ (USD)', 'الميزانية (دولار)');
  String get adSubmitApproval =>
      _get('Submit for approval', 'منظوری کے لیے جمع کریں', 'إرسال للاعتماد');
  String get adApprove =>
      _get('Approve campaign', 'مہم منظور کریں', 'اعتماد الحملة');
  String get adReject => _get('Reject', 'مسترد کریں', 'رفض');
  String get adApprovedToast =>
      _get('Campaign approved ✓', 'مہم منظور ہو گئی ✓', 'تم اعتماد الحملة ✓');
  String get adSubmittedToast => _get(
    'Submitted for approval ✓',
    'منظوری کے لیے جمع ہو گیا ✓',
    'أُرسل للاعتماد ✓',
  );
  String get adRejectedToast =>
      _get('Campaign rejected', 'مہم مسترد ہو گئی', 'رُفضت الحملة');
  String get adStatusDraft => _get('Draft', 'مسودہ', 'مسودة');
  String get adStatusPending =>
      _get('Pending approval', 'منظوری زیر التواء', 'بانتظار الاعتماد');
  String get adStatusApproved => _get('Approved', 'منظور شدہ', 'معتمدة');
  String get adStatusRejected => _get('Rejected', 'مسترد شدہ', 'مرفوضة');
  String get adWhyThisSegment =>
      _get('Why this segment?', 'یہ حصہ کیوں؟', 'لماذا هذه الشريحة؟');
  String get adHeuristicNote => _get(
    'Heuristic proposal — no AI provider is configured yet.',
    'تخمینی تجویز — ابھی کوئی AI فراہم کنندہ منسلک نہیں۔',
    'مقترح تقريبي — لم يتم ربط مزوِّد ذكاء اصطناعي بعد.',
  );
  String get adAiNote => _get(
    'Proposed with AI assistance — review before approving.',
    'AI کی مدد سے تجویز کردہ — منظور کرنے سے پہلے جائزہ لیں۔',
    'مقترح بمساعدة الذكاء الاصطناعي — راجعه قبل الاعتماد.',
  );
  String get adMyCampaigns =>
      _get('My ad campaigns', 'میری اشتہاری مہمات', 'حملاتي الإعلانية');
  String get adNewCampaign =>
      _get('New ad campaign', 'نئی اشتہاری مہم', 'حملة إعلانية جديدة');
  String get adNoCampaigns => _get(
    'No ad campaigns yet. Build your first one.',
    'ابھی کوئی اشتہاری مہم نہیں۔ اپنی پہلی مہم بنائیں۔',
    'لا حملات إعلانية بعد. ابنِ أول حملة لك.',
  );
  String get adBuildFailed => _get(
    'Could not build the campaign. Try again.',
    'مہم نہیں بن سکی۔ دوبارہ کوشش کریں۔',
    'تعذَّر بناء الحملة. حاول مجدداً.',
  );

  // AI Ads — Phase 2: Sponsored Discovery
  String get sponsored => _get('Sponsored', 'مشتہر', 'إعلان مموَّل');
  String get sponsoredNote => _get(
    'Paid placement — clearly labeled. Delivery is measured from genuine events only.',
    'معاوضہ جگہ — واضح طور پر نشان زد۔ ترسیل صرف حقیقی واقعات سے ماپی جاتی ہے۔',
    'موضع مدفوع — موسوم بوضوح. يُقاس التوزيع من الأحداث الحقيقية فقط.',
  );
  String get adLaunch =>
      _get('Launch campaign', 'مہم شروع کریں', 'إطلاق الحملة');
  String get adPause =>
      _get('Pause delivery', 'ترسیل روکیں', 'إيقاف التوزيع مؤقتاً');
  String get adResume =>
      _get('Resume delivery', 'ترسیل بحال کریں', 'استئناف التوزيع');
  String get adLaunchedToast => _get(
    'Campaign launched — now delivering ✓',
    'مہم شروع ہو گئی — اب ترسیل جاری ہے ✓',
    'انطلقت الحملة — التوزيع جارٍ الآن ✓',
  );
  String get adPausedToast =>
      _get('Delivery paused', 'ترسیل روک دی گئی', 'تم إيقاف التوزيع مؤقتاً');
  String get adResumedToast =>
      _get('Delivery resumed', 'ترسیل بحال ہو گئی', 'تم استئناف التوزيع');
  String get adStatusActive => _get('Active', 'فعال', 'نشطة');
  String get adStatusPaused => _get('Paused', 'روکی ہوئی', 'موقوفة مؤقتاً');
  String get adStatusCompleted => _get('Completed', 'مکمل', 'مكتملة');
  String get adDelivery => _get('Delivery', 'ترسیل', 'التوزيع');
  String get adSpend => _get('Spend', 'خرچ', 'الإنفاق');
  String get adImpressions => _get('Impressions', 'نمایاں', 'مرات الظهور');
  String get adPacing => _get('Daily pacing', 'روزانہ رفتار', 'الإيقاع اليومي');
  String get adOnPace => _get('On pace', 'رفتار پر', 'ضمن الإيقاع');
  String get adOverPace =>
      _get('Daily limit reached', 'روزانہ حد پوری', 'تم بلوغ الحد اليومي');
  String get adWhySponsored => _get(
    'Why am I seeing this?',
    'یہ مجھے کیوں دکھ رہا ہے؟',
    'لماذا أرى هذا؟',
  );
  String get adSimulatedNote => _get(
    'Simulated accounting from genuine events — not real money movement.',
    'حقیقی واقعات سے تخمینی حساب — اصل رقم کی منتقلی نہیں۔',
    'محاسبة تقديرية من أحداث حقيقية — ليست حركة أموال فعلية.',
  );
  // Phase 3: AI Distribution & Optimization Agent.
  String get adOptimization =>
      _get('AI Optimization', 'AI اصلاح', 'تحسين الذكاء الاصطناعي');
  String get adOptimizeNow =>
      _get('Optimize now', 'ابھی اصلاح کریں', 'حسِّن الآن');
  String get adOptimizing => _get(
    'AI is analyzing measured performance…',
    'AI ماپی گئی کارکردگی کا تجزیہ کر رہا ہے…',
    'يحلِّل الذكاء الاصطناعي الأداء المقاس…',
  );
  String get adOptimizedToast =>
      _get('Optimization complete ✓', 'اصلاح مکمل ✓', 'اكتمل التحسين ✓');
  String get adOptimizeFailed => _get(
    'Optimization failed. Try again.',
    'اصلاح ناکام ہوئی۔ دوبارہ کوشش کریں۔',
    'فشل التحسين. حاول مجدداً.',
  );
  String get adLatestRun =>
      _get('Latest optimization run', 'تازہ ترین اصلاح', 'آخر عملية تحسين');
  String get adNoRunsYet => _get(
    'No optimization runs yet. Run the AI optimizer to learn from genuine events.',
    'ابھی کوئی اصلاح نہیں ہوئی۔ حقیقی واقعات سے سیکھنے کے لیے AI اصلاح چلائیں۔',
    'لا عمليات تحسين بعد. شغِّل المحسِّن للتعلُّم من الأحداث الحقيقية.',
  );
  String get adSafetyPausedNote => _get(
    'Safety pause: suspicious traffic was detected, so delivery stopped automatically. An admin must review it before delivery resumes.',
    'حفاظتی روک: مشکوک ٹریفک پائی گئی، اس لیے ترسیل خودکار طور پر رک گئی۔ بحالی سے پہلے ایڈمن کو جائزہ لینا ہوگا۔',
    'إيقاف احترازي: رُصدت حركة مشبوهة فتوقف التوزيع تلقائياً. يجب أن يراجعه مدير قبل استئناف التوزيع.',
  );
  String get adSegmentPerformance =>
      _get('Segment performance', 'حصوں کی کارکردگی', 'أداء الشرائح');
  String get adVariantPerformance =>
      _get('Creative variants', 'تخلیقی اقسام', 'النسخ الإبداعية');
  String get adPlacementPerformance => _get('Placements', 'مقامات', 'المواضع');
  String get adDecisionFeed => _get(
    'Why the AI changed things',
    'AI نے تبدیلیاں کیوں کیں',
    'لماذا غيَّر الذكاء الاصطناعي الأمور',
  );
  String get adInsufficientData => _get(
    'Too little data to judge yet',
    'جائزے کے لیے ابھی ڈیٹا ناکافی ہے',
    'البيانات قليلة جداً للحكم بعد',
  );
  String get adWeight => _get('Weight', 'وزن', 'الوزن');
  String get adEngagementRate =>
      _get('Engagement rate', 'مشغولیت کی شرح', 'معدل التفاعل');
  String get adOptimizeNote => _get(
    'Measured from genuine events only. The optimizer never raises your budget — it only reweights distribution.',
    'صرف حقیقی واقعات سے ماپا گیا۔ اصلاح آپ کا بجٹ کبھی نہیں بڑھاتا — صرف ترسیل کی تقسیم بدلتا ہے۔',
    'يُقاس من الأحداث الحقيقية فقط. لا يرفع المحسِّن ميزانيتك أبداً — بل يعيد توزيع الأوزان فقط.',
  );
  // Phase 4: Conversion Attribution.
  String get adDashboard =>
      _get('Attribution dashboard', 'انتساب ڈیش بورڈ', 'لوحة الانتساب');
  String get adReach => _get('Reach', 'رسائی', 'الوصول');
  String get adViews => _get('Views', 'ویوز', 'المشاهدات');
  String get adEngagement => _get('Engagement', 'مشغولیت', 'التفاعل');
  String get adFollowersGained =>
      _get('Followers gained', 'نئے فالوورز', 'متابعون جدد');
  String get adClicks => _get('Clicks', 'کلکس', 'النقرات');
  String get adLeads => _get('Leads', 'لیڈز', 'العملاء المحتملون');
  String get adConversions => _get('Conversions', 'کنورژنز', 'التحويلات');
  String get adCostPerResult =>
      _get('Cost per result', 'فی نتیجہ لاگت', 'التكلفة لكل نتيجة');
  String get adAttrRevenue =>
      _get('Attributable revenue', 'منسوب آمدنی', 'الإيرادات المنسوبة');
  String get adMeasured => _get('Measured', 'ماپا گیا', 'مقاس');
  String get adEstimate => _get('Estimate', 'تخمینہ', 'تقدير');
  String get adLastClick => _get(
    'Last-click attribution — each conversion is credited to the ad tap that preceded it.',
    'آخری کلک انتساب — ہر کنورژن اس اشتہاری کلک کو دیا جاتا ہے جو اس سے پہلے ہوا۔',
    'انتساب النقرة الأخيرة — يُنسَب كل تحويل إلى نقرة الإعلان التي سبقته.',
  );
  String get adRevenueNote => _get(
    'Revenue is advertiser-reported / measured from their pixel, webhook, or API — not platform-verified sales.',
    'آمدنی مشتہر کی رپورٹ کردہ / ماپی گئی ہے (پکسل، ویب ہک یا API سے) — پلیٹفارم سے تصدیق شدہ فروخت نہیں۔',
    'الإيرادات مُبلَّغ عنها من المعلن / مقاسة من البكسل أو الويبهوك — ليست مبيعات موثَّقة من المنصة.',
  );
  // Audience Intelligence Engine (multi-source).
  String get audienceIntel =>
      _get('Audience Intelligence', 'آڈینس انٹیلی جنس', 'ذكاء الجمهور');
  String get aiSources => _get('Sources', 'ذرائع', 'المصادر');
  String get aiSegments => _get('Segments', 'طبقات', 'الشرائح');
  String get aiFingerprint => _get('Fingerprint', 'فنگر پرنٹ', 'البصمة');
  String get aiSourceStatusReady => _get('Ready', 'تیار', 'جاهز');
  String get aiSourceStatusNotConfigured =>
      _get('Not configured', 'ترتیب نہیں', 'غير مُعَدّ');
  String get aiSourceStatusDegraded => _get('Degraded', 'متاثر', 'متدهور');
  String get aiNoFakeData => _get(
    'Unconfigured sources return no data \u2014 never synthetic.',
    'غیر ترتیب شدہ ذرائع کوئی ڈیٹا نہیں دیتے \u2014 کبھی مصنوعی نہیں۔',
    'المصادر غير المُعَدَّة لا تُرجع بيانات — أبداً بيانات اصطناعية.',
  );
  String get aiVolumeUnavailable =>
      _get('Volume unavailable', 'حجم دستیاب نہیں', 'الحجم غير متاح');
  String get aiConfidence => _get('Confidence', 'اعتماد', 'الثقة');
  String get aiSegmentPath => _get('Path', 'راستہ', 'المسار');
  String get aiSourceBreakdown =>
      _get('Source breakdown', 'ذرائع کی تفصیل', 'تفصيل المصادر');
  String get aiAnalyzePost => _get(
    'Analyze post for audience fit',
    'آڈینس مطابقت کے لیے پوسٹ کا تجزیہ کریں',
    'تحليل المنشور لملاءمة الجمهور',
  );
  String get aiPastePostHint => _get(
    'Paste post text or a link\u2026',
    'پوسٹ کا متن یا لنک پیسٹ کریں\u2026',
    'الصق نص المنشور أو رابطاً…',
  );
  String get aiNoMatch => _get(
    'No strong segment matches yet.',
    'ابھی کوئی مضبوط مطابقت نہیں۔',
    'لا مطابقات قوية للشرائح بعد.',
  );
  String get aiFitScore => _get('Fit score', 'مطابقت اسکور', 'درجة الملاءمة');
  String get aiRelevanceFitNote => _get(
    'Relevance fit \u2014 not a reach or virality guarantee.',
    'مطابقت کا اندازہ \u2014 رسائی یا وائرلٹی کی ضمانت نہیں۔',
    'ملاءمة الصلة — ليست ضماناً للوصول أو الانتشار.',
  );
  String get aiWhyThis =>
      _get('Why this segment', 'یہ طبقہ کیوں', 'لماذا هذه الشريحة');

  // Multilingual language layer
  String get langSettings => _get('Language', 'زبان', 'اللغة');
  String get langUiLanguage =>
      _get('App language', 'ایپ کی زبان', 'لغة التطبيق');
  String get langUiFullNote =>
      _get('Full interface', 'مکمل انٹرفیس', 'واجهة كاملة');
  String get langUiPartialNote => _get(
    'Interface not fully translated yet — content languages fully supported.',
    'انٹرفیس ابھی مکمل ترجمہ نہیں — مواد کی زبانیں مکمل معاون ہیں۔',
    'الواجهة غير مترجمة بالكامل بعد — لغات المحتوى مدعومة بالكامل.',
  );
  String get langContentLanguages =>
      _get('Content languages', 'مواد کی زبانیں', 'لغات المحتوى');
  String get langPreferred =>
      _get('Preferred language', 'ترجیحی زبان', 'اللغة المفضلة');
  String get langAllRelevant => _get(
    'All relevant languages',
    'تمام متعلقہ زبانیں',
    'كل اللغات ذات الصلة',
  );
  String get langAllRelevantDesc => _get(
    'Let AI match content across every supported language.',
    'AI کو ہر معاون زبان میں مواد ملانے دیں۔',
    'دع الذكاء الاصطناعي يطابق المحتوى عبر كل اللغات المدعومة.',
  );
  String get langOriginal =>
      _get('Original language', 'اصل زبان', 'اللغة الأصلية');
  String get langUncertain =>
      _get('Language uncertain', 'زبان غیر یقینی', 'اللغة غير مؤكدة');
  String get langMixed =>
      _get('Mixed languages', 'مخلوط زبانیں', 'لغات مختلطة');
  String get langTransliterated =>
      _get('Romanized text', 'رومن متن', 'نص مُحوَّل');
  String get langSuggested => _get(
    'Suggested language audiences',
    'تجویز کردہ زبانیں',
    'جماهير لغات مقترحة',
  );
  String get langSuggestedDesc => _get(
    'AI suggests extra language audiences — suggestions only, never guarantees.',
    'AI اضافی زبانوں کے سامعین تجویز کرتا ہے — صرف تجاویز، کبھی ضمانت نہیں۔',
    'يقترح الذكاء الاصطناعي جماهير لغات إضافية — اقتراحات فقط، لا ضمانات أبداً.',
  );
  String get langWhySuggested =>
      _get('Why suggested?', 'تجویز کیوں؟', 'لماذا تُقترَح؟');
  String get langTargetingMode =>
      _get('Language targeting', 'زبان کا ہدف', 'استهداف اللغة');
  String get langModeSingle => _get('Single language', 'ایک زبان', 'لغة واحدة');
  String get langModeMultiple =>
      _get('Multiple languages', 'متعدد زبانیں', 'لغات متعددة');
  String get langModeAllRelevant =>
      _get('All relevant', 'تمام متعلقہ', 'كل ذات الصلة');
  String get langSelectLanguages =>
      _get('Select languages', 'زبانیں منتخب کریں', 'اختر اللغات');
  String get langByLanguage =>
      _get('By language', 'زبان کے لحاظ سے', 'حسب اللغة');
  String get langUnrecorded =>
      _get('Unrecorded', 'غیر ریکارڈ شدہ', 'غير مسجَّلة');
  String get langFallbackNote => _get(
    'No translation yet — shown in English.',
    'ابھی ترجمہ نہیں — انگریزی میں دکھایا گیا۔',
    'لا توجد ترجمة بعد — يُعرض بالإنجليزية.',
  );
  String get langSearchLanguages =>
      _get('Search languages…', 'زبانیں تلاش کریں…', 'ابحث عن اللغات…');
  String get notifications => _get('Notifications', 'اطلاعات', 'الإشعارات');
  String get noNotifications =>
      _get('No notifications yet.', 'ابھی کوئی اطلاع نہیں۔', 'لا إشعارات بعد.');

  // ---- Approved 10-screen board (2026-09-26) ----
  String get splashTagline => _get(
    'Create • Discover • Grow',
    'تخلیق • دریافت • گرو',
    'أنشئ • اكتشف • نمِّ',
  );
  String get splashHeadline => _get(
    'Turn Your Content Into Real Growth',
    'اپنے مواد کو حقیقی گروتھ میں بدلیں',
    'حوِّل محتواك إلى نموٍّ حقيقي',
  );
  String get splashSub => _get(
    'AI-powered discovery & advertising platform for creators, businesses and brands.',
    'تخلیق کاروں، کاروباروں اور برانڈز کے لیے AI سے چلنے والا ڈسکوری اور اشتہاری پلیٹ فارم۔',
    'منصة اكتشاف وإعلان بالذكاء الاصطناعي للمبدعين والشركات والعلامات التجارية.',
  );
  String get getStarted => _get('Get Started', 'شروع کریں', 'ابدأ');
  String get alreadyHaveAccount => _get(
    'I already have an account',
    'میرا اکاؤنٹ پہلے سے موجود ہے',
    'لديّ حساب بالفعل',
  );
  String get forYou => _get('For You', 'آپ کے لیے', 'لك');
  String get trending => _get('Trending', 'ٹرینڈنگ', 'الرائج');
  String get following => _get('Following', 'فالونگ', 'المتابَعون');
  String get aiPicks =>
      _get('AI Picks', 'AI انتخاب', 'اختيارات الذكاء الاصطناعي');
  String get searchAnything =>
      _get('Search anything…', 'کچھ بھی تلاش کریں…', 'ابحث عن أي شيء…');
  String get exploreTopics =>
      _get('Explore Topics', 'موضوعات دیکھیں', 'استكشف المواضيع');
  String get trendingNow => _get('Trending Now', 'ابھی ٹرینڈنگ', 'الرائج الآن');
  String get popularLanguages =>
      _get('Popular Languages', 'مقبول زبانیں', 'لغات شائعة');
  String get aiRecommendedForYou => _get(
    'AI Recommended For You',
    'AI کی تجویز — آپ کے لیے',
    'موصى به لك بالذكاء الاصطناعي',
  );
  String get seeAll => _get('See all', 'سب دیکھیں', 'عرض الكل');
  String postsCount(int n) => _get('$n posts', '$n پوسٹس', '$n منشورات');
  String get whatToDoToday => _get(
    'What would you like to do today?',
    'آج آپ کیا کرنا چاہیں گے؟',
    'ماذا تريد أن تفعل اليوم؟',
  );
  String get analyzePost =>
      _get('Analyze Post', 'پوسٹ کا تجزیہ', 'تحليل المنشور');
  String get analyzePostDesc => _get(
    'Paste a link and let AI analyze it',
    'لنک پیسٹ کریں اور AI سے تجزیہ کروائیں',
    'الصق رابطاً ودع الذكاء الاصطناعي يحلِّله',
  );
  String get uploadContent =>
      _get('Upload Content', 'مواد اپ لوڈ کریں', 'رفع المحتوى');
  String get uploadContentDesc => _get(
    'Add your photo, video or file',
    'اپنی تصویر، ویڈیو یا فائل شامل کریں',
    'أضف صورتك أو مقطعك أو ملفك',
  );
  String get findAudience =>
      _get('Find Audience', 'سامعین تلاش کریں', 'اعثر على الجمهور');
  String get findAudienceDesc => _get(
    'Discover the right audience',
    'صحیح سامعین دریافت کریں',
    'اكتشف الجمهور المناسب',
  );
  String get promoteWithAI =>
      _get('Promote with AI', 'AI سے پروموٹ کریں', 'روِّج بالذكاء الاصطناعي');
  String get promoteWithAIDesc => _get(
    'Create a campaign in seconds',
    'سیکنڈوں میں مہم بنائیں',
    'أنشئ حملة في ثوانٍ',
  );
  String get letAiGrowContent => _get(
    'Let AI Grow Your Content',
    'AI سے اپنا مواد بڑھوائیں',
    'دع الذكاء الاصطناعي ينمِّي محتواك',
  );
  String get letAiGrowContentDesc => _get(
    'Smart analysis • Right audience • Better results',
    'ذہین تجزیہ • صحیح سامعین • بہتر نتائج',
    'تحليل ذكي • جمهور مناسب • نتائج أفضل',
  );
  String get uploadComingSoon => _get(
    'Photo & video upload is coming in the next release — analyze a link for now.',
    'تصویر اور ویڈیو اپ لوڈ اگلی ریلیز میں آ رہا ہے — فی الحال لنک کا تجزیہ کریں۔',
    'رفع الصور والفيديو قادم في الإصدار التالي — حلِّل رابطاً الآن.',
  );
  String get analyzeLinkInstead => _get(
    'Analyze a link instead',
    'اس کے بجائے لنک کا تجزیہ کریں',
    'حلِّل رابطاً بدلاً من ذلك',
  );
  // --- Upload Studio ---
  String get uploadStudio =>
      _get('Upload Studio', 'اپ لوڈ اسٹوڈیو', 'استوديو الرفع');
  String get pickFromPhone =>
      _get('Pick from phone', 'فون سے منتخب کریں', 'اختر من الهاتف');
  String get pickFileHint => _get(
    'Photo, video, audio or document — up to 50 MB',
    'تصویر، ویڈیو، آڈیو یا دستاویز — 50 MB تک',
    'صورة أو فيديو أو صوت أو مستند — حتى 50 م.ب',
  );
  String get uploading =>
      _get('Uploading…', 'اپ لوڈ ہو رہا ہے…', 'جارٍ الرفع…');
  String get uploadFailed =>
      _get('Upload failed', 'اپ لوڈ ناکام ہوا', 'فشل الرفع');
  String get tryAgain => _get('Try again', 'دوبارہ کوشش کریں', 'حاول مجدداً');
  String get uploadedOk => _get('Uploaded', 'اپ لوڈ ہو گیا', 'تم الرفع');
  String get addCaption => _get('Add a caption', 'کیپشن لکھیں', 'أضف تعليقاً');
  String get captionHint => _get(
    'What is this about? Add 2–4 hashtags…',
    'یہ کس بارے میں ہے؟ 2–4 ہیش ٹیگز شامل کریں…',
    'ما موضوع هذا؟ أضف 2–4 وسوم…',
  );
  String get aiCheck => _get('AI Check', 'AI چیک', 'فحص الذكاء الاصطناعي');
  String get checking => _get('Checking…', 'چیک ہو رہا ہے…', 'جارٍ الفحص…');
  String get growThisContent =>
      _get('Grow this content', 'اس مواد کو بڑھوائیں', 'نمِّ هذا المحتوى');
  String get recommendations => _get('Recommendations', 'تجاویز', 'توصيات');
  String get readinessChecklist =>
      _get('Readiness checklist', 'تیاری کی چیک لسٹ', 'قائمة الجاهزية');
  String get heuristicNote => _get(
    'Heuristic estimate — not a guarantee',
    'تخمینی جائزہ — ضمانت نہیں',
    'تقدير تقريبي — ليس ضماناً',
  );
  String get aiAnalyzePostTitle => _get(
    'AI Analyze Post',
    'AI پوسٹ تجزیہ',
    'تحليل المنشور بالذكاء الاصطناعي',
  );
  String get nextAudienceInsights => _get(
    'Next: Audience Insights',
    'اگلا: آڈینس انسائٹس',
    'التالي: رؤى الجمهور',
  );
  String get nextCampaignSetup =>
      _get('Next: Campaign Setup', 'اگلا: مہم سیٹ اپ', 'التالي: إعداد الحملة');
  String get audienceInsights =>
      _get('Audience Insights', 'آڈینس انسائٹس', 'رؤى الجمهور');
  String get recommendedAudience =>
      _get('Recommended Audience', 'تجویز کردہ سامعین', 'الجمهور الموصى به');
  String get audienceBreakdown =>
      _get('Audience Breakdown', 'سامعین کی تفصیل', 'تفصيل الجمهور');
  String get whyThisAudience =>
      _get('Why this audience?', 'یہ سامعین کیوں؟', 'لماذا هذا الجمهور؟');
  String get whyThisAudienceBody => _get(
    'Based on trending interest, search patterns and similar audience behavior.',
    'ٹرینڈنگ دلچسپی، تلاش کے رجحانات اور ملتے جلتے سامعین کے رویے کی بنیاد پر۔',
    'بناءً على الاهتمامات الرائجة وأنماط البحث وسلوك الجماهير المشابهة.',
  );
  String get aiMatched =>
      _get('AI Matched', 'AI میچڈ', 'مطابق بالذكاء الاصطناعي');
  String get virelloAudience =>
      _get('Virello Audience', 'وائرلو آڈینس', 'جمهور Virello');
  String get noAudienceMatches => _get(
    'No strong audience matches yet — try a different post or link.',
    'ابھی کوئی مضبوط سامعین کی مطابقت نہیں — کوئی اور پوسٹ یا لنک آزمائیں۔',
    'لا مطابقات قوية للجمهور بعد — جرِّب منشوراً أو رابطاً آخر.',
  );
  String get objective => _get('Objective', 'مقصد', 'الهدف');
  String get salesObj => _get('Sales', 'فروخت', 'المبيعات');
  String get salesObjDesc =>
      _get('Drive purchases', 'خریداری بڑھائیں', 'زيادة المشتريات');
  String get leadsObj => _get('Leads', 'لیڈز', 'العملاء المحتملون');
  String get leadsObjDesc => _get(
    'Get customer details',
    'گاہک کی تفصیلات حاصل کریں',
    'احصل على بيانات العملاء',
  );
  String get engagementObj => _get('Engagement', 'مشغولیت', 'التفاعل');
  String get engagementObjDesc => _get(
    'More likes & comments',
    'زیادہ لائکس اور کمنٹس',
    'مزيد من الإعجابات والتعليقات',
  );
  String get followersObj => _get('Followers', 'فالوورز', 'المتابعون');
  String get followersObjDesc =>
      _get('Grow your audience', 'اپنے سامعین بڑھائیں', 'نمِّ جمهورك');
  String get targetAudience =>
      _get('Target Audience', 'ہدف سامعین', 'الجمهور المستهدف');
  String get aiRecommended =>
      _get('AI Recommended', 'AI تجویز کردہ', 'موصى به بالذكاء الاصطناعي');
  String get duration => _get('Duration', 'مدت', 'المدة');
  String get day1 => _get('1 Day', '1 دن', 'يوم واحد');
  String get day3 => _get('3 Days', '3 دن', '3 أيام');
  String get day7 => _get('7 Days', '7 دن', '7 أيام');
  String get day14 => _get('14 Days', '14 دن', '14 يوماً');
  String get dailyBudget =>
      _get('Daily Budget', 'روزانہ بجٹ', 'الميزانية اليومية');
  String get reviewAndLaunch =>
      _get('Review & Launch', 'جائزہ اور لانچ', 'مراجعة وإطلاق');
  String get budgetNeverExceeded => _get(
    'AI will never exceed your approved budget.',
    'AI آپ کے منظور شدہ بجٹ سے کبھی تجاوز نہیں کرے گا۔',
    'لن يتجاوز الذكاء الاصطناعي ميزانيتك المعتمدة أبداً.',
  );
  String get aiGrowthAgent =>
      _get('AI Growth Agent', 'AI گروتھ ایجنٹ', 'وكيل النمو بالذكاء الاصطناعي');
  String get working => _get('Working…', 'کام جاری…', 'جارٍ العمل…');
  String get estimatedReach =>
      _get('Estimated Reach', 'متوقع رسائی', 'الوصول المقدَّر');
  String get estimatedEngagement =>
      _get('Estimated Engagement', 'متوقع مشغولیت', 'التفاعل المقدَّر');
  String get usuallyTakes => _get(
    'This usually takes 2–5 minutes',
    'اس میں عام طور پر 2–5 منٹ لگتے ہیں',
    'يستغرق هذا عادة 2–5 دقائق',
  );
  String get totalReach => _get('Total Reach', 'کل رسائی', 'إجمالي الوصول');
  String get totalViews => _get('Total Views', 'کل ویوز', 'إجمالي المشاهدات');
  String get totalSales => _get('Total Sales', 'کل فروخت', 'إجمالي المبيعات');
  String get activeT => _get('Active', 'فعال', 'نشطة');
  String get completedT => _get('Completed', 'مکمل', 'مكتملة');
  String get draftsT => _get('Drafts', 'مسودے', 'مسودات');
  String daysLeft(int n) => _get('$n days left', '$n دن باقی', 'متبقٍ $n أيام');
  String get myInterests => _get('My Interests', 'میری دلچسپیاں', 'اهتماماتي');
  String get savedCollections =>
      _get('Saved Collections', 'محفوظ مجموعے', 'مجموعات محفوظة');
  String get editProfile =>
      _get('Edit Profile', 'پروفائل ایڈٹ کریں', 'تعديل الملف');
  String get postsStat => _get('Posts', 'پوسٹس', 'المنشورات');
  String get followersStat => _get('Followers', 'فالوورز', 'المتابعون');
  String get followingStat => _get('Following', 'فالونگ', 'يتابع');
  String itemsCount(int n) => _get('$n items', '$n آئٹمز', '$n عناصر');
  String get smartContent => _get('Smart Content', 'ذہین مواد', 'محتوى ذكي');
  String get rightAudience =>
      _get('Right Audience', 'صحیح سامعین', 'الجمهور المناسب');
  String get realGrowth => _get('Real Growth', 'حقیقی گروتھ', 'نمو حقيقي');
  String get aiPoweredIntelligence => _get(
    'AI Powered Intelligence',
    'AI سے چلنے والی ذہانت',
    'ذكاء مدعوم بالذكاء الاصطناعي',
  );
  String get globalAudience =>
      _get('Global Audience', 'عالمی سامعین', 'جمهور عالمي');
  String get multiLanguageSupport =>
      _get('Multi-Language Support', 'کثیر لسانی معاونت', 'دعم متعدد اللغات');
  String get secureTransparent =>
      _get('Secure & Transparent', 'محفوظ اور شفاف', 'آمن وشفاف');
  String get stepAnalyzing =>
      _get('Analyzing content', 'مواد کا تجزیہ', 'تحليل المحتوى');
  String get stepUnderstanding => _get(
    'Understanding product & intent',
    'پروڈکٹ اور مقصد کو سمجھنا',
    'فهم المنتج والنية',
  );
  String get stepFinding => _get(
    'Finding audience segments',
    'سامعین کے حصے تلاش کرنا',
    'إيجاد شرائح الجمهور',
  );
  String get stepMatching => _get(
    'Matching languages & interests',
    'زبانیں اور دلچسپیاں ملانا',
    'مطابقة اللغات والاهتمامات',
  );
  String get stepPlacing => _get(
    'Choosing best placements',
    'بہترین جگہوں کا انتخاب',
    'اختيار أفضل المواضع',
  );
  String get stepLaunching =>
      _get('Launching campaign', 'مہم لانچ کرنا', 'إطلاق الحملة');
  String get stepMonitoring =>
      _get('Monitoring & optimizing', 'نگرانی اور بہتری', 'المراقبة والتحسين');
  String get pendingLabel =>
      _get('(pending)', '(زیر التواء)', '(قيد الانتظار)');
  String get createTitle => _get('Create', 'تخلیق', 'أنشئ');
  String get viewCampaign => _get('View Campaign', 'مہم دیکھیں', 'عرض الحملة');
  String get topMatches => _get('Top matches', 'بہترین میچز', 'أفضل المطابقات');
  String get rankedByScore => _get(
    'Ranked by match score',
    'میچ اسکور کے لحاظ سے ترتیب',
    'مرتَّبة حسب درجة المطابقة',
  );
  String get followingSoon => _get(
    'Creator follows are coming soon — save items to build your list.',
    'تخلیق کار فالو جلد آ رہا ہے — اپنی فہرست کے لیے آئٹمز محفوظ کریں۔',
    'متابعة المبدعين قادمة قريباً — احفظ العناصر لبناء قائمتك.',
  );
  String get analyticsMenu => _get('Analytics', 'تجزیات', 'التحليلات');
  String get settingsMenu => _get('Settings', 'ترتیبات', 'الإعدادات');
  String get billingTitle => _get(
    'Billing & subscriptions',
    'بلنگ اور سبسکرپشنز',
    'الفوترة والاشتراكات',
  );
  String get aiSupport =>
      _get('AI Support', 'AI معاونت', 'دعم الذكاء الاصطناعي');
  String get howVirelloGrows => _get(
    'How Virello grows you',
    'وائرلو آپ کو کیسے بڑھاتا ہے',
    'كيف ينمِّيك Virello',
  );
  String get whatWeNeverDo =>
      _get('What we never do', 'ہم کیا کبھی نہیں کرتے', 'ما لا نفعله أبداً');
  String get aiSupportSoon => _get(
    'AI Support is coming soon.',
    'AI معاونت جلد آ رہی ہے۔',
    'دعم الذكاء الاصطناعي قادم قريباً.',
  );
  String get neverDoList => _get(
    'No fake followers, likes, views or comments.\nNo bots or automation on your accounts.\nNo password access — official connections only.\nNo guaranteed virality, reach or sales.',
    'کوئی جعلی فالوورز، لائکس، ویوز یا تبصرے نہیں۔\nآپ کے اکاؤنٹس پر کوئی بوٹس یا آٹومیشن نہیں۔\nپاس ورڈ تک رسائی نہیں — صرف سرکاری کنکشن۔\nوائرل ہونے، رسائی یا فروخت کی کوئی ضمانت نہیں۔',
    'لا متابعين أو إعجابات أو مشاهدات أو تعليقات مزيَّفة.\nلا روبوتات أو أتمتة على حساباتك.\nلا وصول لكلمات المرور — اتصالات رسمية فقط.\nلا ضمان للانتشار أو الوصول أو المبيعات.',
  );
  String get geoTitle => _get(
    'Audience geography',
    'آڈینس کی جغرافیائی حدود',
    'النطاق الجغرافي للجمهور',
  );
  String get geoAiRecommended =>
      _get('AI Recommended', 'AI تجویز کردہ', 'موصى به من الذكاء الاصطناعي');
  String get geoAiRecommendedDesc => _get(
    'AI picks countries from your post\'s language and topic',
    'AI آپ کی پوسٹ کی زبان اور موضوع سے ممالک چنتا ہے',
    'يختار الذكاء الاصطناعي الدول من لغة منشورك وموضوعه',
  );
  String get geoWorldwide => _get('Worldwide', 'دنیا بھر', 'جميع أنحاء العالم');
  String get geoWorldwideDesc => _get(
    'Deliver everywhere — maximum reach',
    'ہر جگہ ڈیلیور کریں — زیادہ سے زیادہ رسائی',
    'التوصيل في كل مكان — أقصى وصول',
  );
  String get geoCustom =>
      _get('Choose countries', 'ممالک منتخب کریں', 'اختيار الدول');
  String get geoCustomDesc => _get(
    'Pick specific countries yourself',
    'خود مخصوص ممالک چنیں',
    'اختر دولاً محددة بنفسك',
  );
  String get geoQuickRegions =>
      _get('Quick regions', 'فوری علاقے', 'مناطق سريعة');
  String get geoSearchCountries =>
      _get('Search countries…', 'ممالک تلاش کریں…', 'ابحث عن الدول…');
  String get geoWhyThese =>
      _get('Why these countries?', 'یہ ممالک کیوں؟', 'لماذا هذه الدول؟');
  String geoCountriesSelected(int n) =>
      _get('$n selected', '$n منتخب', 'تم اختيار $n');
  String get geoNeedCountry => _get(
    'Select at least one country',
    'کم از کم ایک ملک منتخب کریں',
    'اختر دولة واحدة على الأقل',
  );
  String get geoAiNote => _get(
    'AI suggestion — you approve the final list',
    'AI تجویز — حتمی فہرست آپ منظور کرتے ہیں',
    'اقتراح الذكاء الاصطناعي — أنت تعتمد القائمة النهائية',
  );
  // --- Modern country picker + market brief ---
  String get geoAllRegions => _get('All', 'سب', 'الكل');
  String get geoUseAiSuggestion => _get(
    'Use AI suggestion',
    'AI تجویز استعمال کریں',
    'استخدم اقتراح الذكاء الاصطناعي',
  );
  String get geoYourMarkets => _get('Your markets', 'آپ کی مارکیٹس', 'أسواقك');
  String get geoMarketBriefNote => _get(
    'AI will match your content language and audience to these markets.',
    'AI آپ کے مواد کی زبان اور سامعین کو ان مارکیٹس سے ملائے گا۔',
    'سيطابق الذكاء الاصطناعي لغة محتواك وجمهورك مع هذه الأسواق.',
  );
  String get geoAiSuggestedBadge =>
      _get('AI suggested', 'AI کی تجویز', 'مقترح بالذكاء الاصطناعي');
  String get geoYourPickBadge => _get('Your pick', 'آپ کا انتخاب', 'اختيارك');

  // Free Grow vs Paid Boost — plans, packages, agents.
  String get freeGrow => _get('Free Grow', 'مفت گرو', 'نمو مجاني');
  String get paidBoost => _get('Paid Boost', 'پیڈ بوسٹ', 'تعزيز مدفوع');
  String get freeGrowTag => _get(
    'Worldwide · Limited · \$0',
    'عالمی · محدود · \$0',
    'عالمي · محدود · 0\$',
  );
  String get paidBoostTag => _get(
    'Choose a package · Target countries',
    'پیکیج چنیں · ممالک ٹارگٹ کریں',
    'اختر باقة · استهدف الدول',
  );
  String get freeGrowLimits =>
      _get('Free Grow limits', 'مفت گرو کی حدود', 'حدود النمو المجاني');
  String get freeLimitCampaigns => _get(
    'Up to 3 live campaigns',
    'زیادہ سے زیادہ 3 لائیو مہمات',
    'حتى 3 حملات نشطة',
  );
  String get freeLimitImpressions => _get(
    'Up to 1,000 genuine impressions per campaign',
    'فی مہم 1,000 حقیقی امپریشنز تک',
    'حتى 1000 ظهور حقيقي لكل حملة',
  );
  String get freeWorldwideOnly => _get(
    'Worldwide audience only — no country picker',
    'صرف عالمی سامعین — ملک منتخب نہیں ہوگا',
    'جمهور عالمي فقط — بدون اختيار الدول',
  );
  String get freeNoBudget => _get(
    'No budget, no spend — \$0',
    'کوئی بجٹ نہیں، کوئی خرچ نہیں — \$0',
    'بدون ميزانية، بدون إنفاق — 0\$',
  );
  String get choosePackage =>
      _get('Choose your package', 'اپنا پیکیج چنیں', 'اختر باقتك');
  String get packagePopular =>
      _get('Most popular', 'سب سے مقبول', 'الأكثر شعبية');
  String packageDays(int n) => _get('$n days', '$n دن', '$n يوم');
  String get managedByFreeAi => _get(
    'Managed by Free Grow AI',
    'فری گرو AI کے زیر انتظام',
    'يُدار بواسطة نمو مجاني AI',
  );
  String get managedByPaidAi => _get(
    'Managed by Paid Boost AI',
    'پیڈ بوسٹ AI کے زیر انتظام',
    'يُدار بواسطة تعزيز مدفوع AI',
  );
  String get freeGrowAiDesc => _get(
    'Your organic growth manager — worldwide reach, zero budget.',
    'آپ کا آرگینک گروتھ مینیجر — عالمی رسائی، صفر بجٹ۔',
    'مدير نموك العضوي — وصول عالمي، ميزانية صفر.',
  );
  String get paidBoostAiDesc => _get(
    'Your paid growth manager — targeted reach, inside your package budget.',
    'آپ کا پیڈ گروتھ مینیجر — ٹارگٹڈ رسائی، آپ کے پیکیج بجٹ کے اندر۔',
    'مدير نموك المدفوع — وصول مستهدف، ضمن ميزانية باقتك.',
  );
  String get freeServices => _get('Free Services', 'مفت سروسز', 'خدمات مجانية');
  String get paidServices => _get('Paid Services', 'پیڈ سروسز', 'خدمات مدفوعة');
  String get planLockedNote => _get(
    "Plan can't change after creation",
    'بننے کے بعد پلان نہیں بدل سکتا',
    'لا يمكن تغيير الخطة بعد الإنشاء',
  );
  String get choosePlan =>
      _get('Choose your plan', 'اپنا پلان چنیں', 'اختر خطتك');
  String get freeModuleBadge => _get('100% free', '100% مفت', 'مجاني 100٪');
  String get paidModuleBadge => _get('Paid', 'پیڈ', 'مدفوع');
  String get freeGrowDesc => _get(
    'AI works to grow your content organically across Virello\'s discovery network — worldwide audience, \$0. No packages, no budget controls, no spend.',
    'AI آپ کے مواد کو Virello کے ڈسکوری نیٹ ورک میں آرگینک طریقے سے بڑھانے کی کوشش کرتا ہے — عالمی سامعین، \$0۔ کوئی پیکیج نہیں، کوئی بجٹ کنٹرول نہیں، کوئی خرچ نہیں۔',
    'يعمل الذكاء الاصطناعي على تنمية المحتوى الخاص بك عضوياً عبر شبكة اكتشاف Virello — جمهور عالمي، 0\$. لا باقات، لا ضوابط ميزانية، لا إنفاق.',
  );
  String freeLimitCampaignsN(int n) => _get(
    'Up to $n live campaigns',
    'زیادہ سے زیادہ $n لائیو مہمات',
    'حتى $n حملات نشطة',
  );
  String freeLimitImpressionsN(String n) => _get(
    'Up to $n genuine impressions per campaign',
    'فی مہم $n حقیقی امپریشنز تک',
    'حتى $n ظهور حقيقي لكل حملة',
  );
  String get freeWindDown => _get(
    'AI winds down automatically at 80% of the impression cap',
    'امپریشن حد کے 80 فیصد پر AI خودکار طور پر سست ہو جاتا ہے',
    'يتباطأ الذكاء الاصطناعي تلقائياً عند 80٪ من حد الظهور',
  );
  String get paidBoostDesc => _get(
    'AI runs paid promotion inside the budget you approve by picking a package. Targeted countries, fixed duration — you approve everything before launch.',
    'AI آپ کے منظور کردہ بجٹ کے اندر پیڈ پروموشن چلاتا ہے — پیکیج منتخب کر کے بجٹ طے کریں۔ ٹارگٹڈ ممالک، مقررہ مدت — لانچ سے پہلے سب کچھ آپ منظور کرتے ہیں۔',
    'يدير الذكاء الاصطناعي الترويج المدفوع ضمن الميزانية التي تعتمدها باختيار باقة. دول مستهدفة، مدة ثابتة — تعتمد كل شيء قبل الإطلاق.',
  );
  String get packageIsBudget => _get(
    'Your package IS your budget — no manual budgeting needed',
    'آپ کا پیکیج ہی آپ کا بجٹ ہے — دستی بجٹنگ کی ضرورت نہیں',
    'باقتك هي ميزانيتك — لا حاجة لتحديد الميزانية يدوياً',
  );
  String get paidLimitsTitle =>
      _get('Paid Boost limits', 'پیڈ بوسٹ کی حدود', 'حدود التعزيز المدفوع');
  String get paidLimitSpend => _get(
    'Spend capped at your package price — never more',
    'خرچ آپ کے پیکیج کی قیمت تک محدود — اس سے زیادہ کبھی نہیں',
    'الإنفاق محدود بسعر باقتك — لا يتجاوزه أبداً',
  );
  String get paidLimitDuration => _get(
    'Fixed duration per package — set by the package you pick',
    'ہر پیکیج کی مقررہ مدت — آپ کے منتخب کردہ پیکیج کے مطابق',
    'مدة ثابتة لكل باقة — حسب الباقة التي تختارها',
  );
  String get paidLimitCountries => _get(
    'Targeted countries you approve before launch',
    'لانچ سے پہلے آپ جن ممالک کو منظور کریں',
    'دول مستهدفة تعتمدها قبل الإطلاق',
  );

  // Tutorial / Guide
  String get tutorialTitle =>
      _get('Tutorial / Guide', 'ٹیوٹوریل / گائیڈ', 'الشرح / الدليل');
  String get tutorialMenu =>
      _get('Tutorial / Guide', 'ٹیوٹوریل / گائیڈ', 'الشرح / الدليل');
  String get tutorialMenuSub => _get(
    'Watch how to use Virello',
    'دیکھیں Virello کیسے استعمال کریں',
    'شاهد كيفية استخدام Virello',
  );
  String get tutorialChapters => _get('Chapters', 'ابواب', 'الفصول');
  String get tutorialReplay => _get('Replay', 'دوبارہ چلائیں', 'إعادة التشغيل');
  String get tutorialRestartChapter =>
      _get('Restart chapter', 'باب دوبارہ شروع کریں', 'إعادة الفصل');
  String tutorialResume(String at) =>
      _get('Resume from $at', '$at سے جاری رکھیں', 'الاستئناف من $at');
  String get tutorialLoadError => _get(
    'Could not load the tutorial video.',
    'ٹیوٹوریل ویڈیو لوڈ نہیں ہو سکی۔',
    'تعذّر تحميل فيديو الشرح.',
  );
  String get tutorialNote => _get(
    'A guided walkthrough of the whole app, narrated in Urdu — with built-in subtitles in 44 languages.',
    'پوری ایپ کا رہنمائی والا تعارف، اردو میں بیان کردہ — 44 زبانوں میں بلٹ اِن سب ٹائٹلز کے ساتھ۔',
    'جولة إرشادية في التطبيق كاملاً، باللغة الأردية — مع ترجمة مدمجة بـ 44 لغة.',
  );
  String get tutorialSubtitles => _get('Subtitles', 'سب ٹائٹلز', 'الترجمة');
  String get play => _get('Play', 'چلائیں', 'تشغيل');
  String get tutChWelcome => _get(
    'Welcome to Virello',
    'Virello میں خوش آمدید',
    'مرحباً بك في Virello',
  );
  String get tutChHome => _get('Home Feed', 'ہوم فیڈ', 'الخلاصة الرئيسية');
  String get tutChDiscover => _get('Discover', 'ڈسکور', 'اكتشف');
  String get tutChCreate => _get('Create', 'بنائیں', 'إنشاء');
  String get tutChAnalyze =>
      _get('AI Analyze', 'AI تجزیہ', 'تحليل الذكاء الاصطناعي');
  String get tutChAudience =>
      _get('Audience Insights', 'آڈینس انسائٹس', 'رؤى الجمهور');
  String get tutChSetup => _get('Campaign Setup', 'مہم سیٹ اپ', 'إعداد الحملة');
  String get tutChAgent =>
      _get('AI Growth Agent', 'AI گروتھ ایجنٹ', 'وكيل النمو بالذكاء الاصطناعي');
  String get tutChCampaigns => _get('Campaigns', 'مہمات', 'الحملات');
  String get tutChProfile => _get('Profile', 'پروفائل', 'الملف الشخصي');
  String get tutChThanks => _get('Thank You', 'شکریہ', 'شكراً لك');

  // Profile editing
  String get nameLabel => _get('Name', 'نام', 'الاسم');
  String get profileUpdated => _get(
    'Profile updated.',
    'پروفائل اپ ڈیٹ ہو گئی۔',
    'تم تحديث الملف الشخصي.',
  );

  // Billing (read-only catalog display)
  String get currentPlan =>
      _get('Current plan', 'موجودہ پلان', 'الخطة الحالية');
  String get plansTitle => _get('Plans', 'پلانز', 'الخطط');
  String get creditPacksTitle =>
      _get('Credit packs', 'کریڈٹ پیکس', 'حزم الاعتمادات');
  String get acceptedPayments =>
      _get('Accepted payments', 'قبول شدہ ادائیگی', 'المدفوعات المقبولة');
  String get paymentsNote => _get(
    'PayPal, Payoneer, Google Pay only — all payments are verified server-side.',
    'صرف PayPal، Payoneer، Google Pay — تمام ادائیگیاں سرور پر تصدیق ہوتی ہیں۔',
    'PayPal وPayoneer وGoogle Pay فقط — تُتحقق جميع المدفوعات من الخادم.',
  );
  String aiCreditsMonth(int n) => _get(
    '$n AI credits / month',
    '$n AI کریڈٹس / ماہ',
    '$n من اعتمادات الذكاء الاصطناعي / شهر',
  );
  String campaignsAllowed(int n) =>
      _get('$n campaigns allowed', '$n مہمات کی اجازت', '$n حملات مسموحة');
  String get perMonth => _get('/month', '/ماہ', '/شهر');
  String get creditsUnit => _get('credits', 'کریڈٹس', 'اعتمادات');

  // AI Support chat
  String get supportAutomatedNote => _get(
    'You\'re chatting with Virello\'s automated support assistant — answers are generated, not from a human agent.',
    'آپ وائرلو کے خودکار معاونت اسسٹنٹ سے بات کر رہے ہیں — جوابات تیار کردہ ہیں، کسی انسانی ایجنٹ کے نہیں۔',
    'أنت تتحدث مع مساعد دعم Virello الآلي — الإجابات مُولَّدة، وليست من وكيل بشري.',
  );
  String get askQuestionHint =>
      _get('Ask a question…', 'سوال پوچھیں…', 'اطرح سؤالاً…');
  String get supportWelcome => _get(
    'Hi! I\'m Virello\'s support assistant. Ask me anything about plans, campaigns, or features.',
    'سلام! میں وائرلو کا معاونت اسسٹنٹ ہوں۔ پلانز، مہمات یا فیچرز کے بارے میں کچھ بھی پوچھیں۔',
    'مرحباً! أنا مساعد دعم Virello. اسألني أي شيء عن الخطط أو الحملات أو الميزات.',
  );

  // Following
  String get followingEmpty => _get(
    'You\'re not following anyone yet — follow creators to see them here.',
    'آپ ابھی کسی کو فالو نہیں کر رہے — تخلیق کاروں کو فالو کریں تاکہ وہ یہاں نظر آئیں۔',
    'أنت لا تتابع أحداً بعد — تابع المبدعين لرؤيتهم هنا.',
  );
  String get followCreatorTitle =>
      _get('Follow a creator', 'تخلیق کار فالو کریں', 'تابع مبدعاً');
  String get creatorHandleLabel =>
      _get('Creator handle', 'تخلیق کار کا ہینڈل', 'اسم المبدع');
  String get creatorNameLabel => _get(
    'Display name (optional)',
    'نام (اختیاری)',
    'الاسم المعروض (اختياري)',
  );
  String get followBtn => _get('Follow', 'فالو کریں', 'تابع');
  String get unfollowBtn => _get('Unfollow', 'ان فالو کریں', 'إلغاء المتابعة');
  String get followingTab => _get('Following', 'فالونگ', 'يتابع');

  // Analytics
  String get noAnalyticsYet => _get(
    'No analytics yet — launch a campaign and real numbers will appear here.',
    'ابھی کوئی تجزیات نہیں — مہم لانچ کریں تو حقیقی اعداد یہاں نظر آئیں گے۔',
    'لا تحليلات بعد — أطلق حملة وستظهر الأرقام الحقيقية هنا.',
  );
  String get dailyBreakdownNote => _get(
    'Daily breakdown appears once today\'s data is recorded.',
    'آج کا ڈیٹا ریکارڈ ہوتے ہی روزانہ کی تفصیل یہاں نظر آئے گی۔',
    'يظهر التفصيل اليومي فور تسجيل بيانات اليوم.',
  );
  String get dailyReachTitle =>
      _get('Daily reach', 'روزانہ رسائی', 'الوصول اليومي');

  // Upload context carried forward
  String get attachedMedia =>
      _get('Attached media', 'منسلک میڈیا', 'الوسائط المرفقة');

  // In-app post reader
  String get readerAiSummary => _get(
    'AI summary · automated preview',
    'AI خلاصہ · خودکار پیش نظارہ',
    'ملخص الذكاء الاصطناعي · معاينة تلقائية',
  );
  String get readerKeyPoints =>
      _get('Key points', 'اہم نکات', 'النقاط الرئيسية');
  String get readerExcerpt =>
      _get('Excerpt from the original', 'اصل سے اقتباس', 'مقتطف من الأصل');
  String get readerWhyPicked => _get(
    'Why this was picked for you',
    'یہ آپ کے لیے کیوں چنا گیا',
    'لماذا تم اختيار هذا لك',
  );
  String get readerAnalyzeWithAI =>
      _get('Analyze with AI', 'AI سے تجزیہ کریں', 'حلّل بالذكاء الاصطناعي');
  String get readerFindAudience =>
      _get('Find Audience', 'آڈینس تلاش کریں', 'اعثر على الجمهور');
  String get readerReadOriginal => _get(
    'Read original ↗ · opens in browser',
    'اصل پڑھیں ↗ · براؤزر میں کھلے گا',
    'اقرأ الأصل ↗ · يفتح في المتصفح',
  );
  String get readerRetry => _get('Retry', 'دوبارہ کوشش کریں', 'إعادة المحاولة');
  String get readerLoadError => _get(
    'Could not load a preview for this post. Check your connection and try again.',
    'اس پوسٹ کا پیش نظارہ لوڈ نہیں ہو سکا۔ اپنا کنکشن چیک کریں اور دوبارہ کوشش کریں۔',
    'تعذّر تحميل معاينة لهذا المنشور. تحقق من الاتصال وحاول مجددًا.',
  );
  String get readerNoPreview => _get(
    'No preview available for this link yet.',
    'اس لنک کا پیش نظارہ ابھی دستیاب نہیں۔',
    'لا تتوفر معاينة لهذا الرابط بعد.',
  );
  String get readerVia => _get('via', 'بذریعہ', 'عبر');
  String get readerSave => _get('Save', 'محفوظ کریں', 'احفظ');
  String get readerSaved => _get('Saved', 'محفوظ شدہ', 'محفوظ');
  String get readerAutomatedNote => _get(
    'Transformed preview: short excerpt + automated summary. Full text stays on the original page.',
    'تبدیل شدہ پیش نظارہ: مختصر اقتباس + خودکار خلاصہ۔ مکمل متن اصل صفحے پر رہتا ہے۔',
    'معاينة مُحوَّلة: مقتطف قصير + ملخص تلقائي. يبقى النص الكامل على الصفحة الأصلية.',
  );

  // Free Growth Tools (Create hub section).
  String get freeGrowthTools =>
      _get('Free Growth Tools', 'مفت گروتھ ٹولز', 'أدوات النمو المجانية');
  String get toolTransform =>
      _get('Link → Native Posts', 'لنک ← نیٹو پوسٹس', 'الرابط ← منشورات أصلية');
  String get toolTransformDesc => _get(
    'Turn any link into native video scripts, carousels & threads',
    'کسی بھی لنک کو نیٹو ویڈیو اسکرپٹ، کیروسل اور تھریڈز میں بدلیں',
    'حوِّل أي رابط إلى نصوص فيديو ومنشورات أصلية',
  );
  String get toolCtrAudit =>
      _get('Link CTR Check', 'لنک CTR چیک', 'فحص CTR للرابط');
  String get toolCtrAuditDesc => _get(
    'Audit your link preview: title, image & social cards',
    'اپنے لنک پریویو کا آڈٹ: عنوان، تصویر اور سوشل کارڈز',
    'دقّق معاينة رابطك: العنوان والصورة والبطاقات',
  );
  String get toolSeeding =>
      _get('Community Seeding', 'کمیونٹی سیڈنگ', 'النشر المجتمعي');
  String get toolSeedingDesc => _get(
    'AI-matched communities + tailored drafts you post yourself',
    'AI سے میچ شدہ کمیونٹیز + ڈرافٹس جو آپ خود پوسٹ کریں',
    'مجتمعات مطابقة بالذكاء الاصطناعي + مسودات تنشرها بنفسك',
  );
  String get toolCollab =>
      _get('Creator Collabs', 'کریئیٹر تعاون', 'تعاون المبدعين');
  String get toolCollabDesc => _get(
    'Find creators whose audience fits your content',
    'ایسے کریئیٹرز تلاش کریں جن کی آڈینس آپ کے مواد سے میل کھائے',
    'اعثر على مبدعين يناسب جمهورهم محتواك',
  );
  String get toolReferral => _get(
    'Refer & Earn Credits',
    'ریفر کریں، کریڈٹ کمائیں',
    'أحِل واكسب رصيدًا',
  );
  String get toolReferralDesc => _get(
    'Share your link — you both earn AI credits on signup',
    'اپنا لنک شیئر کریں — سائن اپ پر دونوں کو AI کریڈٹ',
    'شارك رابطك — تكسبان رصيد ذكاء اصطناعي عند التسجيل',
  );
  String get toolLinkCards =>
      _get('Link Cards in Discovery', 'ڈسکوری میں لنک کارڈز', 'بطاقات الروابط');
  String get toolLinkCardsDesc => _get(
    'Your links render as rich native cards in the feed',
    'آپ کے لنکس فیڈ میں خوبصورت نیٹو کارڈز بن کر دکھیں',
    'تظهر روابطك كبطاقات أصلية غنية في الموجز',
  );

  // ------------------------------ Ask Virello (Phase 1) ------------------------------
  String get askVirello =>
      _get('Ask Virello', 'وائریلو سے پوچھیں', 'اسأل فيريلو');
  String get askVirelloHint => _get(
    'Ask anything — create, grow, sell, learn…',
    'کچھ بھی پوچھیں — بنائیں، بڑھائیں، بیچیں، سیکھیں…',
    'اسأل أي شيء — أنشئ، نمِّ، بِع، تعلَّم…',
  );
  String get askVirelloWelcome => _get(
    'Hi! I\'m Virello, your AI assistant. Just tell me what you want — "create a video", "grow this post", "sell this product" — and I\'ll route it to the right tool.',
    'ہیلو! میں وائریلو ہوں، آپ کا AI اسسٹنٹ۔ بس بتائیں کیا چاہیے — "ویڈیو بنائیں"، "یہ پوسٹ بڑھائیں"، "یہ پروڈکٹ بیچیں" — میں صحیح ٹول تک پہنچا دوں گا۔',
    'مرحبًا! أنا فيريلو، مساعدك الذكي. أخبرني فقط بما تريد — "أنشئ فيديو"، "نمِّ هذا المنشور"، "بِع هذا المنتج" — وسأوجّهك إلى الأداة المناسبة.',
  );
  String get newChat => _get('New chat', 'نئی چیٹ', 'محادثة جديدة');
  String get devPreviewNote => _get(
    'Development preview — heuristic output',
    'ڈیولپمنٹ پیش نظارہ — ہیورسٹک آؤٹ پٹ',
    'معاينة تطويرية — مخرجات استكشافية',
  );
  String get comingSoonPhase => _get(
    'Coming in a later phase',
    'اگلے مرحلے میں آ رہا ہے',
    'قادم في مرحلة لاحقة',
  );
  String get askFailed => _get(
    'Couldn\'t reach Virello AI. Check your connection and try again.',
    'وائریلو AI سے رابطہ نہ ہو سکا۔ کنکشن چیک کریں اور دوبارہ کوشش کریں۔',
    'تعذّر الوصول إلى فيريلو. تحقق من الاتصال وحاول مجددًا.',
  );

  // ------------------------------ Shop (Phase 1 placeholder) ------------------------------
  String get shop => _get('Shop', 'شاپ', 'المتجر');
  String get shopComingSoon =>
      _get('Shop is coming soon', 'شاپ جلد آ رہی ہے', 'المتجر قادم قريبًا');
  String get shopComingSoonDesc => _get(
    'Product discovery, price comparison and creator storefronts arrive in Phase 4. Ask Virello about your product in the meantime!',
    'پروڈکٹ ڈسکوری، قیمت کا موازنہ اور کریئیٹر اسٹورز فیز 4 میں آئیں گے۔ تب تک وائریلو سے اپنے پروڈکٹ کے بارے میں پوچھیں!',
    'اكتشاف المنتجات ومقارنة الأسعار وواجهات المبدعين قادمة في المرحلة 4. اسأل فيريلو عن منتجك في هذه الأثناء!',
  );

  // ------------------------------ Affiliate (Phase 4, FTC/Amazon disclosure) ------------------------------
  /// Shown on every affiliate product detail per FTC + Amazon Associates rules.
  String get affiliateDisclosure => _get(
    'Affiliate link — we may earn a commission',
    'ایفیلی ایٹ لنک — ہمیں کمیشن مل سکتا ہے',
    'رابط تابع — قد نحصل على عمولة',
  );
  String get affiliateBadge => _get('Affiliate', 'ایفیلی ایٹ', 'تابع');
  String get syncAffiliate =>
      _get('Sync price', 'قیمت اپ ڈیٹ کریں', 'مزامنة السعر');
  String get syncNotConfigured => _get(
    'Price sync needs Amazon API credentials (coming soon)',
    'قیمت اپ ڈیٹ کے لیے Amazon API درکار ہے (جلد آ رہا ہے)',
    'مزامنة السعر تحتاج بيانات Amazon API (قريبًا)',
  );

  // ------------------------------ Home next actions (Phase 1) ------------------------------
  String get nextActions => _get(
    'AI suggested next actions',
    'AI کی تجویز کردہ اگلے اقدامات',
    'الخطوات التالية المقترحة بالذكاء الاصطناعي',
  );
  String get actionAnalyzePost =>
      _get('Analyze a post', 'پوسٹ کا تجزیہ کریں', 'حلِّل منشورًا');
  String get actionAskVirello =>
      _get('Ask Virello', 'وائریلو سے پوچھیں', 'اسأل فيريلو');
  String get actionViewCampaigns =>
      _get('View campaigns', 'مہمات دیکھیں', 'عرض الحملات');

  /// Human label for an AI Core intent code.
  String intentLabel(String intent) {
    switch (intent) {
      case 'create_content':
        return _get('Create', 'تخلیق', 'إنشاء');
      case 'analyze_content':
        return _get('Analyze', 'تجزیہ', 'تحليل');
      case 'grow':
        return _get('Grow', 'گرو', 'نمِّ');
      case 'discover':
        return _get('Discover', 'دریافت', 'اكتشف');
      case 'shop':
        return _get('Shop', 'شاپ', 'المتجر');
      case 'learn':
        return _get('Learn', 'سیکھیں', 'تعلَّم');
      case 'entertain':
        return _get('Entertain', 'تفریح', 'ترفيه');
      case 'support':
        return _get('Support', 'سپورٹ', 'الدعم');
      default:
        return _get('Assistant', 'اسسٹنٹ', 'المساعد');
    }
  }

  /// Emoji for an AI Core intent code.
  String intentEmoji(String intent) {
    switch (intent) {
      case 'create_content':
        return '🎨';
      case 'analyze_content':
        return '🔍';
      case 'grow':
        return '📈';
      case 'discover':
        return '🧭';
      case 'shop':
        return '🛍️';
      case 'learn':
        return '🎓';
      case 'entertain':
        return '🎭';
      case 'support':
        return '💬';
      default:
        return '✨';
    }
  }

  // ------------------------------ Viral Lab (Phase 2) ------------------------------
  String get viralLab => _get('Viral Lab', 'وائرل لیب', 'مختبر الانتشار');
  String get viralLabDesc => _get(
    'Analyze any post, get improvements & variations',
    'کسی بھی پوسٹ کا تجزیہ کریں، بہتری اور ورژن حاصل کریں',
    'حلِّل أي منشور واحصل على تحسينات ونسخ',
  );
  String get pasteLinkOrText => _get(
    'Paste a post link or write your text…',
    'پوسٹ کا لنک پیسٹ کریں یا اپنا متن لکھیں…',
    'الصق رابط منشور أو اكتب نصك…',
  );
  String get analyzeImprove =>
      _get('Analyze & Improve', 'تجزیہ اور بہتری', 'حلِّل وحسِّن');
  String get improvementAreas =>
      _get('Improvement areas', 'بہتری کے شعبے', 'مجالات التحسين');
  String get rewrittenHook => _get(
    'Example rewritten hook',
    'دوبارہ لکھا ہوا ہوک (مثال)',
    'مثال على بداية محسنة',
  );
  String get variations => _get('Variations', 'مختلف ورژن', 'نسخ متنوعة');
  String get copyText => _get('Copy', 'کاپی', 'نسخ');
  String get copied => _get('Copied!', 'کاپی ہو گیا!', 'تم النسخ!');
  String get whyItWorks =>
      _get('Why it works', 'یہ کیوں کام کرتا ہے', 'لماذا ينجح');
  String get priorityHigh => _get('High priority', 'اہم', 'أولوية عالية');
  String get priorityMedium =>
      _get('Medium priority', 'درمیانی', 'أولوية متوسطة');
  String get scoreLabel =>
      _get('Packaging score', 'پیکجنگ اسکور', 'درجة التغليف');
  String get enterTextFirst => _get(
    'Enter a link or some text first.',
    'پہلے لنک یا متن درج کریں۔',
    'أدخل رابطًا أو نصًا أولًا.',
  );

  // ------------------------------ Creator Studio (Phase 3) ------------------------------
  String get creatorStudio =>
      _get('Creator Studio', 'کریئیٹر اسٹوڈیو', 'استوديو المبدع');
  String get creatorStudioDesc => _get(
    'AI ideas, scripts, captions & hooks',
    'AI آئیڈیاز، اسکرپٹس، کیپشنز اور ہوکس',
    'أفكار ونصوص وتسميات وبدايات بالذكاء الاصطناعي',
  );
  String get tabIdeas => _get('Ideas', 'آئیڈیاز', 'أفكار');
  String get tabScripts => _get('Scripts', 'اسکرپٹس', 'نصوص');
  String get tabCaptions => _get('Captions', 'کیپشنز', 'تسميات');
  String get tabHooks => _get('Hooks', 'ہوکس', 'بدايات');
  String get topicHint => _get(
    'What is it about? e.g. sourdough baking',
    'موضوع کیا ہے؟ مثلاً سرڈو بریڈ بیکنگ',
    'ما الموضوع؟ مثال: خبز العجين المخمر',
  );
  String get generateIdeas =>
      _get('Generate ideas', 'آئیڈیاز بنائیں', 'ولِّد أفكارًا');
  String get generateScript =>
      _get('Generate script', 'اسکرپٹ بنائیں', 'ولِّد نصًا');
  String get generateCaptions =>
      _get('Generate captions', 'کیپشنز بنائیں', 'ولِّد تسميات');
  String get generateHooks =>
      _get('Generate hooks', 'ہوکس بنائیں', 'ولِّد بدايات');
  String get formatVideo => _get('Video', 'ویڈیو', 'فيديو');
  String get formatReel => _get('Reel', 'ریل', 'ريل');
  String get formatPost => _get('Post', 'پوسٹ', 'منشور');
  String get scriptHook => _get('Hook', 'ہوک', 'البداية');
  String get scriptBody => _get('Body', 'متن', 'المتن');
  String get scriptCta =>
      _get('Call to action', 'کال ٹو ایکشن', 'الدعوة لاتخاذ إجراء');
  String get noResultsYet => _get(
    'Your creations will appear here.',
    'آپ کی تخلیقات یہاں نظر آئیں گی۔',
    'ستظهر إبداعاتك هنا.',
  );

  // ------------------------------ AI Academy (Phase 5) ------------------------------
  String get academy => _get('Academy', 'اکیڈمی', 'الأكاديمية');
  String get academyTagline => _get(
    'Bite-size lessons to grow your craft',
    'اپنے ہنر کو بڑھانے کے لیے مختصر اسباق',
    'دروس قصيرة لتنمية مهاراتك',
  );
  String get lessonLibrary =>
      _get('Lesson library', 'اسباق کی لائبریری', 'مكتبة الدروس');
  String get categoryAll => _get('All', 'تمام', 'الكل');
  String get categoryContent => _get('Content', 'مواد', 'المحتوى');
  String get categoryGrowth => _get('Growth', 'گروتھ', 'النمو');
  String get categoryCommerce => _get('Commerce', 'کامرس', 'التجارة');
  String get categoryMarketing => _get('Marketing', 'مارکیٹنگ', 'التسويق');
  String get levelBeginner => _get('Beginner', 'ابتدائی', 'مبتدئ');
  String get levelIntermediate => _get('Intermediate', 'درمیانہ', 'متوسط');
  String get levelAdvanced => _get('Advanced', 'اعلیٰ', 'متقدم');
  String get startLesson => _get('Start lesson', 'سبق شروع کریں', 'ابدأ الدرس');
  String get markComplete =>
      _get('Mark complete', 'مکمل قرار دیں', 'وضع علامة مكتمل');
  String get completed => _get('Completed', 'مکمل', 'مكتمل');
  String get takeQuiz => _get('Take quiz', 'کوئز دیں', 'خذ الاختبار');
  String get submitQuiz =>
      _get('Submit quiz', 'کوئز جمع کریں', 'أرسل الاختبار');
  String get yourScore => _get('Your score', 'آپ کا اسکور', 'نتيجتك');
  String get passedQuiz => _get(
    'Quiz passed — well done!',
    'کوئز پاس — شاباش!',
    'نجحت في الاختبار — أحسنت!',
  );
  String get keepTrying => _get(
    'Not quite there yet — try again!',
    'ابھی مکمل نہیں ہوا — دوبارہ کوشش کریں!',
    'ليس بعد — حاول مرة أخرى!',
  );
  String get noLessons =>
      _get('No lessons yet', 'ابھی کوئی سبق نہیں', 'لا دروس بعد');
  String questionOf(int n, int total) =>
      _get('Question $n of $total', 'سوال $n از $total', 'السؤال $n من $total');
  String get quizScore => _get('Quiz', 'کوئز', 'الاختبار');
  String get openAcademy => _get('Learn', 'سیکھیں', 'تعلَّم');
  String get openAcademyDesc => _get(
    'Short lessons on content, growth & selling',
    'مواد، گروتھ اور فروخت پر مختصر اسباق',
    'دروس قصيرة عن المحتوى والنمو والبيع',
  );

  // ------------------------------ AI Entertainment (Phase 6) ------------------------------
  String get stories => _get('Stories', 'کہانیاں', 'القصص');
  String get storiesTagline => _get(
    'AI storytime — just for fun',
    'AI کہانی کا وقت — صرف تفریح کے لیے',
    'وقت القصص بالذكاء الاصطناعي — للمتعة فقط',
  );
  String get storyPromptHint => _get(
    'Give a topic or idea… e.g. a space adventure',
    'کوئی موضوع یا خیال لکھیں… مثلاً خلا کا سفر',
    'أعطِ موضوعًا أو فكرة… مثال: مغامرة فضائية',
  );
  String get generateStory =>
      _get('Generate story', 'کہانی بنائیں', 'ولِّد قصة');
  String get regenerate => _get('Regenerate', 'دوبارہ بنائیں', 'أعد التوليد');
  String get shortLength => _get('Short', 'مختصر', 'قصيرة');
  String get mediumLength => _get('Medium', 'درمیانی', 'متوسطة');
  String get comicIdea => _get('Comic idea', 'کامک آئیڈیا', 'فكرة كوميك');
  String get comicTopicHint => _get(
    'What should the comic be about?',
    'کامک کس موضوع پر ہو؟',
    'عن ماذا يجب أن يكون الكوميك؟',
  );
  String get panels => _get('Panels', 'پینلز', 'اللوحات');
  String get generate => _get('Generate', 'بنائیں', 'ولِّد');
  String get openStories => _get('Stories', 'کہانیاں', 'القصص');
  String get openStoriesDesc => _get(
    'AI stories & comic ideas for fun',
    'تفریح کے لیے AI کہانیاں اور کامک آئیڈیاز',
    'قصص وأفكار كوميك بالذكاء الاصطناعي للمتعة',
  );
  String get learnAndPlay =>
      _get('Learn & Play', 'سیکھیں اور کھیلیں', 'تعلَّم والعب');
  String get storyTab => _get('Story', 'کہانی', 'قصة');
  String get comicTab => _get('Comic', 'کامک', 'كوميك');

  // ------------------------------ Shop (Phase 4) ------------------------------
  String get shopSearchHint =>
      _get('Search products…', 'پروڈکٹس تلاش کریں…', 'ابحث عن منتجات…');
  String get shopCatAll => _get('All', 'سب', 'الكل');
  String get shopCatMen => _get('Men', 'مرد', 'رجال');
  String get shopCatWomen => _get('Women', 'خواتین', 'نساء');
  String get shopCatSale => _get('Sale', 'سیل', 'تخفيضات');
  String get shopCatBestSellers =>
      _get('Best Sellers', 'بیسٹ سیلرز', 'الأكثر مبيعًا');
  String get shopEmptyTitle =>
      _get('No products yet', 'ابھی کوئی پروڈکٹ نہیں', 'لا توجد منتجات بعد');
  String get shopEmptyDesc => _get(
    'Be the first to list a product in the Virello Shop.',
    'وائریلو شاپ میں پہلا پروڈکٹ لسٹ کریں۔',
    'كن أول من يعرض منتجًا في متجر فيريلو.',
  );
  String get shopSell => _get('Sell', 'بیچیں', 'بِع');
  String get shopBuyNow => _get('Buy Now', 'ابھی خریدیں', 'اشترِ الآن');
  String get shopCheckoutSoon => _get(
    'Checkout via PayPal / Payoneer / Google Pay is being connected. This product page is live — payment opens soon.',
    'PayPal / Payoneer / Google Pay کے ذریعے چیک آؤٹ جلد منسلک ہو رہا ہے۔ یہ پروڈکٹ پیج لائیو ہے — ادائیگی جلد کھلے گی۔',
    'الدفع عبر PayPal / Payoneer / Google Pay قيد الربط. صفحة المنتج نشطة — سيُفتح الدفع قريبًا.',
  );
  String get shopInStock => _get('In stock', 'اسٹاک میں', 'متوفر');
  String get shopOutOfStock => _get('Out of stock', 'اسٹاک ختم', 'نفد المخزون');
  String get shopLimitedStock =>
      _get('Limited stock', 'محدود اسٹاک', 'مخزون محدود');
  String get shopNewBadge => _get('New', 'نیا', 'جديد');
  String get shopAskVirelloAbout => _get(
    'Ask Virello about this',
    'وائریلو سے اس کے بارے میں پوچھیں',
    'اسأل فيريلو عن هذا',
  );
  String get shopRelated =>
      _get('Related products', 'متعلقہ پروڈکٹس', 'منتجات ذات صلة');
  String get shopThis => _get('Shop this', 'یہ خریدیں', 'تسوَّق هذا');
  String get shopThisDesc => _get(
    'Products in the Virello Shop matching this post',
    'اس پوسٹ سے ملتے جلتے وائریلو شاپ کے پروڈکٹس',
    'منتجات متجر فيريلو المطابقة لهذا المنشور',
  );
  String get sellTitle =>
      _get('List a product', 'پروڈکٹ لسٹ کریں', 'اعرض منتجًا');
  String get sellTitleHint =>
      _get('Product title', 'پروڈکٹ کا نام', 'اسم المنتج');
  String get sellDescHint => _get(
    'Describe your product…',
    'اپنے پروڈکٹ کی تفصیل لکھیں…',
    'صِف منتجك…',
  );
  String get sellPriceHint => _get('Price', 'قیمت', 'السعر');
  String get sellCurrency => _get('Currency', 'کرنسی', 'العملة');
  String get sellCategory => _get('Category', 'کیٹیگری', 'الفئة');
  String get sellImagesHint => _get(
    'Image URLs (one per line)',
    'تصویر کے URLs (ہر لائن میں ایک)',
    'روابط الصور (رابط في كل سطر)',
  );
  String get sellStockHint =>
      _get('Stock quantity', 'اسٹاک کی تعداد', 'كمية المخزون');
  String get sellIsAffiliate => _get(
    'This is an affiliate product',
    'یہ ایفیلی ایٹ پروڈکٹ ہے',
    'هذا منتج تابع',
  );
  String get sellAffiliateUrlHint => _get(
    'Affiliate link (https://…)',
    'ایفیلی ایٹ لنک (https://…)',
    'رابط التابع (https://…)',
  );
  String get sellAffiliateProvider =>
      _get('Affiliate provider', 'ایفیلی ایٹ فراہم کنندہ', 'مزوّد التابع');
  String get sellSubmit =>
      _get('List product', 'پروڈکٹ لسٹ کریں', 'اعرض المنتج');
  String get sellSuccess => _get(
    'Product listed successfully!',
    'پروڈکٹ کامیابی سے لسٹ ہو گیا!',
    'تم عرض المنتج بنجاح!',
  );
  String get sellFailed => _get(
    'Couldn\'t list the product. Check the fields and try again.',
    'پروڈکٹ لسٹ نہ ہو سکا۔ فیلڈز چیک کریں اور دوبارہ کوشش کریں۔',
    'تعذّر عرض المنتج. تحقق من الحقول وحاول مجددًا.',
  );
  String get sellNeedTitlePrice => _get(
    'Title and a valid price are required.',
    'نام اور درست قیمت ضروری ہے۔',
    'الاسم والسعر الصحيح مطلوبان.',
  );
  String get sellNeedAffiliateUrl => _get(
    'An affiliate product needs a valid http(s) affiliate link.',
    'ایفیلی ایٹ پروڈکٹ کے لیے درست http(s) لنک ضروری ہے۔',
    'المنتج التابع يحتاج رابط تابع http(s) صالحًا.',
  );
  String get shopSortNote => _get(
    'Ranked by product page views (sales tracking coming soon)',
    'پروڈکٹ پیج ویوز کے حساب سے ترتیب (سیلز ٹریکنگ جلد آ رہی ہے)',
    'مرتّبة حسب مشاهدات صفحة المنتج (تتبّع المبيعات قريبًا)',
  );

  // ---- Lavish Shop rebuild (Phase 4 UI refresh) ----
  String get shopTitleBar => _get('Shop', 'شاپ', 'المتجر');
  String get shopCatalogTitle => _get('SHOP', 'شاپ', 'المتجر');
  String get shopYouMightLike =>
      _get('You might like', 'آپ کو پسند آ سکتا ہے', 'قد يعجبك');
  String get shopViewAll => _get('view all', 'سب دیکھیں', 'عرض الكل');
  String get shopTrending => _get('Trending', 'ٹرینڈنگ', 'الرائج');
  String get shopRecommendedForYou =>
      _get('Recommended for you', 'آپ کے لیے تجویز کردہ', 'موصى به لك');
  String get shopPostDetails =>
      _get('POST DETAILS', 'پوسٹ کی تفصیلات', 'تفاصيل المنشور');
  String get shopMore => _get('more', 'مزید', 'المزيد');
  String get shopVirelloShop =>
      _get('Virello Shop', 'وائریلو شاپ', 'متجر فيريلو');
  String get shopSortBy => _get('Sort by', 'ترتیب دیں', 'ترتيب حسب');
  String get shopSortNewest => _get('Newest', 'جدید ترین', 'الأحدث');
  String get shopSortPriceAsc => _get(
    'Price: Low to High',
    'قیمت: کم سے زیادہ',
    'السعر: من الأقل إلى الأعلى',
  );
  String get shopSortPriceDesc => _get(
    'Price: High to Low',
    'قیمت: زیادہ سے کم',
    'السعر: من الأعلى إلى الأقل',
  );
  String get shopSortPopular =>
      _get('Most popular', 'مقبول ترین', 'الأكثر شعبية');
  String get shopCheckPriceAmazon => _get(
    'Check price on Amazon',
    'ایمیزون پر قیمت دیکھیں',
    'تحقق من السعر على أمازون',
  );
  String get shopLinkCopied =>
      _get('Link copied', 'لنک کاپی ہو گیا', 'تم نسخ الرابط');
  String get shopClearFilters =>
      _get('Clear filters', 'فلٹر صاف کریں', 'مسح المرشحات');
  String get shopCatTech => _get('Tech', 'ٹیک', 'تقنية');
  String get shopCatFashion => _get('Fashion', 'فیشن', 'أزياء');
  String get shopCatHome => _get('Home', 'گھر', 'المنزل');
  String get shopCatFitness => _get('Fitness', 'فٹنس', 'لياقة');
  String get shopCatBeauty => _get('Beauty', 'بیوٹی', 'جمال');
  String get shopListYours => _get('List yours', 'اپنا لسٹ کریں', 'اعرض منتجك');
  String get timeNow => _get('now', 'ابھی', 'الآن');
  String timeMinAgo(int n) => _get('$n min ago', '$n منٹ پہلے', 'منذ $n دقيقة');
  String timeHoursAgo(int n) =>
      _get('$n hr ago', '$n گھنٹے پہلے', 'منذ $n ساعة');
  String timeDaysAgo(int n) => _get('$n days ago', '$n دن پہلے', 'منذ $n يوم');

  // ---- Discover feed rebuild ----
  String get discoverForYou => _get('For You', 'آپ کے لیے', 'لك');
  String get discoverSearchHint =>
      _get('Search posts…', 'پوسٹس تلاش کریں…', 'ابحث في المنشورات…');
  String get discoverNotifications =>
      _get('Notifications', 'اطلاعات', 'الإشعارات');
  String get discoverNoNotifications => _get(
    'No notifications yet',
    'ابھی کوئی اطلاع نہیں',
    'لا توجد إشعارات بعد',
  );
  String get discoverAskVirello =>
      _get('Ask Virello', 'وائریلو سے پوچھیں', 'اسأل فيريلو');
  String get discoverSavedTitle => _get('Saved', 'محفوظ شدہ', 'المحفوظة');
  String get discoverLearnPlay =>
      _get('Learn & Play', 'سیکھیں اور کھیلیں', 'تعلّم والعب');

  // ---- 2026-09-29 master board: auth flow (screens 01-06) ----
  String get boardIdeasAmplified => _get(
    'Your ideas. Amplified.',
    'آپ کے خیالات۔ نئی بلندیوں پر۔',
    'أفكارك. بتضخيم.',
  );
  String get boardWelcomeTitle => _get(
    'Welcome to Virello AI',
    'Virello AI میں خوش آمدید',
    'مرحباً بك في Virello AI',
  );
  String get boardWelcomeDesc => _get(
    'Create amazing content, grow your audience, sell your products and just learn new skills — all in one place.',
    'شاندار مواد بنائیں، اپنے ناظرین بڑھائیں، اپنی مصنوعات بیچیں اور نئی مہارتیں سیکھیں — سب ایک جگہ۔',
    'أنشئ محتوى رائعاً، ونمِّ جمهورك، وبِع منتجاتك، وتعلّم مهارات جديدة — كل ذلك في مكان واحد.',
  );
  String get boardCreateAccount =>
      _get('Create Account', 'اکاؤنٹ بنائیں', 'إنشاء حساب');
  String get boardFullName => _get('Full name', 'پورا نام', 'الاسم الكامل');
  String get boardSelectLanguage =>
      _get('Select Language', 'زبان منتخب کریں', 'اختر اللغة');
  String get boardInterestedIn => _get(
    'What are you interested in?',
    'آپ کو کس چیز میں دلچسپی ہے؟',
    'ما الذي يهمك؟',
  );
  String get boardWelcomeBack =>
      _get('Welcome Back', 'واپس خوش آمدید', 'مرحباً بعودتك');
}
