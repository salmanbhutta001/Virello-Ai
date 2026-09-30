/// Hand-rolled strings for the scaffold (keeps pubspec dependency-light).
/// 11 full UI languages: en, ur, ar, hi, fr, es, pt, de, tr, id, bn.
/// Production path: flutter_intl + ARB codegen (see lib/l10n/*.arb).
class AppStrings {
  final String code; // 'en'|'ur'|'ar'|'hi'|'fr'|'es'|'pt'|'de'|'tr'|'id'|'bn'
  bool get isArabic => code == 'ar';
  const AppStrings(this.code);
  bool get isUrdu => code == 'ur';
  // Argument order for _get: en, ur, ar, hi, fr, es, pt, de, tr, id, bn.
  // Any language with no value falls back to English.
  String _get(String en, String ur,
      [String? ar,
      String? hi,
      String? fr,
      String? es,
      String? pt,
      String? de,
      String? tr,
      String? id,
      String? bn]) {
    switch (code) {
      case 'ur':
        return ur;
      case 'ar':
        return ar ?? en;
      case 'hi':
        return hi ?? en;
      case 'fr':
        return fr ?? en;
      case 'es':
        return es ?? en;
      case 'pt':
        return pt ?? en;
      case 'de':
        return de ?? en;
      case 'tr':
        return tr ?? en;
      case 'id':
        return id ?? en;
      case 'bn':
        return bn ?? en;
      default:
        return en;
    }
  }

  String get appTagline => _get(
        'Your AI Growth Manager',
        'آپ کا AI گروتھ مینیجر',
        'مدير النمو بالذكاء الاصطناعي',
      
        'आपका AI ग्रोथ मैनेजर',
        'Votre gestionnaire de croissance IA',
        'Tu gestor de crecimiento con IA',
        'Seu gestor de crescimento com IA',
        'Dein KI-Wachstumsmanager',
        'Yapay Zekâ Büyüme Yöneticin',
        'Manajer Pertumbuhan AI Anda',
        'আপনার AI গ্রোথ ম্যানেজার'
      );
  String get home => _get('Home', 'ہوم', 'الرئيسية',
        'होम',
        'Accueil',
        'Inicio',
        'Início',
        'Start',
        'Ana Sayfa',
        'Beranda',
        'হোম'
      );
  String get grow => _get('Grow', 'گرو', 'نمِّ',
        'ग्रो',
        'Croissance',
        'Crecer',
        'Crescer',
        'Wachstum',
        'Büyüme',
        'Grow',
        'গ্রো'
      );
  String get campaigns => _get('Campaigns', 'مہمات', 'الحملات',
        'अभियान',
        'Campagnes',
        'Campañas',
        'Campanhas',
        'Kampagnen',
        'Kampanyalar',
        'Kampanye',
        'ক্যাম্পেইন'
      );
  String get analytics => _get('Analytics', 'تجزیات', 'التحليلات',
        'एनालिटिक्स',
        'Statistiques',
        'Estadísticas',
        'Estatísticas',
        'Statistiken',
        'Analitik',
        'Analitik',
        'অ্যানালিটিক্স'
      );
  String get profile => _get('Profile', 'پروفائل', 'الملف الشخصي',
        'प्रोफ़ाइल',
        'Profil',
        'Perfil',
        'Perfil',
        'Profil',
        'Profil',
        'Profil',
        'প্রোফাইল'
      );
  String get letAiGrow =>
      _get('LET AI GROW', 'AI سے گرو کریں', 'دَع الذكاء الاصطناعي ينمِّي',
        'AI से ग्रो करें',
        'LAISSE L\'IA CROÎTRE',
        'DEJA QUE LA IA CREZCA',
        'DEIXE A IA CRESCER',
        'LASS DIE KI WACHSEN',
        'YZ İLE BÜYÜ',
        'BIARKAN AI TUMBUH',
        'AI দিয়ে গ্রো করুন'
      );
  String get pasteYourPost =>
      _get('Paste your post', 'اپنی پوسٹ کا لنک پیسٹ کریں', 'الصق منشورك',
        'अपनी पोस्ट पेस्ट करें',
        'Colle ton post',
        'Pega tu publicación',
        'Cole sua publicação',
        'Füge deinen Beitrag ein',
        'Gönderini yapıştır',
        'Tempel postinganmu',
        'আপনার পোস্ট পেস্ট করুন'
      );
  String get pasteHint => _get(
        'Paste a public post or video link…',
        'عوامی پوسٹ یا ویڈیو کا لنک یہاں پیسٹ کریں…',
        'الصق رابط منشور عام أو فيديو…',
      
        'कोई पब्लिक पोस्ट या वीडियो लिंक पेस्ट करें…',
        'Colle le lien d\'un post ou d\'une vidéo public…',
        'Pega el enlace de una publicación o video público…',
        'Cole o link de uma publicação ou vídeo público…',
        'Füge den Link zu einem öffentlichen Beitrag oder Video ein…',
        'Herkese açık bir gönderi veya video bağlantısı yapıştır…',
        'Tempel tautan postingan atau video publik…',
        'একটি পাবলিক পোস্ট বা ভিডিও লিংক পেস্ট করুন…'
      );
  String get chooseYourGoal =>
      _get('Choose your goal', 'اپنا ہدف منتخب کریں', 'اختر هدفك',
        'अपना लक्ष्य चुनें',
        'Choisis ton objectif',
        'Elige tu objetivo',
        'Escolha seu objetivo',
        'Wähle dein Ziel',
        'Hedefini seç',
        'Pilih tujuanmu',
        'আপনার লক্ষ্য বেছে নিন'
      );
  String get setBudget =>
      _get('Markets & budget', 'مارکیٹس اور بجٹ', 'الأسواق والميزانية',
        'मार्केट और बजट',
        'Marchés et budget',
        'Mercados y presupuesto',
        'Mercados e orçamento',
        'Märkte & Budget',
        'Pazarlar ve bütçe',
        'Pasar & anggaran',
        'মার্কেট ও বাজেট'
      );
  String get review => _get('Review', 'جائزہ', 'مراجعة',
        'समीक्षा',
        'Vérifier',
        'Revisar',
        'Revisar',
        'Überprüfen',
        'İncele',
        'Tinjau',
        'পর্যালোচনা'
      );
  String get continueBtn => _get('Continue', 'جاری رکھیں', 'متابعة',
        'जारी रखें',
        'Continuer',
        'Continuar',
        'Continuar',
        'Weiter',
        'Devam Et',
        'Lanjutkan',
        'চালিয়ে যান'
      );
  String get back => _get('Back', 'پیچھے', 'رجوع',
        'वापस',
        'Retour',
        'Atrás',
        'Voltar',
        'Zurück',
        'Geri',
        'Kembali',
        'পেছনে'
      );
  String get organic => _get(
        'AI Organic Growth',
        'AI آرگینک گروتھ',
        'النمو العضوي بالذكاء الاصطناعي',
      
        'AI ऑर्गेनिक ग्रोथ',
        'Croissance organique IA',
        'Crecimiento orgánico con IA',
        'Crescimento orgânico com IA',
        'KI-organisches Wachstum',
        'YZ Organik Büyüme',
        'Pertumbuhan Organik AI',
        'AI অর্গানিক গ্রোথ'
      );
  String get organicDesc => _get(
        'No ad budget. AI optimizes content & discovery.',
        'بغیر اشتہاری بجٹ — AI مواد اور دریافت کو بہتر بناتا ہے۔',
        'بدون ميزانية إعلانية. يحسِّن الذكاء الاصطناعي المحتوى والاكتشاف.',
      
        'कोई विज्ञापन बजट नहीं। AI कंटेंट और डिस्कवरी को बेहतर बनाता है।',
        'Sans budget publicitaire. L\'IA optimise le contenu et la découverte.',
        'Sin presupuesto publicitario. La IA optimiza el contenido y el descubrimiento.',
        'Sem orçamento de anúncios. A IA otimiza o conteúdo e a descoberta.',
        'Kein Werbebudget. Die KI optimiert Inhalte & Entdeckung.',
        'Reklam bütçesi yok. YZ içerik ve keşfi optimize eder.',
        'Tanpa anggaran iklan. AI mengoptimalkan konten & penemuan.',
        'কোনো বিজ্ঞাপন বাজেট নেই। AI কনটেন্ট ও ডিসকভারি অপটিমাইজ করে।'
      );
  String get paid =>
      _get('AI Paid Boost', 'AI پیڈ بوسٹ', 'التعزيز المدفوع بالذكاء الاصطناعي',
        'AI पेड बूस्ट',
        'Boost payant IA',
        'Impulso pagado con IA',
        'Impulso pago com IA',
        'KI Paid Boost',
        'YZ Ücretli Boost',
        'Boost Berbayar AI',
        'AI পেইড বুস্ট'
      );
  String get paidDesc => _get(
        'AI manages ads within your approved budget.',
        'AI آپ کے منظور شدہ بجٹ میں اشتہارات چلاتا ہے۔',
        'يدير الذكاء الاصطناعي الإعلانات ضمن ميزانيتك المعتمدة.',
      
        'AI आपके स्वीकृत बजट के भीतर विज्ञापन संभालता है।',
        'L\'IA gère les publicités dans ton budget approuvé.',
        'La IA gestiona los anuncios dentro de tu presupuesto aprobado.',
        'A IA gerencia os anúncios dentro do seu orçamento aprovado.',
        'Die KI verwaltet Anzeigen innerhalb deines genehmigten Budgets.',
        'YZ, onayladığın bütçe dahilinde reklamları yönetir.',
        'AI mengelola iklan dalam anggaran yang kamu setujui.',
        'AI আপনার অনুমোদিত বাজেটের মধ্যে বিজ্ঞাপন পরিচালনা করে।'
      );
  String get trustTitle => _get('Trust Center', 'ٹرسٹ سینٹر', 'مركز الثقة',
        'ट्रस्ट सेंटर',
        'Centre de confiance',
        'Centro de confianza',
        'Central de confiança',
        'Vertrauenszentrum',
        'Güven Merkezi',
        'Pusat Kepercayaan',
        'ট্রাস্ট সেন্টার'
      );
  String get neverFake => _get(
        'We never use fake engagement',
        'ہم کبھی جعلی انگیجمنٹ استعمال نہیں کرتے',
        'لا نستخدم التفاعل المزيَّف أبداً',
      
        'हम कभी नकली एंगेजमेंट इस्तेमाल नहीं करते',
        'On n\'utilise jamais de faux engagement',
        'Nunca usamos interacción falsa',
        'Nunca usamos engajamento falso',
        'Wir nutzen niemals gefälschte Interaktion',
        'Asla sahte etkileşim kullanmayız',
        'Kami tidak pernah menggunakan interaksi palsu',
        'আমরা কখনো ভুয়া এনগেজমেন্ট ব্যবহার করি না'
      );
  String get noGuarantees => _get(
        'No guaranteed virality — honest optimization & reporting.',
        'وائرل ہونے کی ضمانت نہیں — ایماندارانہ اصلاح اور رپورٹنگ۔',
        'لا ضمان للانتشار — تحسين وتقارير صادقة.',
      
        'वायरल होने की गारंटी नहीं — ईमानदार ऑप्टिमाइज़ेशन और रिपोर्टिंग।',
        'Pas de viralité garantie — optimisation et rapports honnêtes.',
        'Sin viralidad garantizada: optimización y reportes honestos.',
        'Sem viralidade garantida — otimização e relatórios honestos.',
        'Keine garantierte Viralität — ehrliche Optimierung & Berichte.',
        'Garantili viralite yok — dürüst optimizasyon ve raporlama.',
        'Tidak ada jaminan viral — optimasi & pelaporan yang jujur.',
        'ভাইরাল হওয়ার গ্যারান্টি নেই — সৎ অপটিমাইজেশন ও রিপোর্টিং।'
      );
  String get freePlan => _get('Free Plan', 'مفت پلان', 'الخطة المجانية',
        'फ्री प्लान',
        'Offre gratuite',
        'Plan gratuito',
        'Plano gratuito',
        'Kostenloser Plan',
        'Ücretsiz Plan',
        'Paket Gratis',
        'ফ্রি প্ল্যান'
      );
  String get goPremium =>
      _get('Go Premium', 'پریمیم لیں', 'الترقية إلى المميز',
        'प्रीमियम लें',
        'Passer Premium',
        'Hazte Premium',
        'Assine o Premium',
        'Premium holen',
        'Premium\'e Geç',
        'Upgrade ke Premium',
        'প্রিমিয়াম নিন'
      );

  // Discovery → Analyze → Result → Save journey
  String get discover => _get('Discover', 'دریافت کریں', 'اكتشف',
        'डिस्कवर',
        'Découvrir',
        'Descubrir',
        'Descobrir',
        'Entdecken',
        'Keşfet',
        'Temukan',
        'ডিসকভার'
      );
  String get discoverTagline => _get(
        'Content matched to your interests — by real interest, never fake engagement.',
        'آپ کی دلچسپیوں کے مطابق مواد — حقیقی دلچسپی سے، کبھی جعلی انگیجمنٹ نہیں۔',
        'محتوى يطابق اهتماماتك — باهتمام حقيقي، لا تفاعل مزيَّف أبداً.',
      
        'आपकी रुचियों से मेल खाता कंटेंट — असली रुचि से, कभी नकली एंगेजमेंट नहीं।',
        'Du contenu adapté à tes centres d\'intérêt — par intérêt réel, jamais de faux engagement.',
        'Contenido acorde a tus intereses, por interés real, nunca interacción falsa.',
        'Conteúdo alinhado aos seus interesses — por interesse real, nunca engajamento falso.',
        'Inhalte passend zu deinen Interessen — durch echtes Interesse, niemals gefälschte Interaktion.',
        'İlgi alanlarına uygun içerik — gerçek ilgiyle, asla sahte etkileşim yok.',
        'Konten yang sesuai minatmu — dari minat asli, bukan interaksi palsu.',
        'আপনার আগ্রহের সাথে মিলিয়ে কনটেন্ট — আসল আগ্রহ থেকে, কখনো ভুয়া এনগেজমেন্ট নয়।'
      );
  String get analyze => _get('Analyze', 'تجزیہ کریں', 'حلِّل',
        'विश्लेषण',
        'Analyser',
        'Analizar',
        'Analisar',
        'Analysieren',
        'Analiz Et',
        'Analisis',
        'বিশ্লেষণ'
      );
  String get analyzing =>
      _get('Analyzing…', 'تجزیہ ہو رہا ہے…', 'جارٍ التحليل…',
        'विश्लेषण हो रहा है…',
        'Analyse en cours…',
        'Analizando…',
        'Analisando…',
        'Wird analysiert…',
        'Analiz ediliyor…',
        'Menganalisis…',
        'বিশ্লেষণ চলছে…'
      );
  String get analyzingSub => _get(
        'Fetching the post and scoring its packaging.',
        'پوسٹ حاصل کر کے اس کی پیشکش کا اسکور بنایا جا رہا ہے۔',
        'جارٍ جلب المنشور وتقييم عرضه.',
      
        'पोस्ट लाई जा रही है और उसकी पैकेजिंग का स्कोर बनाया जा रहा है।',
        'On récupère le post et on évalue sa présentation.',
        'Obteniendo la publicación y puntuando su presentación.',
        'Buscando a publicação e avaliando sua apresentação.',
        'Beitrag wird abgerufen und seine Aufmachung bewertet.',
        'Gönderi alınıyor ve sunumu puanlanıyor.',
        'Mengambil postingan dan menilai kemasannya.',
        'পোস্ট আনা হচ্ছে এবং এর উপস্থাপনের স্কোর করা হচ্ছে।'
      );
  String get yourInterests =>
      _get('Your interests', 'آپ کی دلچسپیاں', 'اهتماماتك',
        'आपकी रुचियां',
        'Tes centres d\'intérêt',
        'Tus intereses',
        'Seus interesses',
        'Deine Interessen',
        'İlgi alanların',
        'Minatmu',
        'আপনার আগ্রহ'
      );
  String get recommendedForYou =>
      _get('Recommended for you', 'آپ کے لیے تجاویز', 'مُقترح لك',
        'आपके लिए सुझाव',
        'Recommandé pour toi',
        'Recomendado para ti',
        'Recomendado para você',
        'Für dich empfohlen',
        'Senin için önerilen',
        'Direkomendasikan untukmu',
        'আপনার জন্য প্রস্তাবিত'
      );
  String get whyThis => _get('Why this?', 'یہ کیوں؟', 'لماذا هذا؟',
        'यह क्यों?',
        'Pourquoi celui-ci ?',
        '¿Por qué esto?',
        'Por que este?',
        'Warum dieser?',
        'Neden bu?',
        'Kenapa ini?',
        'এটা কেন?'
      );
  String get tapToAnalyze =>
      _get('Tap to analyze', 'تجزیے کے لیے تھپتھپائیں', 'اضغط للتحليل',
        'विश्लेषण के लिए टैप करें',
        'Touche pour analyser',
        'Toca para analizar',
        'Toque para analisar',
        'Tippen zum Analysieren',
        'Analiz etmek için dokun',
        'Ketuk untuk menganalisis',
        'বিশ্লেষণ করতে ট্যাপ করুন'
      );
  String get contentScore =>
      _get('Content score', 'مواد کا اسکور', 'درجة المحتوى',
        'कंटेंट स्कोर',
        'Score du contenu',
        'Puntuación del contenido',
        'Pontuação do conteúdo',
        'Content-Score',
        'İçerik puanı',
        'Skor konten',
        'কনটেন্ট স্কোর'
      );
  String get save => _get('Save', 'محفوظ کریں', 'حفظ',
        'सेव करें',
        'Enregistrer',
        'Guardar',
        'Salvar',
        'Speichern',
        'Kaydet',
        'Simpan',
        'সেভ করুন'
      );
  String get saved => _get('Saved', 'محفوظ شدہ', 'محفوظ',
        'सेव किया गया',
        'Enregistré',
        'Guardado',
        'Salvo',
        'Gespeichert',
        'Kaydedildi',
        'Tersimpan',
        'সেভ হয়েছে'
      );
  String get savedDone => _get('Saved ✓', 'محفوظ ہو گیا ✓', 'تم الحفظ ✓',
        'सेव हो गया ✓',
        'Enregistré ✓',
        'Guardado ✓',
        'Salvo ✓',
        'Gespeichert ✓',
        'Kaydedildi ✓',
        'Tersimpan ✓',
        'সেভ হয়েছে ✓'
      );
  String get alreadySaved => _get(
        'Already in your saved list',
        'پہلے سے محفوظ شدہ فہرست میں ہے',
        'موجود مسبقاً في قائمتك المحفوظة',
      
        'पहले से आपकी सेव की गई सूची में है',
        'Déjà dans tes éléments enregistrés',
        'Ya está en tu lista de guardados',
        'Já está na sua lista de salvos',
        'Bereits in deiner gespeicherten Liste',
        'Zaten kayıtlı listende',
        'Sudah ada di daftar simpananmu',
        'ইতিমধ্যে আপনার সেভ করা তালিকায় আছে'
      );
  String get growThisPost =>
      _get('Grow this post', 'اس پوسٹ کو گرو کریں', 'نمِّ هذا المنشور',
        'इस पोस्ट को ग्रो करें',
        'Développe ce post',
        'Haz crecer esta publicación',
        'Faça esta publicação crescer',
        'Diesen Beitrag wachsen lassen',
        'Bu gönderiyi büyüt',
        'Kembangkan postingan ini',
        'এই পোস্টটি গ্রো করুন'
      );
  String get nothingHere =>
      _get('Nothing here yet.', 'ابھی یہاں کچھ نہیں۔', 'لا يوجد شيء هنا بعد.',
        'यहां अभी कुछ नहीं है।',
        'Rien ici pour l\'instant.',
        'Nada aquí todavía.',
        'Nada aqui ainda.',
        'Hier ist noch nichts.',
        'Burada henüz bir şey yok.',
        'Belum ada apa pun di sini.',
        'এখানে এখনো কিছু নেই।'
      );
  String get pickInterestsHint => _get(
        'Pick a few interests to get recommendations.',
        'تجاویز کے لیے چند دلچسپیاں منتخب کریں۔',
        'اختر بعض الاهتمامات للحصول على توصيات.',
      
        'सुझाव पाने के लिए कुछ रुचियां चुनें।',
        'Choisis quelques centres d\'intérêt pour recevoir des recommandations.',
        'Elige algunos intereses para recibir recomendaciones.',
        'Escolha alguns interesses para receber recomendações.',
        'Wähle ein paar Interessen, um Empfehlungen zu erhalten.',
        'Öneriler almak için birkaç ilgi alanı seç.',
        'Pilih beberapa minat untuk mendapatkan rekomendasi.',
        'প্রস্তাবনা পেতে কয়েকটি আগ্রহ বেছে নিন।'
      );
  String get invalidUrl => _get(
        'Please enter a valid http(s) link.',
        'براہ کرم درست لنک درج کریں۔',
        'يُرجى إدخال رابط http(s) صالح.',
      
        'कृपया एक मान्य http(s) लिंक दर्ज करें।',
        'Entre un lien http(s) valide.',
        'Ingresa un enlace http(s) válido.',
        'Insira um link http(s) válido.',
        'Bitte einen gültigen http(s)-Link eingeben.',
        'Lütfen geçerli bir http(s) bağlantısı gir.',
        'Masukkan tautan http(s) yang valid.',
        'একটি বৈধ http(s) লিংক দিন।'
      );
  String get analyzeFailed => _get(
        'Analysis failed. Check your connection and try again.',
        'تجزیہ ناکام ہوا۔ کنکشن چیک کر کے دوبارہ کوشش کریں۔',
        'فشل التحليل. تحقق من اتصالك وحاول مجدداً.',
      
        'विश्लेषण विफल रहा। अपना कनेक्शन जांचें और पुनः प्रयास करें।',
        'Échec de l\'analyse. Vérifie ta connexion et réessaie.',
        'Falló el análisis. Revisa tu conexión e inténtalo de nuevo.',
        'Falha na análise. Verifique sua conexão e tente novamente.',
        'Analyse fehlgeschlagen. Prüfe deine Verbindung und versuch es erneut.',
        'Analiz başarısız oldu. Bağlantını kontrol et ve tekrar dene.',
        'Analisis gagal. Periksa koneksimu dan coba lagi.',
        'বিশ্লেষণ ব্যর্থ হয়েছে। সংযোগ পরীক্ষা করে আবার চেষ্টা করুন।'
      );
  String get noTitle =>
      _get('Untitled post', 'بغیر عنوان پوسٹ', 'منشور بلا عنوان',
        'बिना शीर्षक वाली पोस्ट',
        'Post sans titre',
        'Publicación sin título',
        'Publicação sem título',
        'Beitrag ohne Titel',
        'Başlıksız gönderi',
        'Postingan tanpa judul',
        'শিরোনামহীন পোস্ট'
      );
  String get fetchLevelOembed => _get(
        'Rich preview fetched',
        'مکمل پیش نظارہ حاصل ہوا',
        'تم جلب معاينة غنية',
      
        'रिच प्रीव्यू लाया गया',
        'Aperçu enrichi récupéré',
        'Vista previa enriquecida obtenida',
        'Prévia avançada carregada',
        'Erweiterte Vorschau abgerufen',
        'Zengin önizleme alındı',
        'Pratinjau kaya dimuat',
        'রিচ প্রিভিউ আনা হয়েছে'
      );
  String get fetchLevelOpengraph =>
      _get('Preview fetched', 'پیش نظارہ حاصل ہوا', 'تم جلب المعاينة',
        'प्रीव्यू लाया गया',
        'Aperçu récupéré',
        'Vista previa obtenida',
        'Prévia carregada',
        'Vorschau abgerufen',
        'Önizleme alındı',
        'Pratinjau dimuat',
        'প্রিভিউ আনা হয়েছে'
      );
  String get fetchLevelMinimal => _get(
        'Link only — site blocked previews',
        'صرف لنک — سائٹ نے پیش نظارہ روکا',
        'الرابط فقط — الموقع حظر المعاينات',
      
        'सिर्फ लिंक — साइट ने प्रीव्यू ब्लॉक किया',
        'Lien uniquement — le site a bloqué les aperçus',
        'Solo enlace: el sitio bloqueó las vistas previas',
        'Apenas link — o site bloqueou as prévias',
        'Nur Link — Seite hat Vorschauen blockiert',
        'Yalnızca bağlantı — site önizlemeleri engelledi',
        'Hanya tautan — situs memblokir pratinjau',
        'শুধু লিংক — সাইট প্রিভিউ ব্লক করেছে'
      );
  String get estimatedNote => _get(
        'Heuristic estimate — not a prediction or guarantee of reach.',
        'اندازاً جائزہ — رسائی کی پیشگوئی یا ضمانت نہیں۔',
        'تقدير تقريبي — ليس توقعاً أو ضماناً للوصول.',
      
        'अनुमानित आंकड़ा — रीच की भविष्यवाणी या गारंटी नहीं।',
        'Estimation approximative — ni prédiction ni garantie de portée.',
        'Estimación aproximada: no es una predicción ni garantía de alcance.',
        'Estimativa aproximada — não é previsão nem garantia de alcance.',
        'Grobe Schätzung — keine Vorhersage oder Garantie der Reichweite.',
        'Yaklaşık tahmin — erişim öngörüsü veya garantisi değildir.',
        'Perkiraan kasar — bukan prediksi atau jaminan jangkauan.',
        'আনুমানিক হিসাব — রিচের পূর্বাভাস বা গ্যারান্টি নয়।'
      );

  // Auth (email OTP — never social passwords)
  String get signInTitle => _get(
        'Sign in with email',
        'ای میل سے سائن ان کریں',
        'تسجيل الدخول بالبريد الإلكتروني',
      
        'ईमेल से साइन इन करें',
        'Se connecter avec un e-mail',
        'Iniciar sesión con correo',
        'Entrar com e-mail',
        'Mit E-Mail anmelden',
        'E-postayla giriş yap',
        'Masuk dengan email',
        'ইমেইল দিয়ে সাইন ইন করুন'
      );
  String get emailHint =>
      _get('you@example.com', 'you@example.com', 'you@example.com',
        'you@example.com',
        'you@example.com',
        'you@example.com',
        'you@example.com',
        'you@example.com',
        'you@example.com',
        'you@example.com',
        'you@example.com'
      );
  String get enterCode => _get(
        'Enter the code we emailed you',
        'ای میل پر بھیجا گیا کوڈ درج کریں',
        'أدخل الرمز الذي أرسلناه إلى بريدك',
      
        'हमने जो कोड ईमेल किया है, उसे दर्ज करें',
        'Entre le code qu\'on t\'a envoyé par e-mail',
        'Ingresa el código que te enviamos por correo',
        'Digite o código que enviamos para seu e-mail',
        'Gib den Code ein, den wir dir per E-Mail geschickt haben',
        'Sana e-postayla gönderdiğimiz kodu gir',
        'Masukkan kode yang kami kirim ke emailmu',
        'আমরা যে কোডটি ইমেইলে পাঠিয়েছি তা লিখুন'
      );
  String get codeHint =>
      _get('6-digit code', '6 ہندسوں کا کوڈ', 'رمز من 6 أرقام',
        '6 अंकों का कोड',
        'Code à 6 chiffres',
        'Código de 6 dígitos',
        'Código de 6 dígitos',
        '6-stelliger Code',
        '6 haneli kod',
        'Kode 6 digit',
        '৬-সংখ্যার কোড'
      );
  String get useDifferentEmail => _get(
        'Use a different email',
        'مختلف ای میل استعمال کریں',
        'استخدام بريد إلكتروني مختلف',
      
        'कोई दूसरा ईमेल इस्तेमाल करें',
        'Utiliser un autre e-mail',
        'Usar otro correo',
        'Usar outro e-mail',
        'Andere E-Mail verwenden',
        'Farklı bir e-posta kullan',
        'Gunakan email lain',
        'অন্য ইমেইল ব্যবহার করুন'
      );
  String get verify => _get('Verify', 'تصدیق کریں', 'تحقق',
        'सत्यापित करें',
        'Vérifier',
        'Verificar',
        'Verificar',
        'Bestätigen',
        'Doğrula',
        'Verifikasi',
        'যাচাই করুন'
      );
  String get invalidEmail => _get(
        'Please enter a valid email address.',
        'براہ کرم درست ای میل درج کریں۔',
        'يُرجى إدخال بريد إلكتروني صالح.',
      
        'कृपया एक मान्य ईमेल पता दर्ज करें।',
        'Entre une adresse e-mail valide.',
        'Ingresa una dirección de correo válida.',
        'Insira um endereço de e-mail válido.',
        'Bitte eine gültige E-Mail-Adresse eingeben.',
        'Lütfen geçerli bir e-posta adresi gir.',
        'Masukkan alamat email yang valid.',
        'একটি বৈধ ইমেইল ঠিকানা দিন।'
      );
  String get invalidCode => _get(
        'Invalid or expired code. Try again.',
        'غلط یا پرانا کوڈ۔ دوبارہ کوشش کریں۔',
        'رمز غير صالح أو منتهٍ. حاول مجدداً.',
      
        'अमान्य या एक्सपायर्ड कोड। पुनः प्रयास करें।',
        'Code invalide ou expiré. Réessaie.',
        'Código inválido o vencido. Inténtalo de nuevo.',
        'Código inválido ou expirado. Tente novamente.',
        'Ungültiger oder abgelaufener Code. Versuch es erneut.',
        'Geçersiz veya süresi dolmuş kod. Tekrar dene.',
        'Kode tidak valid atau kedaluwarsa. Coba lagi.',
        'অবৈধ বা মেয়াদোত্তীর্ণ কোড। আবার চেষ্টা করুন।'
      );
  String get signInFailed => _get(
        'Sign-in failed. Check your connection and try again.',
        'سائن ان ناکام۔ کنکشن چیک کر کے دوبارہ کوشش کریں۔',
        'فشل تسجيل الدخول. تحقق من اتصالك وحاول مجدداً.',
      
        'साइन इन विफल रहा। अपना कनेक्शन जांचें और पुनः प्रयास करें।',
        'Échec de la connexion. Vérifie ta connexion et réessaie.',
        'Error al iniciar sesión. Revisa tu conexión e inténtalo de nuevo.',
        'Falha no login. Verifique sua conexão e tente novamente.',
        'Anmeldung fehlgeschlagen. Prüfe deine Verbindung und versuch es erneut.',
        'Giriş başarısız oldu. Bağlantını kontrol et ve tekrar dene.',
        'Gagal masuk. Periksa koneksimu dan coba lagi.',
        'সাইন ইন ব্যর্থ হয়েছে। সংযোগ পরীক্ষা করে আবার চেষ্টা করুন।'
      );
  String get sessionExpired => _get(
        'Session expired. Please sign in again.',
        'سیشن ختم۔ دوبارہ سائن ان کریں۔',
        'انتهت الجلسة. يُرجى تسجيل الدخول مجدداً.',
      
        'सेशन समाप्त हो गया। कृपया फिर से साइन इन करें।',
        'Session expirée. Reconnecte-toi.',
        'Sesión vencida. Inicia sesión de nuevo.',
        'Sessão expirada. Entre novamente.',
        'Sitzung abgelaufen. Bitte melde dich erneut an.',
        'Oturumun süresi doldu. Lütfen tekrar giriş yap.',
        'Sesi kedaluwarsa. Silakan masuk lagi.',
        'সেশন শেষ হয়ে গেছে। আবার সাইন ইন করুন।'
      );
  // --- Social sign-in (Google / Apple) ---
  String get orContinueWith =>
      _get('or continue with', 'یا جاری رکھیں', 'أو تابع باستخدام',
        'या जारी रखें',
        'ou continuer avec',
        'o continúa con',
        'ou continue com',
        'oder weiter mit',
        'veya şununla devam et',
        'atau lanjutkan dengan',
        'অথবা চালিয়ে যান'
      );
  String get continueWithGoogle => _get(
        'Continue with Google',
        'Google سے جاری رکھیں',
        'المتابعة باستخدام Google',
      
        'Google से जारी रखें',
        'Continuer avec Google',
        'Continuar con Google',
        'Continuar com o Google',
        'Mit Google fortfahren',
        'Google ile devam et',
        'Lanjutkan dengan Google',
        'Google দিয়ে চালিয়ে যান'
      );
  String get socialSignInFailed => _get(
        'Social sign-in failed. Try email code instead.',
        'سوشل سائن ان ناکام۔ ای میل کوڈ استعمال کریں۔',
        'فشل تسجيل الدخول الاجتماعي. جرّب رمز البريد الإلكتروني.',
      
        'सोशल साइन इन विफल रहा। ईमेल कोड आज़माएं।',
        'Connexion sociale échouée. Essaie plutôt le code e-mail.',
        'Error en el inicio de sesión social. Prueba con el código de correo.',
        'Falha no login social. Tente o código por e-mail.',
        'Soziale Anmeldung fehlgeschlagen. Versuch es stattdessen mit dem E-Mail-Code.',
        'Sosyal giriş başarısız oldu. Bunun yerine e-posta kodunu dene.',
        'Login sosial gagal. Coba kode email saja.',
        'সোশ্যাল সাইন ইন ব্যর্থ হয়েছে। ইমেইল কোড ব্যবহার করুন।'
      );
  String get noPasswordsNote => _get(
        'We never ask for your social-media passwords.',
        'ہم کبھی آپ کے سوشل میڈیا پاس ورڈ نہیں مانگتے۔',
        'لا نطلب كلمات مرور حساباتك الاجتماعية أبداً.',
      
        'हम कभी आपके सोशल मीडिया पासवर्ड नहीं मांगते।',
        'On ne te demande jamais tes mots de passe de réseaux sociaux.',
        'Nunca te pedimos las contraseñas de tus redes sociales.',
        'Nunca pedimos suas senhas de redes sociais.',
        'Wir fragen niemals nach deinen Social-Media-Passwörtern.',
        'Sosyal medya şifrelerini asla istemeyiz.',
        'Kami tidak pernah meminta kata sandi media sosialmu.',
        'আমরা কখনো আপনার সোশ্যাল মিডিয়া পাসওয়ার্ড চাই না।'
      );
  // --- Reddit-style login redesign ---
  String get logInTitle => _get('Log In', 'لاگ ان', 'تسجيل الدخول',
        'लॉग इन',
        'Connexion',
        'Iniciar sesión',
        'Entrar',
        'Anmelden',
        'Giriş Yap',
        'Masuk',
        'লগ ইন'
      );
  String get loginAgreementLead => _get(
        'By continuing, you agree to our ',
        'جاری رکھ کر آپ ہماری ',
        'بالمتابعة، أنت توافق على ',
      
        'जारी रखकर आप हमारे ',
        'En continuant, tu acceptes nos ',
        'Al continuar, aceptas nuestras ',
        'Ao continuar, você concorda com os ',
        'Durch Fortfahren akzeptierst du: ',
        'Devam ederek şunları kabul ediyorsun: ',
        'Dengan melanjutkan, kamu menyetujui ',
        'চালিয়ে যাওয়ার মাধ্যমে আপনি সম্মত হচ্ছেন: '
      );
  String get userAgreement =>
      _get('User Agreement', 'یوزر ایگریمنٹ', 'اتفاقية المستخدم',
        'उपयोगकर्ता अनुबंध',
        'Conditions d\'utilisation',
        'Condiciones de uso',
        'Termos de uso',
        'Nutzungsbedingungen',
        'Kullanıcı Sözleşmesi',
        'Perjanjian Pengguna',
        'ব্যবহারকারী চুক্তি'
      );
  String get loginAgreementMid => _get(
        ' and acknowledge that you understand the ',
        ' سے اتفاق کرتے ہیں اور تسلیم کرتے ہیں کہ آپ نے ',
        ' وتقر بأنك تفهم ',
      
        ' से सहमत हैं और समझते हैं ',
        ' et tu reconnais avoir compris la ',
        ' y reconoces haber leído la ',
        ' e reconhece que leu a ',
        ' und ',
        ', ',
        ' dan menyatakan telah memahami ',
        ' ও '
      );
  String get privacyPolicy =>
      _get('Privacy Policy', 'پرائیویسی پالیسی', 'سياسة الخصوصية',
        'गोपनीयता नीति',
        'Politique de confidentialité',
        'Política de privacidad',
        'Política de privacidade',
        'Datenschutzerklärung',
        'Gizlilik Politikası',
        'Kebijakan Privasi',
        'গোপনীয়তা নীতি'
      );
  String get policySoon => _get(
        'Available after production setup.',
        'پروڈکشن سیٹ اپ کے بعد دستیاب ہوگا۔',
        'متاح بعد إعداد الإنتاج.',
      
        'प्रोडक्शन सेटअप के बाद उपलब्ध होगा।',
        'Disponible après la mise en production.',
        'Disponible tras la configuración de producción.',
        'Disponível após a configuração de produção.',
        'Nach dem Produktions-Setup verfügbar.',
        'Üretim kurulumundan sonra kullanılabilir.',
        'Tersedia setelah penyiapan produksi.',
        'প্রোডাকশন সেটআপের পর উপলব্ধ হবে।'
      );
  String get continueWithApple => _get(
        'Continue with Apple',
        'Apple سے جاری رکھیں',
        'المتابعة باستخدام Apple',
      
        'Apple से जारी रखें',
        'Continuer avec Apple',
        'Continuar con Apple',
        'Continuar com a Apple',
        'Mit Apple fortfahren',
        'Apple ile devam et',
        'Lanjutkan dengan Apple',
        'Apple দিয়ে চালিয়ে যান'
      );
  String get emailMeCode => _get(
        'Email me a one-time code',
        'مجھے ون ٹائم کوڈ ای میل کریں',
        'أرسل لي رمز تحقق لمرة واحدة',
      
        'मुझे वन-टाइम कोड ईमेल करें',
        'Envoie-moi un code unique',
        'Envíame un código de un solo uso',
        'Envie-me um código único',
        'Schick mir einen Einmal-Code',
        'Bana tek kullanımlık kod e-postala',
        'Kirimkan kode sekali pakai ke emailku',
        'আমাকে একবার ব্যবহারযোগ্য কোড ইমেইল করুন'
      );
  String get orDivider => _get('OR', 'یا', 'أو',
        'या',
        'OU',
        'O',
        'OU',
        'ODER',
        'VEYA',
        'ATAU',
        'অথবা'
      );
  String get emailLabel => _get('Email', 'ای میل', 'البريد الإلكتروني',
        'ईमेल',
        'E-mail',
        'Correo electrónico',
        'E-mail',
        'E-Mail',
        'E-posta',
        'Email',
        'ইমেইল'
      );
  String get newToVirello =>
      _get('New to Virello?', 'Virello میں نئے ہیں؟', 'جديد على Virello؟',
        'Virello पर नए हैं?',
        'Nouveau sur Virello ?',
        '¿Nuevo en Virello?',
        'Novo no Virello?',
        'Neu bei Virello?',
        'Virello\'da yeni misin?',
        'Baru di Virello?',
        'Virello-তে নতুন?'
      );
  String get signUpLink => _get('Sign Up', 'سائن اپ کریں', 'سجّل',
        'साइन अप करें',
        'S\'inscrire',
        'Registrarse',
        'Cadastrar-se',
        'Registrieren',
        'Kaydol',
        'Daftar',
        'সাইন আপ করুন'
      );
  String get signOut => _get('Sign out', 'سائن آؤٹ', 'تسجيل الخروج',
        'साइन आउट करें',
        'Se déconnecter',
        'Cerrar sesión',
        'Sair',
        'Abmelden',
        'Çıkış yap',
        'Keluar',
        'সাইন আউট করুন'
      );
  // --- Email + password auth ---
  String get logInBtn => _get('Log In', 'لاگ ان کریں', 'تسجيل الدخول',
        'लॉग इन करें',
        'Se connecter',
        'Iniciar sesión',
        'Entrar',
        'Anmelden',
        'Giriş Yap',
        'Masuk',
        'লগ ইন করুন'
      );
  String get passwordLabel => _get('Password', 'پاس ورڈ', 'كلمة المرور',
        'पासवर्ड',
        'Mot de passe',
        'Contraseña',
        'Senha',
        'Passwort',
        'Şifre',
        'Kata sandi',
        'পাসওয়ার্ড'
      );
  String get passwordHint =>
      _get('Enter your password', 'اپنا پاس ورڈ لکھیں', 'أدخل كلمة المرور',
        'अपना पासवर्ड दर्ज करें',
        'Entre ton mot de passe',
        'Ingresa tu contraseña',
        'Digite sua senha',
        'Gib dein Passwort ein',
        'Şifreni gir',
        'Masukkan kata sandimu',
        'আপনার পাসওয়ার্ড লিখুন'
      );
  String get forgotPassword =>
      _get('Forgot password?', 'پاس ورڈ بھول گئے؟', 'نسيت كلمة المرور؟',
        'पासवर्ड भूल गए?',
        'Mot de passe oublié ?',
        '¿Olvidaste tu contraseña?',
        'Esqueceu a senha?',
        'Passwort vergessen?',
        'Şifreni mi unuttun?',
        'Lupa kata sandi?',
        'পাসওয়ার্ড ভুলে গেছেন?'
      );
  String get signUpTitle =>
      _get('Create your account', 'اپنا اکاؤنٹ بنائیں', 'أنشئ حسابك',
        'अपना अकाउंट बनाएं',
        'Crée ton compte',
        'Crea tu cuenta',
        'Crie sua conta',
        'Erstelle dein Konto',
        'Hesabını oluştur',
        'Buat akunmu',
        'আপনার অ্যাকাউন্ট তৈরি করুন'
      );
  String get nameLabelOptional => _get(
        'Full name (optional)',
        'پورا نام (اختیاری)',
        'الاسم الكامل (اختياري)',
      
        'पूरा नाम (वैकल्पिक)',
        'Nom complet (facultatif)',
        'Nombre completo (opcional)',
        'Nome completo (opcional)',
        'Vollständiger Name (optional)',
        'Ad Soyad (isteğe bağlı)',
        'Nama lengkap (opsional)',
        'পুরো নাম (ঐচ্ছিক)'
      );
  String get confirmPasswordLabel =>
      _get('Confirm password', 'پاس ورڈ کی تصدیق', 'تأكيد كلمة المرور',
        'पासवर्ड की पुष्टि करें',
        'Confirme le mot de passe',
        'Confirma la contraseña',
        'Confirme a senha',
        'Passwort bestätigen',
        'Şifreyi onayla',
        'Konfirmasi kata sandi',
        'পাসওয়ার্ড নিশ্চিত করুন'
      );
  String get signUpBtn => _get('Sign Up', 'سائن اپ کریں', 'إنشاء الحساب',
        'साइन अप करें',
        'Créer mon compte',
        'Crear cuenta',
        'Criar conta',
        'Konto erstellen',
        'Hesap oluştur',
        'Buat akun',
        'অ্যাকাউন্ট তৈরি করুন'
      );
  String get alreadyHaveAccountQ => _get(
        'Already have an account?',
        'پہلے سے اکاؤنٹ ہے؟',
        'لديك حساب بالفعل؟',
      
        'पहले से अकाउंट है?',
        'Tu as déjà un compte ?',
        '¿Ya tienes una cuenta?',
        'Já tem uma conta?',
        'Hast du schon ein Konto?',
        'Zaten hesabın var mı?',
        'Sudah punya akun?',
        'ইতিমধ্যে অ্যাকাউন্ট আছে?'
      );
  String get logInLink => _get('Log In', 'لاگ ان', 'تسجيل الدخول',
        'लॉग इन',
        'Se connecter',
        'Iniciar sesión',
        'Entrar',
        'Anmelden',
        'Giriş yap',
        'Masuk',
        'লগ ইন'
      );
  String get resetPasswordTitle =>
      _get('Reset password', 'پاس ورڈ ری سیٹ کریں', 'إعادة تعيين كلمة المرور',
        'पासवर्ड रीसेट करें',
        'Réinitialisation du mot de passe',
        'Restablecer contraseña',
        'Redefinir senha',
        'Passwort zurücksetzen',
        'Şifre sıfırlama',
        'Atur ulang kata sandi',
        'পাসওয়ার্ড রিসেট'
      );
  String get sendCodeBtn => _get('Send code', 'کوڈ بھیجیں', 'إرسال الرمز',
        'कोड भेजें',
        'Envoyer le code',
        'Enviar código',
        'Enviar código',
        'Code senden',
        'Kodu gönder',
        'Kirim kode',
        'কোড পাঠান'
      );
  String get codeSentTo =>
      _get('Code sent to', 'کوڈ بھیجا گیا', 'تم إرسال الرمز إلى',
        'कोड भेजा गया',
        'Code envoyé à',
        'Código enviado a',
        'Código enviado para',
        'Code gesendet an',
        'Kod şuraya gönderildi:',
        'Kode dikirim ke',
        'কোড পাঠানো হয়েছে'
      );
  String get newPasswordLabel =>
      _get('New password', 'نیا پاس ورڈ', 'كلمة مرور جديدة',
        'नया पासवर्ड',
        'Nouveau mot de passe',
        'Nueva contraseña',
        'Nova senha',
        'Neues Passwort',
        'Yeni şifre',
        'Kata sandi baru',
        'নতুন পাসওয়ার্ড'
      );
  String get resetPasswordBtn =>
      _get('Reset password', 'پاس ورڈ ری سیٹ کریں', 'إعادة تعيين كلمة المرور',
        'पासवर्ड रीसेट करें',
        'Réinitialiser le mot de passe',
        'Restablecer contraseña',
        'Redefinir senha',
        'Passwort zurücksetzen',
        'Şifreyi sıfırla',
        'Atur ulang kata sandi',
        'পাসওয়ার্ড রিসেট করুন'
      );
  String get passwordTooShort => _get(
        'Password must be at least 8 characters.',
        'پاس ورڈ کم از کم 8 حروف کا ہو۔',
        'يجب أن تتكون كلمة المرور من 8 أحرف على الأقل.',
      
        'पासवर्ड कम से कम 8 अक्षरों का होना चाहिए।',
        'Le mot de passe doit comporter au moins 8 caractères.',
        'La contraseña debe tener al menos 8 caracteres.',
        'A senha deve ter pelo menos 8 caracteres.',
        'Das Passwort muss mindestens 8 Zeichen lang sein.',
        'Şifre en az 8 karakter olmalı.',
        'Kata sandi minimal 8 karakter.',
        'পাসওয়ার্ড কমপক্ষে ৮ অক্ষরের হতে হবে।'
      );
  String get passwordsDontMatch => _get(
        "Passwords don't match.",
        'پاس ورڈ آپس میں نہیں ملتے۔',
        'كلمتا المرور غير متطابقتين.',
      
        'पासवर्ड मेल नहीं खा रहे।',
        'Les mots de passe ne correspondent pas.',
        'Las contraseñas no coinciden.',
        'As senhas não coincidem.',
        'Die Passwörter stimmen nicht überein.',
        'Şifreler eşleşmiyor.',
        'Kata sandi tidak cocok.',
        'পাসওয়ার্ড মিলছে না।'
      );
  String get accountExistsSignIn => _get(
        'An account with this email already exists. Sign in instead, or use Forgot password to set a password.',
        'اس ای میل سے اکاؤنٹ پہلے سے موجود ہے۔ لاگ ان کریں یا پاس ورڈ سیٹ کرنے کے لیے Forgot password استعمال کریں۔',
        'يوجد حساب بهذا البريد بالفعل. سجّل الدخول أو استخدم "نسيت كلمة المرور" لتعيين كلمة مرور.',
      
        'इस ईमेल से अकाउंट पहले से मौजूद है। लॉग इन करें, या पासवर्ड सेट करने के लिए \'पासवर्ड भूल गए?\' इस्तेमाल करें।',
        'Un compte existe déjà avec cet e-mail. Connecte-toi, ou utilise « Mot de passe oublié ? » pour définir un mot de passe.',
        'Ya existe una cuenta con este correo. Inicia sesión o usa «¿Olvidaste tu contraseña?» para crear una.',
        'Já existe uma conta com este e-mail. Entre ou use «Esqueceu a senha?» para definir uma senha.',
        'Mit dieser E-Mail existiert bereits ein Konto. Melde dich an oder nutze „Passwort vergessen?“, um ein Passwort festzulegen.',
        'Bu e-postayla zaten bir hesap var. Giriş yap veya şifre belirlemek için \'Şifreni mi unuttun?\' seçeneğini kullan.',
        'Sudah ada akun dengan email ini. Masuk saja, atau gunakan \'Lupa kata sandi?\' untuk membuat kata sandi.',
        'এই ইমেইলে ইতিমধ্যে একটি অ্যাকাউন্ট আছে। লগ ইন করুন, অথবা পাসওয়ার্ড সেট করতে \'পাসওয়ার্ড ভুলে গেছেন?\' ব্যবহার করুন।'
      );
  String get invalidEmailOrPassword => _get(
        'Invalid email or password.',
        'ای میل یا پاس ورڈ غلط ہے۔',
        'البريد الإلكتروني أو كلمة المرور غير صحيحة.',
      
        'ईमेल या पासवर्ड गलत है।',
        'E-mail ou mot de passe invalide.',
        'Correo o contraseña inválidos.',
        'E-mail ou senha inválidos.',
        'E-Mail oder Passwort ungültig.',
        'E-posta veya şifre hatalı.',
        'Email atau kata sandi salah.',
        'ইমেইল বা পাসওয়ার্ড ভুল।'
      );
  String get tooManyAttempts => _get(
        'Too many attempts. Try again in a few minutes.',
        'بہت سی کوششیں۔ چند منٹ بعد دوبارہ کوشش کریں۔',
        'محاولات كثيرة. حاول مجدداً بعد بضع دقائق.',
      
        'बहुत ज़्यादा प्रयास। कुछ मिनट बाद पुनः प्रयास करें।',
        'Trop de tentatives. Réessaie dans quelques minutes.',
        'Demasiados intentos. Inténtalo de nuevo en unos minutos.',
        'Muitas tentativas. Tente novamente em alguns minutos.',
        'Zu viele Versuche. Versuch es in ein paar Minuten erneut.',
        'Çok fazla deneme. Birkaç dakika sonra tekrar dene.',
        'Terlalu banyak percobaan. Coba lagi dalam beberapa menit.',
        'অনেক বেশি চেষ্টা। কয়েক মিনিট পর আবার চেষ্টা করুন।'
      );
  // --- Settings page ---
  String get settingsTitle => _get('Settings', 'سیٹنگز', 'الإعدادات',
        'सेटिंग्स',
        'Paramètres',
        'Ajustes',
        'Configurações',
        'Einstellungen',
        'Ayarlar',
        'Pengaturan',
        'সেটিংস'
      );
  String get accountSection => _get('Account', 'اکاؤنٹ', 'الحساب',
        'अकाउंट',
        'Compte',
        'Cuenta',
        'Conta',
        'Konto',
        'Hesap',
        'Akun',
        'অ্যাকাউন্ট'
      );
  String get preferencesSection => _get('Preferences', 'ترجیحات', 'التفضيلات',
        'प्राथमिकताएं',
        'Préférences',
        'Preferencias',
        'Preferências',
        'Präferenzen',
        'Tercihler',
        'Preferensi',
        'পছন্দসমূহ'
      );
  String get planBillingSection =>
      _get('Plan & Billing', 'پلان اور بلنگ', 'الخطة والفوترة',
        'प्लान और बिलिंग',
        'Formule et facturation',
        'Plan y facturación',
        'Plano e cobrança',
        'Plan & Abrechnung',
        'Plan ve Faturalandırma',
        'Paket & Penagihan',
        'প্ল্যান ও বিলিং'
      );
  String get trustLegalSection =>
      _get('Trust & Legal', 'اعتماد اور قانونی', 'الثقة والقانون',
        'ट्रस्ट और कानूनी',
        'Confiance et mentions légales',
        'Confianza y legal',
        'Confiança e jurídico',
        'Vertrauen & Rechtliches',
        'Güven ve Yasal',
        'Kepercayaan & Hukum',
        'ট্রাস্ট ও আইনি'
      );
  String get supportSection => _get('Support', 'سپورٹ', 'الدعم',
        'सपोर्ट',
        'Assistance',
        'Ayuda',
        'Suporte',
        'Hilfe',
        'Destek',
        'Dukungan',
        'সাপোর্ট'
      );
  String get aboutSection => _get('About', 'کے بارے میں', 'حول',
        'बारे में',
        'À propos',
        'Acerca de',
        'Sobre',
        'Über',
        'Hakkında',
        'Tentang',
        'সম্পর্কে'
      );
  String get changePasswordTitle =>
      _get('Change password', 'پاس ورڈ تبدیل کریں', 'تغيير كلمة المرور',
        'पासवर्ड बदलें',
        'Changer le mot de passe',
        'Cambiar contraseña',
        'Alterar senha',
        'Passwort ändern',
        'Şifreyi değiştir',
        'Ubah kata sandi',
        'পাসওয়ার্ড পরিবর্তন করুন'
      );
  String get currentPasswordLabel =>
      _get('Current password', 'موجودہ پاس ورڈ', 'كلمة المرور الحالية',
        'वर्तमान पासवर्ड',
        'Mot de passe actuel',
        'Contraseña actual',
        'Senha atual',
        'Aktuelles Passwort',
        'Mevcut şifre',
        'Kata sandi saat ini',
        'বর্তমান পাসওয়ার্ড'
      );
  String get passwordChangedOk => _get(
        'Password changed successfully.',
        'پاس ورڈ کامیابی سے تبدیل ہو گیا۔',
        'تم تغيير كلمة المرور بنجاح.',
      
        'पासवर्ड सफलतापूर्वक बदल गया।',
        'Mot de passe modifié avec succès.',
        'Contraseña cambiada correctamente.',
        'Senha alterada com sucesso.',
        'Passwort erfolgreich geändert.',
        'Şifre başarıyla değiştirildi.',
        'Kata sandi berhasil diubah.',
        'পাসওয়ার্ড সফলভাবে পরিবর্তন হয়েছে।'
      );
  String get currentPasswordWrong => _get(
        'Current password is incorrect.',
        'موجودہ پاس ورڈ غلط ہے۔',
        'كلمة المرور الحالية غير صحيحة.',
      
        'वर्तमान पासवर्ड गलत है।',
        'Le mot de passe actuel est incorrect.',
        'La contraseña actual es incorrecta.',
        'A senha atual está incorreta.',
        'Das aktuelle Passwort ist falsch.',
        'Mevcut şifre hatalı.',
        'Kata sandi saat ini salah.',
        'বর্তমান পাসওয়ার্ড ভুল।'
      );
  String get noPasswordYet => _get(
        'This account has no password yet. Use "Forgot password?" on the login screen to set one.',
        'اس اکاؤنٹ کا ابھی کوئی پاس ورڈ نہیں۔ سیٹ کرنے کے لیے لاگ ان اسکرین پر "Forgot password?" استعمال کریں۔',
        'لا توجد كلمة مرور لهذا الحساب بعد. استخدم "نسيت كلمة المرور؟" في شاشة الدخول لتعيين واحدة.',
      
        'इस अकाउंट में अभी कोई पासवर्ड नहीं है। सेट करने के लिए लॉगिन स्क्रीन पर \'पासवर्ड भूल गए?\' इस्तेमाल करें।',
        'Ce compte n\'a pas encore de mot de passe. Utilise « Mot de passe oublié ? » sur l\'écran de connexion pour en définir un.',
        'Esta cuenta aún no tiene contraseña. Usa «¿Olvidaste tu contraseña?» en la pantalla de inicio de sesión para crear una.',
        'Esta conta ainda não tem senha. Use «Esqueceu a senha?» na tela de login para definir uma.',
        'Dieses Konto hat noch kein Passwort. Nutze „Passwort vergessen?“ auf dem Anmeldebildschirm, um eines festzulegen.',
        'Bu hesapta henüz şifre yok. Belirlemek için giriş ekranındaki \'Şifreni mi unuttun?\' seçeneğini kullan.',
        'Akun ini belum punya kata sandi. Gunakan \'Lupa kata sandi?\' di layar masuk untuk membuatnya.',
        'এই অ্যাকাউন্টে এখনো কোনো পাসওয়ার্ড নেই। সেট করতে লগইন স্ক্রিনে \'পাসওয়ার্ড ভুলে গেছেন?\' ব্যবহার করুন।'
      );
  String get appVersion => _get('Version', 'ورژن', 'الإصدار',
        'वर्ज़न',
        'Version',
        'Versión',
        'Versão',
        'Version',
        'Sürüm',
        'Versi',
        'সংস্করণ'
      );
  String get signOutConfirm => _get(
        'Sign out of Virello?',
        'Virello سے سائن آؤٹ کریں؟',
        'تسجيل الخروج من Virello؟',
      
        'Virello से साइन आउट करें?',
        'Se déconnecter de Virello ?',
        '¿Cerrar sesión en Virello?',
        'Sair do Virello?',
        'Von Virello abmelden?',
        'Virello\'dan çıkış yapılsın mı?',
        'Keluar dari Virello?',
        'Virello থেকে সাইন আউট করবেন?'
      );
  String get cancelBtn => _get('Cancel', 'منسوخ کریں', 'إلغاء',
        'रद्द करें',
        'Annuler',
        'Cancelar',
        'Cancelar',
        'Abbrechen',
        'İptal',
        'Batal',
        'বাতিল করুন'
      );
  String get appearanceLabel =>
      _get('Dark theme', 'ڈارک تھیم', 'المظهر الداكن',
        'डार्क थीम',
        'Thème sombre',
        'Tema oscuro',
        'Tema escuro',
        'Dunkles Design',
        'Koyu tema',
        'Tema gelap',
        'ডার্ক থিম'
      );

  // Campaigns (real backend data)
  String get noCampaigns =>
      _get('No campaigns yet', 'ابھی کوئی مہم نہیں', 'لا حملات بعد',
        'अभी कोई अभियान नहीं',
        'Aucune campagne pour l\'instant',
        'Aún no hay campañas',
        'Nenhuma campanha ainda',
        'Noch keine Kampagnen',
        'Henüz kampanya yok',
        'Belum ada kampanye',
        'এখনো কোনো ক্যাম্পেইন নেই'
      );
  String get noCampaignsHint => _get(
        'Tap LET AI GROW to launch your first one.',
        'پہلی مہم کے لیے LET AI GROW دبائیں۔',
        'اضغط «دَع الذكاء الاصطناعي ينمِّي» لإطلاق أول حملة.',
      
        'अपना पहला अभियान शुरू करने के लिए LET AI GROW पर टैप करें।',
        'Touche LET AI GROW pour lancer ta première campagne.',
        'Toca LET AI GROW para lanzar tu primera campaña.',
        'Toque em LET AI GROW para lançar sua primeira campanha.',
        'Tippe auf LET AI GROW, um deine erste Kampagne zu starten.',
        'İlk kampanyanı başlatmak için LET AI GROW\'a dokun.',
        'Ketuk LET AI GROW untuk meluncurkan kampanye pertamamu.',
        'আপনার প্রথম ক্যাম্পেইন চালু করতে LET AI GROW-এ ট্যাপ করুন।'
      );
  String get metricsSoon => _get(
        'Metrics will appear once your campaign is live.',
        'مہم لائیو ہوتے ہی اعداد و شمار یہاں آئیں گے۔',
        'ستظهر المقاييس عندما تصبح حملتك نشطة.',
      
        'आपका अभियान लाइव होते ही मेट्रिक्स दिखेंगी।',
        'Les statistiques apparaîtront une fois ta campagne en ligne.',
        'Las métricas aparecerán cuando tu campaña esté activa.',
        'As métricas aparecerão quando sua campanha estiver no ar.',
        'Kennzahlen erscheinen, sobald deine Kampagne live ist.',
        'Kampanyan yayına girince metrikler görünecek.',
        'Metrik akan muncul setelah kampanyemu tayang.',
        'আপনার ক্যাম্পেইন লাইভ হলেই মেট্রিক্স দেখা যাবে।'
      );
  String get pause => _get('Pause', 'روکیں', 'إيقاف مؤقت',
        'रोकें',
        'Pause',
        'Pausar',
        'Pausar',
        'Pausieren',
        'Duraklat',
        'Jeda',
        'বিরতি দিন'
      );
  String get pausedToast =>
      _get('Campaign paused', 'مہم روک دی گئی', 'تم إيقاف الحملة مؤقتاً',
        'अभियान रोका गया',
        'Campagne en pause',
        'Campaña en pausa',
        'Campanha pausada',
        'Kampagne pausiert',
        'Kampanya duraklatıldı',
        'Kampanye dijeda',
        'ক্যাম্পেইন বিরতিতে'
      );
  String get growFailed => _get(
        'Could not launch. Check your connection and try again.',
        'لانچ ناکام۔ کنکشن چیک کر کے دوبارہ کوشش کریں۔',
        'تعذَّر الإطلاق. تحقق من اتصالك وحاول مجدداً.',
      
        'शुरू नहीं हो सका। अपना कनेक्शन जांचें और पुनः प्रयास करें।',
        'Impossible de lancer. Vérifie ta connexion et réessaie.',
        'No se pudo lanzar. Revisa tu conexión e inténtalo de nuevo.',
        'Não foi possível lançar. Verifique sua conexão e tente novamente.',
        'Start fehlgeschlagen. Prüfe deine Verbindung und versuch es erneut.',
        'Başlatılamadı. Bağlantını kontrol et ve tekrar dene.',
        'Gagal meluncurkan. Periksa koneksimu dan coba lagi.',
        'চালু করা যায়নি। সংযোগ পরীক্ষা করে আবার চেষ্টা করুন।'
      );
  String get launching =>
      _get('Launching…', 'لانچ ہو رہا ہے…', 'جارٍ الإطلاق…',
        'शुरू हो रहा है…',
        'Lancement…',
        'Lanzando…',
        'Lançando…',
        'Wird gestartet…',
        'Başlatılıyor…',
        'Meluncurkan…',
        'চালু হচ্ছে…'
      );
  String get campaignLive => _get(
        'Your campaign is live. AI is optimizing within your approved limits.',
        'آپ کی مہم لائیو ہے۔ AI آپ کی منظور شدہ حدود میں بہتر بنا رہا ہے۔',
        'حملتك نشطة. يحسِّن الذكاء الاصطناعي ضمن حدودك المعتمدة.',
      
        'आपका अभियान लाइव है। AI आपकी स्वीकृत सीमाओं के भीतर ऑप्टिमाइज़ कर रहा है।',
        'Ta campagne est en ligne. L\'IA optimise dans tes limites approuvées.',
        'Tu campaña está activa. La IA está optimizando dentro de tus límites aprobados.',
        'Sua campanha está no ar. A IA está otimizando dentro dos seus limites aprovados.',
        'Deine Kampagne ist live. Die KI optimiert innerhalb deiner genehmigten Limits.',
        'Kampanyan yayında. YZ, onayladığın limitler dahilinde optimize ediyor.',
        'Kampanyemu sudah tayang. AI mengoptimalkan dalam batas yang kamu setujui.',
        'আপনার ক্যাম্পেইন লাইভ। AI আপনার অনুমোদিত সীমার মধ্যে অপটিমাইজ করছে।'
      );

  // Admin Dashboard
  String get adminDashboard =>
      _get('Admin Panel', 'ایڈمن پینل', 'لوحة الإدارة',
        'एडमिन पैनल',
        'Panneau d\u2019administration',
        'Panel de administración',
        'Painel do administrador',
        'Admin-Panel',
        'Yönetici Paneli',
        'Panel Admin',
        'অ্যাডমিন প্যানেল'
      );
  String get adminOverview => _get('Overview', 'جائزہ', 'نظرة عامة',
        'अवलोकन',
        'Vue d\'ensemble',
        'Resumen',
        'Visão geral',
        'Übersicht',
        'Genel Bakış',
        'Ringkasan',
        'সারসংক্ষেপ'
      );
  // Hidden PIN entry -> admin panel (profile version tapped 5x).
  String get adminPinTitle => _get('Admin Access', 'ایڈمن رسائی', 'دخول المسؤول');
  String get adminPinHint =>
      _get('Enter admin PIN', 'ایڈمن PIN درج کریں', 'أدخل رمز المسؤول');
  String get adminPinWrong => _get(
      'Wrong PIN, try again', 'غلط PIN، دوبارہ کوشش کریں', 'رمز خاطئ، حاول مرة أخرى');
  String get adminPinNotAllowed => _get(
      'This account is not authorized for admin access',
      'یہ اکاؤنٹ ایڈمن رسائی کے لیے مجاز نہیں ہے',
      'هذا الحساب غير مصرّح له بالوصول الإداري');
  String get adminPinLocked => _get('Too many attempts, try later',
      'بہت زیادہ کوششیں، بعد میں کوشش کریں', 'محاولات كثيرة، حاول لاحقًا');
  String get adminUsers => _get('Users', 'صارفین', 'المستخدمون',
        'यूज़र्स',
        'Utilisateurs',
        'Usuarios',
        'Usuários',
        'Nutzer',
        'Kullanıcılar',
        'Pengguna',
        'ব্যবহারকারী'
      );
  // --- Admin user-visit analytics ---
  String get adminAnalytics => _get('Analytics', 'اینالٹکس', 'التحليلات',
        'एनालिटिक्स',
        'Statistiques',
        'Estadísticas',
        'Estatísticas',
        'Statistiken',
        'Analitik',
        'Analitik',
        'অ্যানালিটিক্স'
      );
  String get rangeDaily => _get('Daily', 'روزانہ', 'يومي',
        'दैनिक',
        'Quotidien',
        'Diario',
        'Diário',
        'Täglich',
        'Günlük',
        'Harian',
        'দৈনিক'
      );
  String get rangeWeekly => _get('Weekly', 'ہفتہ وار', 'أسبوعي',
        'साप्ताहिक',
        'Hebdomadaire',
        'Semanal',
        'Semanal',
        'Wöchentlich',
        'Haftalık',
        'Mingguan',
        'সাপ্তাহিক'
      );
  String get rangeMonthly => _get('Monthly', 'ماہانہ', 'شهري',
        'मासिक',
        'Mensuel',
        'Mensual',
        'Mensal',
        'Monatlich',
        'Aylık',
        'Bulanan',
        'মাসিক'
      );
  String get statDau => _get('Daily active', 'روزانہ فعال', 'نشط يومياً',
        'दैनिक सक्रिय',
        'Actifs quotidiens',
        'Activos diarios',
        'Ativos diários',
        'Täglich aktiv',
        'Günlük aktif',
        'Aktif harian',
        'দৈনিক সক্রিয়'
      );
  String get statWau => _get('Weekly active', 'ہفتہ وار فعال', 'نشط أسبوعياً',
        'साप्ताहिक सक्रिय',
        'Actifs hebdomadaires',
        'Activos semanales',
        'Ativos semanais',
        'Wöchentlich aktiv',
        'Haftalık aktif',
        'Aktif mingguan',
        'সাপ্তাহিক সক্রিয়'
      );
  String get statMau => _get('Monthly active', 'ماہانہ فعال', 'نشط شهرياً',
        'मासिक सक्रिय',
        'Actifs mensuels',
        'Activos mensuales',
        'Ativos mensais',
        'Monatlich aktiv',
        'Aylık aktif',
        'Aktif bulanan',
        'মাসিক সক্রিয়'
      );
  String get statSignups => _get('New signups', 'نئے سائن اپ', 'تسجيلات جديدة',
        'नए साइन अप',
        'Nouvelles inscriptions',
        'Nuevos registros',
        'Novos cadastros',
        'Neue Registrierungen',
        'Yeni kayıtlar',
        'Pendaftaran baru',
        'নতুন সাইন আপ'
      );
  String get statVisits => _get('Visits', 'وزٹس', 'الزيارات',
        'विज़िट्स',
        'Visites',
        'Visitas',
        'Visitas',
        'Besuche',
        'Ziyaretler',
        'Kunjungan',
        'ভিজিট'
      );
  String get statTotalUsers =>
      _get('Total users', 'کل صارفین', 'إجمالي المستخدمين',
        'कुल यूज़र्स',
        'Utilisateurs totaux',
        'Usuarios totales',
        'Total de usuários',
        'Nutzer gesamt',
        'Toplam kullanıcı',
        'Total pengguna',
        'মোট ব্যবহারকারী'
      );
  String get salesTitle => _get('Sales', 'فروخت', 'المبيعات',
        'बिक्री',
        'Ventes',
        'Ventas',
        'Vendas',
        'Umsatz',
        'Satışlar',
        'Penjualan',
        'বিক্রয়'
      );
  String get salesTotalRevenue =>
      _get('Total revenue', 'کل آمدنی', 'إجمالي الإيرادات',
        'कुल राजस्व',
        'Revenu total',
        'Ingresos totales',
        'Receita total',
        'Gesamtumsatz',
        'Toplam gelir',
        'Total pendapatan',
        'মোট আয়'
      );
  String get salesNetRevenue =>
      _get('Net revenue', 'خالص آمدنی', 'صافي الإيرادات',
        'शुद्ध राजस्व',
        'Revenu net',
        'Ingresos netos',
        'Receita líquida',
        'Nettoumsatz',
        'Net gelir',
        'Pendapatan bersih',
        'নিট আয়'
      );
  String get salesOrders => _get('Orders', 'آرڈرز', 'الطلبات',
        'ऑर्डर्स',
        'Commandes',
        'Pedidos',
        'Pedidos',
        'Bestellungen',
        'Siparişler',
        'Pesanan',
        'অর্ডার'
      );
  String get salesSubscriptions =>
      _get('Subscriptions', 'سبسکرپشنز', 'الاشتراكات',
        'सब्सक्रिप्शन्स',
        'Abonnements',
        'Suscripciones',
        'Assinaturas',
        'Abos',
        'Abonelikler',
        'Langganan',
        'সাবস্ক্রিপশন'
      );
  String get salesCredits => _get('Credits', 'کریڈٹس', 'الأرصدة',
        'क्रेडिट्स',
        'Crédits',
        'Créditos',
        'Créditos',
        'Credits',
        'Krediler',
        'Kredit',
        'ক্রেডিট'
      );
  String get salesRefunds => _get('Refunds', 'ریفنڈز', 'المبالغ المستردة',
        'रिफंड्स',
        'Remboursements',
        'Reembolsos',
        'Reembolsos',
        'Rückerstattungen',
        'İadeler',
        'Pengembalian dana',
        'রিফান্ড'
      );
  String get lastActive => _get('Last active', 'آخری سرگرمی', 'آخر نشاط',
        'अंतिम सक्रियता',
        'Dernière activité',
        'Última actividad',
        'Última atividade',
        'Zuletzt aktiv',
        'Son aktiflik',
        'Terakhir aktif',
        'সর্বশেষ সক্রিয়'
      );
  String get neverActive => _get('Never', 'کبھی نہیں', 'أبداً',
        'कभी नहीं',
        'Jamais',
        'Nunca',
        'Nunca',
        'Nie',
        'Hiç',
        'Tidak pernah',
        'কখনো না'
      );
  String get adminPayments => _get('Payments', 'ادائیگیاں', 'المدفوعات',
        'भुगतान',
        'Paiements',
        'Pagos',
        'Pagamentos',
        'Zahlungen',
        'Ödemeler',
        'Pembayaran',
        'পেমেন্ট'
      );
  String get adminFraud =>
      _get('Fraud flags', 'فراڈ الرٹس', 'تنبيهات الاحتيال',
        'धोखाधड़ी अलर्ट्स',
        'Alertes de fraude',
        'Alertas de fraude',
        'Alertas de fraude',
        'Betrugsverdacht',
        'Dolandırıcılık uyarıları',
        'Tanda penipuan',
        'জালিয়াতি সতর্কতা'
      );
  String get adminDiscovery =>
      _get('Discovery queue', 'ڈسکوری قطار', 'قائمة الاكتشاف',
        'डिस्कवरी कतार',
        'File de découverte',
        'Cola de descubrimiento',
        'Fila de descoberta',
        'Entdeckungs-Warteschlange',
        'Keşif kuyruğu',
        'Antrean penemuan',
        'ডিসকভারি সারি'
      );
  String get adminPlans => _get('Plans', 'پلانز', 'الخطط',
        'प्लान्स',
        'Formules',
        'Planes',
        'Planos',
        'Pläne',
        'Planlar',
        'Paket',
        'প্ল্যান'
      );
  String get adminBroadcasts => _get('Broadcasts', 'اعلانات', 'البثّ',
        'ब्रॉडकास्ट्स',
        'Diffusions',
        'Transmisiones',
        'Transmissões',
        'Broadcasts',
        'Yayınlar',
        'Siaran',
        'ব্রডকাস্ট'
      );
  String get adminSettings => _get('Settings', 'ترتیبات', 'الإعدادات',
        'सेटिंग्स',
        'Paramètres',
        'Ajustes',
        'Configurações',
        'Einstellungen',
        'Ayarlar',
        'Pengaturan',
        'সেটিংস'
      );
  String get adminAudit => _get('Audit log', 'آڈٹ لاگ', 'سجل التدقيق',
        'ऑडिट लॉग',
        'Journal d\'audit',
        'Registro de auditoría',
        'Log de auditoria',
        'Prüfprotokoll',
        'Denetim günlüğü',
        'Log audit',
        'অডিট লগ'
      );
  String get adminAiUsage =>
      _get('AI usage', 'AI استعمال', 'استخدام الذكاء الاصطناعي',
        'AI उपयोग',
        'Utilisation de l\'IA',
        'Uso de la IA',
        'Uso da IA',
        'KI-Nutzung',
        'YZ kullanımı',
        'Penggunaan AI',
        'AI ব্যবহার'
      );
  // ---- Admin Panel: full edit/delete (posts, products, users, campaigns,
  // broadcasts, discovery, fraud flags, tickets) ----
  String get adminPosts => _get('Posts', 'پوسٹس', 'المنشورات');
  String get adminProducts => _get('Products', 'پراڈکٹس', 'المنتجات');
  String get adminTickets => _get('Tickets', 'ٹکٹ', 'التذاكر');
  // ---- Admin Panel: withdrawals + reward rates ----
  String get adminWithdrawals => _get('Withdrawals', 'رقوم کی واپسی', 'السحوبات');
  String get wdPending => _get('Pending', 'زیر التواء', 'قيد الانتظار');
  String get wdApproved => _get('Approved', 'منظور شدہ', 'معتمدة');
  String get wdPaid => _get('Paid', 'ادا شدہ', 'مدفوعة');
  String get wdRejected => _get('Rejected', 'مسترد شدہ', 'مرفوضة');
  String get wdApprove => _get('Approve', 'منظور کریں', 'اعتماد');
  String get wdReject => _get('Reject', 'مسترد کریں', 'رفض');
  String get wdMarkPaid => _get('Mark paid', 'ادا شدہ نشان لگائیں', 'تحديد كمدفوع');
  String get wdBankName => _get('Bank', 'بینک', 'البنك');
  String get wdAccountTitle => _get('Account title', 'اکاؤنٹ کا نام', 'اسم الحساب');
  String get wdIban => _get('IBAN', 'آئی بین', 'الآيبان');
  String get wdAgeConfirmed => _get('18+ confirmed', '18+ کی تصدیق', 'تم تأكيد 18+');
  String get wdRequested => _get('Requested', 'درخواست', 'طُلب');
  String get wdAdminNote => _get('Admin note (optional)', 'ایڈمن نوٹ (اختیاری)', 'ملاحظة المشرف (اختياري)');
  String get wdRejectReason => _get('Rejection reason', 'مسترد کرنے کی وجہ', 'سبب الرفض');
  String get wdPaymentRef => _get('Payment reference', 'ادائیگی کا حوالہ', 'مرجع الدفع');
  String get wdApproveConfirm => _get(
      'Approve this withdrawal?', 'کیا یہ واپسی منظور کر دیں؟', 'اعتماد هذا السحب؟');
  String get wdRejectConfirm => _get(
      'Reject this withdrawal? The amount returns to the user balance.',
      'کیا یہ واپسی مسترد کر دیں؟ رقم صارف کے بیلنس میں واپس آ جائے گی۔',
      'رفض هذا السحب؟ سيعود المبلغ إلى رصيد المستخدم.');
  String get wdMarkPaidConfirm => _get(
      'Mark as paid? Confirm the bank transfer is done.',
      'ادا شدہ نشان لگائیں؟ تصدیق کریں کہ بینک ٹرانسفر ہو گیا ہے۔',
      'تحديد كمدفوع؟ تأكد من إتمام التحويل البنكي.');
  String get wdReasonRequired => _get(
      'Please enter a reason.', 'براہ کرم وجہ لکھیں۔', 'يرجى إدخال السبب.');
  String get wdRefRequired => _get(
      'Please enter the payment reference.', 'براہ کرم ادائیگی کا حوالہ لکھیں۔', 'يرجى إدخال مرجع الدفع.');
  String get wdNoPending => _get(
      'No pending withdrawals.', 'کوئی زیر التواء واپسی نہیں۔', 'لا توجد سحوبات قيد الانتظار.');
  String get wdNoApproved => _get(
      'No approved withdrawals awaiting payment.', 'ادائیگی کے منتظر کوئی منظور شدہ واپسی نہیں۔', 'لا توجد سحوبات معتمدة بانتظار الدفع.');
  String get wdNoPaid => _get(
      'No paid withdrawals yet.', 'ابھی کوئی ادا شدہ واپسی نہیں۔', 'لا توجد سحوبات مدفوعة بعد.');
  String get wdNoRejected => _get(
      'No rejected withdrawals.', 'کوئی مسترد شدہ واپسی نہیں۔', 'لا توجد سحوبات مرفوضة.');
  // ---- Admin Panel: reward claims (proof-review queue) ----
  String get adminClaims => _get('Claims', 'دعوے', 'المطالبات');
  String get clPending => _get('Pending', 'زیر التواء', 'قيد الانتظار');
  String get clApproved => _get('Approved', 'منظور شدہ', 'معتمدة');
  String get clRejected => _get('Rejected', 'مسترد شدہ', 'مرفوضة');
  String get clApprove => _get('Approve', 'منظور کریں', 'اعتماد');
  String get clReject => _get('Reject', 'مسترد کریں', 'رفض');
  String get clProof => _get('Proof', 'ثبوت', 'إثبات');
  String get clViewProof => _get('Tap to view full proof', 'مکمل ثبوت دیکھنے کے لیے تھپتھپائیں', 'انقر لعرض الإثبات الكامل');
  String get clType => _get('Type', 'قسم', 'النوع');
  String get clAmount => _get('Reward', 'انعام', 'المكافأة');
  String get clFiled => _get('Filed', 'درج', 'قُدم');
  String get clAdminNote => _get('Admin note (optional)', 'ایڈمن نوٹ (اختیاری)', 'ملاحظة المشرف (اختياري)');
  String get clRejectReason => _get('Rejection reason', 'مسترد کرنے کی وجہ', 'سبب الرفض');
  String get clApproveConfirm => _get(
      'Approve this claim? The reward will be credited.',
      'کیا یہ دعویٰ منظور کر دیں؟ انعام کریڈٹ ہو جائے گا۔',
      'اعتماد هذه المطالبة؟ سيتم إضافة المكافأة.');
  String get clRejectConfirm => _get(
      'Reject this claim? Nothing will be credited.',
      'کیا یہ دعویٰ مسترد کر دیں؟ کوئی انعام نہیں ملے گا۔',
      'رفض هذه المطالبة؟ لن يتم إضافة أي مكافأة.');
  String get clReasonRequired => _get(
      'Please enter a reason.', 'براہ کرم وجہ لکھیں۔', 'يرجى إدخال السبب.');
  String get clNoPending => _get(
      'No pending claims.', 'کوئی زیر التواء دعویٰ نہیں۔', 'لا توجد مطالبات قيد الانتظار.');
  String get clNoApproved => _get(
      'No approved claims.', 'کوئی منظور شدہ دعویٰ نہیں۔', 'لا توجد مطالبات معتمدة.');
  String get clNoRejected => _get(
      'No rejected claims.', 'کوئی مسترد شدہ دعویٰ نہیں۔', 'لا توجد مطالبات مرفوضة.');
  // ---- Admin Panel: per-post reward badge ----
  String get clPostReward => _get('Post reward', 'پوسٹ کا انعام', 'مكافأة المنشور');
  String get clSetReward => _get(
      'Set reward (cents)', 'انعام مقرر کریں (سینٹ)', 'تعيين المكافأة (سنت)');
  String get clRewardHint => _get(
      'e.g. 5 = \$0.05. 0 = default badge.',
      'مثلاً 5 = \$0.05۔ 0 = ڈیفالٹ بیج۔',
      'مثال: 5 = \$0.05. 0 = الشارة الافتراضية.');
  String get clInvalidAmount => _get(
      'Enter a valid non-negative number.', 'درست غیر منفی عدد لکھیں۔', 'أدخل رقمًا صحيحًا غير سالب.');
  String get rewardRates => _get('Reward Rates', 'انعامی شرحیں', 'أسعار المكافآت');
  String get rrSaved => _get('Rates saved.', 'شرحیں محفوظ ہو گئیں۔', 'تم حفظ الأسعار.');
  String get rrShareCents => _get('Per share (cents)', 'فی شیئر (سینٹ)', 'لكل مشاركة (سنت)');
  String get rrShareDailyCap => _get('Shares per day (cap)', 'روزانہ شیئر کی حد', 'حد المشاركات اليومي');
  String get rrShareClickCents => _get('Per share click (cents)', 'فی شیئر کلک (سینٹ)', 'لكل نقرة مشاركة (سنت)');
  String get rrShareClickDailyCap => _get('Share clicks per day (cap)', 'روزانہ شیئر کلکس کی حد', 'حد نقرات المشاركة اليومي');
  String get rrProductClickCents => _get('Per product click (cents)', 'فی پراڈکٹ کلک (سینٹ)', 'لكل نقرة منتج (سنت)');
  String get rrProductClickDailyCap => _get('Product clicks per day (cap)', 'روزانہ پراڈکٹ کلکس کی حد', 'حد نقرات المنتج اليومي');
  String get rrWeeklyTopSeller => _get('Weekly top seller (cents)', 'ہفتہ وار ٹاپ سیلر (سینٹ)', 'أفضل بائع أسبوعي (سنت)');
  String get rrMonthlyTopSeller => _get('Monthly top seller (cents)', 'ماہانہ ٹاپ سیلر (سینٹ)', 'أفضل بائع شهري (سنت)');
  String get rrMinWithdraw => _get('Min withdrawal (cents)', 'کم از کم واپسی (سینٹ)', 'الحد الأدنى للسحب (سنت)');
  String get rrPointsToCash => _get('Points→cash per 1000 (cents)', 'پوائنٹس→کیش فی 1000 (سینٹ)', 'النقاط→نقد لكل 1000 (سنت)');
  String get rrMinConvertPoints => _get('Min points to convert', 'کنورٹ کے لیے کم از کم پوائنٹس', 'الحد الأدنى للنقاط للتحويل');
  String get rrVolumeThresholds => _get('Volume bonus thresholds (JSON)', 'والیوم بونس حدیں (JSON)', 'عتبات مكافأة الحجم (JSON)');
  String get rrInvalidNumber => _get(
      'Please enter valid numbers.', 'براہ کرم درست اعداد لکھیں۔', 'يرجى إدخال أرقام صحيحة.');
  String get searchComments => _get('Search comments…', 'تبصرے تلاش کریں…', 'ابحث في التعليقات…');
  String get editComment => _get('Edit comment', 'تبصرہ ایڈٹ کریں', 'تعديل التعليق');
  String get deleteComment => _get('Delete comment', 'تبصرہ حذف کریں', 'حذف التعليق');
  String get deleteCommentConfirm => _get(
      'Delete this comment?', 'کیا یہ تبصرہ حذف کر دیں؟', 'حذف هذا التعليق؟');
  String get commentLabel => _get('Comment', 'تبصرہ', 'التعليق');
  String get editProduct => _get('Edit product', 'پراڈکٹ ایڈٹ کریں', 'تعديل المنتج');
  String get deleteProduct => _get('Delete product', 'پراڈکٹ حذف کریں', 'حذف المنتج');
  String get deleteProductConfirm => _get(
      'Delete this product?', 'کیا یہ پراڈکٹ حذف کر دیں؟', 'حذف هذا المنتج؟');
  String get productTitleLabel => _get('Title', 'عنوان', 'العنوان');
  String get productPriceLabel => _get('Price (USD)', 'قیمت (USD)', 'السعر (دولار)');
  String get productCategoryLabel => _get('Category', 'کیٹیگری', 'الفئة');
  String get productActiveLabel => _get('Active', 'فعال', 'نشط');
  String get editName => _get('Edit name', 'نام ایڈٹ کریں', 'تعديل الاسم');
  String get deleteUser => _get('Delete user', 'صارف حذف کریں', 'حذف المستخدم');
  String get deleteUserConfirm => _get(
      'Delete this user and everything they own? This cannot be undone.',
      'کیا یہ صارف اور اس کا تمام ڈیٹا حذف کر دیں؟ یہ واپس نہیں ہوگا۔',
      'حذف هذا المستخدم وكل ما يملك؟ لا يمكن التراجع عن هذا.');
  String get editCampaign => _get('Edit campaign', 'مہم ایڈٹ کریں', 'تعديل الحملة');
  String get deleteCampaign => _get('Delete campaign', 'مہم حذف کریں', 'حذف الحملة');
  String get statusLabel => _get('Status', 'حیثیت', 'الحالة');
  String get budgetLabel => _get('Budget (USD)', 'بجٹ (USD)', 'الميزانية (دولار)');
  String get editBroadcast => _get('Edit broadcast', 'براڈکاسٹ ایڈٹ کریں', 'تعديل البث');
  String get deleteBroadcast => _get('Delete broadcast', 'براڈکاسٹ حذف کریں', 'حذف البث');
  String get deleteBroadcastConfirm => _get(
      'Delete this broadcast?', 'کیا یہ براڈکاسٹ حذف کر دیں؟', 'حذف هذا البث؟');
  String get deletePlacement => _get('Delete placement', 'پلیسمنٹ حذف کریں', 'حذف الموضع');
  String get deletePlacementConfirm => _get(
      'Remove this placement from discovery?',
      'کیا یہ پلیسمنٹ ڈسکوری سے ہٹا دیں؟',
      'إزالة هذا الموضع من الاكتشاف؟');
  String get deleteFlag => _get('Delete flag', 'فلیگ حذف کریں', 'حذف العلامة');
  String get deleteFlagConfirm => _get(
      'Permanently dismiss this fraud flag?',
      'کیا یہ فراڈ فلیگ مستقل طور پر ختم کر دیں؟',
      'تجاهل علامة الاحتيال هذه نهائيًا؟');
  String get deleteTicket => _get('Delete ticket', 'ٹکٹ حذف کریں', 'حذف التذكرة');
  String get deleteTicketConfirm => _get(
      'Delete this support ticket?',
      'کیا یہ سپورٹ ٹکٹ حذف کر دیں؟',
      'حذف تذكرة الدعم هذه؟');
  String get confirmDeleteTitle => _get('Are you sure?', 'کیا آپ کو یقین ہے؟', 'هل أنت متأكد؟');
  String get confirmDeleteAction => _get('Delete', 'حذف کریں', 'حذف');
  String get totalUsers => _get('Users', 'صارفین', 'المستخدمون',
        'यूज़र्स',
        'Utilisateurs',
        'Usuarios',
        'Usuários',
        'Nutzer',
        'Kullanıcılar',
        'Pengguna',
        'ব্যবহারকারী'
      );
  String get totalCampaigns => _get('Campaigns', 'مہمات', 'الحملات',
        'अभियान',
        'Campagnes',
        'Campañas',
        'Campanhas',
        'Kampagnen',
        'Kampanyalar',
        'Kampanye',
        'ক্যাম্পেইন'
      );
  String get liveCampaigns => _get('Live now', 'ابھی لائیو', 'نشطة الآن',
        'अभी लाइव',
        'En ligne',
        'En vivo',
        'Ao vivo',
        'Jetzt live',
        'Şu an yayında',
        'Tayang sekarang',
        'এখন লাইভ'
      );
  String get revenueUsd =>
      _get('Revenue (USD)', 'آمدنی (USD)', 'الإيرادات (دولار)',
        'राजस्व (USD)',
        'Revenu (USD)',
        'Ingresos (USD)',
        'Receita (USD)',
        'Umsatz (USD)',
        'Gelir (USD)',
        'Pendapatan (USD)',
        'আয় (USD)'
      );
  String get openFlags =>
      _get('Open fraud flags', 'کھلے فراڈ الرٹس', 'تنبيهات احتيال مفتوحة',
        'खुले धोखाधड़ी अलर्ट्स',
        'Alertes de fraude ouvertes',
        'Alertas de fraude abiertas',
        'Alertas de fraude abertos',
        'Offene Betrugsverdachtsfälle',
        'Açık dolandırıcılık uyarıları',
        'Tanda penipuan terbuka',
        'খোলা জালিয়াতি সতর্কতা'
      );
  String get byStatus => _get('By status', 'حیثیت کے لحاظ سے', 'حسب الحالة',
        'स्थिति के अनुसार',
        'Par statut',
        'Por estado',
        'Por status',
        'Nach Status',
        'Duruma göre',
        'Berdasarkan status',
        'স্ট্যাটাস অনুযায়ী'
      );
  String get byGoal => _get('By goal', 'ہدف کے لحاظ سے', 'حسب الهدف',
        'लक्ष्य के अनुसार',
        'Par objectif',
        'Por objetivo',
        'Por objetivo',
        'Nach Ziel',
        'Hedefe göre',
        'Berdasarkan tujuan',
        'লক্ষ্য অনুযায়ী'
      );
  String get suspend => _get('Suspend', 'معطل کریں', 'تعليق',
        'निलंबित करें',
        'Suspendre',
        'Suspender',
        'Suspender',
        'Sperren',
        'Askıya al',
        'Tangguhkan',
        'স্থগিত করুন'
      );
  String get unsuspend => _get('Unsuspend', 'بحال کریں', 'إلغاء التعليق',
        'निलंबन हटाएं',
        'Réactiver',
        'Reactivar',
        'Reativar',
        'Entsperren',
        'Askıyı kaldır',
        'Batalkan penangguhan',
        'স্থগিতাদেশ তুলুন'
      );
  String get makeAdmin => _get('Make admin', 'ایڈمن بنائیں', 'جعله مديراً',
        'एडमिन बनाएं',
        'Nommer admin',
        'Hacer administrador',
        'Tornar administrador',
        'Zum Admin machen',
        'Yönetici yap',
        'Jadikan admin',
        'অ্যাডমিন বানান'
      );
  String get adjustCredits =>
      _get('Adjust credits', 'کریڈٹ ایڈجسٹ کریں', 'تعديل الرصيد',
        'क्रेडिट समायोजित करें',
        'Ajuster les crédits',
        'Ajustar créditos',
        'Ajustar créditos',
        'Credits anpassen',
        'Krediyi ayarla',
        'Sesuaikan kredit',
        'ক্রেডিট সমন্বয় করুন'
      );
  String get creditsDelta =>
      _get('Credit change (+/-)', 'کریڈٹ تبدیلی (+/-)', 'تغيير الرصيد (+/-)',
        'क्रेडिट बदलाव (+/-)',
        'Variation de crédits (+/-)',
        'Cambio de créditos (+/-)',
        'Alteração de créditos (+/-)',
        'Kreditänderung (+/-)',
        'Kredi değişimi (+/-)',
        'Perubahan kredit (+/-)',
        'ক্রেডিট পরিবর্তন (+/-)'
      );
  String get reason => _get('Reason', 'وجہ', 'السبب',
        'कारण',
        'Motif',
        'Motivo',
        'Motivo',
        'Grund',
        'Sebep',
        'Alasan',
        'কারণ'
      );
  String get resolve => _get('Resolve', 'حل کریں', 'حلّ',
        'समाधान करें',
        'Résoudre',
        'Resolver',
        'Resolver',
        'Lösen',
        'Çöz',
        'Selesaikan',
        'সমাধান করুন'
      );
  String get approve => _get('Approve', 'منظور کریں', 'اعتماد',
        'स्वीकृत करें',
        'Approuver',
        'Aprobar',
        'Aprovar',
        'Genehmigen',
        'Onayla',
        'Setujui',
        'অনুমোদন করুন'
      );
  String get reject => _get('Reject', 'مسترد کریں', 'رفض',
        'अस्वीकार करें',
        'Rejeter',
        'Rechazar',
        'Rejeitar',
        'Ablehnen',
        'Reddet',
        'Tolak',
        'প্রত্যাখ্যান করুন'
      );
  String get noteOptional =>
      _get('Note (optional)', 'نوٹ (اختیاری)', 'ملاحظة (اختياري)',
        'नोट (वैकल्पिक)',
        'Note (facultatif)',
        'Nota (opcional)',
        'Observação (opcional)',
        'Notiz (optional)',
        'Not (isteğe bağlı)',
        'Catatan (opsional)',
        'নোট (ঐচ্ছিক)'
      );
  String get searchUsers => _get(
        'Search by email…',
        'ای میل سے تلاش کریں…',
        'البحث بالبريد الإلكتروني…',
      
        'ईमेल से खोजें…',
        'Rechercher par e-mail…',
        'Buscar por correo…',
        'Buscar por e-mail…',
        'Per E-Mail suchen…',
        'E-postayla ara…',
        'Cari berdasarkan email…',
        'ইমেইল দিয়ে খুঁজুন…'
      );
  String get noItems =>
      _get('Nothing here yet.', 'یہاں ابھی کچھ نہیں۔', 'لا يوجد شيء هنا بعد.',
        'यहां अभी कुछ नहीं है।',
        'Rien ici pour l\'instant.',
        'Nada aquí todavía.',
        'Nada aqui ainda.',
        'Hier ist noch nichts.',
        'Burada henüz bir şey yok.',
        'Belum ada apa pun di sini.',
        'এখানে এখনো কিছু নেই।'
      );
  String get adminOnly => _get(
        'Admin access required.',
        'ایڈمن رسائی درکار ہے۔',
        'يتطلب صلاحية المدير.',
      
        'एडमिन एक्सेस आवश्यक है।',
        'Accès admin requis.',
        'Se requiere acceso de administrador.',
        'Acesso de administrador necessário.',
        'Admin-Zugriff erforderlich.',
        'Yönetici erişimi gerekli.',
        'Diperlukan akses admin.',
        'অ্যাডমিন অ্যাক্সেস প্রয়োজন।'
      );
  String get composeBroadcast => _get('New broadcast', 'نیا اعلان', 'بثّ جديد',
        'नया ब्रॉडकास्ट',
        'Nouvelle diffusion',
        'Nueva transmisión',
        'Nova transmissão',
        'Neuer Broadcast',
        'Yeni yayın',
        'Siaran baru',
        'নতুন ব্রডকাস্ট'
      );
  String get sendBroadcast => _get('Send', 'بھیجیں', 'إرسال',
        'भेजें',
        'Envoyer',
        'Enviar',
        'Enviar',
        'Senden',
        'Gönder',
        'Kirim',
        'পাঠান'
      );
  String get broadcastTitle => _get('Title', 'عنوان', 'العنوان',
        'शीर्षक',
        'Titre',
        'Título',
        'Título',
        'Titel',
        'Başlık',
        'Judul',
        'শিরোনাম'
      );
  String get broadcastBody => _get('Message', 'پیغام', 'الرسالة',
        'संदेश',
        'Message',
        'Mensaje',
        'Mensagem',
        'Nachricht',
        'Mesaj',
        'Pesan',
        'বার্তা'
      );
  String get audience => _get('Audience', 'سامعین', 'الجمهور',
        'ऑडियंस',
        'Audience',
        'Audiencia',
        'Público',
        'Zielgruppe',
        'Kitle',
        'Audiens',
        'অডিয়েন্স'
      );
  String get audienceAll => _get('All users', 'تمام صارفین', 'كل المستخدمين',
        'सभी यूज़र्स',
        'Tous les utilisateurs',
        'Todos los usuarios',
        'Todos os usuários',
        'Alle Nutzer',
        'Tüm kullanıcılar',
        'Semua pengguna',
        'সব ব্যবহারকারী'
      );
  String get audienceFree => _get('Free plan', 'مفت پلان', 'الخطة المجانية',
        'फ्री प्लान',
        'Offre gratuite',
        'Plan gratuito',
        'Plano gratuito',
        'Kostenloser Plan',
        'Ücretsiz plan',
        'Paket gratis',
        'ফ্রি প্ল্যান'
      );
  String get audiencePaid => _get('Paid plans', 'پیڈ پلانز', 'الخطط المدفوعة',
        'पेड प्लान्स',
        'Offres payantes',
        'Planes de pago',
        'Planos pagos',
        'Bezahlte Pläne',
        'Ücretli planlar',
        'Paket berbayar',
        'পেইড প্ল্যান'
      );
  String get editPlan => _get('Edit plan', 'پلان ایڈٹ کریں', 'تعديل الخطة',
        'प्लान एडिट करें',
        'Modifier la formule',
        'Editar plan',
        'Editar plano',
        'Plan bearbeiten',
        'Planı düzenle',
        'Edit paket',
        'প্ল্যান এডিট করুন'
      );
  String get planName => _get('Name', 'نام', 'الاسم',
        'नाम',
        'Nom',
        'Nombre',
        'Nome',
        'Name',
        'Ad',
        'Nama',
        'নাম'
      );
  String get priceUsd => _get('Price (USD)', 'قیمت (USD)', 'السعر (دولار)',
        'कीमत (USD)',
        'Prix (USD)',
        'Precio (USD)',
        'Preço (USD)',
        'Preis (USD)',
        'Fiyat (USD)',
        'Harga (USD)',
        'দাম (USD)'
      );
  String get creditsMonthly => _get(
        'Monthly AI credits',
        'ماہانہ AI کریڈٹ',
        'رصيد الذكاء الاصطناعي الشهري',
      
        'मासिक AI क्रेडिट',
        'Crédits IA mensuels',
        'Créditos de IA mensuales',
        'Créditos de IA mensais',
        'Monatliche KI-Credits',
        'Aylık YZ kredisi',
        'Kredit AI bulanan',
        'মাসিক AI ক্রেডিট'
      );
  String get campaignsLimit =>
      _get('Campaign limit', 'مہم کی حد', 'حد الحملات',
        'अभियान सीमा',
        'Limite de campagnes',
        'Límite de campañas',
        'Limite de campanhas',
        'Kampagnenlimit',
        'Kampanya limiti',
        'Batas kampanye',
        'ক্যাম্পেইন সীমা'
      );
  String get planActive => _get('Active', 'فعال', 'نشطة',
        'सक्रिय',
        'Actif',
        'Activo',
        'Ativo',
        'Aktiv',
        'Aktif',
        'Aktif',
        'সক্রিয়'
      );
  String get sortOrder => _get('Sort order', 'ترتیب', 'ترتيب الفرز',
        'क्रमबद्धता',
        'Ordre de tri',
        'Orden de clasificación',
        'Ordem de classificação',
        'Sortierreihenfolge',
        'Sıralama düzeni',
        'Urutan',
        'সাজানোর ক্রম'
      );
  String get editSetting =>
      _get('Edit setting', 'ترتیب ایڈٹ کریں', 'تعديل الإعداد',
        'सेटिंग एडिट करें',
        'Modifier le paramètre',
        'Editar ajuste',
        'Editar configuração',
        'Einstellung bearbeiten',
        'Ayari düzenle',
        'Edit pengaturan',
        'সেটিং এডিট করুন'
      );
  String get settingValueJson =>
      _get('Value (JSON)', 'ویلیو (JSON)', 'القيمة (JSON)',
        'मान (JSON)',
        'Valeur (JSON)',
        'Valor (JSON)',
        'Valor (JSON)',
        'Wert (JSON)',
        'Değer (JSON)',
        'Nilai (JSON)',
        'মান (JSON)'
      );
  String get saveChanges => _get('Save', 'محفوظ کریں', 'حفظ',
        'सेव करें',
        'Enregistrer',
        'Guardar',
        'Salvar',
        'Speichern',
        'Kaydet',
        'Simpan',
        'সেভ করুন'
      );
  String get cancel => _get('Cancel', 'منسوخ کریں', 'إلغاء',
        'रद्द करें',
        'Annuler',
        'Cancelar',
        'Cancelar',
        'Abbrechen',
        'İptal',
        'Batal',
        'বাতিল করুন'
      );
  String get done => _get('Done', 'ہو گیا', 'تم',
        'हो गया',
        'Terminé',
        'Listo',
        'Pronto',
        'Fertig',
        'Tamam',
        'Selesai',
        'হয়ে গেছে'
      );
  String get actionDone => _get('Done', 'ہو گیا', 'تم',
        'हो गया',
        'Terminé',
        'Listo',
        'Pronto',
        'Fertig',
        'Tamam',
        'Selesai',
        'হয়ে গেছে'
      );
  String get invalidJson => _get(
        'Invalid JSON. Check the syntax and try again.',
        'غلط JSON۔ سِنٹیکس چیک کر کے دوبارہ کوشش کریں۔',
        'JSON غير صالح. تحقق من الصياغة وحاول مجدداً.',
      
        'अमान्य JSON। सिंटैक्स जांचें और पुनः प्रयास करें।',
        'JSON invalide. Vérifie la syntaxe et réessaie.',
        'JSON inválido. Revisa la sintaxis e inténtalo de nuevo.',
        'JSON inválido. Verifique a sintaxe e tente novamente.',
        'Ungültiges JSON. Prüfe die Syntax und versuch es erneut.',
        'Geçersiz JSON. Sözdizimini kontrol et ve tekrar dene.',
        'JSON tidak valid. Periksa sintaksnya dan coba lagi.',
        'অবৈধ JSON। সিনট্যাক্স পরীক্ষা করে আবার চেষ্টা করুন।'
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
          'hook': 'हुक',
          'clarity': 'स्पष्टता',
          'hashtag_hygiene': 'हैशटैग',
          'media': 'मीडिया',
          'cta': 'कॉल टू एक्शन',
          'language_fit': 'भाषा की अनुकूलता',
        }[key] ??
            key,
        const {
          'hook': 'Accroche',
          'clarity': 'Clarté',
          'hashtag_hygiene': 'Hashtags',
          'media': 'Média',
          'cta': 'Appel à l\'action',
          'language_fit': 'Adéquation linguistique',
        }[key] ??
            key,
        const {
          'hook': 'Gancho',
          'clarity': 'Claridad',
          'hashtag_hygiene': 'Etiquetas',
          'media': 'Multimedia',
          'cta': 'Llamado a la acción',
          'language_fit': 'Ajuste de idioma',
        }[key] ??
            key,
        const {
          'hook': 'Gancho',
          'clarity': 'Clareza',
          'hashtag_hygiene': 'Hashtags',
          'media': 'Mídia',
          'cta': 'Chamada para ação',
          'language_fit': 'Adequação de idioma',
        }[key] ??
            key,
        const {
          'hook': 'Hook',
          'clarity': 'Klarheit',
          'hashtag_hygiene': 'Hashtags',
          'media': 'Medien',
          'cta': 'Handlungsaufforderung',
          'language_fit': 'Sprachliche Passung',
        }[key] ??
            key,
        const {
          'hook': 'Kanca',
          'clarity': 'Netlik',
          'hashtag_hygiene': 'Etiketler',
          'media': 'Medya',
          'cta': 'Eylem çağrısı',
          'language_fit': 'Dil uyumu',
        }[key] ??
            key,
        const {
          'hook': 'Kait',
          'clarity': 'Kejelasan',
          'hashtag_hygiene': 'Tagar',
          'media': 'Media',
          'cta': 'Ajakan bertindak',
          'language_fit': 'Kesesuaian bahasa',
        }[key] ??
            key,
        const {
          'hook': 'হুক',
          'clarity': 'স্পষ্টতা',
          'hashtag_hygiene': 'হ্যাশট্যাগ',
          'media': 'মিডিয়া',
          'cta': 'কল টু অ্যাকশন',
          'language_fit': 'ভাষার সামঞ্জস্য',
        }[key] ??
            key,
      );

  String get growthEngine =>
      _get('AI Growth Engine', 'AI گروتھ انجن', 'محرك النمو بالذكاء الاصطناعي',
        'AI ग्रोथ इंजन',
        'Moteur de croissance IA',
        'Motor de crecimiento con IA',
        'Motor de crescimento com IA',
        'KI-Wachstumsmotor',
        'YZ Büyüme Motoru',
        'Mesin Pertumbuhan AI',
        'AI গ্রোথ ইঞ্জিন'
      );
  String get engineTagline => _get(
        'Autonomous analyze → distribute → learn → optimize loop',
        'خودکار تجزیہ → تقسیم → سیکھنے → بہتری کا سلسلہ',
        'حلقة مستقلة: تحليل ← توزيع ← تعلُّم ← تحسين',
      
        'स्वायत्त विश्लेषण → वितरण → सीखना → ऑप्टिमाइज़ेशन चक्र',
        'Boucle autonome : analyser → distribuer → apprendre → optimiser',
        'Ciclo autónomo: analizar → distribuir → aprender → optimizar',
        'Ciclo autônomo: analisar → distribuir → aprender → otimizar',
        'Autonome Schleife: Analysieren → Verteilen → Lernen → Optimieren',
        'Otonom döngü: analiz et → dağıt → öğren → optimize et',
        'Siklus otonom: analisis → distribusikan → pelajari → optimalkan',
        'স্বয়ংক্রিয় চক্র: বিশ্লেষণ → বিতরণ → শেখা → অপটিমাইজেশন'
      );
  String get engineWhatItDoes => _get(
        'Let the AI grow this post on autopilot',
        'AI کو اس پوسٹ کو خودکار طریقے سے بڑھانے دیں',
        'دع الذكاء الاصطناعي ينمِّي هذا المنشور تلقائياً',
      
        'AI को इस पोस्ट को ऑटोपायलट पर ग्रो करने दें',
        'Laisse l\'IA développer ce post en pilote automatique',
        'Deja que la IA haga crecer esta publicación en piloto automático',
        'Deixe a IA fazer esta publicação crescer no piloto automático',
        'Lass die KI diesen Beitrag im Autopilot wachsen lassen',
        'YZ\'nin bu gönderiyi otomatik pilotta büyütmesine izin ver',
        'Biarkan AI mengembangkan postingan ini secara autopilot',
        'AI-কে এই পোস্টটি অটোপাইলটে গ্রো করতে দিন'
      );
  String get engineWhatItDoesBody => _get(
        'The Growth Engine finds the right audience segments in the Discovery Platform, tries content variations, measures genuine views, saves and dismissals, and shifts distribution toward what real people respond to. Every decision is explained and logged. No fake engagement, ever.',
        'گروتھ انجن ڈسکوری پلیٹ فارم میں صحیح آڈینس تلاش کرتا ہے، مواد کی مختلف صورتیں آزماتا ہے، حقیقی ویوز، سیوز اور مستردیوں کی پیمائش کرتا ہے، اور تقسیم کو اسی طرف موڑتا ہے جس کا حقیقی لوگ جواب دیں۔ ہر فیصلہ واضح اور محفوظ ہوتا ہے۔ کبھی جعلی انگیجمنٹ نہیں۔',
        'يجد محرك النمو شرائح الجمهور المناسبة، ويجرِّب نسخ المحتوى، ويقيس التفاعلات الحقيقية، ويعيد التوزيع نحو الأفضل.',
      
        'ग्रोथ इंजन डिस्कवरी प्लेटफ़ॉर्म में सही ऑडियंस सेगमेंट ढूंढता है, कंटेंट के रूपांतर आज़माता है, असली व्यूज़, सेव और डिस्मिसल मापता है, और वितरण को उसी ओर मोड़ता है जिस पर असली लोग प्रतिक्रिया देते हैं। हर फैसला समझाया और लॉग किया जाता है। कभी नकली एंगेजमेंट नहीं।',
        'Le moteur de croissance trouve les bons segments d\'audience dans la plateforme de découverte, teste des variantes de contenu, mesure les vues, enregistrements et rejets authentiques, et oriente la distribution vers ce à quoi les vraies personnes réagissent. Chaque décision est expliquée et journalisée. Jamais de faux engagement.',
        'El motor de crecimiento encuentra los segmentos de audiencia adecuados en la plataforma de descubrimiento, prueba variantes de contenido, mide vistas, guardados y descartes genuinos, y dirige la distribución hacia lo que responde la gente real. Cada decisión se explica y se registra. Nunca interacción falsa.',
        'O motor de crescimento encontra os segmentos de público certos na plataforma de descoberta, testa variações de conteúdo, mede visualizações, salvamentos e dispensas genuínos, e direciona a distribuição para o que pessoas reais respondem. Cada decisão é explicada e registrada. Nunca engajamento falso.',
        'Der Wachstumsmotor findet die richtigen Zielgruppensegmente in der Discovery-Plattform, testet Content-Varianten, misst echte Aufrufe, Speicherungen und Ablehnungen und lenkt die Verteilung dorthin, worauf echte Menschen reagieren. Jede Entscheidung wird erklärt und protokolliert. Niemals gefälschte Interaktion.',
        'Büyüme Motoru, Keşif Platformu\'nda doğru kitle segmentlerini bulur, içerik varyasyonlarını dener, gerçek görüntülemeleri, kaydetmeleri ve reddetmeleri ölçer ve dağıtımı gerçek insanların tepki verdiğine yönlendirir. Her karar açıklanır ve kaydedilir. Asla sahte etkileşim yok.',
        'Mesin Pertumbuhan menemukan segmen audiens yang tepat di Platform Penemuan, mencoba variasi konten, mengukur tayangan, simpanan, dan penolakan asli, serta mengarahkan distribusi ke hal yang direspons orang sungguhan. Setiap keputusan dijelaskan dan dicatat. Tidak pernah ada interaksi palsu.',
        'গ্রোথ ইঞ্জিন ডিসকভারি প্ল্যাটফর্মে সঠিক অডিয়েন্স সেগমেন্ট খুঁজে, কনটেন্টের ভিন্ন রূপ চেষ্টা করে, আসল ভিউ, সেভ ও বাতিল মাপে, এবং বিতরণকে সেদিকে নিয়ে যায় যেখানে আসল মানুষ সাড়া দেয়। প্রতিটি সিদ্ধান্ত ব্যাখ্যা ও লগ করা হয়। কখনো ভুয়া এনগেজমেন্ট নয়।'
      );
  String get engineStart => _get(
        'Start AI Growth Engine',
        'AI گروتھ انجن شروع کریں',
        'بدء محرك النمو',
      
        'AI ग्रोथ इंजन शुरू करें',
        'Démarrer le moteur de croissance IA',
        'Iniciar el motor de crecimiento con IA',
        'Iniciar o motor de crescimento com IA',
        'KI-Wachstumsmotor starten',
        'YZ Büyüme Motoru\'nu başlat',
        'Mulai Mesin Pertumbuhan AI',
        'AI গ্রোথ ইঞ্জিন চালু করুন'
      );
  String get engineStarted =>
      _get('Growth Engine started', 'گروتھ انجن شروع ہو گیا', 'بدأ محرك النمو',
        'ग्रोथ इंजन शुरू हो गया',
        'Moteur de croissance démarré',
        'Motor de crecimiento iniciado',
        'Motor de crescimento iniciado',
        'Wachstumsmotor gestartet',
        'Büyüme Motoru başlatıldı',
        'Mesin Pertumbuhan dimulai',
        'গ্রোথ ইঞ্জিন চালু হয়েছে'
      );
  String get engineSegments =>
      _get('Audience segments', 'آڈینس سیگمنٹس', 'شرائح الجمهور',
        'ऑडियंस सेगमेंट्स',
        'Segments d\'audience',
        'Segmentos de audiencia',
        'Segmentos de público',
        'Zielgruppensegmente',
        'Kitle segmentleri',
        'Segmen audiens',
        'অডিয়েন্স সেগমেন্ট'
      );
  String get engineVariants =>
      _get('Content variants', 'مواد کی مختلف صورتیں', 'نسخ المحتوى',
        'कंटेंट के रूपांतर',
        'Variantes de contenu',
        'Variantes de contenido',
        'Variações de conteúdo',
        'Content-Varianten',
        'İçerik varyasyonları',
        'Variasi konten',
        'কনটেন্টের ভিন্ন রূপ'
      );
  String get engineLearnings => _get(
        'What the AI learned',
        'AI نے کیا سیکھا',
        'ما تعلَّمه الذكاء الاصطناعي',
      
        'AI ने क्या सीखा',
        'Ce que l\'IA a appris',
        'Lo que aprendió la IA',
        'O que a IA aprendeu',
        'Was die KI gelernt hat',
        'YZ\'nin öğrendikleri',
        'Yang dipelajari AI',
        'AI যা শিখেছে'
      );
  String get engineAuditTrail => _get('Audit trail', 'آڈٹ ٹریل', 'سجل التدقيق',
        'ऑडिट ट्रेल',
        'Journal d\'audit',
        'Registro de auditoría',
        'Trilha de auditoria',
        'Prüfpfad',
        'Denetim izi',
        'Jejak audit',
        'অডিট ট্রেইল'
      );
  String get engineRound => _get('Round', 'راؤنڈ', 'الجولة',
        'राउंड',
        'Tour',
        'Ronda',
        'Rodada',
        'Runde',
        'Tur',
        'Putaran',
        'রাউন্ড'
      );
  String get enginePlacement => _get('Placement', 'پلیسمنٹ', 'الموضع',
        'प्लेसमेंट',
        'Placement',
        'Ubicación',
        'Posicionamento',
        'Platzierung',
        'Yerleşim',
        'Penempatan',
        'প্লেসমেন্ট'
      );
  String get engineResume => _get('Resume', 'بحال کریں', 'استئناف',
        'फिर से शुरू करें',
        'Reprendre',
        'Reanudar',
        'Retomar',
        'Fortsetzen',
        'Devam et',
        'Lanjutkan',
        'আবার চালু করুন'
      );
  String get engineRunRound =>
      _get('Run round now', 'ابھی راؤنڈ چلائیں', 'تشغيل جولة الآن',
        'अभी राउंड चलाएं',
        'Lancer un tour maintenant',
        'Ejecutar ronda ahora',
        'Executar rodada agora',
        'Runde jetzt ausführen',
        'Turu şimdi çalıştır',
        'Jalankan putaran sekarang',
        'এখনই রাউন্ড চালান'
      );
  String get engineStop => _get('Stop', 'روکیں', 'إيقاف',
        'रोकें',
        'Arrêter',
        'Detener',
        'Parar',
        'Stoppen',
        'Durdur',
        'Hentikan',
        'থামান'
      );
  String get engineStopConfirm => _get(
        'Stop the Growth Engine for this campaign? Distribution and learning will halt.',
        'اس مہم کے لیے گروتھ انجن روک دیں؟ تقسیم اور سیکھنا رک جائے گا۔',
        'إيقاف محرك النمو لهذه الحملة؟ سيتوقف التوزيع والتعلُّم.',
      
        'इस अभियान के लिए ग्रोथ इंजन रोकें? वितरण और सीखना रुक जाएगा।',
        'Arrêter le moteur de croissance pour cette campagne ? La distribution et l\'apprentissage s\'arrêteront.',
        '¿Detener el motor de crecimiento de esta campaña? La distribución y el aprendizaje se detendrán.',
        'Parar o motor de crescimento desta campanha? A distribuição e o aprendizado serão interrompidos.',
        'Wachstumsmotor für diese Kampagne stoppen? Verteilung und Lernen werden angehalten.',
        'Bu kampanya için Büyüme Motoru durdurulsun mu? Dağıtım ve öğrenme duracak.',
        'Hentikan Mesin Pertumbuhan untuk kampanye ini? Distribusi dan pembelajaran akan berhenti.',
        'এই ক্যাম্পেইনের জন্য গ্রোথ ইঞ্জিন থামাবেন? বিতরণ ও শেখা বন্ধ হয়ে যাবে।'
      );
  String get engineStopped =>
      _get('Growth Engine stopped', 'گروتھ انجن رک گیا', 'توقف محرك النمو',
        'ग्रोथ इंजन रुक गया',
        'Moteur de croissance arrêté',
        'Motor de crecimiento detenido',
        'Motor de crescimento parado',
        'Wachstumsmotor gestoppt',
        'Büyüme Motoru durduruldu',
        'Mesin Pertumbuhan dihentikan',
        'গ্রোথ ইঞ্জিন থেমে গেছে'
      );
  String get enginePaused => _get(
        'Growth Engine paused',
        'گروتھ انجن موقوف',
        'تم إيقاف محرك النمو مؤقتاً',
      
        'ग्रोथ इंजन रोका गया',
        'Moteur de croissance en pause',
        'Motor de crecimiento en pausa',
        'Motor de crescimento pausado',
        'Wachstumsmotor pausiert',
        'Büyüme Motoru duraklatıldı',
        'Mesin Pertumbuhan dijeda',
        'গ্রোথ ইঞ্জিন বিরতিতে'
      );
  String get engineResumed =>
      _get('Growth Engine resumed', 'گروتھ انجن بحال', 'تم استئناف محرك النمو',
        'ग्रोथ इंजन फिर से शुरू हुआ',
        'Moteur de croissance repris',
        'Motor de crecimiento reanudado',
        'Motor de crescimento retomado',
        'Wachstumsmotor fortgesetzt',
        'Büyüme Motoru devam ettirildi',
        'Mesin Pertumbuhan dilanjutkan',
        'গ্রোথ ইঞ্জিন আবার চালু হয়েছে'
      );
  String get engineRoundDone =>
      _get('Round completed', 'راؤنڈ مکمل', 'اكتملت الجولة',
        'राउंड पूरा हुआ',
        'Tour terminé',
        'Ronda completada',
        'Rodada concluída',
        'Runde abgeschlossen',
        'Tur tamamlandı',
        'Putaran selesai',
        'রাউন্ড সম্পন্ন'
      );
  String get engineWeight => _get('Weight', 'وزن', 'الوزن',
        'वेट',
        'Poids',
        'Peso',
        'Peso',
        'Gewichtung',
        'Ağırlık',
        'Bobot',
        'ওয়েট'
      );
  String get engineRotation => _get('rotation', 'گردش', 'التناوب',
        'रोटेशन',
        'rotation',
        'rotación',
        'rotação',
        'Rotation',
        'rotasyon',
        'rotasi',
        'রোটেশন'
      );
  String get engineWhy => _get('Why', 'کیوں', 'لماذا',
        'क्यों',
        'Pourquoi',
        'Por qué',
        'Por quê',
        'Warum',
        'Neden',
        'Mengapa',
        'কেন'
      );
  String get engineNoLearningsYet => _get(
        'No learnings yet — the first round is still collecting genuine interactions.',
        'ابھی کوئی سیکھ نہیں — پہلا راؤنڈ حقیقی تعاملات جمع کر رہا ہے۔',
        'لا نتائج تعلُّم بعد — الجولة الأولى ما زالت تجمع تفاعلات حقيقية.',
      
        'अभी कोई सीख नहीं — पहला राउंड असली इंटरैक्शन इकट्ठा कर रहा है।',
        'Pas encore d\'apprentissages — le premier tour collecte encore des interactions authentiques.',
        'Aún no hay aprendizajes: la primera ronda sigue recopilando interacciones genuinas.',
        'Sem aprendizados ainda — a primeira rodada ainda está coletando interações genuínas.',
        'Noch keine Erkenntnisse — die erste Runde sammelt noch echte Interaktionen.',
        'Henüz öğrenme yok — ilk tur hâlâ gerçek etkileşimleri topluyor.',
        'Belum ada pembelajaran — putaran pertama masih mengumpulkan interaksi asli.',
        'এখনো কোনো শেখা হয়নি — প্রথম রাউন্ড এখনো আসল ইন্টারঅ্যাকশন সংগ্রহ করছে।'
      );
  String get engineDisclaimer => _get(
        'The Growth Engine only measures genuine interactions from real users in the Discovery Platform. Weights and suggestions are heuristic estimates — Virello never guarantees virality, reach, or sales.',
        'گروتھ انجن صرف ڈسکوری پلیٹ فارم کے حقیقی صارفین کے تعاملات کی پیمائش کرتا ہے۔ وزن اور تجاویز تخمینی ہیں — وائرلو کبھی وائرل ہونے، رسائی یا فروخت کی ضمانت نہیں دیتا۔',
        'يقيس محرك النمو التفاعلات الحقيقية فقط من مستخدمين حقيقيين. الأوزان والاقتراحات تقديرات، لا ضمانات.',
      
        'ग्रोथ इंजन डिस्कवरी प्लेटफ़ॉर्म में असली यूज़र्स की केवल असली इंटरैक्शन मापता है। वेट और सुझाव अनुमानित आंकड़े हैं — Virello कभी वायरलिटी, रीच या बिक्री की गारंटी नहीं देता।',
        'Le moteur de croissance ne mesure que les interactions authentiques de vrais utilisateurs dans la plateforme de découverte. Les poids et suggestions sont des estimations approximatives — Virello ne garantit jamais la viralité, la portée ni les ventes.',
        'El motor de crecimiento solo mide interacciones genuinas de usuarios reales en la plataforma de descubrimiento. Los pesos y sugerencias son estimaciones aproximadas: Virello nunca garantiza viralidad, alcance ni ventas.',
        'O motor de crescimento mede apenas interações genuínas de usuários reais na plataforma de descoberta. Pesos e sugestões são estimativas aproximadas — o Virello nunca garante viralidade, alcance ou vendas.',
        'Der Wachstumsmotor misst nur echte Interaktionen echter Nutzer in der Discovery-Plattform. Gewichtungen und Vorschläge sind grobe Schätzungen — Virello garantiert niemals Viralität, Reichweite oder Umsatz.',
        'Büyüme Motoru, Keşif Platformu\'ndaki gerçek kullanıcıların yalnızca gerçek etkileşimlerini ölçer. Ağırlıklar ve öneriler yaklaşık tahminlerdir — Virello asla viralite, erişim veya satış garantisi vermez.',
        'Mesin Pertumbuhan hanya mengukur interaksi asli dari pengguna nyata di Platform Penemuan. Bobot dan saran adalah perkiraan kasar — Virello tidak pernah menjamin viralitas, jangkauan, atau penjualan.',
        'গ্রোথ ইঞ্জিন ডিসকভারি প্ল্যাটফর্মে আসল ব্যবহারকারীদের শুধুমাত্র আসল ইন্টারঅ্যাকশন মাপে। ওয়েট ও পরামর্শ আনুমানিক হিসাব — Virello কখনো ভাইরালিটি, রিচ বা বিক্রয়ের গ্যারান্টি দেয় না।'
      );
  String get aiOptimizedCaption => _get(
        'AI-optimized presentation',
        'AI سے بہتر پیشکش',
        'عرض محسَّن بالذكاء الاصطناعي',
      
        'AI-ऑप्टिमाइज़्ड प्रस्तुति',
        'Présentation optimisée par l\'IA',
        'Presentación optimizada con IA',
        'Apresentação otimizada com IA',
        'KI-optimierte Präsentation',
        'YZ ile optimize edilmiş sunum',
        'Presentasi yang dioptimalkan AI',
        'AI-অপটিমাইজড উপস্থাপনা'
      );

  // AI Ad Builder (Phase 1)
  String get adBuilder => _get(
        'AI Ad Builder',
        'AI اشتہار بلڈر',
        'منشئ الإعلانات بالذكاء الاصطناعي',
      
        'AI विज्ञापन बिल्डर',
        'Créateur de pubs IA',
        'Creador de anuncios con IA',
        'Criador de anúncios com IA',
        'KI-Anzeigen-Builder',
        'YZ Reklam Oluşturucu',
        'Pembuat Iklan AI',
        'AI বিজ্ঞাপন বিল্ডার'
      );
  String get adBuilderTagline => _get(
        'Paste a post or link — AI analyzes it, proposes a campaign, and waits for your approval. Nothing launches without you.',
        'پوسٹ یا لنک پیسٹ کریں — AI اس کا تجزیہ کرے گا، مہم تجویز کرے گا اور آپ کی منظوری کا انتظار کرے گا۔ آپ کے بغیر کچھ شروع نہیں ہوگا۔',
        'الصق منشوراً أو رابطاً — يحلِّله الذكاء الاصطناعي ويقترح حملة وينتظر موافقتك. لا يُطلَق شيء بدونك.',
      
        'पोस्ट या लिंक पेस्ट करें — AI उसका विश्लेषण करता है, अभियान प्रस्तावित करता है और आपकी स्वीकृति का इंतज़ार करता है। आपके बिना कुछ शुरू नहीं होगा।',
        'Colle un post ou un lien — l\'IA l\'analyse, propose une campagne et attend ton approbation. Rien ne se lance sans toi.',
        'Pega una publicación o un enlace: la IA lo analiza, propone una campaña y espera tu aprobación. Nada se lanza sin ti.',
        'Cole uma publicação ou link — a IA analisa, propõe uma campanha e aguarda sua aprovação. Nada é lançado sem você.',
        'Füge einen Beitrag oder Link ein — die KI analysiert ihn, schlägt eine Kampagne vor und wartet auf deine Freigabe. Nichts startet ohne dich.',
        'Bir gönderi veya bağlantı yapıştır — YZ onu analiz eder, bir kampanya önerir ve onayını bekler. Sensiz hiçbir şey başlamaz.',
        'Tempel postingan atau tautan — AI menganalisisnya, mengusulkan kampanye, dan menunggu persetujuanmu. Tidak ada yang diluncurkan tanpamu.',
        'একটি পোস্ট বা লিংক পেস্ট করুন — AI এটি বিশ্লেষণ করে, একটি ক্যাম্পেইন প্রস্তাব করে এবং আপনার অনুমোদনের অপেক্ষা করে। আপনাকে ছাড়া কিছু চালু হবে না।'
      );
  String get adPasteLabel =>
      _get('Post text or link', 'پوسٹ کا متن یا لنک', 'نص المنشور أو الرابط',
        'पोस्ट टेक्स्ट या लिंक',
        'Texte du post ou lien',
        'Texto de la publicación o enlace',
        'Texto da publicação ou link',
        'Beitragstext oder Link',
        'Gönderi metni veya bağlantı',
        'Teks postingan atau tautan',
        'পোস্ট টেক্সট বা লিংক'
      );
  String get adPasteHint => _get(
        'Paste post text or a public link…',
        'پوسٹ کا متن یا عوامی لنک پیسٹ کریں…',
        'الصق نص المنشور أو رابطاً عاماً…',
      
        'पोस्ट टेक्स्ट या पब्लिक लिंक पेस्ट करें…',
        'Colle le texte du post ou un lien public…',
        'Pega el texto de la publicación o un enlace público…',
        'Cole o texto da publicação ou um link público…',
        'Füge Beitragstext oder einen öffentlichen Link ein…',
        'Gönderi metnini veya herkese açık bir bağlantıyı yapıştır…',
        'Tempel teks postingan atau tautan publik…',
        'পোস্ট টেক্সট বা একটি পাবলিক লিংক পেস্ট করুন…'
      );
  String get adBudgetCap => _get(
        'Budget cap (USD, optional)',
        'بجٹ کی حد (USD، اختیاری)',
        'الحد الأقصى للميزانية (دولار، اختياري)',
      
        'बजट सीमा (USD, वैकल्पिक)',
        'Plafond de budget (USD, facultatif)',
        'Tope de presupuesto (USD, opcional)',
        'Teto de orçamento (USD, opcional)',
        'Budgetobergrenze (USD, optional)',
        'Bütçe üst sınırı (USD, isteğe bağlı)',
        'Batas anggaran (USD, opsional)',
        'বাজেট সীমা (USD, ঐচ্ছিক)'
      );
  String get adAnalyzeBuild => _get(
        'Analyze & build proposal',
        'تجزیہ کریں اور تجویز بنائیں',
        'حلِّل وابنِ المقترح',
      
        'विश्लेषण करें और प्रस्ताव बनाएं',
        'Analyser et créer la proposition',
        'Analizar y crear propuesta',
        'Analisar e criar proposta',
        'Analysieren & Vorschlag erstellen',
        'Analiz et ve teklif oluştur',
        'Analisis & buat usulan',
        'বিশ্লেষণ করুন ও প্রস্তাব তৈরি করুন'
      );
  String get adBuilding => _get(
        'AI is analyzing your content…',
        'AI آپ کے مواد کا تجزیہ کر رہا ہے…',
        'يحلِّل الذكاء الاصطناعي محتواك…',
      
        'AI आपका कंटेंट विश्लेषित कर रहा है…',
        'L\'IA analyse ton contenu…',
        'La IA está analizando tu contenido…',
        'A IA está analisando seu conteúdo…',
        'Die KI analysiert deinen Inhalt…',
        'YZ içeriğini analiz ediyor…',
        'AI sedang menganalisis kontenmu…',
        'AI আপনার কনটেন্ট বিশ্লেষণ করছে…'
      );
  String get academyAskAi => _get(
        'Ask AI about this lesson',
        'اس سبق کے بارے میں AI سے پوچھیں',
      );
  String get academyAskDesc => _get(
        'Stuck on something? The AI answers from this lesson\u2019s content.',
        'کچھ سمجھ نہیں آیا؟ AI اسی سبق کے مواد سے جواب دے گا۔',
      );
  String get academyAskOpen => _get(
        'Ask a question',
        'سوال پوچھیں',
      );
  String get academyAskHint => _get(
        'Type your question\u2026',
        'اپنا سوال لکھیں\u2026',
      );
  String get campInsightsTitle => _get(
        'AI Campaign Insights',
        'AI مہم کی تجاویز',
      );
  String get campInsightsEmpty => _get(
        'AI could not generate insights right now. Try refreshing.',
        'AI اس وقت تجاویز نہیں بنا سکا۔ دوبارہ کوشش کریں۔',
      );
  String get campInsightsRefresh => _get(
        'Refresh insights',
        'تجاویز تازہ کریں',
      );
  String get adCopyTitle => _get(
        'AI Ad Copy',
        'AI اشتہاری متن',
      );
  String get adCopyDesc => _get(
        'Three ready-to-use copy variants for your analyzed post.',
        'آپ کی تجزیہ شدہ پوسٹ کے لیے تین تیار اشتہاری متن۔',
      );
  String get adCopyGenerate => _get(
        'Generate ad copy',
        'اشتہاری متن بنائیں',
      );
  String get adCopyVariant => _get(
        'Variant',
        'ورژن',
      );
  String get adAnalysis =>
      _get('AI analysis', 'AI تجزیہ', 'تحليل الذكاء الاصطناعي',
        'AI विश्लेषण',
        'Analyse IA',
        'Análisis de la IA',
        'Análise da IA',
        'KI-Analyse',
        'YZ analizi',
        'Analisis AI',
        'AI বিশ্লেষণ'
      );
  String get adProposal =>
      _get('Campaign proposal', 'مہم کی تجویز', 'مقترح الحملة',
        'अभियान प्रस्ताव',
        'Proposition de campagne',
        'Propuesta de campaña',
        'Proposta de campanha',
        'Kampagnenvorschlag',
        'Kampanya teklifi',
        'Usulan kampanye',
        'ক্যাম্পেইন প্রস্তাব'
      );
  String get adSegments =>
      _get('Audience segments', 'سامعین کے حصے', 'شرائح الجمهور',
        'ऑडियंस सेगमेंट्स',
        'Segments d\'audience',
        'Segmentos de audiencia',
        'Segmentos de público',
        'Zielgruppensegmente',
        'Kitle segmentleri',
        'Segmen audiens',
        'অডিয়েন্স সেগমেন্ট'
      );
  String get adReachEstimate =>
      _get('Estimated reach', 'متوقع رسائی', 'الوصول المقدَّر',
        'अनुमानित रीच',
        'Portée estimée',
        'Alcance estimado',
        'Alcance estimado',
        'Geschätzte Reichweite',
        'Tahmini erişim',
        'Perkiraan jangkauan',
        'আনুমানিক রিচ'
      );
  String get adEstimateNote => _get(
        'Estimate — not a guarantee. Real results depend on content, delivery, and budget.',
        'تخمینہ — ضمانت نہیں۔ اصل نتائج مواد، ترسیل اور بجٹ پر منحصر ہیں۔',
        'تقدير — ليس ضماناً. تعتمد النتائج الحقيقية على المحتوى والتوزيع والميزانية.',
      
        'अनुमान — गारंटी नहीं। असली नतीजे कंटेंट, डिलीवरी और बजट पर निर्भर हैं।',
        'Estimation — pas une garantie. Les résultats réels dépendent du contenu, de la diffusion et du budget.',
        'Estimación, no garantía. Los resultados reales dependen del contenido, la entrega y el presupuesto.',
        'Estimativa — não é garantia. Os resultados reais dependem do conteúdo, da entrega e do orçamento.',
        'Schätzung — keine Garantie. Echte Ergebnisse hängen von Inhalt, Auslieferung und Budget ab.',
        'Tahmin — garanti değil. Gerçek sonuçlar içeriğe, dağıtıma ve bütçeye bağlıdır.',
        'Perkiraan — bukan jaminan. Hasil nyata bergantung pada konten, penayangan, dan anggaran.',
        'আনুমানিক — গ্যারান্টি নয়। আসল ফলাফল কনটেন্ট, ডেলিভারি ও বাজেটের উপর নির্ভর করে।'
      );
  String get adObjective => _get('Objective', 'مقصد', 'الهدف',
        'उद्देश्य',
        'Objectif',
        'Objetivo',
        'Objetivo',
        'Ziel',
        'Hedef',
        'Tujuan',
        'উদ্দেশ্য'
      );
  String get adDuration => _get('Duration (days)', 'مدت (دن)', 'المدة (أيام)',
        'अवधि (दिन)',
        'Durée (jours)',
        'Duración (días)',
        'Duração (dias)',
        'Dauer (Tage)',
        'Süre (gün)',
        'Durasi (hari)',
        'মেয়াদ (দিন)'
      );
  String get adBudget => _get('Budget (USD)', 'بجٹ (USD)', 'الميزانية (دولار)',
        'बजट (USD)',
        'Budget (USD)',
        'Presupuesto (USD)',
        'Orçamento (USD)',
        'Budget (USD)',
        'Bütçe (USD)',
        'Anggaran (USD)',
        'বাজেট (USD)'
      );
  String get adSubmitApproval =>
      _get('Submit for approval', 'منظوری کے لیے جمع کریں', 'إرسال للاعتماد',
        'स्वीकृति के लिए भेजें',
        'Soumettre pour approbation',
        'Enviar para aprobación',
        'Enviar para aprovação',
        'Zur Genehmigung einreichen',
        'Onay için gönder',
        'Kirim untuk persetujuan',
        'অনুমোদনের জন্য পাঠান'
      );
  String get adApprove =>
      _get('Approve campaign', 'مہم منظور کریں', 'اعتماد الحملة',
        'अभियान स्वीकृत करें',
        'Approuver la campagne',
        'Aprobar campaña',
        'Aprovar campanha',
        'Kampagne genehmigen',
        'Kampanyayı onayla',
        'Setujui kampanye',
        'ক্যাম্পেইন অনুমোদন করুন'
      );
  String get adReject => _get('Reject', 'مسترد کریں', 'رفض',
        'अस्वीकार करें',
        'Rejeter',
        'Rechazar',
        'Rejeitar',
        'Ablehnen',
        'Reddet',
        'Tolak',
        'প্রত্যাখ্যান করুন'
      );
  String get adApprovedToast =>
      _get('Campaign approved ✓', 'مہم منظور ہو گئی ✓', 'تم اعتماد الحملة ✓',
        'अभियान स्वीकृत ✓',
        'Campagne approuvée ✓',
        'Campaña aprobada ✓',
        'Campanha aprovada ✓',
        'Kampagne genehmigt ✓',
        'Kampanya onaylandı ✓',
        'Kampanye disetujui ✓',
        'ক্যাম্পেইন অনুমোদিত ✓'
      );
  String get adSubmittedToast => _get(
        'Submitted for approval ✓',
        'منظوری کے لیے جمع ہو گیا ✓',
        'أُرسل للاعتماد ✓',
      
        'स्वीकृति के लिए भेजा गया ✓',
        'Soumis pour approbation ✓',
        'Enviado para aprobación ✓',
        'Enviado para aprovação ✓',
        'Zur Genehmigung eingereicht ✓',
        'Onay için gönderildi ✓',
        'Dikirim untuk persetujuan ✓',
        'অনুমোদনের জন্য পাঠানো হয়েছে ✓'
      );
  String get adRejectedToast =>
      _get('Campaign rejected', 'مہم مسترد ہو گئی', 'رُفضت الحملة',
        'अभियान अस्वीकृत',
        'Campagne rejetée',
        'Campaña rechazada',
        'Campanha rejeitada',
        'Kampagne abgelehnt',
        'Kampanya reddedildi',
        'Kampanye ditolak',
        'ক্যাম্পেইন প্রত্যাখ্যাত'
      );
  String get adStatusDraft => _get('Draft', 'مسودہ', 'مسودة',
        'ड्राफ्ट',
        'Brouillon',
        'Borrador',
        'Rascunho',
        'Entwurf',
        'Taslak',
        'Draf',
        'খসড়া'
      );
  String get adStatusPending =>
      _get('Pending approval', 'منظوری زیر التواء', 'بانتظار الاعتماد',
        'स्वीकृति लंबित',
        'En attente d\'approbation',
        'Pendiente de aprobación',
        'Aguardando aprovação',
        'Genehmigung ausstehend',
        'Onay bekliyor',
        'Menunggu persetujuan',
        'অনুমোদন বাকি'
      );
  String get adStatusApproved => _get('Approved', 'منظور شدہ', 'معتمدة',
        'स्वीकृत',
        'Approuvée',
        'Aprobada',
        'Aprovada',
        'Genehmigt',
        'Onaylandı',
        'Disetujui',
        'অনুমোদিত'
      );
  String get adStatusRejected => _get('Rejected', 'مسترد شدہ', 'مرفوضة',
        'अस्वीकृत',
        'Rejetée',
        'Rechazada',
        'Rejeitada',
        'Abgelehnt',
        'Reddedildi',
        'Ditolak',
        'প্রত্যাখ্যাত'
      );
  String get adWhyThisSegment =>
      _get('Why this segment?', 'یہ حصہ کیوں؟', 'لماذا هذه الشريحة؟',
        'यह सेगमेंट क्यों?',
        'Pourquoi ce segment ?',
        '¿Por qué este segmento?',
        'Por que este segmento?',
        'Warum dieses Segment?',
        'Neden bu segment?',
        'Kenapa segmen ini?',
        'এই সেগমেন্ট কেন?'
      );
  String get adHeuristicNote => _get(
        'Heuristic proposal — no AI provider is configured yet.',
        'تخمینی تجویز — ابھی کوئی AI فراہم کنندہ منسلک نہیں۔',
        'مقترح تقريبي — لم يتم ربط مزوِّد ذكاء اصطناعي بعد.',
      
        'अनुमानित प्रस्ताव — अभी कोई AI प्रोवाइडर कॉन्फ़िगर नहीं है।',
        'Proposition approximative — aucun fournisseur d\'IA n\'est encore configuré.',
        'Propuesta aproximada: aún no hay ningún proveedor de IA configurado.',
        'Proposta aproximada — nenhum provedor de IA configurado ainda.',
        'Grober Vorschlag — noch kein KI-Anbieter konfiguriert.',
        'Yaklaşık teklif — henüz YZ sağlayıcısı yapılandırılmadı.',
        'Usulan kasar — belum ada penyedia AI yang dikonfigurasi.',
        'আনুমানিক প্রস্তাব — এখনো কোনো AI প্রদানকারী কনফিগার করা হয়নি।'
      );
  String get adAiNote => _get(
        'Proposed with AI assistance — review before approving.',
        'AI کی مدد سے تجویز کردہ — منظور کرنے سے پہلے جائزہ لیں۔',
        'مقترح بمساعدة الذكاء الاصطناعي — راجعه قبل الاعتماد.',
      
        'AI की मदद से प्रस्तावित — स्वीकृत करने से पहले समीक्षा करें।',
        'Proposé avec l\'aide de l\'IA — vérifie avant d\'approuver.',
        'Propuesto con ayuda de la IA: revísalo antes de aprobar.',
        'Proposto com ajuda da IA — revise antes de aprovar.',
        'Mit KI-Unterstützung vorgeschlagen — vor der Genehmigung prüfen.',
        'YZ yardımıyla önerildi — onaylamadan önce incele.',
        'Diusulkan dengan bantuan AI — tinjau sebelum menyetujui.',
        'AI-এর সহায়তায় প্রস্তাবিত — অনুমোদনের আগে পর্যালোচনা করুন।'
      );
  String get adMyCampaigns =>
      _get('My ad campaigns', 'میری اشتہاری مہمات', 'حملاتي الإعلانية',
        'मेरे विज्ञापन अभियान',
        'Mes campagnes publicitaires',
        'Mis campañas publicitarias',
        'Minhas campanhas de anúncios',
        'Meine Werbekampagnen',
        'Reklam kampanyalarım',
        'Kampanye iklanku',
        'আমার বিজ্ঞাপন ক্যাম্পেইন'
      );
  String get adNewCampaign =>
      _get('New ad campaign', 'نئی اشتہاری مہم', 'حملة إعلانية جديدة',
        'नया विज्ञापन अभियान',
        'Nouvelle campagne publicitaire',
        'Nueva campaña publicitaria',
        'Nova campanha de anúncios',
        'Neue Werbekampagne',
        'Yeni reklam kampanyası',
        'Kampanye iklan baru',
        'নতুন বিজ্ঞাপন ক্যাম্পেইন'
      );
  String get adNoCampaigns => _get(
        'No ad campaigns yet. Build your first one.',
        'ابھی کوئی اشتہاری مہم نہیں۔ اپنی پہلی مہم بنائیں۔',
        'لا حملات إعلانية بعد. ابنِ أول حملة لك.',
      
        'अभी कोई विज्ञापन अभियान नहीं। अपना पहला बनाएं।',
        'Aucune campagne publicitaire pour l\'instant. Crée ta première.',
        'Aún no hay campañas publicitarias. Crea la primera.',
        'Nenhuma campanha de anúncios ainda. Crie a primeira.',
        'Noch keine Werbekampagnen. Erstelle deine erste.',
        'Henüz reklam kampanyası yok. İlkini oluştur.',
        'Belum ada kampanye iklan. Buat yang pertama.',
        'এখনো কোনো বিজ্ঞাপন ক্যাম্পেইন নেই। আপনার প্রথমটি তৈরি করুন।'
      );
  String get adBuildFailed => _get(
        'Could not build the campaign. Try again.',
        'مہم نہیں بن سکی۔ دوبارہ کوشش کریں۔',
        'تعذَّر بناء الحملة. حاول مجدداً.',
      
        'अभियान नहीं बनाया जा सका। पुनः प्रयास करें।',
        'Impossible de créer la campagne. Réessaie.',
        'No se pudo crear la campaña. Inténtalo de nuevo.',
        'Não foi possível criar a campanha. Tente novamente.',
        'Kampagne konnte nicht erstellt werden. Versuch es erneut.',
        'Kampanya oluşturulamadı. Tekrar dene.',
        'Gagal membuat kampanye. Coba lagi.',
        'ক্যাম্পেইন তৈরি করা যায়নি। আবার চেষ্টা করুন।'
      );

  // AI Ads — Phase 2: Sponsored Discovery
  String get sponsored => _get('Sponsored', 'مشتہر', 'إعلان مموَّل',
        'स्पॉन्सर्ड',
        'Sponsorisé',
        'Patrocinado',
        'Patrocinado',
        'Gesponsert',
        'Sponsorlu',
        'Bersponsor',
        'স্পনসরড'
      );
  String get sponsoredNote => _get(
        'Paid placement — clearly labeled. Delivery is measured from genuine events only.',
        'معاوضہ جگہ — واضح طور پر نشان زد۔ ترسیل صرف حقیقی واقعات سے ماپی جاتی ہے۔',
        'موضع مدفوع — موسوم بوضوح. يُقاس التوزيع من الأحداث الحقيقية فقط.',
      
        'भुगतान वाला प्लेसमेंट — स्पष्ट रूप से लेबल किया गया। डिलीवरी केवल असली इवेंट्स से मापी जाती है।',
        'Placement payant — clairement indiqué. La diffusion est mesurée uniquement à partir d\'événements authentiques.',
        'Ubicación pagada, claramente etiquetada. La entrega se mide solo a partir de eventos genuinos.',
        'Posicionamento pago — claramente identificado. A entrega é medida apenas a partir de eventos genuínos.',
        'Bezahlte Platzierung — klar gekennzeichnet. Die Auslieferung wird nur anhand echter Ereignisse gemessen.',
        'Ücretli yerleşim — açıkça etiketli. Dağıtım yalnızca gerçek olaylardan ölçülür.',
        'Penempatan berbayar — diberi label jelas. Penayangan hanya diukur dari peristiwa asli.',
        'পেইড প্লেসমেন্ট — স্পষ্টভাবে লেবেল করা। ডেলিভারি শুধুমাত্র আসল ইভেন্ট থেকে মাপা হয়।'
      );
  String get adLaunch =>
      _get('Launch campaign', 'مہم شروع کریں', 'إطلاق الحملة',
        'अभियान शुरू करें',
        'Lancer la campagne',
        'Lanzar campaña',
        'Lançar campanha',
        'Kampagne starten',
        'Kampanyayı başlat',
        'Luncurkan kampanye',
        'ক্যাম্পেইন চালু করুন'
      );
  String get adLaunchCampaign =>
      _get('Launch Campaign', 'مہم شروع کریں', 'إطلاق الحملة',
        'अभियान शुरू करें',
        'Lancer la campagne',
        'Lanzar campaña',
        'Lançar campanha',
        'Kampagne starten',
        'Kampanyayı başlat',
        'Luncurkan Kampanye',
        'ক্যাম্পেইন চালু করুন'
      );
  String get adPause =>
      _get('Pause delivery', 'ترسیل روکیں', 'إيقاف التوزيع مؤقتاً',
        'डिलीवरी रोकें',
        'Mettre la diffusion en pause',
        'Pausar entrega',
        'Pausar entrega',
        'Auslieferung pausieren',
        'Dağıtımı duraklat',
        'Jeda penayangan',
        'ডেলিভারি বিরতি দিন'
      );
  String get adResume =>
      _get('Resume delivery', 'ترسیل بحال کریں', 'استئناف التوزيع',
        'डिलीवरी फिर से शुरू करें',
        'Reprendre la diffusion',
        'Reanudar entrega',
        'Retomar entrega',
        'Auslieferung fortsetzen',
        'Dağıtımı sürdür',
        'Lanjutkan penayangan',
        'ডেলিভারি আবার চালু করুন'
      );
  String get adLaunchedToast => _get(
        'Campaign launched — now delivering ✓',
        'مہم شروع ہو گئی — اب ترسیل جاری ہے ✓',
        'انطلقت الحملة — التوزيع جارٍ الآن ✓',
      
        'अभियान शुरू — अब डिलीवर हो रहा है ✓',
        'Campagne lancée — diffusion en cours ✓',
        'Campaña lanzada: entregando ahora ✓',
        'Campanha lançada — entregando agora ✓',
        'Kampagne gestartet — wird jetzt ausgeliefert ✓',
        'Kampanya başlatıldı — dağıtım sürüyor ✓',
        'Kampanye diluncurkan — sedang ditayangkan ✓',
        'ক্যাম্পেইন চালু — এখন ডেলিভারি চলছে ✓'
      );
  String get adPausedToast =>
      _get('Delivery paused', 'ترسیل روک دی گئی', 'تم إيقاف التوزيع مؤقتاً',
        'डिलीवरी रोकी गई',
        'Diffusion en pause',
        'Entrega en pausa',
        'Entrega pausada',
        'Auslieferung pausiert',
        'Dağıtım duraklatıldı',
        'Penayangan dijeda',
        'ডেলিভারি বিরতিতে'
      );
  String get adResumedToast =>
      _get('Delivery resumed', 'ترسیل بحال ہو گئی', 'تم استئناف التوزيع',
        'डिलीवरी फिर से शुरू',
        'Diffusion reprise',
        'Entrega reanudada',
        'Entrega retomada',
        'Auslieferung fortgesetzt',
        'Dağıtım sürüyor',
        'Penayangan dilanjutkan',
        'ডেলিভারি আবার চালু'
      );
  String get adStatusActive => _get('Active', 'فعال', 'نشطة',
        'सक्रिय',
        'Active',
        'Activa',
        'Ativa',
        'Aktiv',
        'Aktif',
        'Aktif',
        'সক্রিয়'
      );
  String get adStatusPaused => _get('Paused', 'روکی ہوئی', 'موقوفة مؤقتاً',
        'रोकी गई',
        'En pause',
        'En pausa',
        'Em pausa',
        'Pausiert',
        'Duraklatıldı',
        'Dijeda',
        'বিরতিতে'
      );
  String get adStatusCompleted => _get('Completed', 'مکمل', 'مكتملة',
        'पूरी हुई',
        'Terminée',
        'Completada',
        'Concluída',
        'Abgeschlossen',
        'Tamamlandı',
        'Selesai',
        'সম্পন্ন'
      );
  String get adDelivery => _get('Delivery', 'ترسیل', 'التوزيع',
        'डिलीवरी',
        'Diffusion',
        'Entrega',
        'Entrega',
        'Auslieferung',
        'Dağıtım',
        'Penayangan',
        'ডেলিভারি'
      );
  String get adSpend => _get('Spend', 'خرچ', 'الإنفاق',
        'खर्च',
        'Dépense',
        'Gasto',
        'Gasto',
        'Ausgaben',
        'Harcama',
        'Belanja',
        'খরচ'
      );
  String get adImpressions => _get('Impressions', 'نمایاں', 'مرات الظهور',
        'इंप्रेशन्स',
        'Impressions',
        'Impresiones',
        'Impressões',
        'Impressionen',
        'Gösterimler',
        'Tayangan',
        'ইমপ্রেশন'
      );
  String get adPacing => _get('Daily pacing', 'روزانہ رفتار', 'الإيقاع اليومي',
        'दैनिक पेसिंग',
        'Rythme quotidien',
        'Ritmo diario',
        'Ritmo diário',
        'Tägliche Verteilung',
        'Günlük tempo',
        'Ritme harian',
        'দৈনিক পেসিং'
      );
  String get adOnPace => _get('On pace', 'رفتار پر', 'ضمن الإيقاع',
        'गति पर है',
        'Dans les temps',
        'En buen ritmo',
        'No ritmo certo',
        'Im Plan',
        'Hedefte',
        'Sesuai rencana',
        'গতিতে আছে'
      );
  String get adOverPace =>
      _get('Daily limit reached', 'روزانہ حد پوری', 'تم بلوغ الحد اليومي',
        'दैनिक सीमा पूरी हो गई',
        'Limite quotidienne atteinte',
        'Límite diario alcanzado',
        'Limite diário atingido',
        'Tageslimit erreicht',
        'Günlük limite ulaşıldı',
        'Batas harian tercapai',
        'দৈনিক সীমা পূর্ণ'
      );
  String get adWhySponsored => _get(
        'Why am I seeing this?',
        'یہ مجھے کیوں دکھ رہا ہے؟',
        'لماذا أرى هذا؟',
      
        'मुझे यह क्यों दिख रहा है?',
        'Pourquoi est-ce que je vois ceci ?',
        '¿Por qué veo esto?',
        'Por que estou vendo isto?',
        'Warum sehe ich das?',
        'Bunu neden görüyorum?',
        'Mengapa saya melihat ini?',
        'আমি এটি কেন দেখছি?'
      );
  String get adSimulatedNote => _get(
        'Simulated accounting from genuine events — not real money movement.',
        'حقیقی واقعات سے تخمینی حساب — اصل رقم کی منتقلی نہیں۔',
        'محاسبة تقديرية من أحداث حقيقية — ليست حركة أموال فعلية.',
      
        'वास्तविक इवेंट्स से सिम्युलेटेड हिसाब — असली पैसों का लेन-देन नहीं।',
        'Comptabilité simulée à partir d\'événements réels — aucun mouvement d\'argent réel.',
        'Contabilidad simulada a partir de eventos reales — sin movimiento real de dinero.',
        'Contabilidade simulada a partir de eventos reais — sem movimentação real de dinheiro.',
        'Simulierte Abrechnung aus echten Ereignissen — keine echten Geldbewegungen.',
        'Gerçek olaylardan simüle edilmiş muhasebe — gerçek para hareketi yok.',
        'Akuntansi simulasi dari peristiwa nyata — bukan pergerakan uang sungguhan.',
        'আসল ইভেন্ট থেকে সিমুলেটেড হিসাব — প্রকৃত অর্থ লেনদেন নয়।'
      );
  // Phase 3: AI Distribution & Optimization Agent.
  String get adOptimization =>
      _get('AI Optimization', 'AI اصلاح', 'تحسين الذكاء الاصطناعي',
        'AI ऑप्टिमाइज़ेशन',
        'Optimisation IA',
        'Optimización con IA',
        'Otimização com IA',
        'KI-Optimierung',
        'Yapay zeka optimizasyonu',
        'Optimasi AI',
        'AI অপ্টিমাইজেশন'
      );
  String get adOptimizeNow =>
      _get('Optimize now', 'ابھی اصلاح کریں', 'حسِّن الآن',
        'अभी ऑप्टिमाइज़ करें',
        'Optimiser',
        'Optimizar ahora',
        'Otimizar agora',
        'Jetzt optimieren',
        'Şimdi optimize et',
        'Optimalkan sekarang',
        'এখনই অপ্টিমাইজ করুন'
      );
  String get adOptimizing => _get(
        'AI is analyzing measured performance…',
        'AI ماپی گئی کارکردگی کا تجزیہ کر رہا ہے…',
        'يحلِّل الذكاء الاصطناعي الأداء المقاس…',
      
        'AI मापे गए प्रदर्शन का विश्लेषण कर रहा है…',
        'L\'IA analyse les performances mesurées…',
        'La IA está analizando el rendimiento medido…',
        'A IA está analisando o desempenho medido…',
        'Die KI analysiert die gemessene Leistung…',
        'Yapay zeka ölçülen performansı analiz ediyor…',
        'AI sedang menganalisis performa terukur…',
        'AI পরিমাপকৃত পারফরম্যান্স বিশ্লেষণ করছে…'
      );
  String get adOptimizedToast =>
      _get('Optimization complete ✓', 'اصلاح مکمل ✓', 'اكتمل التحسين ✓',
        'ऑप्टिमाइज़ेशन पूर्ण ✓',
        'Optimisation terminée ✓',
        'Optimización completa ✓',
        'Otimização concluída ✓',
        'Optimierung abgeschlossen ✓',
        'Optimizasyon tamamlandı ✓',
        'Optimasi selesai ✓',
        'অপ্টিমাইজেশন সম্পূর্ণ ✓'
      );
  String get adOptimizeFailed => _get(
        'Optimization failed. Try again.',
        'اصلاح ناکام ہوئی۔ دوبارہ کوشش کریں۔',
        'فشل التحسين. حاول مجدداً.',
      
        'ऑप्टिमाइज़ेशन विफल रहा। पुनः प्रयास करें।',
        'L\'optimisation a échoué. Réessayez.',
        'La optimización falló. Inténtalo de nuevo.',
        'A otimização falhou. Tente novamente.',
        'Optimierung fehlgeschlagen. Versuche es erneut.',
        'Optimizasyon başarısız oldu. Tekrar dene.',
        'Optimasi gagal. Coba lagi.',
        'অপ্টিমাইজেশন ব্যর্থ হয়েছে। আবার চেষ্টা করুন।'
      );
  String get adLatestRun =>
      _get('Latest optimization run', 'تازہ ترین اصلاح', 'آخر عملية تحسين',
        'नवीनतम ऑप्टिमाइज़ेशन रन',
        'Dernière optimisation',
        'Última optimización',
        'Última otimização',
        'Letzte Optimierung',
        'Son optimizasyon',
        'Optimasi terakhir',
        'সর্বশেষ অপ্টিমাইজেশন'
      );
  String get adNoRunsYet => _get(
        'No optimization runs yet. Run the AI optimizer to learn from genuine events.',
        'ابھی کوئی اصلاح نہیں ہوئی۔ حقیقی واقعات سے سیکھنے کے لیے AI اصلاح چلائیں۔',
        'لا عمليات تحسين بعد. شغِّل المحسِّن للتعلُّم من الأحداث الحقيقية.',
      
        'अभी तक कोई ऑप्टिमाइज़ेशन नहीं हुआ। वास्तविक इवेंट्स से सीखने के लिए AI ऑप्टिमाइज़र चलाएं।',
        'Aucune optimisation pour l\'instant. Lancez l\'optimiseur IA pour apprendre des événements réels.',
        'Aún no hay optimizaciones. Ejecuta el optimizador de IA para aprender de eventos reales.',
        'Nenhuma otimização ainda. Execute o otimizador de IA para aprender com eventos reais.',
        'Noch keine Optimierungen. Starte den KI-Optimierer, um aus echten Ereignissen zu lernen.',
        'Henüz optimizasyon çalıştırılmadı. Gerçek olaylardan öğrenmek için yapay zeka iyileştiriciyi çalıştır.',
        'Belum ada optimasi. Jalankan pengoptimal AI untuk belajar dari peristiwa nyata.',
        'এখনো কোনো অপ্টিমাইজেশন হয়নি। আসল ইভেন্ট থেকে শিখতে AI অপ্টিমাইজার চালান।'
      );
  String get adSafetyPausedNote => _get(
        'Safety pause: suspicious traffic was detected, so delivery stopped automatically. An admin must review it before delivery resumes.',
        'حفاظتی روک: مشکوک ٹریفک پائی گئی، اس لیے ترسیل خودکار طور پر رک گئی۔ بحالی سے پہلے ایڈمن کو جائزہ لینا ہوگا۔',
        'إيقاف احترازي: رُصدت حركة مشبوهة فتوقف التوزيع تلقائياً. يجب أن يراجعه مدير قبل استئناف التوزيع.',
      
        'सुरक्षा रोक: संदिग्ध ट्रैफ़िक पाया गया, इसलिए डिलीवरी अपने आप रुक गई। डिलीवरी फिर से शुरू होने से पहले एडमिन को इसकी समीक्षा करनी होगी।',
        'Pause de sécurité : un trafic suspect a été détecté, la diffusion s\'est donc arrêtée automatiquement. Un administrateur doit l\'examiner avant sa reprise.',
        'Pausa de seguridad: se detectó tráfico sospechoso, por lo que la entrega se detuvo automáticamente. Un administrador debe revisarla antes de reanudarla.',
        'Pausa de segurança: tráfego suspeito foi detectado, então a veiculação parou automaticamente. Um administrador deve revisá-la antes da retomada.',
        'Sicherheitspause: Verdächtiger Traffic wurde erkannt, die Auslieferung wurde automatisch gestoppt. Ein Admin muss sie prüfen, bevor sie fortgesetzt wird.',
        'Güvenlik duraklatması: şüpheli trafik tespit edildi, bu yüzden dağıtım otomatik olarak durduruldu. Dağıtım devam etmeden önce bir yöneticinin incelemesi gerekir.',
        'Jeda keamanan: lalu lintas mencurigakan terdeteksi, sehingga penayangan berhenti otomatis. Admin harus meninjaunya sebelum penayangan dilanjutkan.',
        'নিরাপত্তা বিরতি: সন্দেহজনক ট্রাফিক শনাক্ত হয়েছে, তাই ডেলিভারি স্বয়ংক্রিয়ভাবে বন্ধ হয়ে গেছে। ডেলিভারি পুনরায় শুরু হওয়ার আগে একজন অ্যাডমিনকে এটি পর্যালোচনা করতে হবে।'
      );
  String get adSegmentPerformance =>
      _get('Segment performance', 'حصوں کی کارکردگی', 'أداء الشرائح',
        'सेगमेंट प्रदर्शन',
        'Performance des segments',
        'Rendimiento de segmentos',
        'Desempenho dos segmentos',
        'Segmentleistung',
        'Segment performansı',
        'Performa segmen',
        'সেগমেন্ট পারফরম্যান্স'
      );
  String get adVariantPerformance =>
      _get('Creative variants', 'تخلیقی اقسام', 'النسخ الإبداعية',
        'क्रिएटिव वेरिएंट',
        'Variantes créatives',
        'Variantes creativas',
        'Variações criativas',
        'Kreative Varianten',
        'Yaratıcı varyantlar',
        'Varian kreatif',
        'ক্রিয়েটিভ ভ্যারিয়েন্ট'
      );
  String get adPlacementPerformance => _get('Placements', 'مقامات', 'المواضع',
        'प्लेसमेंट',
        'Emplacements',
        'Ubicaciones',
        'Posicionamentos',
        'Platzierungen',
        'Yerleşimler',
        'Penempatan',
        'প্লেসমেন্ট'
      );
  String get adDecisionFeed => _get(
        'Why the AI changed things',
        'AI نے تبدیلیاں کیوں کیں',
        'لماذا غيَّر الذكاء الاصطناعي الأمور',
      
        'AI ने बदलाव क्यों किए',
        'Pourquoi l\'IA a modifié des éléments',
        'Por qué la IA cambió cosas',
        'Por que a IA mudou as coisas',
        'Warum die KI Dinge geändert hat',
        'Yapay zeka neden değişiklik yaptı',
        'Mengapa AI mengubah berbagai hal',
        'AI কেন পরিবর্তন করেছে'
      );
  String get adInsufficientData => _get(
        'Too little data to judge yet',
        'جائزے کے لیے ابھی ڈیٹا ناکافی ہے',
        'البيانات قليلة جداً للحكم بعد',
      
        'आकलन के लिए अभी डेटा बहुत कम है',
        'Pas encore assez de données pour juger',
        'Aún hay pocos datos para evaluar',
        'Dados insuficientes para avaliar ainda',
        'Noch zu wenig Daten zur Beurteilung',
        'Değerlendirmek için henüz çok az veri var',
        'Data masih terlalu sedikit untuk dinilai',
        'মূল্যায়নের জন্য এখনো ডেটা খুব কম'
      );
  String get adWeight => _get('Weight', 'وزن', 'الوزن',
        'वेट',
        'Pondération',
        'Peso',
        'Peso',
        'Gewichtung',
        'Ağırlık',
        'Bobot',
        'ওজন'
      );
  String get adEngagementRate =>
      _get('Engagement rate', 'مشغولیت کی شرح', 'معدل التفاعل',
        'एंगेजमेंट रेट',
        'Taux d\'engagement',
        'Tasa de interacción',
        'Taxa de engajamento',
        'Interaktionsrate',
        'Etkileşim oranı',
        'Tingkat interaksi',
        'এনগেজমেন্ট রেট'
      );
  String get adOptimizeNote => _get(
        'Measured from genuine events only. The optimizer never raises your budget — it only reweights distribution.',
        'صرف حقیقی واقعات سے ماپا گیا۔ اصلاح آپ کا بجٹ کبھی نہیں بڑھاتا — صرف ترسیل کی تقسیم بدلتا ہے۔',
        'يُقاس من الأحداث الحقيقية فقط. لا يرفع المحسِّن ميزانيتك أبداً — بل يعيد توزيع الأوزان فقط.',
      
        'केवल वास्तविक इवेंट्स से मापा गया। ऑप्टिमाइज़र आपका बजट कभी नहीं बढ़ाता — वह सिर्फ़ वितरण का वज़न बदलता है।',
        'Mesuré uniquement à partir d\'événements réels. L\'optimiseur n\'augmente jamais votre budget — il ne fait que rééquilibrer la distribution.',
        'Medido solo a partir de eventos reales. El optimizador nunca aumenta tu presupuesto — solo redistribuye la entrega.',
        'Medido apenas a partir de eventos reais. O otimizador nunca aumenta seu orçamento — apenas redistribui a veiculação.',
        'Nur aus echten Ereignissen gemessen. Der Optimierer erhöht dein Budget niemals — er gewichtet nur die Verteilung neu.',
        'Yalnızca gerçek olaylardan ölçülür. İyileştirici bütçeni asla artırmaz — yalnızca dağıtımı yeniden dengeler.',
        'Diukur hanya dari peristiwa nyata. Pengoptimal tidak pernah menaikkan anggaranmu — hanya menyeimbangkan ulang distribusi.',
        'শুধুমাত্র আসল ইভেন্ট থেকে পরিমাপ করা। অপ্টিমাইজার কখনো আপনার বাজেট বাড়ায় না — এটি শুধু বণ্টন পুনর্বিন্যাস করে।'
      );
  // Phase 4: Conversion Attribution.
  String get adDashboard =>
      _get('Attribution dashboard', 'انتساب ڈیش بورڈ', 'لوحة الانتساب',
        'एट्रिब्यूशन डैशबोर्ड',
        'Tableau d\'attribution',
        'Panel de atribución',
        'Painel de atribuição',
        'Attributions-Dashboard',
        'İlişkilendirme panosu',
        'Dasbor atribusi',
        'অ্যাট্রিবিউশন ড্যাশবোর্ড'
      );
  String get adReach => _get('Reach', 'رسائی', 'الوصول',
        'रीच',
        'Portée',
        'Alcance',
        'Alcance',
        'Reichweite',
        'Erişim',
        'Jangkauan',
        'রিচ'
      );
  String get adViews => _get('Views', 'ویوز', 'المشاهدات',
        'व्यूज़',
        'Vues',
        'Vistas',
        'Visualizações',
        'Aufrufe',
        'Görüntülenme',
        'Tayangan',
        'ভিউ'
      );
  String get adEngagement => _get('Engagement', 'مشغولیت', 'التفاعل',
        'एंगेजमेंट',
        'Engagement',
        'Interacción',
        'Engajamento',
        'Interaktion',
        'Etkileşim',
        'Interaksi',
        'এনগেজমেন্ট'
      );
  String get adFollowersGained =>
      _get('Followers gained', 'نئے فالوورز', 'متابعون جدد',
        'नए फॉलोअर्स',
        'Abonnés gagnés',
        'Seguidores ganados',
        'Seguidores ganhos',
        'Gewonnene Follower',
        'Kazanılan takipçi',
        'Pengikut yang diperoleh',
        'নতুন ফলোয়ার'
      );
  String get adClicks => _get('Clicks', 'کلکس', 'النقرات',
        'क्लिक्स',
        'Clics',
        'Clics',
        'Cliques',
        'Klicks',
        'Tıklama',
        'Klik',
        'ক্লিক'
      );
  String get adLeads => _get('Leads', 'لیڈز', 'العملاء المحتملون',
        'लीड्स',
        'Prospects',
        'Clientes potenciales',
        'Leads',
        'Leads',
        'Potansiyel müşteri',
        'Prospek',
        'লিড'
      );
  String get adConversions => _get('Conversions', 'کنورژنز', 'التحويلات',
        'कन्वर्ज़न',
        'Conversions',
        'Conversiones',
        'Conversões',
        'Conversions',
        'Dönüşüm',
        'Konversi',
        'কনভার্সন'
      );
  String get adCostPerResult =>
      _get('Cost per result', 'فی نتیجہ لاگت', 'التكلفة لكل نتيجة',
        'प्रति परिणाम लागत',
        'Coût par résultat',
        'Costo por resultado',
        'Custo por resultado',
        'Kosten pro Ergebnis',
        'Sonuç başına maliyet',
        'Biaya per hasil',
        'প্রতি ফলাফলে খরচ'
      );
  String get adAttrRevenue =>
      _get('Attributable revenue', 'منسوب آمدنی', 'الإيرادات المنسوبة',
        'एट्रिब्यूटेबल रेवेन्यू',
        'Revenus attribuables',
        'Ingresos atribuibles',
        'Receita atribuível',
        'Zurechenbarer Umsatz',
        'İlişkilendirilebilir gelir',
        'Pendapatan yang dapat diatribusikan',
        'অ্যাট্রিবিউটেবল রেভিনিউ'
      );
  String get adMeasured => _get('Measured', 'ماپا گیا', 'مقاس',
        'मापा गया',
        'Mesuré',
        'Medido',
        'Medido',
        'Gemessen',
        'Ölçülen',
        'Terukur',
        'পরিমাপকৃত'
      );
  String get adEstimate => _get('Estimate', 'تخمینہ', 'تقدير',
        'अनुमान',
        'Estimation',
        'Estimación',
        'Estimativa',
        'Schätzung',
        'Tahmin',
        'Estimasi',
        'অনুমান'
      );
  String get adLastClick => _get(
        'Last-click attribution — each conversion is credited to the ad tap that preceded it.',
        'آخری کلک انتساب — ہر کنورژن اس اشتہاری کلک کو دیا جاتا ہے جو اس سے پہلے ہوا۔',
        'انتساب النقرة الأخيرة — يُنسَب كل تحويل إلى نقرة الإعلان التي سبقته.',
      
        'लास्ट-क्लिक एट्रिब्यूशन — हर कन्वर्ज़न उस विज्ञापन टैप को दिया जाता है जो उससे पहले हुआ था।',
        'Attribution au dernier clic — chaque conversion est créditée au tap publicitaire qui l\'a précédée.',
        'Atribución al último clic — cada conversión se acredita al toque del anuncio que la precedió.',
        'Atribuição ao último clique — cada conversão é creditada ao toque no anúncio que a precedeu.',
        'Last-Click-Attribution — jede Conversion wird dem Anzeigen-Tap zugeschrieben, der ihr vorausging.',
        'Son tıklama ilişkilendirmesi — her dönüşüm, ondan önce gerçekleşen reklam dokunuşuna yazılır.',
        'Atribusi klik terakhir — setiap konversi dikreditkan ke ketukan iklan yang mendahuluinya.',
        'লাস্ট-ক্লিক অ্যাট্রিবিউশন — প্রতিটি কনভার্সন সেই বিজ্ঞাপন ট্যাপের নামে গণ্য হয় যা তার আগে হয়েছিল।'
      );
  String get adRevenueNote => _get(
        'Revenue is advertiser-reported / measured from their pixel, webhook, or API — not platform-verified sales.',
        'آمدنی مشتہر کی رپورٹ کردہ / ماپی گئی ہے (پکسل، ویب ہک یا API سے) — پلیٹفارم سے تصدیق شدہ فروخت نہیں۔',
        'الإيرادات مُبلَّغ عنها من المعلن / مقاسة من البكسل أو الويبهوك — ليست مبيعات موثَّقة من المنصة.',
      
        'रेवेन्यू विज्ञापनदाता द्वारा रिपोर्ट किया गया / उनके पिक्सेल, वेबहुक या API से मापा गया है — प्लेटफ़ॉर्म द्वारा सत्यापित बिक्री नहीं।',
        'Les revenus sont déclarés par l\'annonceur / mesurés via son pixel, webhook ou API — pas des ventes vérifiées par la plateforme.',
        'Los ingresos son reportados por el anunciante / medidos desde su píxel, webhook o API — no ventas verificadas por la plataforma.',
        'A receita é relatada pelo anunciante / medida a partir de seu pixel, webhook ou API — não vendas verificadas pela plataforma.',
        'Der Umsatz wird vom Werbetreibenden gemeldet / aus seinem Pixel, Webhook oder seiner API gemessen — keine plattformverifizierten Verkäufe.',
        'Gelir, reklamveren tarafından bildirilir / piksel, webhook veya API\'sinden ölçülür — platform tarafından doğrulanmış satışlar değildir.',
        'Pendapatan dilaporkan oleh pengiklan / diukur dari piksel, webhook, atau API mereka — bukan penjualan terverifikasi platform.',
        'রেভিনিউ বিজ্ঞাপনদাতার রিপোর্ট করা / তাদের পিক্সেল, ওয়েবহুক বা API থেকে পরিমাপ করা — প্ল্যাটফর্ম-যাচাইকৃত বিক্রি নয়।'
      );
  // Audience Intelligence Engine (multi-source).
  String get audienceIntel =>
      _get('Audience Intelligence', 'آڈینس انٹیلی جنس', 'ذكاء الجمهور',
        'ऑडियंस इंटेलिजेंस',
        'Intelligence d\'audience',
        'Inteligencia de audiencia',
        'Inteligência de público',
        'Zielgruppen-Intelligenz',
        'Kitle zekası',
        'Kecerdasan audiens',
        'অডিয়েন্স ইন্টেলিজেন্স'
      );
  String get aiSources => _get('Sources', 'ذرائع', 'المصادر',
        'स्रोत',
        'Sources',
        'Fuentes',
        'Fontes',
        'Quellen',
        'Kaynaklar',
        'Sumber',
        'উৎস'
      );
  String get aiSegments => _get('Segments', 'طبقات', 'الشرائح',
        'सेगमेंट',
        'Segments',
        'Segmentos',
        'Segmentos',
        'Segmente',
        'Segmentler',
        'Segmen',
        'সেগমেন্ট'
      );
  String get aiFingerprint => _get('Fingerprint', 'فنگر پرنٹ', 'البصمة',
        'फ़िंगरप्रिंट',
        'Empreinte',
        'Huella',
        'Impressão digital',
        'Fingerabdruck',
        'Parmak izi',
        'Sidik jari',
        'ফিঙ্গারপ্রিন্ট'
      );
  String get aiSourceStatusReady => _get('Ready', 'تیار', 'جاهز',
        'तैयार',
        'Prêt',
        'Listo',
        'Pronto',
        'Bereit',
        'Hazır',
        'Siap',
        'প্রস্তুত'
      );
  String get aiSourceStatusNotConfigured =>
      _get('Not configured', 'ترتیب نہیں', 'غير مُعَدّ',
        'कॉन्फ़िगर नहीं',
        'Non configuré',
        'Sin configurar',
        'Não configurado',
        'Nicht konfiguriert',
        'Yapılandırılmadı',
        'Belum dikonfigurasi',
        'কনফিগার করা হয়নি'
      );
  String get aiSourceStatusDegraded => _get('Degraded', 'متاثر', 'متدهور',
        'खराब स्थिति',
        'Dégradé',
        'Degradado',
        'Degradado',
        'Beeinträchtigt',
        'Zayıflamış',
        'Menurun',
        'অবনত'
      );
  String get aiNoFakeData => _get(
        'Unconfigured sources return no data \u2014 never synthetic.',
        'غیر ترتیب شدہ ذرائع کوئی ڈیٹا نہیں دیتے \u2014 کبھی مصنوعی نہیں۔',
        'المصادر غير المُعَدَّة لا تُرجع بيانات — أبداً بيانات اصطناعية.',
      
        'बिना कॉन्फ़िगर किए गए स्रोत कोई डेटा नहीं देते — कभी कृत्रिम नहीं।',
        'Les sources non configurées ne renvoient aucune donnée — jamais de données synthétiques.',
        'Las fuentes sin configurar no devuelven datos — nunca sintéticos.',
        'Fontes não configuradas não retornam dados — nunca sintéticos.',
        'Nicht konfigurierte Quellen liefern keine Daten — niemals synthetisch.',
        'Yapılandırılmamış kaynaklar veri döndürmez — asla sentetik değil.',
        'Sumber yang belum dikonfigurasi tidak mengembalikan data — tidak pernah sintetis.',
        'কনফিগার না করা উৎস কোনো ডেটা দেয় না — কখনো কৃত্রিম নয়।'
      );
  String get aiVolumeUnavailable =>
      _get('Volume unavailable', 'حجم دستیاب نہیں', 'الحجم غير متاح',
        'वॉल्यूम उपलब्ध नहीं',
        'Volume indisponible',
        'Volumen no disponible',
        'Volume indisponível',
        'Volumen nicht verfügbar',
        'Hacim mevcut değil',
        'Volume tidak tersedia',
        'ভলিউম উপলব্ধ নেই'
      );
  String get aiConfidence => _get('Confidence', 'اعتماد', 'الثقة',
        'विश्वास',
        'Confiance',
        'Confianza',
        'Confiança',
        'Vertrauen',
        'Güven',
        'Keyakinan',
        'আত্মবিশ্বাস'
      );
  String get aiSegmentPath => _get('Path', 'راستہ', 'المسار',
        'पथ',
        'Chemin',
        'Ruta',
        'Caminho',
        'Pfad',
        'Yol',
        'Jalur',
        'পথ'
      );
  String get aiSourceBreakdown =>
      _get('Source breakdown', 'ذرائع کی تفصیل', 'تفصيل المصادر',
        'स्रोत विवरण',
        'Répartition par source',
        'Desglose por fuente',
        'Detalhamento por fonte',
        'Aufschlüsselung nach Quelle',
        'Kaynak dağılımı',
        'Rincian sumber',
        'উৎসভিত্তিক বিবরণ'
      );
  String get aiAnalyzePost => _get(
        'Analyze post for audience fit',
        'آڈینس مطابقت کے لیے پوسٹ کا تجزیہ کریں',
        'تحليل المنشور لملاءمة الجمهور',
      
        'ऑडियंस फ़िट के लिए पोस्ट का विश्लेषण करें',
        'Analyser la publication pour l\'adéquation à l\'audience',
        'Analizar la publicación para la afinidad con la audiencia',
        'Analisar a publicação para adequação ao público',
        'Beitrag auf Zielgruppen-Fit analysieren',
        'Kitle uyumu için gönderiyi analiz et',
        'Analisis postingan untuk kecocokan audiens',
        'অডিয়েন্স ফিটের জন্য পোস্ট বিশ্লেষণ করুন'
      );
  String get aiPastePostHint => _get(
        'Paste post text or a link\u2026',
        'پوسٹ کا متن یا لنک پیسٹ کریں\u2026',
        'الصق نص المنشور أو رابطاً…',
      
        'पोस्ट का टेक्स्ट या लिंक पेस्ट करें…',
        'Collez le texte ou un lien de la publication…',
        'Pega el texto de la publicación o un enlace…',
        'Cole o texto da publicação ou um link…',
        'Beitragstext oder Link einfügen…',
        'Gönderi metnini veya bağlantıyı yapıştır…',
        'Tempel teks postingan atau tautan…',
        'পোস্টের টেক্সট বা লিংক পেস্ট করুন…'
      );
  String get aiNoMatch => _get(
        'No strong segment matches yet.',
        'ابھی کوئی مضبوط مطابقت نہیں۔',
        'لا مطابقات قوية للشرائح بعد.',
      
        'अभी तक कोई मज़बूत सेगमेंट मैच नहीं।',
        'Aucune correspondance forte de segment pour l\'instant.',
        'Aún no hay coincidencias fuertes de segmentos.',
        'Nenhuma correspondência forte de segmentos ainda.',
        'Noch keine starken Segment-Übereinstimmungen.',
        'Henüz güçlü segment eşleşmesi yok.',
        'Belum ada kecocokan segmen yang kuat.',
        'এখনো কোনো শক্তিশালী সেগমেন্ট মিল নেই।'
      );
  String get aiFitScore => _get('Fit score', 'مطابقت اسکور', 'درجة الملاءمة',
        'फ़िट स्कोर',
        'Score d\'adéquation',
        'Puntuación de afinidad',
        'Pontuação de adequação',
        'Fit-Score',
        'Uyum skoru',
        'Skor kecocokan',
        'ফিট স্কোর'
      );
  String get aiRelevanceFitNote => _get(
        'Relevance fit \u2014 not a reach or virality guarantee.',
        'مطابقت کا اندازہ \u2014 رسائی یا وائرلٹی کی ضمانت نہیں۔',
        'ملاءمة الصلة — ليست ضماناً للوصول أو الانتشار.',
      
        'प्रासंगिकता फ़िट — रीच या वायरलिटी की गारंटी नहीं।',
        'Adéquation de pertinence — sans garantie de portée ni de viralité.',
        'Afinidad de relevancia — sin garantía de alcance ni viralidad.',
        'Adequação de relevância — sem garantia de alcance ou viralidade.',
        'Relevanz-Fit — keine Reichweiten- oder Viralitätsgarantie.',
        'Alaka uyumu — erişim veya viralite garantisi değildir.',
        'Kecocokan relevansi — bukan jaminan jangkauan atau viralitas.',
        'প্রাসঙ্গিকতা ফিট — রিচ বা ভাইরালিটির গ্যারান্টি নয়।'
      );
  String get aiWhyThis =>
      _get('Why this segment', 'یہ طبقہ کیوں', 'لماذا هذه الشريحة',
        'यह सेगमेंट क्यों',
        'Pourquoi ce segment',
        'Por qué este segmento',
        'Por que este segmento',
        'Warum dieses Segment',
        'Neden bu segment',
        'Mengapa segmen ini',
        'এই সেগমেন্ট কেন'
      );

  // Multilingual language layer
  String get langSettings => _get('Language', 'زبان', 'اللغة',
        'भाषा',
        'Langue',
        'Idioma',
        'Idioma',
        'Sprache',
        'Dil',
        'Bahasa',
        'ভাষা'
      );
  String get langUiLanguage =>
      _get('App language', 'ایپ کی زبان', 'لغة التطبيق',
        'ऐप की भाषा',
        'Langue de l\'application',
        'Idioma de la aplicación',
        'Idioma do aplicativo',
        'App-Sprache',
        'Uygulama dili',
        'Bahasa aplikasi',
        'অ্যাপের ভাষা'
      );
  String get langUiFullNote =>
      _get('Full interface', 'مکمل انٹرفیس', 'واجهة كاملة',
        'पूर्ण इंटरफ़ेस',
        'Interface complète',
        'Interfaz completa',
        'Interface completa',
        'Vollständige Oberfläche',
        'Tam arayüz',
        'Antarmuka penuh',
        'সম্পূর্ণ ইন্টারফেস'
      );
  String get langUiPartialNote => _get(
        'Interface not fully translated yet — content languages fully supported.',
        'انٹرفیس ابھی مکمل ترجمہ نہیں — مواد کی زبانیں مکمل معاون ہیں۔',
        'الواجهة غير مترجمة بالكامل بعد — لغات المحتوى مدعومة بالكامل.',
      
        'इंटरफ़ेस अभी पूरी तरह अनुवादित नहीं है — सामग्री की भाषाएं पूरी तरह समर्थित हैं।',
        'L\'interface n\'est pas encore entièrement traduite — les langues de contenu sont pleinement prises en charge.',
        'La interfaz aún no está totalmente traducida — los idiomas de contenido son totalmente compatibles.',
        'A interface ainda não está totalmente traduzida — os idiomas de conteúdo são totalmente suportados.',
        'Die Oberfläche ist noch nicht vollständig übersetzt — Inhaltssprachen werden vollständig unterstützt.',
        'Arayüz henüz tam çevrilmedi — içerik dilleri tamamen destekleniyor.',
        'Antarmuka belum sepenuhnya diterjemahkan — bahasa konten didukung penuh.',
        'ইন্টারফেস এখনো পুরোপুরি অনুবাদ হয়নি — কনটেন্টের ভাষাগুলো সম্পূর্ণ সমর্থিত।'
      );
  String get langContentLanguages =>
      _get('Content languages', 'مواد کی زبانیں', 'لغات المحتوى',
        'सामग्री की भाषाएं',
        'Langues de contenu',
        'Idiomas de contenido',
        'Idiomas de conteúdo',
        'Inhaltssprachen',
        'İçerik dilleri',
        'Bahasa konten',
        'কনটেন্টের ভাষা'
      );
  String get langPreferred =>
      _get('Preferred language', 'ترجیحی زبان', 'اللغة المفضلة',
        'पसंदीदा भाषा',
        'Langue préférée',
        'Idioma preferido',
        'Idioma preferido',
        'Bevorzugte Sprache',
        'Tercih edilen dil',
        'Bahasa pilihan',
        'পছন্দের ভাষা'
      );
  String get langAllRelevant => _get(
        'All relevant languages',
        'تمام متعلقہ زبانیں',
        'كل اللغات ذات الصلة',
      
        'सभी प्रासंगिक भाषाएं',
        'Toutes les langues pertinentes',
        'Todos los idiomas relevantes',
        'Todos os idiomas relevantes',
        'Alle relevanten Sprachen',
        'Tüm ilgili diller',
        'Semua bahasa yang relevan',
        'সব প্রাসঙ্গিক ভাষা'
      );
  String get langAllRelevantDesc => _get(
        'Let AI match content across every supported language.',
        'AI کو ہر معاون زبان میں مواد ملانے دیں۔',
        'دع الذكاء الاصطناعي يطابق المحتوى عبر كل اللغات المدعومة.',
      
        'AI को हर समर्थित भाषा में सामग्री मिलाने दें।',
        'Laissez l\'IA associer du contenu dans toutes les langues prises en charge.',
        'Deja que la IA combine contenido en todos los idiomas compatibles.',
        'Deixe a IA combinar conteúdo em todos os idiomas suportados.',
        'Lass die KI Inhalte in allen unterstützten Sprachen zuordnen.',
        'Yapay zekanın desteklenen her dilde içerik eşleştirmesine izin ver.',
        'Biarkan AI mencocokkan konten di setiap bahasa yang didukung.',
        'AI-কে প্রতিটি সমর্থিত ভাষায় কনটেন্ট মেলাতে দিন।'
      );
  String get langOriginal =>
      _get('Original language', 'اصل زبان', 'اللغة الأصلية',
        'मूल भाषा',
        'Langue d\'origine',
        'Idioma original',
        'Idioma original',
        'Originalsprache',
        'Orijinal dil',
        'Bahasa asli',
        'মূল ভাষা'
      );
  String get langUncertain =>
      _get('Language uncertain', 'زبان غیر یقینی', 'اللغة غير مؤكدة',
        'भाषा अनिश्चित',
        'Langue incertaine',
        'Idioma incierto',
        'Idioma incerto',
        'Sprache unsicher',
        'Dil belirsiz',
        'Bahasa tidak pasti',
        'ভাষা অনিশ্চিত'
      );
  String get langMixed =>
      _get('Mixed languages', 'مخلوط زبانیں', 'لغات مختلطة',
        'मिश्रित भाषाएं',
        'Langues mixtes',
        'Idiomas mixtos',
        'Idiomas mistos',
        'Gemischte Sprachen',
        'Karışık diller',
        'Bahasa campuran',
        'মিশ্র ভাষা'
      );
  String get langTransliterated =>
      _get('Romanized text', 'رومن متن', 'نص مُحوَّل',
        'रोमन लिपि में टेक्स्ट',
        'Texte romanisé',
        'Texto romanizado',
        'Texto romanizado',
        'Romanisierter Text',
        'Latin harfli metin',
        'Teks latin',
        'রোমান হরফে লেখা'
      );
  String get langSuggested => _get(
        'Suggested language audiences',
        'تجویز کردہ زبانیں',
        'جماهير لغات مقترحة',
      
        'सुझाई गई भाषाओं के ऑडियंस',
        'Audiences de langues suggérées',
        'Audiencias de idiomas sugeridos',
        'Públicos de idiomas sugeridos',
        'Vorgeschlagene Sprachen-Zielgruppen',
        'Önerilen dil kitleleri',
        'Audiens bahasa yang disarankan',
        'প্রস্তাবিত ভাষার অডিয়েন্স'
      );
  String get langSuggestedDesc => _get(
        'AI suggests extra language audiences — suggestions only, never guarantees.',
        'AI اضافی زبانوں کے سامعین تجویز کرتا ہے — صرف تجاویز، کبھی ضمانت نہیں۔',
        'يقترح الذكاء الاصطناعي جماهير لغات إضافية — اقتراحات فقط، لا ضمانات أبداً.',
      
        'AI अतिरिक्त भाषाओं के ऑडियंस सुझाता है — सिर्फ़ सुझाव, कभी गारंटी नहीं।',
        'L\'IA suggère des audiences de langues supplémentaires — suggestions uniquement, jamais de garanties.',
        'La IA sugiere audiencias de idiomas adicionales — solo sugerencias, nunca garantías.',
        'A IA sugere públicos de idiomas adicionais — apenas sugestões, nunca garantias.',
        'Die KI schlägt zusätzliche Sprachen-Zielgruppen vor — nur Vorschläge, niemals Garantien.',
        'Yapay zeka ek dil kitleleri önerir — yalnızca öneri, asla garanti değil.',
        'AI menyarankan audiens bahasa tambahan — hanya saran, bukan jaminan.',
        'AI অতিরিক্ত ভাষার অডিয়েন্স প্রস্তাব করে — শুধু প্রস্তাব, কখনো গ্যারান্টি নয়।'
      );
  String get langWhySuggested =>
      _get('Why suggested?', 'تجویز کیوں؟', 'لماذا تُقترَح؟',
        'सुझाव क्यों?',
        'Pourquoi suggéré ?',
        '¿Por qué sugerido?',
        'Por que sugerido?',
        'Warum vorgeschlagen?',
        'Neden önerildi?',
        'Mengapa disarankan?',
        'কেন প্রস্তাবিত?'
      );
  String get langTargetingMode =>
      _get('Language targeting', 'زبان کا ہدف', 'استهداف اللغة',
        'भाषा टारगेटिंग',
        'Ciblage linguistique',
        'Segmentación por idioma',
        'Segmentação por idioma',
        'Sprachen-Targeting',
        'Dil hedefleme',
        'Penargetan bahasa',
        'ভাষা টার্গেটিং'
      );
  String get langModeSingle => _get('Single language', 'ایک زبان', 'لغة واحدة',
        'एक भाषा',
        'Langue unique',
        'Un solo idioma',
        'Idioma único',
        'Einzelne Sprache',
        'Tek dil',
        'Satu bahasa',
        'একটি ভাষা'
      );
  String get langModeMultiple =>
      _get('Multiple languages', 'متعدد زبانیں', 'لغات متعددة',
        'कई भाषाएं',
        'Plusieurs langues',
        'Varios idiomas',
        'Vários idiomas',
        'Mehrere Sprachen',
        'Birden fazla dil',
        'Beberapa bahasa',
        'একাধিক ভাষা'
      );
  String get langModeAllRelevant =>
      _get('All relevant', 'تمام متعلقہ', 'كل ذات الصلة',
        'सभी प्रासंगिक',
        'Toutes pertinentes',
        'Todos relevantes',
        'Todos relevantes',
        'Alle relevanten',
        'Tümü ilgili',
        'Semua yang relevan',
        'সব প্রাসঙ্গিক'
      );
  String get langSelectLanguages =>
      _get('Select languages', 'زبانیں منتخب کریں', 'اختر اللغات',
        'भाषाएं चुनें',
        'Sélectionner les langues',
        'Seleccionar idiomas',
        'Selecionar idiomas',
        'Sprachen auswählen',
        'Dilleri seç',
        'Pilih bahasa',
        'ভাষা নির্বাচন করুন'
      );
  String get langByLanguage =>
      _get('By language', 'زبان کے لحاظ سے', 'حسب اللغة',
        'भाषा के अनुसार',
        'Par langue',
        'Por idioma',
        'Por idioma',
        'Nach Sprache',
        'Dile göre',
        'Berdasarkan bahasa',
        'ভাষা অনুযায়ী'
      );
  String get langUnrecorded =>
      _get('Unrecorded', 'غیر ریکارڈ شدہ', 'غير مسجَّلة',
        'रिकॉर्ड नहीं',
        'Non enregistré',
        'Sin registrar',
        'Não registrado',
        'Nicht erfasst',
        'Kaydedilmemiş',
        'Belum tercatat',
        'রেকর্ড হয়নি'
      );
  String get langFallbackNote => _get(
        'No translation yet — shown in English.',
        'ابھی ترجمہ نہیں — انگریزی میں دکھایا گیا۔',
        'لا توجد ترجمة بعد — يُعرض بالإنجليزية.',
      
        'अभी अनुवाद नहीं है — अंग्रेज़ी में दिखाया गया।',
        'Pas encore de traduction — affiché en anglais.',
        'Aún sin traducción — mostrado en inglés.',
        'Sem tradução ainda — exibido em inglês.',
        'Noch keine Übersetzung — auf Englisch angezeigt.',
        'Henüz çeviri yok — İngilizce gösteriliyor.',
        'Belum ada terjemahan — ditampilkan dalam bahasa Inggris.',
        'এখনো অনুবাদ নেই — ইংরেজিতে দেখানো হয়েছে।'
      );
  String get langSearchLanguages =>
      _get('Search languages…', 'زبانیں تلاش کریں…', 'ابحث عن اللغات…',
        'भाषाएं खोजें…',
        'Rechercher des langues…',
        'Buscar idiomas…',
        'Pesquisar idiomas…',
        'Sprachen suchen…',
        'Dil ara…',
        'Cari bahasa…',
        'ভাষা খুঁজুন…'
      );
  String get notifications => _get('Notifications', 'اطلاعات', 'الإشعارات',
        'नोटिफ़िकेशन',
        'Notifications',
        'Notificaciones',
        'Notificações',
        'Benachrichtigungen',
        'Bildirimler',
        'Notifikasi',
        'নোটিফিকেশন'
      );
  String get noNotifications =>
      _get('No notifications yet.', 'ابھی کوئی اطلاع نہیں۔', 'لا إشعارات بعد.',
        'अभी तक कोई नोटिफ़िकेशन नहीं।',
        'Aucune notification pour l\'instant.',
        'Aún no hay notificaciones.',
        'Nenhuma notificação ainda.',
        'Noch keine Benachrichtigungen.',
        'Henüz bildirim yok.',
        'Belum ada notifikasi.',
        'এখনো কোনো নোটিফিকেশন নেই।'
      );

  // ---- Approved 10-screen board (2026-09-26) ----
  String get splashTagline => _get(
        'Create • Discover • Grow',
        'تخلیق • دریافت • گرو',
        'أنشئ • اكتشف • نمِّ',
      
        'बनाएं • डिस्कवर • ग्रो',
        'Créer • Découvrir • Croissance',
        'Crear • Descubrir • Crecer',
        'Criar • Descobrir • Crescer',
        'Erstellen • Entdecken • Wachstum',
        'Oluştur • Keşfet • Büyüme',
        'Buat • Temukan • Grow',
        'তৈরি করুন • ডিসকভার • গ্রো'
      );
  String get splashHeadline => _get(
        'Turn Your Content Into Real Growth',
        'اپنے مواد کو حقیقی گروتھ میں بدلیں',
        'حوِّل محتواك إلى نموٍّ حقيقي',
      
        'अपने कंटेंट को असली ग्रोथ में बदलें',
        'Transformez votre contenu en croissance réelle',
        'Convierte tu contenido en crecimiento real',
        'Transforme seu conteúdo em crescimento real',
        'Verwandle deine Inhalte in echtes Wachstum',
        'İçeriğini gerçek büyümeye dönüştür',
        'Ubah kontenmu menjadi pertumbuhan nyata',
        'আপনার কনটেন্টকে আসল গ্রোথে বদলান'
      );
  String get splashSub => _get(
        'AI-powered discovery & advertising platform for creators, businesses and brands.',
        'تخلیق کاروں، کاروباروں اور برانڈز کے لیے AI سے چلنے والا ڈسکوری اور اشتہاری پلیٹ فارم۔',
        'منصة اكتشاف وإعلان بالذكاء الاصطناعي للمبدعين والشركات والعلامات التجارية.',
      
        'क्रिएटर्स, व्यवसायों और ब्रांड्स के लिए AI-संचालित डिस्कवरी और विज्ञापन प्लेटफ़ॉर्म।',
        'Plateforme de découverte et de publicité alimentée par l\'IA pour les créateurs, les entreprises et les marques.',
        'Plataforma de descubrimiento y publicidad impulsada por IA para creadores, negocios y marcas.',
        'Plataforma de descoberta e publicidade com IA para criadores, empresas e marcas.',
        'KI-gestützte Discovery- und Werbeplattform für Creator, Unternehmen und Marken.',
        'İçerik üreticiler, işletmeler ve markalar için yapay zeka destekli keşif ve reklam platformu.',
        'Platform penemuan & periklanan bertenaga AI untuk kreator, bisnis, dan merek.',
        'ক্রিয়েটর, ব্যবসা ও ব্র্যান্ডের জন্য AI-চালিত ডিসকভারি ও বিজ্ঞাপন প্ল্যাটফর্ম।'
      );
  String get getStarted => _get('Get Started', 'شروع کریں', 'ابدأ',
        'शुरू करें',
        'Commencer',
        'Comenzar',
        'Começar',
        'Los geht\'s',
        'Başla',
        'Mulai',
        'শুরু করুন'
      );
  String get alreadyHaveAccount => _get(
        'I already have an account',
        'میرا اکاؤنٹ پہلے سے موجود ہے',
        'لديّ حساب بالفعل',
      
        'मेरा पहले से अकाउंट है',
        'J\'ai déjà un compte',
        'Ya tengo una cuenta',
        'Já tenho uma conta',
        'Ich habe bereits ein Konto',
        'Zaten bir hesabım var',
        'Saya sudah punya akun',
        'আমার ইতিমধ্যে একটি অ্যাকাউন্ট আছে'
      );
  String get forYou => _get('For You', 'آپ کے لیے', 'لك',
        'आपके लिए',
        'Pour vous',
        'Para ti',
        'Para você',
        'Für dich',
        'Senin için',
        'Untukmu',
        'আপনার জন্য'
      );
  String get trending => _get('Trending', 'ٹرینڈنگ', 'الرائج',
        'ट्रेंडिंग',
        'Tendances',
        'Tendencias',
        'Em alta',
        'Trends',
        'Trendler',
        'Tren',
        'ট্রেন্ডিং'
      );
  String get following => _get('Following', 'فالونگ', 'المتابَعون',
        'फॉलोइंग',
        'Abonnements',
        'Siguiendo',
        'Seguindo',
        'Folgst du',
        'Takip edilenler',
        'Diikuti',
        'ফলোইং'
      );
  String get aiPicks =>
      _get('AI Picks', 'AI انتخاب', 'اختيارات الذكاء الاصطناعي',
        'AI पिक्स',
        'Choix de l\'IA',
        'Selección de IA',
        'Escolhas da IA',
        'KI-Auswahl',
        'Yapay zeka seçimleri',
        'Pilihan AI',
        'AI পিকস'
      );
  String get searchAnything =>
      _get('Search anything…', 'کچھ بھی تلاش کریں…', 'ابحث عن أي شيء…',
        'कुछ भी खोजें…',
        'Rechercher…',
        'Busca lo que sea…',
        'Pesquise qualquer coisa…',
        'Alles suchen…',
        'Her şeyi ara…',
        'Cari apa saja…',
        'যেকোনো কিছু খুঁজুন…'
      );
  String get exploreTopics =>
      _get('Explore Topics', 'موضوعات دیکھیں', 'استكشف المواضيع',
        'टॉपिक्स देखें',
        'Explorer les sujets',
        'Explorar temas',
        'Explorar tópicos',
        'Themen entdecken',
        'Konuları keşfet',
        'Jelajahi topik',
        'টপিক দেখুন'
      );
  String get trendingNow => _get('Trending Now', 'ابھی ٹرینڈنگ', 'الرائج الآن',
        'अभी ट्रेंडिंग',
        'Tendances actuelles',
        'Tendencias ahora',
        'Em alta agora',
        'Jetzt im Trend',
        'Şu an trendler',
        'Sedang tren',
        'এখন ট্রেন্ডিং'
      );
  String get popularLanguages =>
      _get('Popular Languages', 'مقبول زبانیں', 'لغات شائعة',
        'लोकप्रिय भाषाएं',
        'Langues populaires',
        'Idiomas populares',
        'Idiomas populares',
        'Beliebte Sprachen',
        'Popüler diller',
        'Bahasa populer',
        'জনপ্রিয় ভাষা'
      );
  String get aiRecommendedForYou => _get(
        'AI Recommended For You',
        'AI کی تجویز — آپ کے لیے',
        'موصى به لك بالذكاء الاصطناعي',
      
        'AI की सिफ़ारिश — आपके लिए',
        'Recommandé par l\'IA pour vous',
        'Recomendado por la IA para ti',
        'Recomendado pela IA para você',
        'Von der KI für dich empfohlen',
        'Yapay zekadan senin için öneriler',
        'Direkomendasikan AI untukmu',
        'AI-এর প্রস্তাবনা — আপনার জন্য'
      );
  String get seeAll => _get('See all', 'سب دیکھیں', 'عرض الكل',
        'सभी देखें',
        'Tout voir',
        'Ver todo',
        'Ver tudo',
        'Alle ansehen',
        'Tümünü gör',
        'Lihat semua',
        'সব দেখুন'
      );
  String postsCount(int n) => _get('$n posts', '$n پوسٹس', '$n منشورات',
        '$n पोस्ट',
        '$n publications',
        '$n publicaciones',
        '$n publicações',
        '$n Beiträge',
        '$n gönderi',
        '$n postingan',
        '$n টি পোস্ট'
      );
  String get whatToDoToday => _get(
        'What would you like to do today?',
        'آج آپ کیا کرنا چاہیں گے؟',
        'ماذا تريد أن تفعل اليوم؟',
      
        'आज आप क्या करना चाहेंगे?',
        'Que souhaitez-vous faire aujourd\'hui ?',
        '¿Qué te gustaría hacer hoy?',
        'O que você gostaria de fazer hoje?',
        'Was möchtest du heute tun?',
        'Bugün ne yapmak istersin?',
        'Apa yang ingin kamu lakukan hari ini?',
        'আজ আপনি কী করতে চান?'
      );
  String get analyzePost =>
      _get('Analyze Post', 'پوسٹ کا تجزیہ', 'تحليل المنشور',
        'पोस्ट का विश्लेषण',
        'Analyser la publication',
        'Analizar publicación',
        'Analisar publicação',
        'Beitrag analysieren',
        'Gönderiyi analiz et',
        'Analisis postingan',
        'পোস্ট বিশ্লেষণ'
      );
  String get analyzePostDesc => _get(
        'Paste a link and let AI analyze it',
        'لنک پیسٹ کریں اور AI سے تجزیہ کروائیں',
        'الصق رابطاً ودع الذكاء الاصطناعي يحلِّله',
      
        'लिंक पेस्ट करें और AI से विश्लेषण करवाएं',
        'Collez un lien et laissez l\'IA l\'analyser',
        'Pega un enlace y deja que la IA lo analice',
        'Cole um link e deixe a IA analisá-lo',
        'Füge einen Link ein und lass ihn von der KI analysieren',
        'Bir bağlantı yapıştır ve yapay zekanın analiz etmesine izin ver',
        'Tempel tautan dan biarkan AI menganalisisnya',
        'একটি লিংক পেস্ট করুন এবং AI-কে বিশ্লেষণ করতে দিন'
      );
  String get uploadContent =>
      _get('Upload Content', 'مواد اپ لوڈ کریں', 'رفع المحتوى',
        'कंटेंट अपलोड करें',
        'Téléverser du contenu',
        'Subir contenido',
        'Enviar conteúdo',
        'Inhalte hochladen',
        'İçerik yükle',
        'Unggah konten',
        'কনটেন্ট আপলোড করুন'
      );
  String get uploadContentDesc => _get(
        'Add your photo, video or file',
        'اپنی تصویر، ویڈیو یا فائل شامل کریں',
        'أضف صورتك أو مقطعك أو ملفك',
      
        'अपनी फ़ोटो, वीडियो या फ़ाइल जोड़ें',
        'Ajoutez votre photo, vidéo ou fichier',
        'Agrega tu foto, video o archivo',
        'Adicione sua foto, vídeo ou arquivo',
        'Füge dein Foto, Video oder deine Datei hinzu',
        'Fotoğrafını, videonu veya dosyanı ekle',
        'Tambahkan foto, video, atau file kamu',
        'আপনার ছবি, ভিডিও বা ফাইল যোগ করুন'
      );
  String get findAudience =>
      _get('Find Audience', 'سامعین تلاش کریں', 'اعثر على الجمهور',
        'ऑडियंस खोजें',
        'Trouver une audience',
        'Encontrar audiencia',
        'Encontrar público',
        'Zielgruppe finden',
        'Kitle bul',
        'Temukan audiens',
        'অডিয়েন্স খুঁজুন'
      );
  String get findAudienceDesc => _get(
        'Discover the right audience',
        'صحیح سامعین دریافت کریں',
        'اكتشف الجمهور المناسب',
      
        'सही ऑडियंस खोजें',
        'Découvrez la bonne audience',
        'Descubre la audiencia adecuada',
        'Descubra o público certo',
        'Entdecke die richtige Zielgruppe',
        'Doğru kitleyi keşfet',
        'Temukan audiens yang tepat',
        'সঠিক অডিয়েন্স খুঁজুন'
      );
  String get promoteWithAI =>
      _get('Promote with AI', 'AI سے پروموٹ کریں', 'روِّج بالذكاء الاصطناعي',
        'AI से प्रमोट करें',
        'Promouvoir avec l\'IA',
        'Promocionar con IA',
        'Promover com IA',
        'Mit KI bewerben',
        'Yapay zeka ile tanıt',
        'Promosikan dengan AI',
        'AI দিয়ে প্রমোট করুন'
      );
  String get promoteWithAIDesc => _get(
        'Create a campaign in seconds',
        'سیکنڈوں میں مہم بنائیں',
        'أنشئ حملة في ثوانٍ',
      
        'सेकंडों में अभियान बनाएं',
        'Créez une campagne en quelques secondes',
        'Crea una campaña en segundos',
        'Crie uma campanha em segundos',
        'Erstelle eine Kampagne in Sekunden',
        'Saniyeler içinde kampanya oluştur',
        'Buat kampanye dalam hitungan detik',
        'সেকেন্ডে ক্যাম্পেইন তৈরি করুন'
      );
  String get letAiGrowContent => _get(
        'Let AI Grow Your Content',
        'AI سے اپنا مواد بڑھوائیں',
        'دع الذكاء الاصطناعي ينمِّي محتواك',
      
        'AI से अपना कंटेंट बढ़वाएं',
        'Laissez l\'IA développer votre contenu',
        'Deja que la IA haga crecer tu contenido',
        'Deixe a IA fazer seu conteúdo crescer',
        'Lass die KI deine Inhalte wachsen lassen',
        'Yapay zekanın içeriğini büyütmesine izin ver',
        'Biarkan AI mengembangkan kontenmu',
        'AI-কে আপনার কনটেন্ট বাড়াতে দিন'
      );
  String get letAiGrowContentDesc => _get(
        'Smart analysis • Right audience • Better results',
        'ذہین تجزیہ • صحیح سامعین • بہتر نتائج',
        'تحليل ذكي • جمهور مناسب • نتائج أفضل',
      
        'स्मार्ट विश्लेषण • सही ऑडियंस • बेहतर परिणाम',
        'Analyse intelligente • Bonne audience • Meilleurs résultats',
        'Análisis inteligente • Audiencia adecuada • Mejores resultados',
        'Análise inteligente • Público certo • Melhores resultados',
        'Intelligente Analyse • Richtige Zielgruppe • Bessere Ergebnisse',
        'Akıllı analiz • Doğru kitle • Daha iyi sonuçlar',
        'Analisis cerdas • Audiens tepat • Hasil lebih baik',
        'স্মার্ট বিশ্লেষণ • সঠিক অডিয়েন্স • ভালো ফলাফল'
      );
  String get uploadComingSoon => _get(
        'Photo & video upload is coming in the next release — analyze a link for now.',
        'تصویر اور ویڈیو اپ لوڈ اگلی ریلیز میں آ رہا ہے — فی الحال لنک کا تجزیہ کریں۔',
        'رفع الصور والفيديو قادم في الإصدار التالي — حلِّل رابطاً الآن.',
      
        'फ़ोटो और वीडियो अपलोड अगले रिलीज़ में आ रहा है — फ़िलहाल लिंक का विश्लेषण करें।',
        'Le téléversement de photos et vidéos arrive dans la prochaine version — analysez un lien pour l\'instant.',
        'La subida de fotos y videos llegará en la próxima versión — analiza un enlace por ahora.',
        'O envio de fotos e vídeos chega na próxima versão — analise um link por enquanto.',
        'Foto- und Video-Upload kommen mit dem nächsten Release — analysiere vorerst einen Link.',
        'Fotoğraf ve video yükleme bir sonraki sürümde geliyor — şimdilik bir bağlantıyı analiz et.',
        'Unggah foto & video hadir di rilis berikutnya — analisis tautan untuk sementara.',
        'পরের রিলিজে ফটো ও ভিডিও আপলোড আসছে — আপাতত একটি লিংক বিশ্লেষণ করুন।'
      );
  String get analyzeLinkInstead => _get(
        'Analyze a link instead',
        'اس کے بجائے لنک کا تجزیہ کریں',
        'حلِّل رابطاً بدلاً من ذلك',
      
        'इसके बजाय लिंक का विश्लेषण करें',
        'Analyser plutôt un lien',
        'Analizar un enlace en su lugar',
        'Analisar um link em vez disso',
        'Stattdessen einen Link analysieren',
        'Bunun yerine bir bağlantıyı analiz et',
        'Analisis tautan saja',
        'বরং একটি লিংক বিশ্লেষণ করুন'
      );
  // --- Upload Studio ---
  String get uploadStudio =>
      _get('Upload Studio', 'اپ لوڈ اسٹوڈیو', 'استوديو الرفع',
        'अपलोड स्टूडियो',
        'Studio de téléversement',
        'Estudio de subida',
        'Estúdio de envio',
        'Upload-Studio',
        'Yükleme Stüdyosu',
        'Studio Unggah',
        'আপলোড স্টুডিও'
      );
  String get pickFromPhone =>
      _get('Pick from phone', 'فون سے منتخب کریں', 'اختر من الهاتف',
        'फ़ोन से चुनें',
        'Choisir depuis le téléphone',
        'Elegir desde el teléfono',
        'Escolher do telefone',
        'Vom Smartphone wählen',
        'Telefondan seç',
        'Pilih dari ponsel',
        'ফোন থেকে বেছে নিন'
      );
  String get pickFileHint => _get(
        'Photo, video, audio or document — up to 50 MB',
        'تصویر، ویڈیو، آڈیو یا دستاویز — 50 MB تک',
        'صورة أو فيديو أو صوت أو مستند — حتى 50 م.ب',
      
        'फ़ोटो, वीडियो, ऑडियो या दस्तावेज़ — 50 MB तक',
        'Photo, vidéo, audio ou document — jusqu\'à 50 Mo',
        'Foto, video, audio o documento — hasta 50 MB',
        'Foto, vídeo, áudio ou documento — até 50 MB',
        'Foto, Video, Audio oder Dokument — bis zu 50 MB',
        'Fotoğraf, video, ses veya belge — 50 MB\'a kadar',
        'Foto, video, audio, atau dokumen — hingga 50 MB',
        'ছবি, ভিডিও, অডিও বা ডকুমেন্ট — 50 MB পর্যন্ত'
      );
  String get uploading =>
      _get('Uploading…', 'اپ لوڈ ہو رہا ہے…', 'جارٍ الرفع…',
        'अपलोड हो रहा है…',
        'Téléversement…',
        'Subiendo…',
        'Enviando…',
        'Wird hochgeladen…',
        'Yükleniyor…',
        'Mengunggah…',
        'আপলোড হচ্ছে…'
      );
  String get uploadFailed =>
      _get('Upload failed', 'اپ لوڈ ناکام ہوا', 'فشل الرفع',
        'अपलोड विफल',
        'Échec du téléversement',
        'Error al subir',
        'Falha no envio',
        'Upload fehlgeschlagen',
        'Yükleme başarısız',
        'Unggahan gagal',
        'আপলোড ব্যর্থ'
      );
  String get tryAgain => _get('Try again', 'دوبارہ کوشش کریں', 'حاول مجدداً',
        'पुनः प्रयास करें',
        'Réessayer',
        'Reintentar',
        'Tentar novamente',
        'Erneut versuchen',
        'Tekrar dene',
        'Coba lagi',
        'আবার চেষ্টা করুন'
      );
  String get uploadedOk => _get('Uploaded', 'اپ لوڈ ہو گیا', 'تم الرفع',
        'अपलोड हो गया',
        'Téléversé',
        'Subido',
        'Enviado',
        'Hochgeladen',
        'Yüklendi',
        'Terunggah',
        'আপলোড হয়েছে'
      );
  String get addCaption => _get('Add a caption', 'کیپشن لکھیں', 'أضف تعليقاً',
        'कैप्शन लिखें',
        'Ajouter une légende',
        'Agrega un pie de foto',
        'Adicionar uma legenda',
        'Bildunterschrift hinzufügen',
        'Açıklama ekle',
        'Tambahkan keterangan',
        'ক্যাপশন লিখুন'
      );
  String get captionHint => _get(
        'What is this about? Add 2–4 hashtags…',
        'یہ کس بارے میں ہے؟ 2–4 ہیش ٹیگز شامل کریں…',
        'ما موضوع هذا؟ أضف 2–4 وسوم…',
      
        'यह किस बारे में है? 2–4 हैशटैग जोड़ें…',
        'De quoi s\'agit-il ? Ajoutez 2 à 4 hashtags…',
        '¿De qué se trata? Agrega 2–4 hashtags…',
        'Do que se trata? Adicione 2–4 hashtags…',
        'Worum geht es? Füge 2–4 Hashtags hinzu…',
        'Bu ne hakkında? 2–4 hashtag ekle…',
        'Ini tentang apa? Tambahkan 2–4 hashtag…',
        'এটি কী সম্পর্কে? 2–4টি হ্যাশট্যাগ যোগ করুন…'
      );
  String get aiCheck => _get('AI Check', 'AI چیک', 'فحص الذكاء الاصطناعي',
        'AI चेक',
        'Vérification IA',
        'Revisión de IA',
        'Verificação da IA',
        'KI-Check',
        'Yapay zeka kontrolü',
        'Pemeriksaan AI',
        'AI চেক'
      );
  String get checking => _get('Checking…', 'چیک ہو رہا ہے…', 'جارٍ الفحص…',
        'जांच हो रही है…',
        'Vérification…',
        'Revisando…',
        'Verificando…',
        'Wird geprüft…',
        'Kontrol ediliyor…',
        'Memeriksa…',
        'যাচাই হচ্ছে…'
      );
  String get growThisContent =>
      _get('Grow this content', 'اس مواد کو بڑھوائیں', 'نمِّ هذا المحتوى',
        'इस कंटेंट को बढ़ाएं',
        'Développer ce contenu',
        'Haz crecer este contenido',
        'Fazer este conteúdo crescer',
        'Diese Inhalte wachsen lassen',
        'Bu içeriği büyüt',
        'Kembangkan konten ini',
        'এই কনটেন্ট বাড়ান'
      );
  String get recommendations => _get('Recommendations', 'تجاویز', 'توصيات',
        'सिफ़ारिशें',
        'Recommandations',
        'Recomendaciones',
        'Recomendações',
        'Empfehlungen',
        'Öneriler',
        'Rekomendasi',
        'প্রস্তাবনা'
      );
  String get readinessChecklist =>
      _get('Readiness checklist', 'تیاری کی چیک لسٹ', 'قائمة الجاهزية',
        'तैयारी चेकलिस्ट',
        'Liste de préparation',
        'Lista de preparación',
        'Lista de preparação',
        'Bereitschafts-Checkliste',
        'Hazırlık kontrol listesi',
        'Daftar periksa kesiapan',
        'প্রস্তুতি চেকলিস্ট'
      );
  String get heuristicNote => _get(
        'Heuristic estimate — not a guarantee',
        'تخمینی جائزہ — ضمانت نہیں',
        'تقدير تقريبي — ليس ضماناً',
      
        'अनुमानित आंकलन — गारंटी नहीं',
        'Estimation heuristique — sans garantie',
        'Estimación heurística — sin garantía',
        'Estimativa heurística — sem garantia',
        'Heuristische Schätzung — keine Garantie',
        'Sezgisel tahmin — garanti değildir',
        'Estimasi heuristik — bukan jaminan',
        'হিউরিস্টিক অনুমান — গ্যারান্টি নয়'
      );
  String get aiAnalyzePostTitle => _get(
        'AI Analyze Post',
        'AI پوسٹ تجزیہ',
        'تحليل المنشور بالذكاء الاصطناعي',
      
        'AI पोस्ट विश्लेषण',
        'Analyse IA de la publication',
        'Análisis de publicación con IA',
        'Análise de publicação com IA',
        'KI-Beitragsanalyse',
        'Yapay zeka gönderi analizi',
        'Analisis Postingan AI',
        'AI পোস্ট বিশ্লেষণ'
      );
  String get nextAudienceInsights => _get(
        'Next: Audience Insights',
        'اگلا: آڈینس انسائٹس',
        'التالي: رؤى الجمهور',
      
        'अगला: ऑडियंस इनसाइट्स',
        'Suivant : infos sur l\'audience',
        'Siguiente: información de la audiencia',
        'Próximo: insights do público',
        'Weiter: Zielgruppen-Insights',
        'Sıradaki: Kitle içgörüleri',
        'Berikutnya: Wawasan Audiens',
        'পরবর্তী: অডিয়েন্স ইনসাইটস'
      );
  String get nextCampaignSetup =>
      _get('Next: Campaign Setup', 'اگلا: مہم سیٹ اپ', 'التالي: إعداد الحملة',
        'अगला: अभियान सेटअप',
        'Suivant : configuration de la campagne',
        'Siguiente: configuración de la campaña',
        'Próximo: configuração da campanha',
        'Weiter: Kampagnen-Setup',
        'Sıradaki: Kampanya kurulumu',
        'Berikutnya: Penyiapan Kampanye',
        'পরবর্তী: ক্যাম্পেইন সেটআপ'
      );
  String get audienceInsights =>
      _get('Audience Insights', 'آڈینس انسائٹس', 'رؤى الجمهور',
        'ऑडियंस इनसाइट्स',
        'Infos sur l\'audience',
        'Información de la audiencia',
        'Insights do público',
        'Zielgruppen-Insights',
        'Kitle içgörüleri',
        'Wawasan Audiens',
        'অডিয়েন্স ইনসাইটস'
      );
  String get recommendedAudience =>
      _get('Recommended Audience', 'تجویز کردہ سامعین', 'الجمهور الموصى به',
        'सुझाई गई ऑडियंस',
        'Audience recommandée',
        'Audiencia recomendada',
        'Público recomendado',
        'Empfohlene Zielgruppe',
        'Önerilen kitle',
        'Audiens yang direkomendasikan',
        'প্রস্তাবিত অডিয়েন্স'
      );
  String get audienceBreakdown =>
      _get('Audience Breakdown', 'سامعین کی تفصیل', 'تفصيل الجمهور',
        'ऑडियंस विवरण',
        'Répartition de l\'audience',
        'Desglose de la audiencia',
        'Detalhamento do público',
        'Zielgruppen-Aufschlüsselung',
        'Kitle dağılımı',
        'Rincian audiens',
        'অডিয়েন্স বিবরণ'
      );
  String get whyThisAudience =>
      _get('Why this audience?', 'یہ سامعین کیوں؟', 'لماذا هذا الجمهور؟',
        'यह ऑडियंस क्यों?',
        'Pourquoi cette audience ?',
        '¿Por qué esta audiencia?',
        'Por que este público?',
        'Warum diese Zielgruppe?',
        'Neden bu kitle?',
        'Mengapa audiens ini?',
        'এই অডিয়েন্স কেন?'
      );
  String get whyThisAudienceBody => _get(
        'Based on trending interest, search patterns and similar audience behavior.',
        'ٹرینڈنگ دلچسپی، تلاش کے رجحانات اور ملتے جلتے سامعین کے رویے کی بنیاد پر۔',
        'بناءً على الاهتمامات الرائجة وأنماط البحث وسلوك الجماهير المشابهة.',
      
        'ट्रेंडिंग रुचि, खोज पैटर्न और समान ऑडियंस व्यवहार के आधार पर।',
        'Basé sur les intérêts tendance, les habitudes de recherche et le comportement d\'audiences similaires.',
        'Basado en intereses en tendencia, patrones de búsqueda y comportamiento de audiencias similares.',
        'Com base em interesses em alta, padrões de pesquisa e comportamento de públicos semelhantes.',
        'Basierend auf Trend-Interessen, Suchmustern und dem Verhalten ähnlicher Zielgruppen.',
        'Trend olan ilgi alanları, arama kalıpları ve benzer kitle davranışlarına dayanır.',
        'Berdasarkan minat yang sedang tren, pola pencarian, dan perilaku audiens serupa.',
        'ট্রেন্ডিং আগ্রহ, সার্চ প্যাটার্ন এবং অনুরূপ অডিয়েন্স আচরণের ভিত্তিতে।'
      );
  String get aiMatched =>
      _get('AI Matched', 'AI میچڈ', 'مطابق بالذكاء الاصطناعي',
        'AI मैच्ड',
        'Associé par l\'IA',
        'Coincidencia de IA',
        'Correspondência da IA',
        'Von der KI zugeordnet',
        'Yapay zeka eşleşti',
        'Dicocokkan AI',
        'AI মিলিয়েছে'
      );
  String get virelloAudience =>
      _get('Virello Audience', 'وائرلو آڈینس', 'جمهور Virello',
        'Virello ऑडियंस',
        'Audience Virello',
        'Audiencia de Virello',
        'Público Virello',
        'Virello-Zielgruppe',
        'Virello kitlesi',
        'Audiens Virello',
        'Virello অডিয়েন্স'
      );
  String get noAudienceMatches => _get(
        'No strong audience matches yet — try a different post or link.',
        'ابھی کوئی مضبوط سامعین کی مطابقت نہیں — کوئی اور پوسٹ یا لنک آزمائیں۔',
        'لا مطابقات قوية للجمهور بعد — جرِّب منشوراً أو رابطاً آخر.',
      
        'अभी तक कोई मज़बूत ऑडियंस मैच नहीं — कोई दूसरी पोस्ट या लिंक आज़माएं।',
        'Aucune correspondance d\'audience forte pour l\'instant — essayez une autre publication ou un autre lien.',
        'Aún no hay coincidencias fuertes de audiencia — prueba con otra publicación o enlace.',
        'Nenhuma correspondência forte de público ainda — tente outra publicação ou link.',
        'Noch keine starken Zielgruppen-Übereinstimmungen — versuch es mit einem anderen Beitrag oder Link.',
        'Henüz güçlü kitle eşleşmesi yok — farklı bir gönderi veya bağlantı dene.',
        'Belum ada kecocokan audiens yang kuat — coba postingan atau tautan lain.',
        'এখনো কোনো শক্তিশালী অডিয়েন্স মিল নেই — অন্য পোস্ট বা লিংক চেষ্টা করুন।'
      );
  String get objective => _get('Objective', 'مقصد', 'الهدف',
        'उद्देश्य',
        'Objectif',
        'Objetivo',
        'Objetivo',
        'Ziel',
        'Hedef',
        'Tujuan',
        'উদ্দেশ্য'
      );
  String get salesObj => _get('Sales', 'فروخت', 'المبيعات',
        'बिक्री',
        'Ventes',
        'Ventas',
        'Vendas',
        'Verkäufe',
        'Satış',
        'Penjualan',
        'বিক্রি'
      );
  String get salesObjDesc =>
      _get('Drive purchases', 'خریداری بڑھائیں', 'زيادة المشتريات',
        'खरीदारी बढ़ाएं',
        'Stimuler les achats',
        'Impulsar compras',
        'Impulsionar compras',
        'Käufe ankurbeln',
        'Satın alımları artır',
        'Dorong pembelian',
        'কেনাকাটা বাড়ান'
      );
  String get leadsObj => _get('Leads', 'لیڈز', 'العملاء المحتملون',
        'लीड्स',
        'Prospects',
        'Clientes potenciales',
        'Leads',
        'Leads',
        'Potansiyel müşteri',
        'Prospek',
        'লিড'
      );
  String get leadsObjDesc => _get(
        'Get customer details',
        'گاہک کی تفصیلات حاصل کریں',
        'احصل على بيانات العملاء',
      
        'ग्राहक विवरण प्राप्त करें',
        'Obtenir les coordonnées des clients',
        'Obtener datos de clientes',
        'Obter dados de clientes',
        'Kundendaten erhalten',
        'Müşteri bilgilerini al',
        'Dapatkan detail pelanggan',
        'গ্রাহকের তথ্য পান'
      );
  String get engagementObj => _get('Engagement', 'مشغولیت', 'التفاعل',
        'एंगेजमेंट',
        'Engagement',
        'Interacción',
        'Engajamento',
        'Interaktion',
        'Etkileşim',
        'Interaksi',
        'এনগেজমেন্ট'
      );
  String get engagementObjDesc => _get(
        'More likes & comments',
        'زیادہ لائکس اور کمنٹس',
        'مزيد من الإعجابات والتعليقات',
      
        'ज़्यादा लाइक्स और कमेंट्स',
        'Plus de mentions J\'aime et de commentaires',
        'Más me gusta y comentarios',
        'Mais curtidas e comentários',
        'Mehr Likes & Kommentare',
        'Daha fazla beğeni ve yorum',
        'Lebih banyak suka & komentar',
        'বেশি লাইক ও কমেন্ট'
      );
  String get followersObj => _get('Followers', 'فالوورز', 'المتابعون',
        'फॉलोअर्स',
        'Abonnés',
        'Seguidores',
        'Seguidores',
        'Follower',
        'Takipçi',
        'Pengikut',
        'ফলোয়ার'
      );
  String get followersObjDesc =>
      _get('Grow your audience', 'اپنے سامعین بڑھائیں', 'نمِّ جمهورك',
        'अपनी ऑडियंस बढ़ाएं',
        'Développez votre audience',
        'Haz crecer tu audiencia',
        'Faça seu público crescer',
        'Lass deine Zielgruppe wachsen',
        'Kitleni büyüt',
        'Kembangkan audiensmu',
        'আপনার অডিয়েন্স বাড়ান'
      );
  String get targetAudience =>
      _get('Target Audience', 'ہدف سامعین', 'الجمهور المستهدف',
        'टारगेट ऑडियंस',
        'Audience cible',
        'Audiencia objetivo',
        'Público-alvo',
        'Zielgruppe',
        'Hedef kitle',
        'Audiens target',
        'টার্গেট অডিয়েন্স'
      );
  String get aiRecommended =>
      _get('AI Recommended', 'AI تجویز کردہ', 'موصى به بالذكاء الاصطناعي',
        'AI सुझाई गई',
        'Recommandé par l\'IA',
        'Recomendado por la IA',
        'Recomendado pela IA',
        'Von der KI empfohlen',
        'Yapay zeka önerisi',
        'Direkomendasikan AI',
        'AI প্রস্তাবিত'
      );
  String get duration => _get('Duration', 'مدت', 'المدة',
        'अवधि',
        'Durée',
        'Duración',
        'Duração',
        'Dauer',
        'Süre',
        'Durasi',
        'মেয়াদ'
      );
  String get day1 => _get('1 Day', '1 دن', 'يوم واحد',
        '1 दिन',
        '1 jour',
        '1 día',
        '1 dia',
        '1 Tag',
        '1 gün',
        '1 hari',
        '1 দিন'
      );
  String get day3 => _get('3 Days', '3 دن', '3 أيام',
        '3 दिन',
        '3 jours',
        '3 días',
        '3 dias',
        '3 Tage',
        '3 gün',
        '3 hari',
        '3 দিন'
      );
  String get day7 => _get('7 Days', '7 دن', '7 أيام',
        '7 दिन',
        '7 jours',
        '7 días',
        '7 dias',
        '7 Tage',
        '7 gün',
        '7 hari',
        '7 দিন'
      );
  String get day14 => _get('14 Days', '14 دن', '14 يوماً',
        '14 दिन',
        '14 jours',
        '14 días',
        '14 dias',
        '14 Tage',
        '14 gün',
        '14 hari',
        '14 দিন'
      );
  String get dailyBudget =>
      _get('Daily Budget', 'روزانہ بجٹ', 'الميزانية اليومية',
        'दैनिक बजट',
        'Budget quotidien',
        'Presupuesto diario',
        'Orçamento diário',
        'Tagesbudget',
        'Günlük bütçe',
        'Anggaran harian',
        'দৈনিক বাজেট'
      );
  String get reviewAndLaunch =>
      _get('Review & Launch', 'جائزہ اور لانچ', 'مراجعة وإطلاق',
        'समीक्षा और लॉन्च',
        'Vérifier et lancer',
        'Revisar y lanzar',
        'Revisar e lançar',
        'Prüfen & starten',
        'İncele ve başlat',
        'Tinjau & luncurkan',
        'পর্যালোচনা ও লঞ্চ'
      );
  String get budgetNeverExceeded => _get(
        'AI will never exceed your approved budget.',
        'AI آپ کے منظور شدہ بجٹ سے کبھی تجاوز نہیں کرے گا۔',
        'لن يتجاوز الذكاء الاصطناعي ميزانيتك المعتمدة أبداً.',
      
        'AI आपके स्वीकृत बजट से कभी आगे नहीं बढ़ेगा।',
        'L\'IA ne dépassera jamais votre budget approuvé.',
        'La IA nunca superará tu presupuesto aprobado.',
        'A IA nunca excederá seu orçamento aprovado.',
        'Die KI wird dein genehmigtes Budget niemals überschreiten.',
        'Yapay zeka onayladığın bütçeyi asla aşmayacak.',
        'AI tidak akan pernah melebihi anggaran yang kamu setujui.',
        'AI কখনো আপনার অনুমোদিত বাজেট অতিক্রম করবে না।'
      );
  String get aiGrowthAgent =>
      _get('AI Growth Agent', 'AI گروتھ ایجنٹ', 'وكيل النمو بالذكاء الاصطناعي',
        'AI ग्रोथ एजेंट',
        'Agent de croissance IA',
        'Agente de crecimiento con IA',
        'Agente de crescimento com IA',
        'KI-Wachstumsagent',
        'Yapay zeka büyüme ajanı',
        'Agen Pertumbuhan AI',
        'AI গ্রোথ এজেন্ট'
      );
  String get working => _get('Working…', 'کام جاری…', 'جارٍ العمل…',
        'काम चल रहा है…',
        'En cours…',
        'Trabajando…',
        'Trabalhando…',
        'Arbeite…',
        'Çalışıyor…',
        'Bekerja…',
        'কাজ চলছে…'
      );
  String get estimatedReach =>
      _get('Estimated Reach', 'متوقع رسائی', 'الوصول المقدَّر',
        'अनुमानित रीच',
        'Portée estimée',
        'Alcance estimado',
        'Alcance estimado',
        'Geschätzte Reichweite',
        'Tahmini erişim',
        'Estimasi jangkauan',
        'আনুমানিক রিচ'
      );
  String get estimatedEngagement =>
      _get('Estimated Engagement', 'متوقع مشغولیت', 'التفاعل المقدَّر',
        'अनुमानित एंगेजमेंट',
        'Engagement estimé',
        'Interacción estimada',
        'Engajamento estimado',
        'Geschätzte Interaktion',
        'Tahmini etkileşim',
        'Estimasi interaksi',
        'আনুমানিক এনগেজমেন্ট'
      );
  String get usuallyTakes => _get(
        'This usually takes 2–5 minutes',
        'اس میں عام طور پر 2–5 منٹ لگتے ہیں',
        'يستغرق هذا عادة 2–5 دقائق',
      
        'इसमें आमतौर पर 2–5 मिनट लगते हैं',
        'Cela prend généralement 2 à 5 minutes',
        'Esto suele tardar de 2 a 5 minutos',
        'Isso geralmente leva de 2 a 5 minutos',
        'Das dauert normalerweise 2–5 Minuten',
        'Bu genellikle 2–5 dakika sürer',
        'Ini biasanya memakan waktu 2–5 menit',
        'এতে সাধারণত 2–5 মিনিট লাগে'
      );
  String get totalReach => _get('Total Reach', 'کل رسائی', 'إجمالي الوصول',
        'कुल रीच',
        'Portée totale',
        'Alcance total',
        'Alcance total',
        'Gesamtreichweite',
        'Toplam erişim',
        'Total jangkauan',
        'মোট রিচ'
      );
  String get totalViews => _get('Total Views', 'کل ویوز', 'إجمالي المشاهدات',
        'कुल व्यूज़',
        'Vues totales',
        'Vistas totales',
        'Visualizações totais',
        'Aufrufe gesamt',
        'Toplam görüntülenme',
        'Total tayangan',
        'মোট ভিউ'
      );
  String get totalSales => _get('Total Sales', 'کل فروخت', 'إجمالي المبيعات',
        'कुल बिक्री',
        'Ventes totales',
        'Ventas totales',
        'Vendas totais',
        'Verkäufe gesamt',
        'Toplam satış',
        'Total penjualan',
        'মোট বিক্রি'
      );
  String get activeT => _get('Active', 'فعال', 'نشطة',
        'सक्रिय',
        'Actif',
        'Activo',
        'Ativo',
        'Aktiv',
        'Aktif',
        'Aktif',
        'সক্রিয়'
      );
  String get completedT => _get('Completed', 'مکمل', 'مكتملة',
        'पूर्ण',
        'Terminé',
        'Completado',
        'Concluído',
        'Abgeschlossen',
        'Tamamlandı',
        'Selesai',
        'সম্পূর্ণ'
      );
  String get draftsT => _get('Drafts', 'مسودے', 'مسودات',
        'ड्राफ्ट्स',
        'Brouillons',
        'Borradores',
        'Rascunhos',
        'Entwürfe',
        'Taslaklar',
        'Draf',
        'ড্রাফট'
      );
  String daysLeft(int n) => _get('$n days left', '$n دن باقی', 'متبقٍ $n أيام',
        '$n दिन बाकी',
        '$n jours restants',
        'Quedan $n días',
        'Faltam $n dias',
        'Noch $n Tage',
        '$n gün kaldı',
        '$n hari tersisa',
        '$n দিন বাকি'
      );
  String get myInterests => _get('My Interests', 'میری دلچسپیاں', 'اهتماماتي',
        'मेरी रुचियां',
        'Mes centres d\'intérêt',
        'Mis intereses',
        'Meus interesses',
        'Meine Interessen',
        'İlgi alanlarım',
        'Minat saya',
        'আমার আগ্রহ'
      );
  String get savedCollections =>
      _get('Saved Collections', 'محفوظ مجموعے', 'مجموعات محفوظة',
        'सहेजे गए संग्रह',
        'Collections enregistrées',
        'Colecciones guardadas',
        'Coleções salvas',
        'Gespeicherte Sammlungen',
        'Kaydedilen koleksiyonlar',
        'Koleksi tersimpan',
        'সংরক্ষিত সংগ্রহ'
      );
  String get editProfile =>
      _get('Edit Profile', 'پروفائل ایڈٹ کریں', 'تعديل الملف',
        'प्रोफ़ाइल एडिट करें',
        'Modifier le profil',
        'Editar perfil',
        'Editar perfil',
        'Profil bearbeiten',
        'Profili düzenle',
        'Edit profil',
        'প্রোফাইল এডিট করুন'
      );
  String get postsStat => _get('Posts', 'پوسٹس', 'المنشورات',
        'पोस्ट्स',
        'Publications',
        'Publicaciones',
        'Publicações',
        'Beiträge',
        'Gönderiler',
        'Postingan',
        'পোস্ট'
      );
  String get followersStat => _get('Followers', 'فالوورز', 'المتابعون',
        'फॉलोअर्स',
        'Abonnés',
        'Seguidores',
        'Seguidores',
        'Follower',
        'Takipçiler',
        'Pengikut',
        'ফলোয়ার'
      );
  String get followingStat => _get('Following', 'فالونگ', 'يتابع',
        'फॉलोइंग',
        'Abonnements',
        'Siguiendo',
        'Seguindo',
        'Gefolgt',
        'Takip edilenler',
        'Diikuti',
        'ফলোইং'
      );
  String itemsCount(int n) => _get('$n items', '$n آئٹمز', '$n عناصر',
        '$n आइटम',
        '$n éléments',
        '$n elementos',
        '$n itens',
        '$n Einträge',
        '$n öğe',
        '$n item',
        '$n টি আইটেম'
      );
  String get smartContent => _get('Smart Content', 'ذہین مواد', 'محتوى ذكي',
        'स्मार्ट कंटेंट',
        'Contenu intelligent',
        'Contenido inteligente',
        'Conteúdo inteligente',
        'Smarte Inhalte',
        'Akıllı içerik',
        'Konten cerdas',
        'স্মার্ট কনটেন্ট'
      );
  String get rightAudience =>
      _get('Right Audience', 'صحیح سامعین', 'الجمهور المناسب',
        'सही ऑडियंस',
        'Bonne audience',
        'Audiencia adecuada',
        'Público certo',
        'Richtige Zielgruppe',
        'Doğru kitle',
        'Audiens yang tepat',
        'সঠিক অডিয়েন্স'
      );
  String get realGrowth => _get('Real Growth', 'حقیقی گروتھ', 'نمو حقيقي',
        'असली ग्रोथ',
        'Croissance réelle',
        'Crecimiento real',
        'Crescimento real',
        'Echtes Wachstum',
        'Gerçek büyüme',
        'Pertumbuhan nyata',
        'আসল গ্রোথ'
      );
  String get aiPoweredIntelligence => _get(
        'AI Powered Intelligence',
        'AI سے چلنے والی ذہانت',
        'ذكاء مدعوم بالذكاء الاصطناعي',
      
        'AI संचालित इंटेलिजेंस',
        'Intelligence alimentée par l\'IA',
        'Inteligencia impulsada por IA',
        'Inteligência com IA',
        'KI-gestützte Intelligenz',
        'Yapay zeka destekli zeka',
        'Kecerdasan bertenaga AI',
        'AI-চালিত ইন্টেলিজেন্স'
      );
  String get globalAudience =>
      _get('Global Audience', 'عالمی سامعین', 'جمهور عالمي',
        'ग्लोबल ऑडियंस',
        'Audience mondiale',
        'Audiencia global',
        'Público global',
        'Globale Zielgruppe',
        'Küresel kitle',
        'Audiens global',
        'গ্লোবাল অডিয়েন্স'
      );
  String get multiLanguageSupport =>
      _get('Multi-Language Support', 'کثیر لسانی معاونت', 'دعم متعدد اللغات',
        'मल्टी-लैंग्वेज सपोर्ट',
        'Prise en charge multilingue',
        'Soporte multilingüe',
        'Suporte multilíngue',
        'Mehrsprachige Unterstützung',
        'Çok dilli destek',
        'Dukungan multi-bahasa',
        'মাল্টি-ল্যাঙ্গুয়েজ সাপোর্ট'
      );
  String get secureTransparent =>
      _get('Secure & Transparent', 'محفوظ اور شفاف', 'آمن وشفاف',
        'सुरक्षित और पारदर्शी',
        'Sécurisé et transparent',
        'Seguro y transparente',
        'Seguro e transparente',
        'Sicher & transparent',
        'Güvenli ve şeffaf',
        'Aman & transparan',
        'নিরাপদ ও স্বচ্ছ'
      );
  String get stepAnalyzing =>
      _get('Analyzing content', 'مواد کا تجزیہ', 'تحليل المحتوى',
        'कंटेंट का विश्लेषण',
        'Analyse du contenu',
        'Analizando contenido',
        'Analisando conteúdo',
        'Inhalte analysieren',
        'İçerik analiz ediliyor',
        'Menganalisis konten',
        'কনটেন্ট বিশ্লেষণ'
      );
  String get stepUnderstanding => _get(
        'Understanding product & intent',
        'پروڈکٹ اور مقصد کو سمجھنا',
        'فهم المنتج والنية',
      
        'प्रोडक्ट और उद्देश्य समझना',
        'Compréhension du produit et de l\'intention',
        'Comprendiendo el producto y la intención',
        'Entendendo o produto e a intenção',
        'Produkt & Absicht verstehen',
        'Ürün ve amaç anlaşılıyor',
        'Memahami produk & maksud',
        'প্রোডাক্ট ও উদ্দেশ্য বোঝা'
      );
  String get stepFinding => _get(
        'Finding audience segments',
        'سامعین کے حصے تلاش کرنا',
        'إيجاد شرائح الجمهور',
      
        'ऑडियंस सेगमेंट खोजना',
        'Recherche de segments d\'audience',
        'Buscando segmentos de audiencia',
        'Buscando segmentos de público',
        'Zielgruppensegmente finden',
        'Kitle segmentleri bulunuyor',
        'Mencari segmen audiens',
        'অডিয়েন্স সেগমেন্ট খোঁজা'
      );
  String get stepMatching => _get(
        'Matching languages & interests',
        'زبانیں اور دلچسپیاں ملانا',
        'مطابقة اللغات والاهتمامات',
      
        'भाषाएं और रुचियां मिलाना',
        'Correspondance des langues et des intérêts',
        'Combinando idiomas e intereses',
        'Combinando idiomas e interesses',
        'Sprachen & Interessen zuordnen',
        'Diller ve ilgi alanları eşleştiriliyor',
        'Mencocokkan bahasa & minat',
        'ভাষা ও আগ্রহ মেলানো'
      );
  String get stepPlacing => _get(
        'Choosing best placements',
        'بہترین جگہوں کا انتخاب',
        'اختيار أفضل المواضع',
      
        'सर्वोत्तम प्लेसमेंट चुनना',
        'Choix des meilleurs emplacements',
        'Eligiendo las mejores ubicaciones',
        'Escolhendo os melhores posicionamentos',
        'Beste Platzierungen wählen',
        'En iyi yerleşimler seçiliyor',
        'Memilih penempatan terbaik',
        'সেরা প্লেসমেন্ট বাছাই'
      );
  String get stepLaunching =>
      _get('Launching campaign', 'مہم لانچ کرنا', 'إطلاق الحملة',
        'अभियान लॉन्च करना',
        'Lancement de la campagne',
        'Lanzando campaña',
        'Lançando campanha',
        'Kampagne starten',
        'Kampanya başlatılıyor',
        'Meluncurkan kampanye',
        'ক্যাম্পেইন লঞ্চ'
      );
  String get stepMonitoring =>
      _get('Monitoring & optimizing', 'نگرانی اور بہتری', 'المراقبة والتحسين',
        'निगरानी और ऑप्टिमाइज़ेशन',
        'Suivi et optimisation',
        'Monitoreando y optimizando',
        'Monitorando e otimizando',
        'Überwachen & optimieren',
        'İzleniyor ve optimize ediliyor',
        'Memantau & mengoptimalkan',
        'পর্যবেক্ষণ ও অপ্টিমাইজেশন'
      );
  String get pendingLabel =>
      _get('(pending)', '(زیر التواء)', '(قيد الانتظار)',
        '(लंबित)',
        '(en attente)',
        '(pendiente)',
        '(pendente)',
        '(ausstehend)',
        '(beklemede)',
        '(tertunda)',
        '(মুলতবি)'
      );
  String get createTitle => _get('Create', 'تخلیق', 'أنشئ',
        'बनाएं',
        'Créer',
        'Crear',
        'Criar',
        'Erstellen',
        'Oluştur',
        'Buat',
        'তৈরি করুন'
      );
  String get viewCampaign => _get('View Campaign', 'مہم دیکھیں', 'عرض الحملة',
        'अभियान देखें',
        'Voir la campagne',
        'Ver campaña',
        'Ver campanha',
        'Kampagne ansehen',
        'Kampanyayı görüntüle',
        'Lihat kampanye',
        'ক্যাম্পেইন দেখুন'
      );
  String get topMatches => _get('Top matches', 'بہترین میچز', 'أفضل المطابقات',
        'शीर्ष मैच',
        'Meilleures correspondances',
        'Mejores coincidencias',
        'Melhores correspondências',
        'Top-Treffer',
        'En iyi eşleşmeler',
        'Kecocokan teratas',
        'সেরা মিল'
      );
  String get rankedByScore => _get(
        'Ranked by match score',
        'میچ اسکور کے لحاظ سے ترتیب',
        'مرتَّبة حسب درجة المطابقة',
      
        'मैच स्कोर के अनुसार क्रमबद्ध',
        'Classé par score de correspondance',
        'Ordenado por puntuación de coincidencia',
        'Classificado por pontuação de correspondência',
        'Nach Match-Score sortiert',
        'Eşleşme skoruna göre sıralandı',
        'Diurutkan berdasarkan skor kecocokan',
        'মিল স্কোর অনুযায়ী সাজানো'
      );
  String get followingSoon => _get(
        'Creator follows are coming soon — save items to build your list.',
        'تخلیق کار فالو جلد آ رہا ہے — اپنی فہرست کے لیے آئٹمز محفوظ کریں۔',
        'متابعة المبدعين قادمة قريباً — احفظ العناصر لبناء قائمتك.',
      
        'क्रिएटर फ़ॉलो जल्द आ रहा है — अपनी सूची बनाने के लिए आइटम सेव करें।',
        'Les abonnements aux créateurs arrivent bientôt — enregistrez des éléments pour constituer votre liste.',
        'Los seguimientos de creadores llegarán pronto — guarda elementos para crear tu lista.',
        'Seguir criadores chega em breve — salve itens para montar sua lista.',
        'Creator-Follows kommen bald — speichere Einträge, um deine Liste aufzubauen.',
        'İçerik üretici takipleri yakında geliyor — listeni oluşturmak için öğeleri kaydet.',
        'Ikuti kreator segera hadir — simpan item untuk membangun daftarmu.',
        'ক্রিয়েটর ফলো শীঘ্রই আসছে — আপনার তালিকা তৈরি করতে আইটেম সেভ করুন।'
      );
  String get analyticsMenu => _get('Analytics', 'تجزیات', 'التحليلات',
        'एनालिटिक्स',
        'Statistiques',
        'Analíticas',
        'Análises',
        'Analytics',
        'Analitik',
        'Analitik',
        'অ্যানালিটিক্স'
      );
  String get settingsMenu => _get('Settings', 'ترتیبات', 'الإعدادات',
        'सेटिंग्स',
        'Paramètres',
        'Ajustes',
        'Configurações',
        'Einstellungen',
        'Ayarlar',
        'Pengaturan',
        'সেটিংস'
      );
  String get billingTitle => _get(
        'Billing & subscriptions',
        'بلنگ اور سبسکرپشنز',
        'الفوترة والاشتراكات',
      
        'बिलिंग और सब्सक्रिप्शन',
        'Facturation et abonnements',
        'Facturación y suscripciones',
        'Cobrança e assinaturas',
        'Abrechnung & Abos',
        'Faturalandırma ve abonelikler',
        'Penagihan & langganan',
        'বিলিং ও সাবস্ক্রিপশন'
      );
  String get playBillingTitle => _get(
        'Buy with Google Play',
        'گوگل پلے سے خریدیں',
        'اشترِ عبر Google Play',
        'Google Play से खरीदें',
        'Acheter avec Google Play',
        'Comprar con Google Play',
        'Comprar com o Google Play',
        'Mit Google Play kaufen',
        'Google Play ile satın al',
        'Beli dengan Google Play',
        'Google Play দিয়ে কিনুন',
      );
  String get playBillingSecureNote => _get(
        'Secure payment via Google Play',
        'گوگل پلے کے ذریعے محفوظ ادائیگی',
        'دفع آمن عبر Google Play',
        'Google Play के माध्यम से सुरक्षित भुगतान',
        'Paiement sécurisé via Google Play',
        'Pago seguro a través de Google Play',
        'Pagamento seguro via Google Play',
        'Sichere Zahlung über Google Play',
        'Google Play ile güvenli ödeme',
        'Pembayaran aman melalui Google Play',
        'Google Play এর মাধ্যমে নিরাপদ পেমেন্ট',
      );
  String get playBillingNotAvailable => _get(
        'Google Play billing is not available on this device.',
        'اس ڈیوائس پر گوگل پلے بلنگ دستیاب نہیں ہے۔',
        'فوترة Google Play غير متاحة على هذا الجهاز.',
        'इस डिवाइस पर Google Play बिलिंग उपलब्ध नहीं है।',
        "La facturation Google Play n'est pas disponible sur cet appareil.",
        'La facturación de Google Play no está disponible en este dispositivo.',
        'O faturamento do Google Play não está disponível neste dispositivo.',
        'Die Google Play-Abrechnung ist auf diesem Gerät nicht verfügbar.',
        'Bu cihazda Google Play faturalandırma kullanılamıyor.',
        'Penagihan Google Play tidak tersedia di perangkat ini.',
        'এই ডিভাইসে Google Play বিলিং উপলব্ধ নয়।',
      );
  String get playBillingPending => _get(
        'Payment pending — complete it in the Play Store.',
        'ادائیگی زیرِ التواء ہے — پلے اسٹور میں مکمل کریں۔',
        'الدفع معلّق — أكمله في متجر Play.',
        'भुगतान लंबित है — Play Store में पूरा करें।',
        'Paiement en attente — terminez-le dans le Play Store.',
        'Pago pendiente — complétalo en Play Store.',
        'Pagamento pendente — conclua-o na Play Store.',
        'Zahlung ausstehend — im Play Store abschließen.',
        "Ödeme bekliyor — Play Store'da tamamlayın.",
        'Pembayaran tertunda — selesaikan di Play Store.',
        'পেমেন্ট মুলতুবি — Play Store-এ সম্পূর্ণ করুন।',
      );
  String get playBillingRestored => _get(
        'Previous purchases restored.',
        'پچھلی خریداریاں بحال ہو گئیں۔',
        'تمت استعادة المشتريات السابقة.',
        'पिछली खरीदारी बहाल हो गई।',
        'Achats précédents restaurés.',
        'Compras anteriores restauradas.',
        'Compras anteriores restauradas.',
        'Frühere Käufe wiederhergestellt.',
        'Önceki satın alımlar geri yüklendi.',
        'Pembelian sebelumnya dipulihkan.',
        'পূর্ববর্তী ক্রয় পুনরুদ্ধার করা হয়েছে।',
      );
  String get playBillingStoreOnly => _get(
        'Purchases are available in the Google Play version of Virello.',
        'خریداریاں وائرلو کے گوگل پلے ورژن میں دستیاب ہیں۔',
        'المشتريات متاحة في نسخة Google Play من Virello.',
        'खरीदारी Virello के Google Play संस्करण में उपलब्ध है।',
        'Les achats sont disponibles dans la version Google Play de Virello.',
        'Las compras están disponibles en la versión de Google Play de Virello.',
        'As compras estão disponíveis na versão Google Play do Virello.',
        'Käufe sind in der Google Play-Version von Virello verfügbar.',
        "Satın alımlar Virello'nun Google Play sürümünde mevcuttur.",
        'Pembelian tersedia di versi Google Play Virello.',
        'ক্রয় Virello-এর Google Play সংস্করণে উপলব্ধ।',
      );
  String get playBillingOpenStore => _get(
        'Open in Play Store',
        'پلے اسٹور میں کھولیں',
        'افتح في متجر Play',
        'Play Store में खोलें',
        'Ouvrir dans le Play Store',
        'Abrir en Play Store',
        'Abrir na Play Store',
        'Im Play Store öffnen',
        "Play Store'da aç",
        'Buka di Play Store',
        'Play Store-এ খুলুন',
      );

  String get aiSupport =>
      _get('AI Support', 'AI معاونت', 'دعم الذكاء الاصطناعي',
        'AI सपोर्ट',
        'Assistance IA',
        'Soporte de IA',
        'Suporte de IA',
        'KI-Support',
        'Yapay zeka desteği',
        'Dukungan AI',
        'AI সাপোর্ট'
      );
  String get howVirelloGrows => _get(
        'How Virello grows you',
        'وائرلو آپ کو کیسے بڑھاتا ہے',
        'كيف ينمِّيك Virello',
      
        'Virello आपको कैसे बढ़ाता है',
        'Comment Virello vous fait grandir',
        'Cómo Virello te hace crecer',
        'Como o Virello faz você crescer',
        'Wie Virello dich wachsen lässt',
        'Virello seni nasıl büyütür',
        'Bagaimana Virello mengembangkanmu',
        'Virello আপনাকে কীভাবে বাড়ায়'
      );
  String get whatWeNeverDo =>
      _get('What we never do', 'ہم کیا کبھی نہیں کرتے', 'ما لا نفعله أبداً',
        'हम क्या कभी नहीं करते',
        'Ce que nous ne faisons jamais',
        'Lo que nunca hacemos',
        'O que nunca fazemos',
        'Was wir niemals tun',
        'Asla yapmadıklarımız',
        'Yang tidak pernah kami lakukan',
        'আমরা যা কখনো করি না'
      );
  String get aiSupportSoon => _get(
        'AI Support is coming soon.',
        'AI معاونت جلد آ رہی ہے۔',
        'دعم الذكاء الاصطناعي قادم قريباً.',
      
        'AI सपोर्ट जल्द आ रहा है।',
        'L\'assistance IA arrive bientôt.',
        'El soporte de IA llegará pronto.',
        'O suporte de IA chega em breve.',
        'Der KI-Support kommt bald.',
        'Yapay zeka desteği yakında geliyor.',
        'Dukungan AI segera hadir.',
        'AI সাপোর্ট শীঘ্রই আসছে।'
      );
  String get neverDoList => _get(
        'No fake followers, likes, views or comments.\nNo bots or automation on your accounts.\nNo password access — official connections only.\nNo guaranteed virality, reach or sales.',
        'کوئی جعلی فالوورز، لائکس، ویوز یا تبصرے نہیں۔\nآپ کے اکاؤنٹس پر کوئی بوٹس یا آٹومیشن نہیں۔\nپاس ورڈ تک رسائی نہیں — صرف سرکاری کنکشن۔\nوائرل ہونے، رسائی یا فروخت کی کوئی ضمانت نہیں۔',
        'لا متابعين أو إعجابات أو مشاهدات أو تعليقات مزيَّفة.\nلا روبوتات أو أتمتة على حساباتك.\nلا وصول لكلمات المرور — اتصالات رسمية فقط.\nلا ضمان للانتشار أو الوصول أو المبيعات.',
      
        'कोई नकली फ़ॉलोअर्स, लाइक्स, व्यूज़ या कमेंट्स नहीं।\nआपके अकाउंट्स पर कोई बॉट्स या ऑटोमेशन नहीं।\nपासवर्ड एक्सेस नहीं — सिर्फ़ आधिकारिक कनेक्शन।\nवायरलिटी, रीच या बिक्री की कोई गारंटी नहीं।',
        'Aucun faux abonné, mention J\'aime, vue ou commentaire.\nAucun bot ni automatisation sur vos comptes.\nAucun accès par mot de passe — connexions officielles uniquement.\nAucune garantie de viralité, de portée ou de ventes.',
        'Sin seguidores, me gusta, vistas o comentarios falsos.\nSin bots ni automatización en tus cuentas.\nSin acceso por contraseña — solo conexiones oficiales.\nSin garantía de viralidad, alcance o ventas.',
        'Sem seguidores, curtidas, visualizações ou comentários falsos.\nSem bots ou automação nas suas contas.\nSem acesso por senha — apenas conexões oficiais.\nSem garantia de viralidade, alcance ou vendas.',
        'Keine gefälschten Follower, Likes, Aufrufe oder Kommentare.\nKeine Bots oder Automatisierung auf deinen Konten.\nKein Passwortzugriff — nur offizielle Verbindungen.\nKeine garantierte Viralität, Reichweite oder Verkäufe.',
        'Sahte takipçi, beğeni, görüntülenme veya yorum yok.\nHesaplarında bot veya otomasyon yok.\nŞifre erişimi yok — yalnızca resmi bağlantılar.\nViralite, erişim veya satış garantisi yok.',
        'Tanpa pengikut, suka, tayangan, atau komentar palsu.\nTanpa bot atau otomatisasi di akunmu.\nTanpa akses kata sandi — hanya koneksi resmi.\nTanpa jaminan viralitas, jangkauan, atau penjualan.',
        'কোনো ভুয়া ফলোয়ার, লাইক, ভিউ বা কমেন্ট নয়।\nআপনার অ্যাকাউন্টে কোনো বট বা অটোমেশন নয়।\nপাসওয়ার্ড অ্যাক্সেস নয় — শুধু অফিসিয়াল সংযোগ।\nভাইরালিটি, রিচ বা বিক্রির কোনো গ্যারান্টি নয়।'
      );
  String get geoTitle => _get(
        'Audience geography',
        'آڈینس کی جغرافیائی حدود',
        'النطاق الجغرافي للجمهور',
      
        'ऑडियंस भूगोल',
        'Géographie de l\'audience',
        'Geografía de la audiencia',
        'Geografia do público',
        'Zielgruppen-Geografie',
        'Kitle coğrafyası',
        'Geografi audiens',
        'অডিয়েন্স ভূগোল'
      );
  String get geoAiRecommended =>
      _get('AI Recommended', 'AI تجویز کردہ', 'موصى به من الذكاء الاصطناعي',
        'AI सुझाई गई',
        'Recommandé par l\'IA',
        'Recomendado por la IA',
        'Recomendado pela IA',
        'Von der KI empfohlen',
        'Yapay zeka önerisi',
        'Direkomendasikan AI',
        'AI প্রস্তাবিত'
      );
  String get geoAiRecommendedDesc => _get(
        'AI picks countries from your post\'s language and topic',
        'AI آپ کی پوسٹ کی زبان اور موضوع سے ممالک چنتا ہے',
        'يختار الذكاء الاصطناعي الدول من لغة منشورك وموضوعه',
      
        'AI आपकी पोस्ट की भाषा और विषय से देश चुनता है',
        'L\'IA choisit des pays selon la langue et le sujet de votre publication',
        'La IA elige países según el idioma y el tema de tu publicación',
        'A IA escolhe países com base no idioma e no tema da sua publicação',
        'Die KI wählt Länder anhand von Sprache und Thema deines Beitrags',
        'Yapay zeka, gönderinin dili ve konusuna göre ülkeler seçer',
        'AI memilih negara dari bahasa dan topik postinganmu',
        'AI আপনার পোস্টের ভাষা ও বিষয় থেকে দেশ বেছে নেয়'
      );
  String get geoWorldwide => _get('Worldwide', 'دنیا بھر', 'جميع أنحاء العالم',
        'दुनिया भर',
        'Monde entier',
        'Todo el mundo',
        'Mundo todo',
        'Weltweit',
        'Dünya çapında',
        'Seluruh dunia',
        'বিশ্বব্যাপী'
      );
  String get geoWorldwideDesc => _get(
        'Deliver everywhere — maximum reach',
        'ہر جگہ ڈیلیور کریں — زیادہ سے زیادہ رسائی',
        'التوصيل في كل مكان — أقصى وصول',
      
        'हर जगह डिलीवर करें — अधिकतम रीच',
        'Diffusez partout — portée maximale',
        'Entrega en todas partes — alcance máximo',
        'Veicule em todos os lugares — alcance máximo',
        'Überall ausliefern — maximale Reichweite',
        'Her yere dağıt — maksimum erişim',
        'Tayangkan di mana saja — jangkauan maksimal',
        'সর্বত্র ডেলিভার করুন — সর্বোচ্চ রিচ'
      );
  String get geoCustom =>
      _get('Choose countries', 'ممالک منتخب کریں', 'اختيار الدول',
        'देश चुनें',
        'Choisir des pays',
        'Elegir países',
        'Escolher países',
        'Länder wählen',
        'Ülkeleri seç',
        'Pilih negara',
        'দেশ বেছে নিন'
      );
  String get geoCustomDesc => _get(
        'Pick specific countries yourself',
        'خود مخصوص ممالک چنیں',
        'اختر دولاً محددة بنفسك',
      
        'खुद विशिष्ट देश चुनें',
        'Choisissez vous-même des pays précis',
        'Elige tú mismo países específicos',
        'Escolha você mesmo países específicos',
        'Wähle selbst bestimmte Länder',
        'Belirli ülkeleri kendin seç',
        'Pilih sendiri negara tertentu',
        'নিজে নির্দিষ্ট দেশ বেছে নিন'
      );
  String get geoQuickRegions =>
      _get('Quick regions', 'فوری علاقے', 'مناطق سريعة',
        'त्वरित क्षेत्र',
        'Régions rapides',
        'Regiones rápidas',
        'Regiões rápidas',
        'Schnellregionen',
        'Hızlı bölgeler',
        'Wilayah cepat',
        'দ্রুত অঞ্চল'
      );
  String get geoSearchCountries =>
      _get('Search countries…', 'ممالک تلاش کریں…', 'ابحث عن الدول…',
        'देश खोजें…',
        'Rechercher des pays…',
        'Buscar países…',
        'Pesquisar países…',
        'Länder suchen…',
        'Ülke ara…',
        'Cari negara…',
        'দেশ খুঁজুন…'
      );
  String get geoWhyThese =>
      _get('Why these countries?', 'یہ ممالک کیوں؟', 'لماذا هذه الدول؟',
        'ये देश क्यों?',
        'Pourquoi ces pays ?',
        '¿Por qué estos países?',
        'Por que estes países?',
        'Warum diese Länder?',
        'Neden bu ülkeler?',
        'Mengapa negara-negara ini?',
        'এই দেশগুলো কেন?'
      );
  String geoCountriesSelected(int n) =>
      _get('$n selected', '$n منتخب', 'تم اختيار $n',
        '$n चयनित',
        '$n sélectionnés',
        '$n seleccionados',
        '$n selecionados',
        '$n ausgewählt',
        '$n seçildi',
        '$n dipilih',
        '$n টি নির্বাচিত'
      );
  String get geoNeedCountry => _get(
        'Select at least one country',
        'کم از کم ایک ملک منتخب کریں',
        'اختر دولة واحدة على الأقل',
      
        'कम से कम एक देश चुनें',
        'Sélectionnez au moins un pays',
        'Selecciona al menos un país',
        'Selecione pelo menos um país',
        'Wähle mindestens ein Land',
        'En az bir ülke seç',
        'Pilih setidaknya satu negara',
        'কমপক্ষে একটি দেশ নির্বাচন করুন'
      );
  String get geoAiNote => _get(
        'AI suggestion — you approve the final list',
        'AI تجویز — حتمی فہرست آپ منظور کرتے ہیں',
        'اقتراح الذكاء الاصطناعي — أنت تعتمد القائمة النهائية',
      
        'AI सुझाव — अंतिम सूची आप स्वीकृत करते हैं',
        'Suggestion de l\'IA — vous approuvez la liste finale',
        'Sugerencia de la IA — tú apruebas la lista final',
        'Sugestão da IA — você aprova a lista final',
        'KI-Vorschlag — du genehmigst die finale Liste',
        'Yapay zeka önerisi — nihai listeyi sen onaylarsın',
        'Saran AI — kamu menyetujui daftar final',
        'AI প্রস্তাব — চূড়ান্ত তালিকা আপনি অনুমোদন করেন'
      );
  // --- Modern country picker + market brief ---
  String get geoAllRegions => _get('All', 'سب', 'الكل',
        'सभी',
        'Tous',
        'Todos',
        'Todos',
        'Alle',
        'Tümü',
        'Semua',
        'সব'
      );
  String get geoUseAiSuggestion => _get(
        'Use AI suggestion',
        'AI تجویز استعمال کریں',
        'استخدم اقتراح الذكاء الاصطناعي',
      
        'AI सुझाव इस्तेमाल करें',
        'Utiliser la suggestion de l\'IA',
        'Usar sugerencia de la IA',
        'Usar sugestão da IA',
        'KI-Vorschlag verwenden',
        'Yapay zeka önerisini kullan',
        'Gunakan saran AI',
        'AI প্রস্তাব ব্যবহার করুন'
      );
  String get geoYourMarkets => _get('Your markets', 'آپ کی مارکیٹس', 'أسواقك',
        'आपके बाज़ार',
        'Vos marchés',
        'Tus mercados',
        'Seus mercados',
        'Deine Märkte',
        'Pazarların',
        'Pasarmu',
        'আপনার বাজার'
      );
  String get geoMarketBriefNote => _get(
        'AI will match your content language and audience to these markets.',
        'AI آپ کے مواد کی زبان اور سامعین کو ان مارکیٹس سے ملائے گا۔',
        'سيطابق الذكاء الاصطناعي لغة محتواك وجمهورك مع هذه الأسواق.',
      
        'AI आपकी कंटेंट भाषा और ऑडियंस को इन बाज़ारों से मिलाएगा।',
        'L\'IA associera la langue de votre contenu et votre audience à ces marchés.',
        'La IA combinará el idioma de tu contenido y tu audiencia con estos mercados.',
        'A IA combinará o idioma do seu conteúdo e seu público com estes mercados.',
        'Die KI ordnet deine Inhaltssprache und Zielgruppe diesen Märkten zu.',
        'Yapay zeka, içerik dilini ve kitleni bu pazarlarla eşleştirecek.',
        'AI akan mencocokkan bahasa konten dan audiensmu dengan pasar-pasar ini.',
        'AI আপনার কনটেন্টের ভাষা ও অডিয়েন্সকে এই বাজারগুলোর সাথে মেলাবে।'
      );
  String get geoAiSuggestedBadge =>
      _get('AI suggested', 'AI کی تجویز', 'مقترح بالذكاء الاصطناعي',
        'AI सुझाई गई',
        'Suggéré par l\'IA',
        'Sugerido por la IA',
        'Sugerido pela IA',
        'Von der KI vorgeschlagen',
        'Yapay zeka önerdi',
        'Disarankan AI',
        'AI প্রস্তাবিত'
      );
  String get geoYourPickBadge => _get('Your pick', 'آپ کا انتخاب', 'اختيارك',
        'आपकी पसंद',
        'Votre choix',
        'Tu elección',
        'Sua escolha',
        'Deine Wahl',
        'Senin seçimin',
        'Pilihanmu',
        'আপনার পছন্দ'
      );

  // Free Grow vs Paid Boost — plans, packages, agents.
  String get freeGrow => _get('Free Grow', 'مفت گرو', 'نمو مجاني',
        'फ्री ग्रो',
        'Croissance gratuite',
        'Crecimiento gratis',
        'Crescimento grátis',
        'Kostenloses Wachstum',
        'Ücretsiz Büyüme',
        'Grow Gratis',
        'ফ্রি গ্রো'
      );
  String get paidBoost => _get('Paid Boost', 'پیڈ بوسٹ', 'تعزيز مدفوع',
        'पेड बूस्ट',
        'Boost payant',
        'Impulso pagado',
        'Impulso pago',
        'Bezahlter Boost',
        'Ücretli Boost',
        'Boost Berbayar',
        'পেইড বুস্ট'
      );
  String get freeGrowTag => _get(
        'Worldwide · Limited · \$0',
        'عالمی · محدود · \$0',
        'عالمي · محدود · 0\$',
      
        'दुनिया भर · सीमित · \$0',
        'Monde entier · Limité · \$0',
        'Todo el mundo · Limitado · \$0',
        'Mundo todo · Limitado · \$0',
        'Weltweit · Begrenzt · \$0',
        'Dünya çapında · Sınırlı · \$0',
        'Seluruh dunia · Terbatas · \$0',
        'বিশ্বব্যাপী · সীমিত · \$0'
      );
  String get paidBoostTag => _get(
        'Choose a package · Target countries',
        'پیکیج چنیں · ممالک ٹارگٹ کریں',
        'اختر باقة · استهدف الدول',
      
        'पैकेज चुनें · देश टारगेट करें',
        'Choisissez un forfait · Ciblez des pays',
        'Elige un paquete · Segmenta países',
        'Escolha um pacote · Segmente países',
        'Paket wählen · Länder targeten',
        'Paket seç · Ülkeleri hedefle',
        'Pilih paket · Targetkan negara',
        'প্যাকেজ বেছে নিন · দেশ টার্গেট করুন'
      );
  String get freeGrowLimits =>
      _get('Free Grow limits', 'مفت گرو کی حدود', 'حدود النمو المجاني',
        'फ्री ग्रो की सीमाएं',
        'Limites de la croissance gratuite',
        'Límites del crecimiento gratis',
        'Limites do crescimento grátis',
        'Limits des kostenlosen Wachstums',
        'Ücretsiz Büyüme limitleri',
        'Batasan Grow Gratis',
        'ফ্রি গ্রোর সীমা'
      );
  String get freeLimitCampaigns => _get(
        'Up to 3 live campaigns',
        'زیادہ سے زیادہ 3 لائیو مہمات',
        'حتى 3 حملات نشطة',
      
        'अधिकतम 3 लाइव अभियान',
        'Jusqu\'à 3 campagnes actives',
        'Hasta 3 campañas activas',
        'Até 3 campanhas ativas',
        'Bis zu 3 aktive Kampagnen',
        'En fazla 3 aktif kampanya',
        'Hingga 3 kampanye aktif',
        'সর্বোচ্চ 3টি লাইভ ক্যাম্পেইন'
      );
  String get freeLimitImpressions => _get(
        'Up to 1,000 genuine impressions per campaign',
        'فی مہم 1,000 حقیقی امپریشنز تک',
        'حتى 1000 ظهور حقيقي لكل حملة',
      
        'प्रति अभियान 1,000 वास्तविक इम्प्रेशन्स तक',
        'Jusqu\'à 1 000 impressions réelles par campagne',
        'Hasta 1.000 impresiones reales por campaña',
        'Até 1.000 impressões reais por campanha',
        'Bis zu 1.000 echte Impressionen pro Kampagne',
        'Kampanya başına 1.000\'e kadar gerçek gösterim',
        'Hingga 1.000 tayangan asli per kampanye',
        'প্রতি ক্যাম্পেইনে 1,000টি আসল ইমপ্রেশন পর্যন্ত'
      );
  String get freeWorldwideOnly => _get(
        'Worldwide audience only — no country picker',
        'صرف عالمی سامعین — ملک منتخب نہیں ہوگا',
        'جمهور عالمي فقط — بدون اختيار الدول',
      
        'सिर्फ़ दुनिया भर की ऑडियंस — देश चुनने का विकल्प नहीं',
        'Audience mondiale uniquement — pas de sélection de pays',
        'Solo audiencia mundial — sin selector de países',
        'Apenas público mundial — sem seletor de países',
        'Nur weltweite Zielgruppe — keine Länderauswahl',
        'Yalnızca dünya çapında kitle — ülke seçimi yok',
        'Hanya audiens seluruh dunia — tanpa pemilih negara',
        'শুধু বিশ্বব্যাপী অডিয়েন্স — দেশ বাছাইয়ের অপশন নেই'
      );
  String get freeNoBudget => _get(
        'No budget, no spend — \$0',
        'کوئی بجٹ نہیں، کوئی خرچ نہیں — \$0',
        'بدون ميزانية، بدون إنفاق — 0\$',
      
        'कोई बजट नहीं, कोई खर्च नहीं — \$0',
        'Aucun budget, aucune dépense — \$0',
        'Sin presupuesto, sin gasto — \$0',
        'Sem orçamento, sem gasto — \$0',
        'Kein Budget, keine Ausgaben — \$0',
        'Bütçe yok, harcama yok — \$0',
        'Tanpa anggaran, tanpa pengeluaran — \$0',
        'বাজেট নেই, খরচ নেই — \$0'
      );
  String get choosePackage =>
      _get('Choose your package', 'اپنا پیکیج چنیں', 'اختر باقتك',
        'अपना पैकेज चुनें',
        'Choisissez votre forfait',
        'Elige tu paquete',
        'Escolha seu pacote',
        'Wähle dein Paket',
        'Paketini seç',
        'Pilih paketmu',
        'আপনার প্যাকেজ বেছে নিন'
      );
  String get packagePopular =>
      _get('Most popular', 'سب سے مقبول', 'الأكثر شعبية',
        'सबसे लोकप्रिय',
        'Le plus populaire',
        'El más popular',
        'Mais popular',
        'Am beliebtesten',
        'En popüler',
        'Paling populer',
        'সবচেয়ে জনপ্রিয়'
      );
  String packageDays(int n) => _get('$n days', '$n دن', '$n يوم',
        '$n दिन',
        '$n jours',
        '$n días',
        '$n dias',
        '$n Tage',
        '$n gün',
        '$n hari',
        '$n দিন'
      );
  String get managedByFreeAi => _get(
        'Managed by Free Grow AI',
        'فری گرو AI کے زیر انتظام',
        'يُدار بواسطة نمو مجاني AI',
      
        'फ्री ग्रो AI द्वारा प्रबंधित',
        'Géré par l\'IA de croissance gratuite',
        'Gestionado por la IA de crecimiento gratis',
        'Gerenciado pela IA de crescimento grátis',
        'Verwaltet von der Free-Grow-KI',
        'Ücretsiz Büyüme yapay zekası tarafından yönetilir',
        'Dikelola oleh AI Grow Gratis',
        'ফ্রি গ্রো AI দ্বারা পরিচালিত'
      );
  String get managedByPaidAi => _get(
        'Managed by Paid Boost AI',
        'پیڈ بوسٹ AI کے زیر انتظام',
        'يُدار بواسطة تعزيز مدفوع AI',
      
        'पेड बूस्ट AI द्वारा प्रबंधित',
        'Géré par l\'IA de boost payant',
        'Gestionado por la IA de impulso pagado',
        'Gerenciado pela IA de impulso pago',
        'Verwaltet von der Paid-Boost-KI',
        'Ücretli Boost yapay zekası tarafından yönetilir',
        'Dikelola oleh AI Boost Berbayar',
        'পেইড বুস্ট AI দ্বারা পরিচালিত'
      );
  String get freeGrowAiDesc => _get(
        'Your organic growth manager — worldwide reach, zero budget.',
        'آپ کا آرگینک گروتھ مینیجر — عالمی رسائی، صفر بجٹ۔',
        'مدير نموك العضوي — وصول عالمي، ميزانية صفر.',
      
        'आपका ऑर्गेनिक ग्रोथ मैनेजर — दुनिया भर की रीच, शून्य बजट।',
        'Votre gestionnaire de croissance organique — portée mondiale, budget zéro.',
        'Tu gestor de crecimiento orgánico — alcance mundial, presupuesto cero.',
        'Seu gerente de crescimento orgânico — alcance mundial, orçamento zero.',
        'Dein Manager für organisches Wachstum — weltweite Reichweite, null Budget.',
        'Organik büyüme yöneticin — dünya çapında erişim, sıfır bütçe.',
        'Manajer pertumbuhan organikmu — jangkauan seluruh dunia, anggaran nol.',
        'আপনার অর্গানিক গ্রোথ ম্যানেজার — বিশ্বব্যাপী রিচ, শূন্য বাজেট।'
      );
  String get paidBoostAiDesc => _get(
        'Your paid growth manager — targeted reach, inside your package budget.',
        'آپ کا پیڈ گروتھ مینیجر — ٹارگٹڈ رسائی، آپ کے پیکیج بجٹ کے اندر۔',
        'مدير نموك المدفوع — وصول مستهدف، ضمن ميزانية باقتك.',
      
        'आपका पेड ग्रोथ मैनेजर — टारगेटेड रीच, आपके पैकेज बजट के भीतर।',
        'Votre gestionnaire de croissance payante — portée ciblée, dans votre budget de forfait.',
        'Tu gestor de crecimiento pagado — alcance segmentado, dentro del presupuesto de tu paquete.',
        'Seu gerente de crescimento pago — alcance segmentado, dentro do orçamento do seu pacote.',
        'Dein Manager für bezahltes Wachstum — gezielte Reichweite, innerhalb deines Paketbudgets.',
        'Ücretli büyüme yöneticin — hedefli erişim, paket bütçenin içinde.',
        'Manajer pertumbuhan berbayarmu — jangkauan tertarget, dalam anggaran paketmu.',
        'আপনার পেইড গ্রোথ ম্যানেজার — টার্গেটেড রিচ, আপনার প্যাকেজ বাজেটের মধ্যে।'
      );
  String get freeServices => _get('Free Services', 'مفت سروسز', 'خدمات مجانية',
        'मुफ़्त सेवाएं',
        'Services gratuits',
        'Servicios gratuitos',
        'Serviços gratuitos',
        'Kostenlose Services',
        'Ücretsiz Hizmetler',
        'Layanan Gratis',
        'ফ্রি সার্ভিস'
      );
  String get paidServices => _get('Paid Services', 'پیڈ سروسز', 'خدمات مدفوعة',
        'पेड सेवाएं',
        'Services payants',
        'Servicios de pago',
        'Serviços pagos',
        'Bezahlte Services',
        'Ücretli Hizmetler',
        'Layanan Berbayar',
        'পেইড সার্ভিস'
      );
  String get planLockedNote => _get(
        "Plan can't change after creation",
        'بننے کے بعد پلان نہیں بدل سکتا',
        'لا يمكن تغيير الخطة بعد الإنشاء',
      
        'बनने के बाद प्लान नहीं बदला जा सकता',
        'Le forfait ne peut pas être modifié après sa création',
        'El plan no se puede cambiar después de crearlo',
        'O plano não pode ser alterado após a criação',
        'Der Plan kann nach der Erstellung nicht geändert werden',
        'Oluşturulduktan sonra plan değiştirilemez',
        'Paket tidak dapat diubah setelah dibuat',
        'তৈরির পর প্ল্যান বদলানো যাবে না'
      );
  String get choosePlan =>
      _get('Choose your plan', 'اپنا پلان چنیں', 'اختر خطتك',
        'अपना प्लान चुनें',
        'Choisissez votre forfait',
        'Elige tu plan',
        'Escolha seu plano',
        'Wähle deinen Plan',
        'Planını seç',
        'Pilih paketmu',
        'আপনার প্ল্যান বেছে নিন'
      );
  String get freeModuleBadge => _get('100% free', '100% مفت', 'مجاني 100٪',
        '100% मुफ़्त',
        '100 % gratuit',
        '100 % gratis',
        '100% grátis',
        '100 % kostenlos',
        '%100 ücretsiz',
        '100% gratis',
        '১০০% ফ্রি'
      );
  String get paidModuleBadge => _get('Paid', 'پیڈ', 'مدفوع',
        'पेड',
        'Payant',
        'De pago',
        'Pago',
        'Bezahlt',
        'Ücretli',
        'Berbayar',
        'পেইড'
      );
  String get freeGrowDesc => _get(
        'AI works to grow your content organically across Virello\'s discovery network — worldwide audience, \$0. No packages, no budget controls, no spend.',
        'AI آپ کے مواد کو Virello کے ڈسکوری نیٹ ورک میں آرگینک طریقے سے بڑھانے کی کوشش کرتا ہے — عالمی سامعین، \$0۔ کوئی پیکیج نہیں، کوئی بجٹ کنٹرول نہیں، کوئی خرچ نہیں۔',
        'يعمل الذكاء الاصطناعي على تنمية المحتوى الخاص بك عضوياً عبر شبكة اكتشاف Virello — جمهور عالمي، 0\$. لا باقات، لا ضوابط ميزانية، لا إنفاق.',
      
        'AI Virello के डिस्कवरी नेटवर्क में आपके कंटेंट को ऑर्गेनिक रूप से बढ़ाने का काम करता है — दुनिया भर की ऑडियंस, \$0। कोई पैकेज नहीं, कोई बजट नियंत्रण नहीं, कोई खर्च नहीं।',
        'L\'IA travaille à développer votre contenu de manière organique sur le réseau de découverte de Virello — audience mondiale, \$0. Aucun forfait, aucun contrôle budgétaire, aucune dépense.',
        'La IA trabaja para hacer crecer tu contenido de forma orgánica en la red de descubrimiento de Virello — audiencia mundial, \$0. Sin paquetes, sin controles de presupuesto, sin gasto.',
        'A IA trabalha para fazer seu conteúdo crescer organicamente na rede de descoberta do Virello — público mundial, \$0. Sem pacotes, sem controles de orçamento, sem gasto.',
        'Die KI arbeitet daran, deine Inhalte organisch im Discovery-Netzwerk von Virello wachsen zu lassen — weltweite Zielgruppe, \$0. Keine Pakete, keine Budgetkontrollen, keine Ausgaben.',
        'Yapay zeka, içeriğini Virello\'nun keşif ağında organik olarak büyütmek için çalışır — dünya çapında kitle, \$0. Paket yok, bütçe kontrolü yok, harcama yok.',
        'AI bekerja mengembangkan kontenmu secara organik di jaringan penemuan Virello — audiens seluruh dunia, \$0. Tanpa paket, tanpa kontrol anggaran, tanpa pengeluaran.',
        'AI Virello-র ডিসকভারি নেটওয়ার্কে আপনার কনটেন্ট অর্গানিকভাবে বাড়াতে কাজ করে — বিশ্বব্যাপী অডিয়েন্স, \$0। কোনো প্যাকেজ নেই, কোনো বাজেট নিয়ন্ত্রণ নেই, কোনো খরচ নেই।'
      );
  String freeLimitCampaignsN(int n) => _get(
        'Up to $n live campaigns',
        'زیادہ سے زیادہ $n لائیو مہمات',
        'حتى $n حملات نشطة',
      
        'अधिकतम $n लाइव अभियान',
        'Jusqu\'à $n campagnes actives',
        'Hasta $n campañas activas',
        'Até $n campanhas ativas',
        'Bis zu $n aktive Kampagnen',
        'En fazla $n aktif kampanya',
        'Hingga $n kampanye aktif',
        'সর্বোচ্চ $n টি লাইভ ক্যাম্পেইন'
      );
  String freeLimitImpressionsN(String n) => _get(
        'Up to $n genuine impressions per campaign',
        'فی مہم $n حقیقی امپریشنز تک',
        'حتى $n ظهور حقيقي لكل حملة',
      
        'प्रति अभियान $n वास्तविक इम्प्रेशन्स तक',
        'Jusqu\'à $n impressions réelles par campagne',
        'Hasta $n impresiones reales por campaña',
        'Até $n impressões reais por campanha',
        'Bis zu $n echte Impressionen pro Kampagne',
        'Kampanya başına $n\'e kadar gerçek gösterim',
        'Hingga $n tayangan asli per kampanye',
        'প্রতি ক্যাম্পেইনে $n টি আসল ইমপ্রেশন পর্যন্ত'
      );
  String get freeWindDown => _get(
        'AI winds down automatically at 80% of the impression cap',
        'امپریشن حد کے 80 فیصد پر AI خودکار طور پر سست ہو جاتا ہے',
        'يتباطأ الذكاء الاصطناعي تلقائياً عند 80٪ من حد الظهور',
      
        'इम्प्रेशन सीमा के 80% पर AI अपने आप धीमा हो जाता है',
        'L\'IA ralentit automatiquement à 80 % du plafond d\'impressions',
        'La IA se desacelera automáticamente al 80 % del límite de impresiones',
        'A IA desacelera automaticamente aos 80 % do limite de impressões',
        'Die KI drosselt automatisch bei 80 % des Impressions-Limits',
        'Yapay zeka, gösterim sınırının %80\'inde otomatik olarak yavaşlar',
        'AI melambat otomatis pada 80% dari batas tayangan',
        'ইমপ্রেশন সীমার 80%-এ AI স্বয়ংক্রিয়ভাবে ধীর হয়ে যায়'
      );
  String get paidBoostDesc => _get(
        'AI runs paid promotion inside the budget you approve by picking a package. Targeted countries, fixed duration — you approve everything before launch.',
        'AI آپ کے منظور کردہ بجٹ کے اندر پیڈ پروموشن چلاتا ہے — پیکیج منتخب کر کے بجٹ طے کریں۔ ٹارگٹڈ ممالک، مقررہ مدت — لانچ سے پہلے سب کچھ آپ منظور کرتے ہیں۔',
        'يدير الذكاء الاصطناعي الترويج المدفوع ضمن الميزانية التي تعتمدها باختيار باقة. دول مستهدفة، مدة ثابتة — تعتمد كل شيء قبل الإطلاق.',
      
        'AI पैकेज चुनकर आपके द्वारा स्वीकृत बजट के भीतर पेड प्रमोशन चलाता है। टारगेटेड देश, निश्चित अवधि — लॉन्च से पहले आप सब कुछ स्वीकृत करते हैं।',
        'L\'IA gère la promotion payante dans le budget que vous approuvez en choisissant un forfait. Pays ciblés, durée fixe — vous approuvez tout avant le lancement.',
        'La IA ejecuta la promoción pagada dentro del presupuesto que apruebas al elegir un paquete. Países segmentados, duración fija — apruebas todo antes del lanzamiento.',
        'A IA executa a promoção paga dentro do orçamento que você aprova ao escolher um pacote. Países segmentados, duração fixa — você aprova tudo antes do lançamento.',
        'Die KI schaltet bezahlte Werbung innerhalb des Budgets, das du mit der Paketwahl genehmigst. Gezielte Länder, feste Dauer — du genehmigst alles vor dem Start.',
        'Yapay zeka, bir paket seçerek onayladığın bütçe içinde ücretli tanıtım yürütür. Hedeflenen ülkeler, sabit süre — lansmandan önce her şeyi sen onaylarsın.',
        'AI menjalankan promosi berbayar dalam anggaran yang kamu setujui dengan memilih paket. Negara tertarget, durasi tetap — kamu menyetujui semuanya sebelum diluncurkan.',
        'AI আপনার প্যাকেজ বেছে নেওয়ার মাধ্যমে অনুমোদিত বাজেটের মধ্যে পেইড প্রমোশন চালায়। টার্গেটেড দেশ, নির্দিষ্ট মেয়াদ — লঞ্চের আগে সবকিছু আপনি অনুমোদন করেন।'
      );
  String get packageIsBudget => _get(
        'Your package IS your budget — no manual budgeting needed',
        'آپ کا پیکیج ہی آپ کا بجٹ ہے — دستی بجٹنگ کی ضرورت نہیں',
        'باقتك هي ميزانيتك — لا حاجة لتحديد الميزانية يدوياً',
      
        'आपका पैकेज ही आपका बजट है — मैन्युअल बजटिंग की ज़रूरत नहीं',
        'Votre forfait EST votre budget — aucune budgétisation manuelle requise',
        'Tu paquete ES tu presupuesto — sin necesidad de presupuestar manualmente',
        'Seu pacote É seu orçamento — sem necessidade de orçamento manual',
        'Dein Paket IST dein Budget — keine manuelle Budgetierung nötig',
        'Paketin bütçenin ta kendisidir — manuel bütçelemeye gerek yok',
        'Paketmu ADALAH anggaranmu — tidak perlu penganggaran manual',
        'আপনার প্যাকেজই আপনার বাজেট — ম্যানুয়াল বাজেটিংয়ের প্রয়োজন নেই'
      );
  String get paidLimitsTitle =>
      _get('Paid Boost limits', 'پیڈ بوسٹ کی حدود', 'حدود التعزيز المدفوع',
        'पेड बूस्ट की सीमाएं',
        'Limites du boost payant',
        'Límites del impulso pagado',
        'Limites do impulso pago',
        'Limits des bezahlten Boosts',
        'Ücretli Boost limitleri',
        'Batasan Boost Berbayar',
        'পেইড বুস্টের সীমা'
      );
  String get paidLimitSpend => _get(
        'Spend capped at your package price — never more',
        'خرچ آپ کے پیکیج کی قیمت تک محدود — اس سے زیادہ کبھی نہیں',
        'الإنفاق محدود بسعر باقتك — لا يتجاوزه أبداً',
      
        'खर्च आपके पैकेज की कीमत तक सीमित — इससे ज़्यादा कभी नहीं',
        'Dépenses plafonnées au prix de votre forfait — jamais plus',
        'Gasto limitado al precio de tu paquete — nunca más',
        'Gasto limitado ao preço do seu pacote — nunca mais',
        'Ausgaben gedeckelt auf deinen Paketpreis — niemals mehr',
        'Harcama paket fiyatınla sınırlı — asla daha fazla değil',
        'Pengeluaran dibatasi pada harga paketmu — tidak pernah lebih',
        'খরচ আপনার প্যাকেজের দামে সীমাবদ্ধ — এর বেশি কখনো নয়'
      );
  String get paidLimitDuration => _get(
        'Fixed duration per package — set by the package you pick',
        'ہر پیکیج کی مقررہ مدت — آپ کے منتخب کردہ پیکیج کے مطابق',
        'مدة ثابتة لكل باقة — حسب الباقة التي تختارها',
      
        'प्रति पैकेज निश्चित अवधि — आपके चुने गए पैकेज द्वारा तय',
        'Durée fixe par forfait — définie par le forfait choisi',
        'Duración fija por paquete — definida por el paquete que elijas',
        'Duração fixa por pacote — definida pelo pacote escolhido',
        'Feste Dauer pro Paket — festgelegt durch das gewählte Paket',
        'Paket başına sabit süre — seçtiğin paket tarafından belirlenir',
        'Durasi tetap per paket — ditentukan oleh paket yang kamu pilih',
        'প্রতি প্যাকেজে নির্দিষ্ট মেয়াদ — আপনার বেছে নেওয়া প্যাকেজ দ্বারা নির্ধারিত'
      );
  String get paidLimitCountries => _get(
        'Targeted countries you approve before launch',
        'لانچ سے پہلے آپ جن ممالک کو منظور کریں',
        'دول مستهدفة تعتمدها قبل الإطلاق',
      
        'टारगेटेड देश जिन्हें आप लॉन्च से पहले स्वीकृत करते हैं',
        'Pays ciblés que vous approuvez avant le lancement',
        'Países segmentados que apruebas antes del lanzamiento',
        'Países segmentados que você aprova antes do lançamento',
        'Gezielte Länder, die du vor dem Start genehmigst',
        'Lansmandan önce onayladığın hedef ülkeler',
        'Negara tertarget yang kamu setujui sebelum diluncurkan',
        'টার্গেটেড দেশ যা আপনি লঞ্চের আগে অনুমোদন করেন'
      );

  // Tutorial / Guide
  String get tutorialTitle =>
      _get('Tutorial / Guide', 'ٹیوٹوریل / گائیڈ', 'الشرح / الدليل',
        'ट्यूटोरियल / गाइड',
        'Tutoriel / Guide',
        'Tutorial / Guía',
        'Tutorial / Guia',
        'Tutorial / Anleitung',
        'Eğitim / Kılavuz',
        'Tutorial / Panduan',
        'টিউটোরিয়াল / গাইড'
      );
  String get tutorialMenu =>
      _get('Tutorial / Guide', 'ٹیوٹوریل / گائیڈ', 'الشرح / الدليل',
        'ट्यूटोरियल / गाइड',
        'Tutoriel / Guide',
        'Tutorial / Guía',
        'Tutorial / Guia',
        'Tutorial / Anleitung',
        'Eğitim / Kılavuz',
        'Tutorial / Panduan',
        'টিউটোরিয়াল / গাইড'
      );
  String get tutorialMenuSub => _get(
        'Watch how to use Virello',
        'دیکھیں Virello کیسے استعمال کریں',
        'شاهد كيفية استخدام Virello',
      
        'देखें Virello कैसे इस्तेमाल करें',
        'Regardez comment utiliser Virello',
        'Mira cómo usar Virello',
        'Veja como usar o Virello',
        'Schau dir an, wie du Virello nutzt',
        'Virello\'nun nasıl kullanılacağını izle',
        'Tonton cara menggunakan Virello',
        'Virello কীভাবে ব্যবহার করবেন দেখুন'
      );
  String get tutorialChapters => _get('Chapters', 'ابواب', 'الفصول',
        'अध्याय',
        'Chapitres',
        'Capítulos',
        'Capítulos',
        'Kapitel',
        'Bölümler',
        'Bab',
        'অধ্যায়'
      );
  String get tutorialReplay => _get('Replay', 'دوبارہ چلائیں', 'إعادة التشغيل',
        'फिर से चलाएं',
        'Rejouer',
        'Repetir',
        'Repetir',
        'Wiederholen',
        'Tekrar oynat',
        'Putar ulang',
        'আবার চালান'
      );
  String get tutorialRestartChapter =>
      _get('Restart chapter', 'باب دوبارہ شروع کریں', 'إعادة الفصل',
        'अध्याय फिर से शुरू करें',
        'Recommencer le chapitre',
        'Reiniciar capítulo',
        'Reiniciar capítulo',
        'Kapitel neu starten',
        'Bölümü yeniden başlat',
        'Mulai ulang bab',
        'অধ্যায় আবার শুরু করুন'
      );
  String tutorialResume(String at) =>
      _get('Resume from $at', '$at سے جاری رکھیں', 'الاستئناف من $at',
        '$at से जारी रखें',
        'Reprendre à $at',
        'Continuar desde $at',
        'Continuar de $at',
        'Ab $at fortsetzen',
        '$at konumundan devam et',
        'Lanjutkan dari $at',
        '$at থেকে চালিয়ে যান'
      );
  String get tutorialLoadError => _get(
        'Could not load the tutorial video.',
        'ٹیوٹوریل ویڈیو لوڈ نہیں ہو سکی۔',
        'تعذّر تحميل فيديو الشرح.',
      
        'ट्यूटोरियल वीडियो लोड नहीं हो सका।',
        'Impossible de charger la vidéo du tutoriel.',
        'No se pudo cargar el video del tutorial.',
        'Não foi possível carregar o vídeo do tutorial.',
        'Das Tutorial-Video konnte nicht geladen werden.',
        'Eğitim videosu yüklenemedi.',
        'Video tutorial tidak dapat dimuat.',
        'টিউটোরিয়াল ভিডিও লোড করা যায়নি।'
      );
  String get tutorialNote => _get(
        'A guided walkthrough of the whole app, narrated in Urdu — with built-in subtitles in 44 languages.',
        'پوری ایپ کا رہنمائی والا تعارف، اردو میں بیان کردہ — 44 زبانوں میں بلٹ اِن سب ٹائٹلز کے ساتھ۔',
        'جولة إرشادية في التطبيق كاملاً، باللغة الأردية — مع ترجمة مدمجة بـ 44 لغة.',
      
        'पूरे ऐप का निर्देशित परिचय, उर्दू में वर्णित — 44 भाषाओं में बिल्ट-इन सबटाइटल्स के साथ।',
        'Une visite guidée de toute l\'application, narrée en ourdou — avec des sous-titres intégrés en 44 langues.',
        'Un recorrido guiado por toda la aplicación, narrado en urdu — con subtítulos integrados en 44 idiomas.',
        'Um tour guiado por todo o aplicativo, narrado em urdu — com legendas integradas em 44 idiomas.',
        'Eine geführte Tour durch die gesamte App, auf Urdu erzählt — mit eingebauten Untertiteln in 44 Sprachen.',
        'Tüm uygulamanın Urduca anlatımlı rehberli turu — 44 dilde yerleşik altyazılarla.',
        'Tur terpandu seluruh aplikasi, dinarasikan dalam bahasa Urdu — dengan subtitle bawaan dalam 44 bahasa.',
        'পুরো অ্যাপের নির্দেশিত ট্যুর, উর্দুতে বর্ণিত — 44টি ভাষায় বিল্ট-ইন সাবটাইটেলসহ।'
      );
  String get tutorialSubtitles => _get('Subtitles', 'سب ٹائٹلز', 'الترجمة',
        'सबटाइटल्स',
        'Sous-titres',
        'Subtítulos',
        'Legendas',
        'Untertitel',
        'Altyazılar',
        'Subtitle',
        'সাবটাইটেল'
      );
  String get play => _get('Play', 'چلائیں', 'تشغيل',
        'चलाएं',
        'Lire',
        'Reproducir',
        'Reproduzir',
        'Abspielen',
        'Oynat',
        'Putar',
        'চালান'
      );
  String get tutChWelcome => _get(
        'Welcome to Virello',
        'Virello میں خوش آمدید',
        'مرحباً بك في Virello',
      
        'Virello में आपका स्वागत है',
        'Bienvenue sur Virello',
        'Bienvenido a Virello',
        'Bem-vindo ao Virello',
        'Willkommen bei Virello',
        'Virello\'ya hoş geldin',
        'Selamat datang di Virello',
        'Virello-তে স্বাগতম'
      );
  String get tutChHome => _get('Home Feed', 'ہوم فیڈ', 'الخلاصة الرئيسية',
        'होम फ़ीड',
        'Fil d\'accueil',
        'Inicio',
        'Feed inicial',
        'Start-Feed',
        'Ana sayfa akışı',
        'Beranda',
        'হোম ফিড'
      );
  String get tutChDiscover => _get('Discover', 'ڈسکور', 'اكتشف',
        'डिस्कवर',
        'Découvrir',
        'Descubrir',
        'Descobrir',
        'Entdecken',
        'Keşfet',
        'Temukan',
        'ডিসকভার'
      );
  String get tutChCreate => _get('Create', 'بنائیں', 'إنشاء',
        'बनाएं',
        'Créer',
        'Crear',
        'Criar',
        'Erstellen',
        'Oluştur',
        'Buat',
        'তৈরি করুন'
      );
  String get tutChAnalyze =>
      _get('AI Analyze', 'AI تجزیہ', 'تحليل الذكاء الاصطناعي',
        'AI विश्लेषण',
        'Analyse IA',
        'Análisis con IA',
        'Análise com IA',
        'KI-Analyse',
        'Yapay zeka analizi',
        'Analisis AI',
        'AI বিশ্লেষণ'
      );
  String get tutChAudience =>
      _get('Audience Insights', 'آڈینس انسائٹس', 'رؤى الجمهور',
        'ऑडियंस इनसाइट्स',
        'Infos sur l\'audience',
        'Información de la audiencia',
        'Insights do público',
        'Zielgruppen-Insights',
        'Kitle içgörüleri',
        'Wawasan Audiens',
        'অডিয়েন্স ইনসাইটস'
      );
  String get tutChSetup => _get('Campaign Setup', 'مہم سیٹ اپ', 'إعداد الحملة',
        'अभियान सेटअप',
        'Configuration de la campagne',
        'Configuración de campaña',
        'Configuração da campanha',
        'Kampagnen-Setup',
        'Kampanya Kurulumu',
        'Penyiapan Kampanye',
        'ক্যাম্পেইন সেটআপ'
      );
  String get tutChAgent =>
      _get('AI Growth Agent', 'AI گروتھ ایجنٹ', 'وكيل النمو بالذكاء الاصطناعي',
        'AI ग्रोथ एजेंट',
        'Agent de croissance IA',
        'Agente de crecimiento IA',
        'Agente de crescimento IA',
        'KI-Wachstumsagent',
        'YZ Büyüme Asistanı',
        'Agen Pertumbuhan AI',
        'AI গ্রোথ এজেন্ট'
      );
  String get tutChCampaigns => _get('Campaigns', 'مہمات', 'الحملات',
        'अभियान',
        'Campagnes',
        'Campañas',
        'Campanhas',
        'Kampagnen',
        'Kampanyalar',
        'Kampanye',
        'ক্যাম্পেইন'
      );
  String get tutChProfile => _get('Profile', 'پروفائل', 'الملف الشخصي',
        'प्रोफ़ाइल',
        'Profil',
        'Perfil',
        'Perfil',
        'Profil',
        'Profil',
        'Profil',
        'প্রোফাইল'
      );
  String get tutChThanks => _get('Thank You', 'شکریہ', 'شكراً لك',
        'धन्यवाद',
        'Merci',
        'Gracias',
        'Obrigado',
        'Danke',
        'Teşekkürler',
        'Terima kasih',
        'ধন্যবাদ'
      );

  // Profile editing
  String get nameLabel => _get('Name', 'نام', 'الاسم',
        'नाम',
        'Nom',
        'Nombre',
        'Nome',
        'Name',
        'Ad',
        'Nama',
        'নাম'
      );
  String get profileUpdated => _get(
        'Profile updated.',
        'پروفائل اپ ڈیٹ ہو گئی۔',
        'تم تحديث الملف الشخصي.',
      
        'प्रोफ़ाइल अपडेट हो गई।',
        'Profil mis à jour.',
        'Perfil actualizado.',
        'Perfil atualizado.',
        'Profil aktualisiert.',
        'Profil güncellendi.',
        'Profil diperbarui.',
        'প্রোফাইল আপডেট হয়েছে।'
      );

  // Billing (read-only catalog display)
  String get currentPlan =>
      _get('Current plan', 'موجودہ پلان', 'الخطة الحالية',
        'वर्तमान प्लान',
        'Offre actuelle',
        'Plan actual',
        'Plano atual',
        'Aktueller Plan',
        'Mevcut plan',
        'Paket saat ini',
        'বর্তমান প্ল্যান'
      );
  String get plansTitle => _get('Plans', 'پلانز', 'الخطط',
        'प्लान',
        'Offres',
        'Planes',
        'Planos',
        'Pläne',
        'Planlar',
        'Paket',
        'প্ল্যান'
      );
  String get creditPacksTitle =>
      _get('Credit packs', 'کریڈٹ پیکس', 'حزم الاعتمادات',
        'क्रेडिट पैक',
        'Packs de crédits',
        'Paquetes de créditos',
        'Pacotes de créditos',
        'Credit-Pakete',
        'Kredi paketleri',
        'Paket kredit',
        'ক্রেডিট প্যাক'
      );
  String get acceptedPayments =>
      _get('Accepted payments', 'قبول شدہ ادائیگی', 'المدفوعات المقبولة',
        'स्वीकार किए जाने वाले भुगतान',
        'Paiements acceptés',
        'Pagos aceptados',
        'Pagamentos aceitos',
        'Akzeptierte Zahlungsmethoden',
        'Kabul edilen ödemeler',
        'Pembayaran yang diterima',
        'গৃহীত পেমেন্ট'
      );
  String get paymentsNote => _get(
        'PayPal, Payoneer, Google Pay only — all payments are verified server-side.',
        'صرف PayPal، Payoneer، Google Pay — تمام ادائیگیاں سرور پر تصدیق ہوتی ہیں۔',
        'PayPal وPayoneer وGoogle Pay فقط — تُتحقق جميع المدفوعات من الخادم.',
      
        'केवल PayPal, Payoneer, Google Pay — सभी भुगतान सर्वर पर सत्यापित होते हैं।',
        'PayPal, Payoneer, Google Pay uniquement — tous les paiements sont vérifiés côté serveur.',
        'Solo PayPal, Payoneer y Google Pay: todos los pagos se verifican en el servidor.',
        'Somente PayPal, Payoneer e Google Pay — todos os pagamentos são verificados no servidor.',
        'Nur PayPal, Payoneer, Google Pay — alle Zahlungen werden serverseitig verifiziert.',
        'Yalnızca PayPal, Payoneer, Google Pay — tüm ödemeler sunucu tarafında doğrulanır.',
        'Hanya PayPal, Payoneer, Google Pay — semua pembayaran diverifikasi di sisi server.',
        'শুধুমাত্র PayPal, Payoneer, Google Pay — সমস্ত পেমেন্ট সার্ভার-সাইড যাচাই করা হয়।'
      );
  String aiCreditsMonth(int n) => _get(
        '$n AI credits / month',
        '$n AI کریڈٹس / ماہ',
        '$n من اعتمادات الذكاء الاصطناعي / شهر',
      
        '$n AI क्रेडिट / माह',
        '$n crédits IA / mois',
        '$n créditos IA / mes',
        '$n créditos IA / mês',
        '$n KI-Credits / Monat',
        '$n YZ kredisi / ay',
        '$n kredit AI / bulan',
        '$n AI ক্রেডিট / মাস'
      );
  String campaignsAllowed(int n) =>
      _get('$n campaigns allowed', '$n مہمات کی اجازت', '$n حملات مسموحة',
        '$n अभियान अनुमत',
        '$n campagnes autorisées',
        '$n campañas permitidas',
        '$n campanhas permitidas',
        '$n Kampagnen erlaubt',
        '$n kampanyaya izin verilir',
        '$n kampanye diizinkan',
        '$nটি ক্যাম্পেইন অনুমোদিত'
      );
  String get perMonth => _get('/month', '/ماہ', '/شهر',
        '/माह',
        '/mois',
        '/mes',
        '/mês',
        '/Monat',
        '/ay',
        '/bulan',
        '/মাস'
      );
  String get creditsUnit => _get('credits', 'کریڈٹس', 'اعتمادات',
        'क्रेडिट',
        'crédits',
        'créditos',
        'créditos',
        'Credits',
        'kredi',
        'kredit',
        'ক্রেডিট'
      );

  // AI Support chat
  String get supportAutomatedNote => _get(
        'You\'re chatting with Virello\'s automated support assistant — answers are generated, not from a human agent.',
        'آپ وائرلو کے خودکار معاونت اسسٹنٹ سے بات کر رہے ہیں — جوابات تیار کردہ ہیں، کسی انسانی ایجنٹ کے نہیں۔',
        'أنت تتحدث مع مساعد دعم Virello الآلي — الإجابات مُولَّدة، وليست من وكيل بشري.',
      
        'आप Virello के स्वचालित सहायता सहायक से चैट कर रहे हैं — उत्तर जनरेट किए जाते हैं, किसी मानव एजेंट से नहीं आते।',
        'Vous discutez avec l\'assistant d\'aide automatisé de Virello — les réponses sont générées, pas rédigées par un agent humain.',
        'Estás chateando con el asistente de soporte automatizado de Virello: las respuestas son generadas, no de un agente humano.',
        'Você está conversando com o assistente de suporte automatizado do Virello — as respostas são geradas, não vêm de um agente humano.',
        'Du chattest mit dem automatisierten Support-Assistenten von Virello — die Antworten werden generiert, nicht von einem menschlichen Agenten geschrieben.',
        'Virello\'nun otomatik destek asistanıyla sohbet ediyorsun — yanıtlar üretilir, bir insan temsilciden gelmez.',
        'Kamu mengobrol dengan asisten dukungan otomatis Virello — jawaban dibuat secara otomatis, bukan dari agen manusia.',
        'আপনি Virello-এর স্বয়ংক্রিয় সাপোর্ট সহকারীর সাথে চ্যাট করছেন — উত্তরগুলো জেনারেট করা, কোনো মানব এজেন্টের নয়।'
      );
  String get askQuestionHint =>
      _get('Ask a question…', 'سوال پوچھیں…', 'اطرح سؤالاً…',
        'कोई सवाल पूछें…',
        'Posez une question…',
        'Haz una pregunta…',
        'Faça uma pergunta…',
        'Frage stellen…',
        'Bir soru sor…',
        'Ajukan pertanyaan…',
        'একটি প্রশ্ন জিজ্ঞাসা করুন…'
      );
  String get supportWelcome => _get(
        'Hi! I\'m Virello\'s support assistant. Ask me anything about plans, campaigns, or features.',
        'سلام! میں وائرلو کا معاونت اسسٹنٹ ہوں۔ پلانز، مہمات یا فیچرز کے بارے میں کچھ بھی پوچھیں۔',
        'مرحباً! أنا مساعد دعم Virello. اسألني أي شيء عن الخطط أو الحملات أو الميزات.',
      
        'नमस्ते! मैं Virello का सहायता सहायक हूँ। प्लान, अभियान या फ़ीचर्स के बारे में कुछ भी पूछें।',
        'Salut ! Je suis l\'assistant d\'aide de Virello. Posez-moi vos questions sur les offres, les campagnes ou les fonctionnalités.',
        '¡Hola! Soy el asistente de soporte de Virello. Pregúntame lo que quieras sobre planes, campañas o funciones.',
        'Olá! Sou o assistente de suporte do Virello. Pergunte qualquer coisa sobre planos, campanhas ou recursos.',
        'Hi! Ich bin der Support-Assistent von Virello. Frag mich alles zu Plänen, Kampagnen oder Funktionen.',
        'Merhaba! Ben Virello\'nun destek asistanıyım. Planlar, kampanyalar veya özellikler hakkında her şeyi sorabilirsin.',
        'Hai! Saya asisten dukungan Virello. Tanyakan apa saja tentang paket, kampanye, atau fitur.',
        'হাই! আমি Virello-এর সাপোর্ট সহকারী। প্ল্যান, ক্যাম্পেইন বা ফিচার সম্পর্কে যেকোনো কিছু জিজ্ঞাসা করুন।'
      );

  // Live Chat Support
  String get liveChatSupport => _get(
        'Live Chat Support',
        'لائیو چیٹ سپورٹ',
        'دعم الدردشة المباشرة',
      );
  String get onlineNow => _get(
        'Online',
        'آن لائن',
        'متصل الآن',
      );
  String get supportCaption => _get(
        'Typically replies in seconds',
        'عام طور پر چند سیکنڈ میں جواب دیتا ہے',
        'يرد عادة خلال ثوانٍ',
      );
  String get typingDots => _get(
        'typing…',
        'لکھ رہا ہے…',
        'يكتب…',
      );
  String get ticketCreatedNote => _get(
        'Your ticket has been created. Our team will follow up soon.',
        'آپ کی ٹکٹ بنا دی گئی ہے۔ ہماری ٹیم جلد رابطہ کرے گی۔',
        'تم إنشاء تذكرتك. سيتواصل معك فريقنا قريباً.',
      );

  // Following
  String get followingEmpty => _get(
        'You\'re not following anyone yet — follow creators to see them here.',
        'آپ ابھی کسی کو فالو نہیں کر رہے — تخلیق کاروں کو فالو کریں تاکہ وہ یہاں نظر آئیں۔',
        'أنت لا تتابع أحداً بعد — تابع المبدعين لرؤيتهم هنا.',
      
        'आप अभी किसी को फ़ॉलो नहीं कर रहे हैं — क्रिएटर्स को फ़ॉलो करें ताकि वे यहाँ दिखें।',
        'Vous ne suivez personne pour le moment — suivez des créateurs pour les voir ici.',
        'Aún no sigues a nadie: sigue a creadores para verlos aquí.',
        'Você ainda não segue ninguém — siga criadores para vê-los aqui.',
        'Du folgst noch niemandem — folge Creatorn, um sie hier zu sehen.',
        'Henüz kimseyi takip etmiyorsun — onları burada görmek için üreticileri takip et.',
        'Kamu belum mengikuti siapa pun — ikuti kreator agar mereka muncul di sini.',
        'আপনি এখনও কাউকে ফলো করছেন না — এখানে দেখতে ক্রিয়েটরদের ফলো করুন।'
      );
  String get followCreatorTitle =>
      _get('Follow a creator', 'تخلیق کار فالو کریں', 'تابع مبدعاً',
        'किसी क्रिएटर को फ़ॉलो करें',
        'Suivre un créateur',
        'Seguir a un creador',
        'Seguir um criador',
        'Einem Creator folgen',
        'Bir üreticiyi takip et',
        'Ikuti kreator',
        'একজন ক্রিয়েটরকে ফলো করুন'
      );
  String get creatorHandleLabel =>
      _get('Creator handle', 'تخلیق کار کا ہینڈل', 'اسم المبدع',
        'क्रिएटर हैंडल',
        'Pseudo du créateur',
        'Nombre de usuario del creador',
        'Nome de usuário do criador',
        'Creator-Handle',
        'Üretici kullanıcı adı',
        'Nama pengguna kreator',
        'ক্রিয়েটর হ্যান্ডেল'
      );
  String get creatorNameLabel => _get(
        'Display name (optional)',
        'نام (اختیاری)',
        'الاسم المعروض (اختياري)',
      
        'डिस्प्ले नाम (वैकल्पिक)',
        'Nom affiché (facultatif)',
        'Nombre visible (opcional)',
        'Nome de exibição (opcional)',
        'Anzeigename (optional)',
        'Görünen ad (isteğe bağlı)',
        'Nama tampilan (opsional)',
        'প্রদর্শন নাম (ঐচ্ছিক)'
      );
  String get followBtn => _get('Follow', 'فالو کریں', 'تابع',
        'फ़ॉलो करें',
        'Suivre',
        'Seguir',
        'Seguir',
        'Folgen',
        'Takip Et',
        'Ikuti',
        'ফলো করুন'
      );
  String get unfollowBtn => _get('Unfollow', 'ان فالو کریں', 'إلغاء المتابعة',
        'अनफ़ॉलो करें',
        'Ne plus suivre',
        'Dejar de seguir',
        'Deixar de seguir',
        'Entfolgen',
        'Takibi Bırak',
        'Berhenti mengikuti',
        'আনফলো করুন'
      );
  String get followingTab => _get('Following', 'فالونگ', 'يتابع',
        'फ़ॉलोइंग',
        'Abonnements',
        'Siguiendo',
        'Seguindo',
        'Abonnements',
        'Takip Edilenler',
        'Mengikuti',
        'ফলোয়িং'
      );

  // Analytics
  String get noAnalyticsYet => _get(
        'No analytics yet — launch a campaign and real numbers will appear here.',
        'ابھی کوئی تجزیات نہیں — مہم لانچ کریں تو حقیقی اعداد یہاں نظر آئیں گے۔',
        'لا تحليلات بعد — أطلق حملة وستظهر الأرقام الحقيقية هنا.',
      
        'अभी कोई विश्लेषण नहीं — अभियान शुरू करें और असली आंकड़े यहाँ दिखेंगे।',
        'Pas encore d\'analyses — lancez une campagne et les vrais chiffres apparaîtront ici.',
        'Aún no hay analíticas: lanza una campaña y los números reales aparecerán aquí.',
        'Sem análises ainda — lance uma campanha e os números reais aparecerão aqui.',
        'Noch keine Analysen — starte eine Kampagne und echte Zahlen erscheinen hier.',
        'Henüz analiz yok — bir kampanya başlat, gerçek sayılar burada görünecek.',
        'Belum ada analitik — luncurkan kampanye dan angka sebenarnya akan muncul di sini.',
        'এখনও কোনো বিশ্লেষণ নেই — একটি ক্যাম্পেইন চালু করুন এবং আসল সংখ্যা এখানে দেখা যাবে।'
      );
  String get dailyBreakdownNote => _get(
        'Daily breakdown appears once today\'s data is recorded.',
        'آج کا ڈیٹا ریکارڈ ہوتے ہی روزانہ کی تفصیل یہاں نظر آئے گی۔',
        'يظهر التفصيل اليومي فور تسجيل بيانات اليوم.',
      
        'आज का डेटा रिकॉर्ड होते ही दैनिक विवरण यहाँ दिखेगा।',
        'Le récapitulatif quotidien s\'affiche dès que les données du jour sont enregistrées.',
        'El desglose diario aparecerá cuando se registren los datos de hoy.',
        'O resumo diário aparece quando os dados de hoje forem registrados.',
        'Die Tagesaufschlüsselung erscheint, sobald die Daten von heute erfasst sind.',
        'Günlük döküm, bugünün verileri kaydedilince görünür.',
        'Rincian harian muncul setelah data hari ini tercatat.',
        'আজকের ডেটা রেকর্ড হলেই দৈনিক বিবরণ দেখা যাবে।'
      );
  String get dailyReachTitle =>
      _get('Daily reach', 'روزانہ رسائی', 'الوصول اليومي',
        'दैनिक रीच',
        'Portée quotidienne',
        'Alcance diario',
        'Alcance diário',
        'Tägliche Reichweite',
        'Günlük erişim',
        'Jangkauan harian',
        'দৈনিক রিচ'
      );

  // Upload context carried forward
  String get attachedMedia =>
      _get('Attached media', 'منسلک میڈیا', 'الوسائط المرفقة',
        'संलग्न मीडिया',
        'Média joint',
        'Contenido adjunto',
        'Mídia anexada',
        'Angehängte Medien',
        'Ekli medya',
        'Media terlampir',
        'সংযুক্ত মিডিয়া'
      );

  // In-app post reader
  String get readerAiSummary => _get(
        'AI summary · automated preview',
        'AI خلاصہ · خودکار پیش نظارہ',
        'ملخص الذكاء الاصطناعي · معاينة تلقائية',
      
        'AI सारांश · स्वचालित पूर्वावलोकन',
        'Résumé IA · aperçu automatique',
        'Resumen IA · vista previa automática',
        'Resumo IA · prévia automática',
        'KI-Zusammenfassung · automatische Vorschau',
        'YZ özeti · otomatik önizleme',
        'Ringkasan AI · pratinjau otomatis',
        'AI সারসংক্ষেপ · স্বয়ংক্রিয় প্রিভিউ'
      );
  String get readerKeyPoints =>
      _get('Key points', 'اہم نکات', 'النقاط الرئيسية',
        'मुख्य बिंदु',
        'Points clés',
        'Puntos clave',
        'Pontos principais',
        'Kernpunkte',
        'Önemli noktalar',
        'Poin penting',
        'মূল পয়েন্ট'
      );
  String get readerExcerpt =>
      _get('Excerpt from the original', 'اصل سے اقتباس', 'مقتطف من الأصل',
        'मूल से उद्धरण',
        'Extrait de l\'original',
        'Fragmento del original',
        'Trecho do original',
        'Auszug aus dem Original',
        'Orijinalden alıntı',
        'Kutipan dari aslinya',
        'মূল থেকে উদ্ধৃতি'
      );
  String get readerWhyPicked => _get(
        'Why this was picked for you',
        'یہ آپ کے لیے کیوں چنا گیا',
        'لماذا تم اختيار هذا لك',
      
        'यह आपके लिए क्यों चुना गया',
        'Pourquoi ceci vous a été proposé',
        'Por qué se eligió esto para ti',
        'Por que isto foi escolhido para você',
        'Warum dir das vorgeschlagen wurde',
        'Bu senin için neden seçildi',
        'Mengapa ini dipilih untukmu',
        'এটি আপনার জন্য কেন বাছাই করা হয়েছে'
      );
  String get readerAnalyzeWithAI =>
      _get('Analyze with AI', 'AI سے تجزیہ کریں', 'حلّل بالذكاء الاصطناعي',
        'AI से विश्लेषण करें',
        'Analyser avec l\'IA',
        'Analizar con IA',
        'Analisar com IA',
        'Mit KI analysieren',
        'YZ ile analiz et',
        'Analisis dengan AI',
        'AI দিয়ে বিশ্লেষণ করুন'
      );
  String get readerFindAudience =>
      _get('Find Audience', 'آڈینس تلاش کریں', 'اعثر على الجمهور',
        'ऑडियंस खोजें',
        'Trouver l\'audience',
        'Encontrar audiencia',
        'Encontrar público',
        'Zielgruppe finden',
        'Kitleyi bul',
        'Temukan audiens',
        'অডিয়েন্স খুঁজুন'
      );
  String get readerReadOriginal => _get(
        'Read original ↗ · opens in browser',
        'اصل پڑھیں ↗ · براؤزر میں کھلے گا',
        'اقرأ الأصل ↗ · يفتح في المتصفح',
      
        'मूल पढ़ें ↗ · ब्राउज़र में खुलेगा',
        'Lire l\'original ↗ · s\'ouvre dans le navigateur',
        'Leer el original ↗ · se abre en el navegador',
        'Ler o original ↗ · abre no navegador',
        'Original lesen ↗ · öffnet im Browser',
        'Orijinali oku ↗ · tarayıcıda açılır',
        'Baca aslinya ↗ · terbuka di browser',
        'মূল পড়ুন ↗ · ব্রাউজারে খুলবে'
      );
  String get readerRetry => _get('Retry', 'دوبارہ کوشش کریں', 'إعادة المحاولة',
        'पुनः प्रयास करें',
        'Réessayer',
        'Reintentar',
        'Tentar novamente',
        'Erneut versuchen',
        'Tekrar Dene',
        'Coba lagi',
        'আবার চেষ্টা করুন'
      );
  String get readerLoadError => _get(
        'Could not load a preview for this post. Check your connection and try again.',
        'اس پوسٹ کا پیش نظارہ لوڈ نہیں ہو سکا۔ اپنا کنکشن چیک کریں اور دوبارہ کوشش کریں۔',
        'تعذّر تحميل معاينة لهذا المنشور. تحقق من الاتصال وحاول مجددًا.',
      
        'इस पोस्ट का पूर्वावलोकन लोड नहीं हो सका। अपना कनेक्शन जाँचें और फिर कोशिश करें।',
        'Impossible de charger l\'aperçu de cette publication. Vérifiez votre connexion et réessayez.',
        'No se pudo cargar la vista previa de esta publicación. Revisa tu conexión e inténtalo de nuevo.',
        'Não foi possível carregar a prévia desta publicação. Verifique sua conexão e tente novamente.',
        'Die Vorschau für diesen Post konnte nicht geladen werden. Prüfe deine Verbindung und versuch es erneut.',
        'Bu gönderinin önizlemesi yüklenemedi. Bağlantını kontrol et ve tekrar dene.',
        'Tidak dapat memuat pratinjau postingan ini. Periksa koneksimu dan coba lagi.',
        'এই পোস্টের প্রিভিউ লোড করা যায়নি। আপনার সংযোগ পরীক্ষা করে আবার চেষ্টা করুন।'
      );
  String get readerNoPreview => _get(
        'No preview available for this link yet.',
        'اس لنک کا پیش نظارہ ابھی دستیاب نہیں۔',
        'لا تتوفر معاينة لهذا الرابط بعد.',
      
        'इस लिंक के लिए अभी कोई पूर्वावलोकन उपलब्ध नहीं है।',
        'Aucun aperçu disponible pour ce lien pour le moment.',
        'Aún no hay vista previa disponible para este enlace.',
        'Nenhuma prévia disponível para este link ainda.',
        'Für diesen Link gibt es noch keine Vorschau.',
        'Bu bağlantı için henüz önizleme yok.',
        'Belum ada pratinjau untuk tautan ini.',
        'এই লিঙ্কের জন্য এখনও কোনো প্রিভিউ উপলব্ধ নেই।'
      );
  String get readerVia => _get('via', 'بذریعہ', 'عبر',
        'द्वारा',
        'via',
        'vía',
        'via',
        'über',
        'üzerinden',
        'via',
        'মাধ্যমে'
      );
  String get readerSave => _get('Save', 'محفوظ کریں', 'احفظ',
        'सेव करें',
        'Enregistrer',
        'Guardar',
        'Salvar',
        'Speichern',
        'Kaydet',
        'Simpan',
        'সেভ করুন'
      );
  String get readerSaved => _get('Saved', 'محفوظ شدہ', 'محفوظ',
        'सेव हो गया',
        'Enregistré',
        'Guardado',
        'Salvo',
        'Gespeichert',
        'Kaydedildi',
        'Tersimpan',
        'সেভ হয়েছে'
      );
  String get readerAutomatedNote => _get(
        'Transformed preview: short excerpt + automated summary. Full text stays on the original page.',
        'تبدیل شدہ پیش نظارہ: مختصر اقتباس + خودکار خلاصہ۔ مکمل متن اصل صفحے پر رہتا ہے۔',
        'معاينة مُحوَّلة: مقتطف قصير + ملخص تلقائي. يبقى النص الكامل على الصفحة الأصلية.',
      
        'बदला हुआ पूर्वावलोकन: छोटा उद्धरण + स्वचालित सारांश। पूरा पाठ मूल पृष्ठ पर ही रहता है।',
        'Aperçu transformé : court extrait + résumé automatique. Le texte complet reste sur la page d\'origine.',
        'Vista previa transformada: fragmento breve + resumen automático. El texto completo queda en la página original.',
        'Prévia transformada: trecho curto + resumo automático. O texto completo fica na página original.',
        'Umgewandelte Vorschau: kurzer Auszug + automatische Zusammenfassung. Der Volltext bleibt auf der Originalseite.',
        'Dönüştürülmüş önizleme: kısa alıntı + otomatik özet. Tam metin orijinal sayfada kalır.',
        'Pratinjau yang diubah: kutipan singkat + ringkasan otomatis. Teks lengkap tetap di halaman aslinya.',
        'রূপান্তরিত প্রিভিউ: সংক্ষিপ্ত উদ্ধৃতি + স্বয়ংক্রিয় সারসংক্ষেপ। সম্পূর্ণ পাঠ মূল পৃষ্ঠাতেই থাকবে।'
      );

  // Free Growth Tools (Create hub section).
  String get freeGrowthTools =>
      _get('Free Growth Tools', 'مفت گروتھ ٹولز', 'أدوات النمو المجانية',
        'मुफ़्त ग्रोथ टूल',
        'Outils de croissance gratuits',
        'Herramientas de crecimiento gratuitas',
        'Ferramentas de crescimento grátis',
        'Kostenlose Wachstumstools',
        'Ücretsiz Büyüme Araçları',
        'Alat Pertumbuhan Gratis',
        'ফ্রি গ্রোথ টুল'
      );
  String get toolTransform =>
      _get('Link → Native Posts', 'لنک ← نیٹو پوسٹس', 'الرابط ← منشورات أصلية',
        'लिंक → नेटिव पोस्ट',
        'Lien → publications natives',
        'Enlace → publicaciones nativas',
        'Link → publicações nativas',
        'Link → native Posts',
        'Bağlantı → Yerel Gönderiler',
        'Tautan → Postingan Native',
        'লিঙ্ক → নেটিভ পোস্ট'
      );
  String get toolTransformDesc => _get(
        'Turn any link into native video scripts, carousels & threads',
        'کسی بھی لنک کو نیٹو ویڈیو اسکرپٹ، کیروسل اور تھریڈز میں بدلیں',
        'حوِّل أي رابط إلى نصوص فيديو ومنشورات أصلية',
      
        'किसी भी लिंक को नेटिव वीडियो स्क्रिप्ट, कैरोसेल और थ्रेड में बदलें',
        'Transformez n\'importe quel lien en scripts vidéo, carrousels et fils natifs',
        'Convierte cualquier enlace en guiones de video, carruseles e hilos nativos',
        'Transforme qualquer link em roteiros de vídeo, carrosséis e threads nativos',
        'Verwandle jeden Link in native Videoskripte, Karussells & Threads',
        'Herhangi bir bağlantıyı yerel video senaryolarına, karusellere ve dizilere dönüştür',
        'Ubah tautan apa pun menjadi skrip video, carousel & thread native',
        'যেকোনো লিঙ্ককে নেটিভ ভিডিও স্ক্রিপ্ট, ক্যারোসেল ও থ্রেডে রূপান্তর করুন'
      );
  String get toolCtrAudit =>
      _get('Link CTR Check', 'لنک CTR چیک', 'فحص CTR للرابط',
        'लिंक CTR जाँच',
        'Vérification du CTR du lien',
        'Revisión del CTR del enlace',
        'Verificação de CTR do link',
        'Link-CTR-Check',
        'Bağlantı TO Kontrolü',
        'Cek CTR Tautan',
        'লিঙ্ক CTR চেক'
      );
  String get toolCtrAuditDesc => _get(
        'Audit your link preview: title, image & social cards',
        'اپنے لنک پریویو کا آڈٹ: عنوان، تصویر اور سوشل کارڈز',
        'دقّق معاينة رابطك: العنوان والصورة والبطاقات',
      
        'अपने लिंक पूर्वावलोकन का ऑडिट करें: शीर्षक, चित्र और सोशल कार्ड',
        'Auditez l\'aperçu de votre lien : titre, image et cartes sociales',
        'Audita la vista previa de tu enlace: título, imagen y tarjetas sociales',
        'Audite a prévia do seu link: título, imagem e cartões sociais',
        'Prüfe deine Link-Vorschau: Titel, Bild & Social Cards',
        'Bağlantı önizlemeni denetle: başlık, görsel ve sosyal kartlar',
        'Audit pratinjau tautanmu: judul, gambar & kartu sosial',
        'আপনার লিঙ্ক প্রিভিউ অডিট করুন: শিরোনাম, ছবি ও সোশ্যাল কার্ড'
      );
  String get toolSeeding =>
      _get('Community Seeding', 'کمیونٹی سیڈنگ', 'النشر المجتمعي',
        'कम्युनिटी सीडिंग',
        'Diffusion communautaire',
        'Siembra en comunidades',
        'Semeadura em comunidades',
        'Community-Seeding',
        'Topluluk Yayılımı',
        'Penyemaian Komunitas',
        'কমিউনিটি সিডিং'
      );
  String get toolSeedingDesc => _get(
        'AI-matched communities + tailored drafts you post yourself',
        'AI سے میچ شدہ کمیونٹیز + ڈرافٹس جو آپ خود پوسٹ کریں',
        'مجتمعات مطابقة بالذكاء الاصطناعي + مسودات تنشرها بنفسك',
      
        'AI से मिले कम्युनिटी + आपके लिए तैयार ड्राफ्ट, जिन्हें आप खुद पोस्ट करें',
        'Communautés appariées par l\'IA + brouillons sur mesure que vous publiez vous-même',
        'Comunidades emparejadas por IA + borradores a medida que publicas tú mismo',
        'Comunidades combinadas por IA + rascunhos personalizados que você publica',
        'KI-gematchte Communities + maßgeschneiderte Entwürfe, die du selbst postest',
        'YZ ile eşleşen topluluklar + kendin paylaşacağın özel taslaklar',
        'Komunitas yang dicocokkan AI + draf khusus yang kamu posting sendiri',
        'AI-মিলানো কমিউনিটি + আপনার জন্য তৈরি ড্রাফ্ট, যা আপনি নিজে পোস্ট করবেন'
      );
  String get toolCollab =>
      _get('Creator Collabs', 'کریئیٹر تعاون', 'تعاون المبدعين',
        'क्रिएटर कोलैब',
        'Collabs créateurs',
        'Colaboraciones de creadores',
        'Colaborações de criadores',
        'Creator-Collabs',
        'Üretici İş Birlikleri',
        'Kolaborasi Kreator',
        'ক্রিয়েটর কোলাব'
      );
  String get toolCollabDesc => _get(
        'Find creators whose audience fits your content',
        'ایسے کریئیٹرز تلاش کریں جن کی آڈینس آپ کے مواد سے میل کھائے',
        'اعثر على مبدعين يناسب جمهورهم محتواك',
      
        'ऐसे क्रिएटर खोजें जिनकी ऑडियंस आपके कंटेंट से मेल खाए',
        'Trouvez des créateurs dont l\'audience correspond à votre contenu',
        'Encuentra creadores cuya audiencia encaje con tu contenido',
        'Encontre criadores cujo público combine com seu conteúdo',
        'Finde Creator, deren Zielgruppe zu deinem Content passt',
        'Kitlesi içeriğine uygun üreticileri bul',
        'Temukan kreator yang audiensnya cocok dengan kontenmu',
        'এমন ক্রিয়েটর খুঁজুন যাদের অডিয়েন্স আপনার কনটেন্টের সাথে মানানসই'
      );
  String get toolReferral => _get(
        'Refer & Earn Credits',
        'ریفر کریں، کریڈٹ کمائیں',
        'أحِل واكسب رصيدًا',
      
        'रेफ़र करें और क्रेडिट कमाएँ',
        'Parrainez et gagnez des crédits',
        'Refiere y gana créditos',
        'Indique e ganhe créditos',
        'Werben & Credits verdienen',
        'Davet Et ve Kredi Kazan',
        'Rujuk & Dapatkan Kredit',
        'রেফার করুন ও ক্রেডিট আয় করুন'
      );
  String get toolReferralDesc => _get(
        'Share your link — you both earn AI credits on signup',
        'اپنا لنک شیئر کریں — سائن اپ پر دونوں کو AI کریڈٹ',
        'شارك رابطك — تكسبان رصيد ذكاء اصطناعي عند التسجيل',
      
        'अपना लिंक शेयर करें — साइनअप पर आप दोनों को AI क्रेडिट मिलेंगे',
        'Partagez votre lien — vous gagnez tous les deux des crédits IA à l\'inscription',
        'Comparte tu enlace: ambos ganan créditos IA al registrarse',
        'Compartilhe seu link — vocês dois ganham créditos IA no cadastro',
        'Teile deinen Link — ihr erhaltet beide KI-Credits bei der Anmeldung',
        'Bağlantını paylaş — kaydolunca ikiniz de YZ kredisi kazanırsınız',
        'Bagikan tautanmu — kalian berdua dapat kredit AI saat mendaftar',
        'আপনার লিঙ্ক শেয়ার করুন — সাইনআপে আপনারা দুজনেই AI ক্রেডিট পাবেন'
      );
  String get toolLinkCards =>
      _get('Link Cards in Discovery', 'ڈسکوری میں لنک کارڈز', 'بطاقات الروابط',
        'डिस्कवरी में लिंक कार्ड',
        'Cartes de liens dans Découverte',
        'Tarjetas de enlace en Descubrir',
        'Cartões de link no Descobrir',
        'Link-Cards in Entdecken',
        'Keşfet\'te Bağlantı Kartları',
        'Kartu Tautan di Temukan',
        'ডিসকভারে লিঙ্ক কার্ড'
      );
  String get toolLinkCardsDesc => _get(
        'Your links render as rich native cards in the feed',
        'آپ کے لنکس فیڈ میں خوبصورت نیٹو کارڈز بن کر دکھیں',
        'تظهر روابطك كبطاقات أصلية غنية في الموجز',
      
        'आपके लिंक फ़ीड में शानदार नेटिव कार्ड के रूप में दिखेंगे',
        'Vos liens s\'affichent comme de belles cartes natives dans le fil',
        'Tus enlaces se muestran como tarjetas nativas enriquecidas en el feed',
        'Seus links aparecem como cartões nativos ricos no feed',
        'Deine Links erscheinen als hochwertige native Cards im Feed',
        'Bağlantıların akışta zengin yerel kartlar olarak görünür',
        'Tautanmu tampil sebagai kartu native yang kaya di feed',
        'আপনার লিঙ্কগুলো ফিডে সমৃদ্ধ নেটিভ কার্ড হিসেবে দেখা যাবে'
      );

  // ------------------------------ Ask Virello (Phase 1) ------------------------------
  String get askVirello =>
      _get('Ask Virello', 'وائریلو سے پوچھیں', 'اسأل فيريلو',
        'Virello से पूछें',
        'Demander à Virello',
        'Preguntar a Virello',
        'Perguntar ao Virello',
        'Virello fragen',
        'Virello\'ya Sor',
        'Tanya Virello',
        'Virello-কে জিজ্ঞাসা করুন'
      );
  String get askVirelloHint => _get(
        'Ask anything — create, grow, sell, learn…',
        'کچھ بھی پوچھیں — بنائیں، بڑھائیں، بیچیں، سیکھیں…',
        'اسأل أي شيء — أنشئ، نمِّ، بِع، تعلَّم…',
      
        'कुछ भी पूछें — बनाएँ, ग्रो करें, बेचें, सीखें…',
        'Demandez tout — créez, développez, vendez, apprenez…',
        'Pregunta lo que sea: crea, crece, vende, aprende…',
        'Pergunte qualquer coisa — crie, cresça, venda, aprenda…',
        'Frag alles — erstellen, wachsen, verkaufen, lernen…',
        'Her şeyi sor — oluştur, büyüt, sat, öğren…',
        'Tanyakan apa saja — buat, kembangkan, jual, pelajari…',
        'যেকোনো কিছু জিজ্ঞাসা করুন — তৈরি করুন, গ্রো করুন, বিক্রি করুন, শিখুন…'
      );
  String get askVirelloWelcome => _get(
        'Hi! I\'m Virello, your AI assistant. Just tell me what you want — "create a video", "grow this post", "sell this product" — and I\'ll route it to the right tool.',
        'ہیلو! میں وائریلو ہوں، آپ کا AI اسسٹنٹ۔ بس بتائیں کیا چاہیے — "ویڈیو بنائیں"، "یہ پوسٹ بڑھائیں"، "یہ پروڈکٹ بیچیں" — میں صحیح ٹول تک پہنچا دوں گا۔',
        'مرحبًا! أنا فيريلو، مساعدك الذكي. أخبرني فقط بما تريد — "أنشئ فيديو"، "نمِّ هذا المنشور"، "بِع هذا المنتج" — وسأوجّهك إلى الأداة المناسبة.',
      
        'नमस्ते! मैं Virello हूँ, आपका AI सहायक। बस बताएँ आपको क्या चाहिए — «वीडियो बनाएँ», «इस पोस्ट को ग्रो करें», «यह प्रोडक्ट बेचें» — और मैं आपको सही टूल तक पहुँचा दूँगा।',
        'Salut ! Je suis Virello, votre assistant IA. Dites-moi simplement ce que vous voulez — « créer une vidéo », « développer cette publication », « vendre ce produit » — et je vous dirigerai vers le bon outil.',
        '¡Hola! Soy Virello, tu asistente IA. Solo dime qué quieres: «crear un video», «impulsar esta publicación», «vender este producto», y te dirigiré a la herramienta adecuada.',
        'Olá! Eu sou o Virello, seu assistente IA. Diga apenas o que você quer — «criar um vídeo», «impulsionar esta publicação», «vender este produto» — e eu te direciono à ferramenta certa.',
        'Hi! Ich bin Virello, dein KI-Assistent. Sag mir einfach, was du willst — „Video erstellen“, „diesen Post pushen“, „dieses Produkt verkaufen“ — und ich leite dich zum richtigen Tool.',
        'Merhaba! Ben Virello, YZ asistanın. Ne istediğini söylemen yeterli — «video oluştur», «bu gönderiyi büyüt», «bu ürünü sat» — seni doğru araca yönlendireyim.',
        'Hai! Saya Virello, asisten AI-mu. Katakan saja maumu — «buat video», «kembangkan postingan ini», «jual produk ini» — dan saya akan mengarahkanmu ke alat yang tepat.',
        'হাই! আমি Virello, আপনার AI সহকারী। শুধু বলুন কী চান — «ভিডিও তৈরি করুন», «এই পোস্টটি গ্রো করুন», «এই পণ্যটি বিক্রি করুন» — আমি আপনাকে সঠিক টুলে নিয়ে যাব।'
      );
  String get newChat => _get('New chat', 'نئی چیٹ', 'محادثة جديدة',
        'नई चैट',
        'Nouvelle discussion',
        'Nuevo chat',
        'Nova conversa',
        'Neuer Chat',
        'Yeni sohbet',
        'Chat baru',
        'নতুন চ্যাট'
      );
  String get devPreviewNote => _get(
        'Development preview — heuristic output',
        'ڈیولپمنٹ پیش نظارہ — ہیورسٹک آؤٹ پٹ',
        'معاينة تطويرية — مخرجات استكشافية',
      
        'विकास पूर्वावलोकन — ह्यूरिस्टिक आउटपुट',
        'Aperçu de développement — résultat heuristique',
        'Vista previa de desarrollo: resultado heurístico',
        'Prévia de desenvolvimento — saída heurística',
        'Entwicklungsvorschau — heuristische Ausgabe',
        'Geliştirme önizlemesi — sezgisel çıktı',
        'Pratinjau pengembangan — keluaran heuristik',
        'ডেভেলপমেন্ট প্রিভিউ — হিউরিস্টিক আউটপুট'
      );
  String get comingSoonPhase => _get(
        'Coming in a later phase',
        'اگلے مرحلے میں آ رہا ہے',
        'قادم في مرحلة لاحقة',
      
        'बाद के चरण में आ रहा है',
        'Disponible dans une phase ultérieure',
        'Disponible en una fase posterior',
        'Disponível em uma fase posterior',
        'Kommt in einer späteren Phase',
        'Daha sonraki bir aşamada geliyor',
        'Hadir di fase berikutnya',
        'পরবর্তী পর্যায়ে আসছে'
      );
  String get askFailed => _get(
        'Couldn\'t reach Virello AI. Check your connection and try again.',
        'وائریلو AI سے رابطہ نہ ہو سکا۔ کنکشن چیک کریں اور دوبارہ کوشش کریں۔',
        'تعذّر الوصول إلى فيريلو. تحقق من الاتصال وحاول مجددًا.',
      
        'Virello AI से संपर्क नहीं हो सका। अपना कनेक्शन जाँचें और फिर कोशिश करें।',
        'Impossible de joindre Virello IA. Vérifiez votre connexion et réessayez.',
        'No se pudo contactar a Virello IA. Revisa tu conexión e inténtalo de nuevo.',
        'Não foi possível alcançar o Virello IA. Verifique sua conexão e tente novamente.',
        'Virello KI konnte nicht erreicht werden. Prüfe deine Verbindung und versuch es erneut.',
        'Virello YZ\'ye ulaşılamadı. Bağlantını kontrol et ve tekrar dene.',
        'Tidak dapat menghubungi Virello AI. Periksa koneksimu dan coba lagi.',
        'Virello AI-এর সাথে সংযোগ করা যায়নি। আপনার সংযোগ পরীক্ষা করে আবার চেষ্টা করুন।'
      );
  String get shopBackendUpdating => _get(
        'Shop is updating on the server. Please try again in a few minutes.',
        'شاپ سرور پر اپ ڈیٹ ہو رہی ہے۔ چند منٹ بعد دوبارہ کوشش کریں۔',
        'المتجر قيد التحديث على الخادم. حاول مجددًا بعد بضع دقائق.',
        'शॉप सर्वर पर अपडेट हो रही है। कृपया कुछ मिनट बाद पुनः प्रयास करें।',
        'La boutique est en cours de mise à jour sur le serveur. Réessayez dans quelques minutes.',
        'La tienda se está actualizando en el servidor. Inténtalo de nuevo en unos minutos.',
        'A loja está a ser atualizada no servidor. Tenta novamente dentro de alguns minutos.',
        'Der Shop wird auf dem Server aktualisiert. Bitte versuche es in wenigen Minuten erneut.',
        'Mağaza sunucuda güncelleniyor. Lütfen birkaç dakika sonra tekrar dene.',
        'Toko sedang diperbarui di server. Silakan coba lagi dalam beberapa menit.',
        'সার্ভারে শপ আপডেট হচ্ছে। কয়েক মিনিট পরে আবার চেষ্টা করুন।'
      );

  // ------------------------------ Shop (Phase 1 placeholder) ------------------------------
  String get shop => _get('Shop', 'شاپ', 'المتجر',
        'शॉप',
        'Boutique',
        'Tienda',
        'Loja',
        'Shop',
        'Mağaza',
        'Toko',
        'শপ'
      );
  String get shopComingSoon =>
      _get('Shop is coming soon', 'شاپ جلد آ رہی ہے', 'المتجر قادم قريبًا',
        'शॉप जल्द आ रही है',
        'La boutique arrive bientôt',
        'La tienda llegará pronto',
        'A loja está chegando',
        'Der Shop kommt bald',
        'Mağaza yakında geliyor',
        'Toko segera hadir',
        'শপ শীঘ্রই আসছে'
      );
  String get shopComingSoonDesc => _get(
        'Product discovery, price comparison and creator storefronts arrive in Phase 4. Ask Virello about your product in the meantime!',
        'پروڈکٹ ڈسکوری، قیمت کا موازنہ اور کریئیٹر اسٹورز فیز 4 میں آئیں گے۔ تب تک وائریلو سے اپنے پروڈکٹ کے بارے میں پوچھیں!',
        'اكتشاف المنتجات ومقارنة الأسعار وواجهات المبدعين قادمة في المرحلة 4. اسأل فيريلو عن منتجك في هذه الأثناء!',
      
        'प्रोडक्ट खोज, कीमत तुलना और क्रिएटर स्टोरफ़्रंट चरण 4 में आ रहे हैं। इस बीच अपने प्रोडक्ट के बारे में Virello से पूछें!',
        'La découverte de produits, la comparaison de prix et les vitrines de créateurs arrivent dans la phase 4. En attendant, demandez à Virello au sujet de votre produit !',
        'El descubrimiento de productos, la comparación de precios y los escaparates de creadores llegan en la fase 4. ¡Mientras tanto, pregunta a Virello sobre tu producto!',
        'Descoberta de produtos, comparação de preços e vitrines de criadores chegam na fase 4. Enquanto isso, pergunte ao Virello sobre seu produto!',
        'Produktentdeckung, Preisvergleich und Creator-Storefronts kommen in Phase 4. Frag Virello in der Zwischenzeit zu deinem Produkt!',
        'Ürün keşfi, fiyat karşılaştırma ve üretici mağazaları 4. aşamada geliyor. Bu arada ürünün hakkında Virello\'ya sor!',
        'Penemuan produk, perbandingan harga, dan etalase kreator hadir di Fase 4. Sementara itu, tanyakan pada Virello tentang produkmu!',
        'পণ্য আবিষ্কার, মূল্য তুলনা এবং ক্রিয়েটর স্টোরফ্রন্ট চতুর্থ পর্যায়ে আসছে। এর মধ্যে আপনার পণ্য সম্পর্কে Virello-কে জিজ্ঞাসা করুন!'
      );

  // ------------------------------ Affiliate (Phase 4, FTC/Amazon disclosure) ------------------------------
  /// Shown on every affiliate product detail per FTC + Amazon Associates rules.
  String get affiliateDisclosure => _get(
        'Affiliate link — we may earn a commission',
        'ایفیلی ایٹ لنک — ہمیں کمیشن مل سکتا ہے',
        'رابط تابع — قد نحصل على عمولة',
      
        'एफ़िलिएट लिंक — हमें कमीशन मिल सकता है',
        'Lien affilié — nous pouvons toucher une commission',
        'Enlace de afiliado: podemos ganar una comisión',
        'Link de afiliado — podemos ganhar uma comissão',
        'Affiliate-Link — wir erhalten ggf. eine Provision',
        'Satış ortaklığı bağlantısı — komisyon kazanabiliriz',
        'Tautan afiliasi — kami mungkin mendapat komisi',
        'অ্যাফিলিয়েট লিঙ্ক — আমরা কমিশন পেতে পারি'
      );
  String get affiliateBadge => _get('Affiliate', 'ایفیلی ایٹ', 'تابع',
        'एफ़िलिएट',
        'Affilié',
        'Afiliado',
        'Afiliado',
        'Affiliate',
        'Satış ortağı',
        'Afiliasi',
        'অ্যাফিলিয়েট'
      );
  String get syncAffiliate =>
      _get('Sync price', 'قیمت اپ ڈیٹ کریں', 'مزامنة السعر',
        'कीमत सिंक करें',
        'Synchroniser le prix',
        'Sincronizar precio',
        'Sincronizar preço',
        'Preis synchronisieren',
        'Fiyatı senkronize et',
        'Sinkronkan harga',
        'মূল্য সিঙ্ক করুন'
      );
  String get syncNotConfigured => _get(
        'Price sync needs Amazon API credentials (coming soon)',
        'قیمت اپ ڈیٹ کے لیے Amazon API درکار ہے (جلد آ رہا ہے)',
        'مزامنة السعر تحتاج بيانات Amazon API (قريبًا)',
      
        'कीमत सिंक के लिए Amazon API क्रेडेंशियल चाहिए (जल्द आ रहा है)',
        'La synchronisation des prix nécessite des identifiants Amazon API (bientôt disponible)',
        'La sincronización de precios necesita credenciales de Amazon API (próximamente)',
        'A sincronização de preços precisa das credenciais da Amazon API (em breve)',
        'Für die Preissynchronisierung sind Amazon-API-Zugangsdaten nötig (bald verfügbar)',
        'Fiyat senkronizasyonu için Amazon API kimlik bilgileri gerekli (yakında)',
        'Sinkronisasi harga memerlukan kredensial Amazon API (segera hadir)',
        'মূল্য সিঙ্কের জন্য Amazon API ক্রেডেনশিয়াল প্রয়োজন (শীঘ্রই আসছে)'
      );

  // ------------------------------ Home next actions (Phase 1) ------------------------------
  String get nextActions => _get(
        'AI suggested next actions',
        'AI کی تجویز کردہ اگلے اقدامات',
        'الخطوات التالية المقترحة بالذكاء الاصطناعي',
      
        'AI द्वारा सुझाए गए अगले कदम',
        'Prochaines actions suggérées par l\'IA',
        'Próximas acciones sugeridas por la IA',
        'Próximas ações sugeridas pela IA',
        'Von der KI vorgeschlagene nächste Schritte',
        'YZ\'nin önerdiği sonraki adımlar',
        'Tindakan berikutnya yang disarankan AI',
        'AI-এর প্রস্তাবিত পরবর্তী পদক্ষেপ'
      );
  String get actionAnalyzePost =>
      _get('Analyze a post', 'پوسٹ کا تجزیہ کریں', 'حلِّل منشورًا',
        'पोस्ट का विश्लेषण करें',
        'Analyser une publication',
        'Analizar una publicación',
        'Analisar uma publicação',
        'Einen Post analysieren',
        'Bir gönderiyi analiz et',
        'Analisis postingan',
        'একটি পোস্ট বিশ্লেষণ করুন'
      );
  String get actionAskVirello =>
      _get('Ask Virello', 'وائریلو سے پوچھیں', 'اسأل فيريلو',
        'Virello से पूछें',
        'Demander à Virello',
        'Preguntar a Virello',
        'Perguntar ao Virello',
        'Virello fragen',
        'Virello\'ya Sor',
        'Tanya Virello',
        'Virello-কে জিজ্ঞাসা করুন'
      );
  String get actionViewCampaigns =>
      _get('View campaigns', 'مہمات دیکھیں', 'عرض الحملات',
        'अभियान देखें',
        'Voir les campagnes',
        'Ver campañas',
        'Ver campanhas',
        'Kampagnen ansehen',
        'Kampanyaları görüntüle',
        'Lihat kampanye',
        'ক্যাম্পেইন দেখুন'
      );

  /// Human label for an AI Core intent code.
  String intentLabel(String intent) {
    switch (intent) {
      case 'create_content':
        return _get('Create', 'تخلیق', 'إنشاء',
        'बनाएँ',
        'Créer',
        'Crear',
        'Criar',
        'Erstellen',
        'Oluştur',
        'Buat',
        'তৈরি করুন'
      );
      case 'analyze_content':
        return _get('Analyze', 'تجزیہ', 'تحليل',
        'विश्लेषण',
        'Analyser',
        'Analizar',
        'Analisar',
        'Analysieren',
        'Analiz',
        'Analisis',
        'বিশ্লেষণ'
      );
      case 'grow':
        return _get('Grow', 'گرو', 'نمِّ',
        'ग्रो',
        'Croissance',
        'Crecer',
        'Crescer',
        'Wachstum',
        'Büyüme',
        'Grow',
        'গ্রো'
      );
      case 'discover':
        return _get('Discover', 'دریافت', 'اكتشف',
        'डिस्कवर',
        'Découvrir',
        'Descubrir',
        'Descobrir',
        'Entdecken',
        'Keşfet',
        'Temukan',
        'ডিসকভার'
      );
      case 'shop':
        return _get('Shop', 'شاپ', 'المتجر',
        'शॉप',
        'Boutique',
        'Tienda',
        'Loja',
        'Shop',
        'Mağaza',
        'Toko',
        'শপ'
      );
      case 'learn':
        return _get('Learn', 'سیکھیں', 'تعلَّم',
        'सीखें',
        'Apprendre',
        'Aprender',
        'Aprender',
        'Lernen',
        'Öğren',
        'Belajar',
        'শিখুন'
      );
      case 'entertain':
        return _get('Entertain', 'تفریح', 'ترفيه',
        'मनोरंजन',
        'Divertissement',
        'Entretenimiento',
        'Entretenimento',
        'Unterhaltung',
        'Eğlence',
        'Hiburan',
        'বিনোদন'
      );
      case 'support':
        return _get('Support', 'سپورٹ', 'الدعم',
        'सहायता',
        'Assistance',
        'Soporte',
        'Suporte',
        'Support',
        'Destek',
        'Dukungan',
        'সাপোর্ট'
      );
      default:
        return _get('Assistant', 'اسسٹنٹ', 'المساعد',
        'सहायक',
        'Assistant',
        'Asistente',
        'Assistente',
        'Assistent',
        'Asistan',
        'Asisten',
        'সহকারী'
      );
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
  String get viralLab => _get('Viral Lab', 'وائرل لیب', 'مختبر الانتشار',
        'वायरल लैब',
        'Labo viral',
        'Laboratorio viral',
        'Laboratório viral',
        'Viral Lab',
        'Viral Laboratuvarı',
        'Lab Viral',
        'ভাইরাল ল্যাব'
      );
  String get viralLabDesc => _get(
        'Analyze any post, get improvements & variations',
        'کسی بھی پوسٹ کا تجزیہ کریں، بہتری اور ورژن حاصل کریں',
        'حلِّل أي منشور واحصل على تحسينات ونسخ',
      
        'किसी भी पोस्ट का विश्लेषण करें, सुधार और वेरिएशन पाएँ',
        'Analysez n\'importe quelle publication, obtenez des améliorations et des variantes',
        'Analiza cualquier publicación y obtén mejoras y variaciones',
        'Analise qualquer publicação e receba melhorias e variações',
        'Analysiere jeden Post und erhalte Verbesserungen & Varianten',
        'Herhangi bir gönderiyi analiz et, iyileştirmeler ve varyasyonlar al',
        'Analisis postingan apa pun, dapatkan peningkatan & variasi',
        'যেকোনো পোস্ট বিশ্লেষণ করুন, উন্নতি ও ভিন্ন সংস্করণ পান'
      );
  String get pasteLinkOrText => _get(
        'Paste a post link or write your text…',
        'پوسٹ کا لنک پیسٹ کریں یا اپنا متن لکھیں…',
        'الصق رابط منشور أو اكتب نصك…',
      
        'पोस्ट का लिंक पेस्ट करें या अपना टेक्स्ट लिखें…',
        'Collez un lien de publication ou écrivez votre texte…',
        'Pega un enlace de publicación o escribe tu texto…',
        'Cole um link de publicação ou escreva seu texto…',
        'Füge einen Post-Link ein oder schreibe deinen Text…',
        'Bir gönderi bağlantısı yapıştır veya metnini yaz…',
        'Tempel tautan postingan atau tulis teksmu…',
        'একটি পোস্ট লিঙ্ক পেস্ট করুন বা আপনার টেক্সট লিখুন…'
      );
  String get analyzeImprove =>
      _get('Analyze & Improve', 'تجزیہ اور بہتری', 'حلِّل وحسِّن',
        'विश्लेषण और सुधार',
        'Analyser et améliorer',
        'Analizar y mejorar',
        'Analisar e melhorar',
        'Analysieren & verbessern',
        'Analiz Et ve İyileştir',
        'Analisis & Tingkatkan',
        'বিশ্লেষণ ও উন্নতি'
      );
  String get improvementAreas =>
      _get('Improvement areas', 'بہتری کے شعبے', 'مجالات التحسين',
        'सुधार के क्षेत्र',
        'Axes d\'amélioration',
        'Áreas de mejora',
        'Áreas de melhoria',
        'Verbesserungsbereiche',
        'İyileştirme alanları',
        'Area peningkatan',
        'উন্নতির ক্ষেত্র'
      );
  String get rewrittenHook => _get(
        'Example rewritten hook',
        'دوبارہ لکھا ہوا ہوک (مثال)',
        'مثال على بداية محسنة',
      
        'फिर से लिखा गया हुक (उदाहरण)',
        'Exemple d\'accroche réécrite',
        'Ejemplo de gancho reescrito',
        'Exemplo de gancho reescrito',
        'Beispiel für einen umgeschriebenen Hook',
        'Yeniden yazılmış kanca örneği',
        'Contoh hook yang ditulis ulang',
        'পুনর্লিখিত হুকের উদাহরণ'
      );
  String get variations => _get('Variations', 'مختلف ورژن', 'نسخ متنوعة',
        'वेरिएशन',
        'Variantes',
        'Variaciones',
        'Variações',
        'Varianten',
        'Varyasyonlar',
        'Variasi',
        'ভিন্ন সংস্করণ'
      );
  String get copyText => _get('Copy', 'کاپی', 'نسخ',
        'कॉपी करें',
        'Copier',
        'Copiar',
        'Copiar',
        'Kopieren',
        'Kopyala',
        'Salin',
        'কপি করুন'
      );
  String get copied => _get('Copied!', 'کاپی ہو گیا!', 'تم النسخ!',
        'कॉपी हो गया!',
        'Copié !',
        '¡Copiado!',
        'Copiado!',
        'Kopiert!',
        'Kopyalandı!',
        'Tersalin!',
        'কপি হয়েছে!'
      );
  String get whyItWorks =>
      _get('Why it works', 'یہ کیوں کام کرتا ہے', 'لماذا ينجح',
        'यह क्यों काम करता है',
        'Pourquoi ça marche',
        'Por qué funciona',
        'Por que funciona',
        'Warum das funktioniert',
        'Neden işe yarar',
        'Mengapa ini berhasil',
        'এটি কেন কাজ করে'
      );
  String get priorityHigh => _get('High priority', 'اہم', 'أولوية عالية',
        'उच्च प्राथमिकता',
        'Priorité haute',
        'Prioridad alta',
        'Prioridade alta',
        'Hohe Priorität',
        'Yüksek öncelik',
        'Prioritas tinggi',
        'উচ্চ অগ্রাধিকার'
      );
  String get priorityMedium =>
      _get('Medium priority', 'درمیانی', 'أولوية متوسطة',
        'मध्यम प्राथमिकता',
        'Priorité moyenne',
        'Prioridad media',
        'Prioridade média',
        'Mittlere Priorität',
        'Orta öncelik',
        'Prioritas sedang',
        'মাঝারি অগ্রাধিকার'
      );
  String get scoreLabel =>
      _get('Packaging score', 'پیکجنگ اسکور', 'درجة التغليف',
        'पैकेजिंग स्कोर',
        'Score de présentation',
        'Puntuación de presentación',
        'Pontuação de apresentação',
        'Verpackungs-Score',
        'Paketleme puanı',
        'Skor pengemasan',
        'প্যাকেজিং স্কোর'
      );
  String get enterTextFirst => _get(
        'Enter a link or some text first.',
        'پہلے لنک یا متن درج کریں۔',
        'أدخل رابطًا أو نصًا أولًا.',
      
        'पहले कोई लिंक या टेक्स्ट दर्ज करें।',
        'Entrez d\'abord un lien ou du texte.',
        'Ingresa primero un enlace o algo de texto.',
        'Insira primeiro um link ou algum texto.',
        'Gib zuerst einen Link oder Text ein.',
        'Önce bir bağlantı veya metin gir.',
        'Masukkan tautan atau teks terlebih dahulu.',
        'প্রথমে একটি লিঙ্ক বা কিছু টেক্সট লিখুন।'
      );

  // ------------------------------ Creator Studio (Phase 3) ------------------------------
  String get creatorStudio =>
      _get('Creator Studio', 'کریئیٹر اسٹوڈیو', 'استوديو المبدع',
        'क्रिएटर स्टूडियो',
        'Studio créateur',
        'Estudio del creador',
        'Estúdio do criador',
        'Creator Studio',
        'Üretici Stüdyosu',
        'Studio Kreator',
        'ক্রিয়েটর স্টুডিও'
      );
  String get creatorStudioDesc => _get(
        'AI ideas, scripts, captions & hooks',
        'AI آئیڈیاز، اسکرپٹس، کیپشنز اور ہوکس',
        'أفكار ونصوص وتسميات وبدايات بالذكاء الاصطناعي',
      
        'AI आइडिया, स्क्रिप्ट, कैप्शन और हुक',
        'Idées, scripts, légendes et accroches IA',
        'Ideas, guiones, subtítulos y ganchos con IA',
        'Ideias, roteiros, legendas e ganchos com IA',
        'KI-Ideen, Skripte, Captions & Hooks',
        'YZ fikirleri, senaryolar, altyazılar ve kancalar',
        'Ide, skrip, caption & hook AI',
        'AI আইডিয়া, স্ক্রিপ্ট, ক্যাপশন ও হুক'
      );
  String get tabIdeas => _get('Ideas', 'آئیڈیاز', 'أفكار',
        'आइडिया',
        'Idées',
        'Ideas',
        'Ideias',
        'Ideen',
        'Fikirler',
        'Ide',
        'আইডিয়া'
      );
  String get tabScripts => _get('Scripts', 'اسکرپٹس', 'نصوص',
        'स्क्रिप्ट',
        'Scripts',
        'Guiones',
        'Roteiros',
        'Skripte',
        'Senaryolar',
        'Skrip',
        'স্ক্রিপ্ট'
      );
  String get tabCaptions => _get('Captions', 'کیپشنز', 'تسميات',
        'कैप्शन',
        'Légendes',
        'Subtítulos',
        'Legendas',
        'Captions',
        'Altyazılar',
        'Caption',
        'ক্যাপশন'
      );
  String get tabHooks => _get('Hooks', 'ہوکس', 'بدايات',
        'हुक',
        'Accroches',
        'Ganchos',
        'Ganchos',
        'Hooks',
        'Kancalar',
        'Hook',
        'হুক'
      );
  String get topicHint => _get(
        'What is it about? e.g. sourdough baking',
        'موضوع کیا ہے؟ مثلاً سرڈو بریڈ بیکنگ',
        'ما الموضوع؟ مثال: خبز العجين المخمر',
      
        'विषय क्या है? जैसे सरडो ब्रेड बेकिंग',
        'De quoi s\'agit-il ? ex. pain au levain',
        '¿De qué trata? p. ej. pan de masa madre',
        'Sobre o que é? ex. pão de fermentação natural',
        'Worum geht es? z. B. Sauerteigbrot backen',
        'Konu ne? örn. ekşi maya ekmeği',
        'Tentang apa? mis. memanggang roti sourdough',
        'বিষয় কী? যেমন: সারডো ব্রেড বেকিং'
      );
  String get generateIdeas =>
      _get('Generate ideas', 'آئیڈیاز بنائیں', 'ولِّد أفكارًا',
        'आइडिया बनाएँ',
        'Générer des idées',
        'Generar ideas',
        'Gerar ideias',
        'Ideen generieren',
        'Fikir üret',
        'Buat ide',
        'আইডিয়া তৈরি করুন'
      );
  String get generateScript =>
      _get('Generate script', 'اسکرپٹ بنائیں', 'ولِّد نصًا',
        'स्क्रिप्ट बनाएँ',
        'Générer un script',
        'Generar guion',
        'Gerar roteiro',
        'Skript generieren',
        'Senaryo üret',
        'Buat skrip',
        'স্ক্রিপ্ট তৈরি করুন'
      );
  String get generateCaptions =>
      _get('Generate captions', 'کیپشنز بنائیں', 'ولِّد تسميات',
        'कैप्शन बनाएँ',
        'Générer des légendes',
        'Generar subtítulos',
        'Gerar legendas',
        'Captions generieren',
        'Altyazı üret',
        'Buat caption',
        'ক্যাপশন তৈরি করুন'
      );
  String get generateHooks =>
      _get('Generate hooks', 'ہوکس بنائیں', 'ولِّد بدايات',
        'हुक बनाएँ',
        'Générer des accroches',
        'Generar ganchos',
        'Gerar ganchos',
        'Hooks generieren',
        'Kanca üret',
        'Buat hook',
        'হুক তৈরি করুন'
      );
  String get formatVideo => _get('Video', 'ویڈیو', 'فيديو',
        'वीडियो',
        'Vidéo',
        'Video',
        'Vídeo',
        'Video',
        'Video',
        'Video',
        'ভিডিও'
      );
  String get formatReel => _get('Reel', 'ریل', 'ريل',
        'Reel',
        'Reel',
        'Reel',
        'Reel',
        'Reel',
        'Reel',
        'Reel',
        'Reel'
      );
  String get formatPost => _get('Post', 'پوسٹ', 'منشور',
        'पोस्ट',
        'Publication',
        'Publicación',
        'Publicação',
        'Post',
        'Gönderi',
        'Postingan',
        'পোস্ট'
      );
  String get scriptHook => _get('Hook', 'ہوک', 'البداية',
        'हुक',
        'Accroche',
        'Gancho',
        'Gancho',
        'Hook',
        'Kanca',
        'Hook',
        'হুক'
      );
  String get scriptBody => _get('Body', 'متن', 'المتن',
        'मुख्य भाग',
        'Corps',
        'Cuerpo',
        'Corpo',
        'Hauptteil',
        'Gövde',
        'Isi',
        'মূল অংশ'
      );
  String get scriptCta =>
      _get('Call to action', 'کال ٹو ایکشن', 'الدعوة لاتخاذ إجراء',
        'कॉल टू एक्शन',
        'Appel à l\'action',
        'Llamada a la acción',
        'Chamada para ação',
        'Call-to-Action',
        'Eylem çağrısı',
        'Ajakan bertindak',
        'কল টু অ্যাকশন'
      );
  String get noResultsYet => _get(
        'Your creations will appear here.',
        'آپ کی تخلیقات یہاں نظر آئیں گی۔',
        'ستظهر إبداعاتك هنا.',
      
        'आपकी बनाई चीज़ें यहाँ दिखेंगी।',
        'Vos créations apparaîtront ici.',
        'Tus creaciones aparecerán aquí.',
        'Suas criações aparecerão aqui.',
        'Deine Kreationen erscheinen hier.',
        'Oluşturdukların burada görünecek.',
        'Kreasimu akan muncul di sini.',
        'আপনার তৈরি জিনিসগুলো এখানে দেখা যাবে।'
      );

  // ------------------------------ AI Academy (Phase 5) ------------------------------
  String get academy => _get('Academy', 'اکیڈمی', 'الأكاديمية',
        'अकादमी',
        'Académie',
        'Academia',
        'Academia',
        'Academy',
        'Akademi',
        'Akademi',
        'অ্যাকাডেমি'
      );
  String get academyTagline => _get(
        'Bite-size lessons to grow your craft',
        'اپنے ہنر کو بڑھانے کے لیے مختصر اسباق',
        'دروس قصيرة لتنمية مهاراتك',
      
        'अपने हुनर को निखारने के लिए छोटे-छोटे पाठ',
        'Des leçons courtes pour développer votre talent',
        'Lecciones breves para perfeccionar tu oficio',
        'Aulas curtas para aprimorar seu talento',
        'Kurze Lektionen für dein Handwerk',
        'Becerini geliştirmek için kısa dersler',
        'Pelajaran singkat untuk mengasah keahlianmu',
        'আপনার দক্ষতা বাড়াতে ছোট ছোট পাঠ'
      );
  String get lessonLibrary =>
      _get('Lesson library', 'اسباق کی لائبریری', 'مكتبة الدروس',
        'पाठ पुस्तकालय',
        'Bibliothèque de leçons',
        'Biblioteca de lecciones',
        'Biblioteca de aulas',
        'Lektionsbibliothek',
        'Ders kitaplığı',
        'Perpustakaan pelajaran',
        'পাঠ লাইব্রেরি'
      );
  String get categoryAll => _get('All', 'تمام', 'الكل',
        'सभी',
        'Tous',
        'Todos',
        'Todos',
        'Alle',
        'Tümü',
        'Semua',
        'সব'
      );
  String get categoryContent => _get('Content', 'مواد', 'المحتوى',
        'कंटेंट',
        'Contenu',
        'Contenido',
        'Conteúdo',
        'Content',
        'İçerik',
        'Konten',
        'কনটেন্ট'
      );
  String get categoryGrowth => _get('Growth', 'گروتھ', 'النمو',
        'ग्रोथ',
        'Croissance',
        'Crecimiento',
        'Crescimento',
        'Wachstum',
        'Büyüme',
        'Pertumbuhan',
        'গ্রোথ'
      );
  String get categoryCommerce => _get('Commerce', 'کامرس', 'التجارة',
        'कॉमर्स',
        'Commerce',
        'Comercio',
        'Comércio',
        'Commerce',
        'Ticaret',
        'Niaga',
        'কমার্স'
      );
  String get categoryMarketing => _get('Marketing', 'مارکیٹنگ', 'التسويق',
        'मार्केटिंग',
        'Marketing',
        'Marketing',
        'Marketing',
        'Marketing',
        'Pazarlama',
        'Pemasaran',
        'মার্কেটিং'
      );
  String get levelBeginner => _get('Beginner', 'ابتدائی', 'مبتدئ',
        'शुरुआती',
        'Débutant',
        'Principiante',
        'Iniciante',
        'Anfänger',
        'Başlangıç',
        'Pemula',
        'শিক্ষানবিস'
      );
  String get levelIntermediate => _get('Intermediate', 'درمیانہ', 'متوسط',
        'मध्यवर्ती',
        'Intermédiaire',
        'Intermedio',
        'Intermediário',
        'Fortgeschritten',
        'Orta seviye',
        'Menengah',
        'মধ্যবর্তী'
      );
  String get levelAdvanced => _get('Advanced', 'اعلیٰ', 'متقدم',
        'उन्नत',
        'Avancé',
        'Avanzado',
        'Avançado',
        'Profi',
        'İleri seviye',
        'Lanjutan',
        'উন্নত'
      );
  String get startLesson => _get('Start lesson', 'سبق شروع کریں', 'ابدأ الدرس',
        'पाठ शुरू करें',
        'Commencer la leçon',
        'Empezar la lección',
        'Começar a aula',
        'Lektion starten',
        'Derse başla',
        'Mulai pelajaran',
        'পাঠ শুরু করুন'
      );
  String get markComplete =>
      _get('Mark complete', 'مکمل قرار دیں', 'وضع علامة مكتمل',
        'पूर्ण के रूप में चिह्नित करें',
        'Marquer comme terminé',
        'Marcar como completado',
        'Marcar como concluído',
        'Als abgeschlossen markieren',
        'Tamamlandı olarak işaretle',
        'Tandai selesai',
        'সম্পূর্ণ হিসেবে চিহ্নিত করুন'
      );
  String get completed => _get('Completed', 'مکمل', 'مكتمل',
        'पूर्ण',
        'Terminé',
        'Completado',
        'Concluído',
        'Abgeschlossen',
        'Tamamlandı',
        'Selesai',
        'সম্পূর্ণ'
      );
  String get takeQuiz => _get('Take quiz', 'کوئز دیں', 'خذ الاختبار',
        'क्विज़ दें',
        'Faire le quiz',
        'Hacer el quiz',
        'Fazer o quiz',
        'Quiz machen',
        'Teste katıl',
        'Ikuti kuis',
        'কুইজ দিন'
      );
  String get submitQuiz =>
      _get('Submit quiz', 'کوئز جمع کریں', 'أرسل الاختبار',
        'क्विज़ जमा करें',
        'Envoyer le quiz',
        'Enviar el quiz',
        'Enviar o quiz',
        'Quiz absenden',
        'Testi gönder',
        'Kirim kuis',
        'কুইজ জমা দিন'
      );
  String get yourScore => _get('Your score', 'آپ کا اسکور', 'نتيجتك',
        'आपका स्कोर',
        'Votre score',
        'Tu puntuación',
        'Sua pontuação',
        'Dein Score',
        'Puanın',
        'Skormu',
        'আপনার স্কোর'
      );
  String get passedQuiz => _get(
        'Quiz passed — well done!',
        'کوئز پاس — شاباش!',
        'نجحت في الاختبار — أحسنت!',
      
        'क्विज़ पास — शाबाश!',
        'Quiz réussi — bravo !',
        'Quiz superado — ¡bien hecho!',
        'Quiz aprovado — muito bem!',
        'Quiz bestanden — gut gemacht!',
        'Testi geçtin — aferin!',
        'Kuis lulus — kerja bagus!',
        'কুইজ পাস — শাবাশ!'
      );
  String get keepTrying => _get(
        'Not quite there yet — try again!',
        'ابھی مکمل نہیں ہوا — دوبارہ کوشش کریں!',
        'ليس بعد — حاول مرة أخرى!',
      
        'अभी थोड़ा और बाकी है — फिर कोशिश करें!',
        'Pas encore tout à fait — réessayez !',
        'Casi lo tienes — ¡inténtalo de nuevo!',
        'Quase lá — tente de novo!',
        'Noch nicht ganz — versuch es nochmal!',
        'Henüz olmadı — tekrar dene!',
        'Belum tepat — coba lagi!',
        'এখনও হয়নি — আবার চেষ্টা করুন!'
      );
  String get noLessons =>
      _get('No lessons yet', 'ابھی کوئی سبق نہیں', 'لا دروس بعد',
        'अभी कोई पाठ नहीं',
        'Pas encore de leçons',
        'Aún no hay lecciones',
        'Sem aulas ainda',
        'Noch keine Lektionen',
        'Henüz ders yok',
        'Belum ada pelajaran',
        'এখনও কোনো পাঠ নেই'
      );
  String questionOf(int n, int total) =>
      _get('Question $n of $total', 'سوال $n از $total', 'السؤال $n من $total',
        'प्रश्न $n / $total',
        'Question $n sur $total',
        'Pregunta $n de $total',
        'Pergunta $n de $total',
        'Frage $n von $total',
        'Soru $n / $total',
        'Pertanyaan $n dari $total',
        'প্রশ্ন $n / $total'
      );
  String get quizScore => _get('Quiz', 'کوئز', 'الاختبار',
        'क्विज़',
        'Quiz',
        'Quiz',
        'Quiz',
        'Quiz',
        'Test',
        'Kuis',
        'কুইজ'
      );
  String get openAcademy => _get('Learn', 'سیکھیں', 'تعلَّم',
        'सीखें',
        'Apprendre',
        'Aprender',
        'Aprender',
        'Lernen',
        'Öğren',
        'Belajar',
        'শিখুন'
      );
  String get openAcademyDesc => _get(
        'Short lessons on content, growth & selling',
        'مواد، گروتھ اور فروخت پر مختصر اسباق',
        'دروس قصيرة عن المحتوى والنمو والبيع',
      
        'कंटेंट, ग्रोथ और बिक्री पर छोटे पाठ',
        'Courtes leçons sur le contenu, la croissance et la vente',
        'Lecciones breves sobre contenido, crecimiento y ventas',
        'Aulas curtas sobre conteúdo, crescimento e vendas',
        'Kurze Lektionen zu Content, Wachstum & Verkaufen',
        'İçerik, büyüme ve satış üzerine kısa dersler',
        'Pelajaran singkat tentang konten, pertumbuhan & penjualan',
        'কনটেন্ট, গ্রোথ ও বিক্রি নিয়ে ছোট পাঠ'
      );

  // ------------------------------ AI Entertainment (Phase 6) ------------------------------
  String get stories => _get('Stories', 'کہانیاں', 'القصص',
        'कहानियाँ',
        'Histoires',
        'Historias',
        'Histórias',
        'Stories',
        'Hikâyeler',
        'Cerita',
        'গল্প'
      );
  String get storiesTagline => _get(
        'AI storytime — just for fun',
        'AI کہانی کا وقت — صرف تفریح کے لیے',
        'وقت القصص بالذكاء الاصطناعي — للمتعة فقط',
      
        'AI कहानी समय — सिर्फ़ मज़े के लिए',
        'Histoires IA — juste pour le plaisir',
        'Cuentos con IA, solo por diversión',
        'Historinhas com IA — só por diversão',
        'KI-Geschichtenzeit — nur zum Spaß',
        'YZ hikâye saati — sadece eğlence için',
        'Dongeng AI — hanya untuk bersenang-senang',
        'AI গল্পের সময় — শুধু মজার জন্য'
      );
  String get storyPromptHint => _get(
        'Give a topic or idea… e.g. a space adventure',
        'کوئی موضوع یا خیال لکھیں… مثلاً خلا کا سفر',
        'أعطِ موضوعًا أو فكرة… مثال: مغامرة فضائية',
      
        'कोई विषय या आइडिया दें… जैसे अंतरिक्ष यात्रा',
        'Donnez un sujet ou une idée… ex. une aventure spatiale',
        'Dame un tema o una idea… p. ej. una aventura espacial',
        'Dê um tema ou ideia… ex. uma aventura espacial',
        'Gib ein Thema oder eine Idee an… z. B. ein Weltraumabenteuer',
        'Bir konu veya fikir ver… örn. bir uzay macerası',
        'Beri topik atau ide… mis. petualangan luar angkasa',
        'একটি বিষয় বা আইডিয়া দিন… যেমন: মহাকাশ অভিযান'
      );
  String get generateStory =>
      _get('Generate story', 'کہانی بنائیں', 'ولِّد قصة',
        'कहानी बनाएँ',
        'Générer une histoire',
        'Generar historia',
        'Gerar história',
        'Story generieren',
        'Hikâye üret',
        'Buat cerita',
        'গল্প তৈরি করুন'
      );
  String get regenerate => _get('Regenerate', 'دوبارہ بنائیں', 'أعد التوليد',
        'फिर से बनाएँ',
        'Régénérer',
        'Regenerar',
        'Gerar novamente',
        'Neu generieren',
        'Yeniden üret',
        'Buat ulang',
        'আবার তৈরি করুন'
      );
  String get shortLength => _get('Short', 'مختصر', 'قصيرة',
        'छोटा',
        'Court',
        'Corto',
        'Curta',
        'Kurz',
        'Kısa',
        'Pendek',
        'ছোট'
      );
  String get mediumLength => _get('Medium', 'درمیانی', 'متوسطة',
        'मध्यम',
        'Moyen',
        'Mediano',
        'Média',
        'Mittel',
        'Orta',
        'Sedang',
        'মাঝারি'
      );
  String get comicIdea => _get('Comic idea', 'کامک آئیڈیا', 'فكرة كوميك',
        'कॉमिक आइडिया',
        'Idée de BD',
        'Idea de cómic',
        'Ideia de quadrinhos',
        'Comic-Idee',
        'Çizgi roman fikri',
        'Ide komik',
        'কমিক আইডিয়া'
      );
  String get comicTopicHint => _get(
        'What should the comic be about?',
        'کامک کس موضوع پر ہو؟',
        'عن ماذا يجب أن يكون الكوميك؟',
      
        'कॉमिक किस बारे में हो?',
        'De quoi devrait parler la BD ?',
        '¿De qué debería tratar el cómic?',
        'Sobre o que deve ser o quadrinho?',
        'Worum soll es im Comic gehen?',
        'Çizgi roman ne hakkında olmalı?',
        'Komiknya tentang apa?',
        'কমিক কী নিয়ে হওয়া উচিত?'
      );
  String get panels => _get('Panels', 'پینلز', 'اللوحات',
        'पैनल',
        'Cases',
        'Viñetas',
        'Quadros',
        'Panels',
        'Paneller',
        'Panel',
        'প্যানেল'
      );
  String get generate => _get('Generate', 'بنائیں', 'ولِّد',
        'बनाएँ',
        'Générer',
        'Generar',
        'Gerar',
        'Generieren',
        'Üret',
        'Buat',
        'তৈরি করুন'
      );
  String get openStories => _get('Stories', 'کہانیاں', 'القصص',
        'कहानियाँ',
        'Histoires',
        'Historias',
        'Histórias',
        'Stories',
        'Hikâyeler',
        'Cerita',
        'গল্প'
      );
  String get openStoriesDesc => _get(
        'AI stories & comic ideas for fun',
        'تفریح کے لیے AI کہانیاں اور کامک آئیڈیاز',
        'قصص وأفكار كوميك بالذكاء الاصطناعي للمتعة',
      
        'मज़े के लिए AI कहानियाँ और कॉमिक आइडिया',
        'Histoires IA et idées de BD pour s\'amuser',
        'Historias con IA e ideas de cómic por diversión',
        'Histórias com IA e ideias de quadrinhos por diversão',
        'KI-Stories & Comic-Ideen zum Spaß',
        'Eğlence için YZ hikâyeleri ve çizgi roman fikirleri',
        'Cerita AI & ide komik untuk bersenang-senang',
        'মজার জন্য AI গল্প ও কমিক আইডিয়া'
      );
  String get learnAndPlay =>
      _get('Learn & Play', 'سیکھیں اور کھیلیں', 'تعلَّم والعب',
        'सीखें और खेलें',
        'Apprendre et jouer',
        'Aprende y juega',
        'Aprenda e divirta-se',
        'Lernen & Spielen',
        'Öğren ve Oyna',
        'Belajar & Bermain',
        'শিখুন ও খেলুন'
      );
  String get storyTab => _get('Story', 'کہانی', 'قصة',
        'कहानी',
        'Histoire',
        'Historia',
        'História',
        'Story',
        'Hikâye',
        'Cerita',
        'গল্প'
      );
  String get comicTab => _get('Comic', 'کامک', 'كوميك',
        'कॉमिक',
        'BD',
        'Cómic',
        'Quadrinhos',
        'Comic',
        'Çizgi roman',
        'Komik',
        'কমিক'
      );

  // ------------------------------ Shop (Phase 4) ------------------------------
  String get shopSearchHint =>
      _get('Search products…', 'پروڈکٹس تلاش کریں…', 'ابحث عن منتجات…',
        'प्रोडक्ट खोजें…',
        'Rechercher des produits…',
        'Buscar productos…',
        'Buscar produtos…',
        'Produkte suchen…',
        'Ürün ara…',
        'Cari produk…',
        'পণ্য খুঁজুন…'
      );
  String get shopCatAll => _get('All', 'سب', 'الكل',
        'सभी',
        'Tous',
        'Todos',
        'Todos',
        'Alle',
        'Tümü',
        'Semua',
        'সব'
      );
  String get shopCatMen => _get('Men', 'مرد', 'رجال',
        'पुरुष',
        'Hommes',
        'Hombres',
        'Homens',
        'Herren',
        'Erkek',
        'Pria',
        'পুরুষ'
      );
  String get shopCatWomen => _get('Women', 'خواتین', 'نساء',
        'महिलाएँ',
        'Femmes',
        'Mujeres',
        'Mulheres',
        'Damen',
        'Kadın',
        'Wanita',
        'নারী'
      );
  String get shopCatSale => _get('Sale', 'سیل', 'تخفيضات',
        'सेल',
        'Soldes',
        'Ofertas',
        'Promoção',
        'Sale',
        'İndirim',
        'Obral',
        'সেল'
      );
  String get shopCatBestSellers =>
      _get('Best Sellers', 'بیسٹ سیلرز', 'الأكثر مبيعًا',
        'बेस्ट सेलर',
        'Meilleures ventes',
        'Más vendidos',
        'Mais vendidos',
        'Bestseller',
        'Çok Satanlar',
        'Terlaris',
        'বেস্ট সেলার'
      );
  String get shopEmptyTitle =>
      _get('No products yet', 'ابھی کوئی پروڈکٹ نہیں', 'لا توجد منتجات بعد',
        'अभी कोई प्रोडक्ट नहीं',
        'Aucun produit pour le moment',
        'Aún no hay productos',
        'Sem produtos ainda',
        'Noch keine Produkte',
        'Henüz ürün yok',
        'Belum ada produk',
        'এখনও কোনো পণ্য নেই'
      );
  String get shopEmptyDesc => _get(
        'Be the first to list a product in the Virello Shop.',
        'وائریلو شاپ میں پہلا پروڈکٹ لسٹ کریں۔',
        'كن أول من يعرض منتجًا في متجر فيريلو.',
      
        'Virello शॉप में पहला प्रोडक्ट लिस्ट करने वाले बनें।',
        'Soyez le premier à mettre un produit en vente dans la boutique Virello.',
        'Sé el primero en publicar un producto en la tienda Virello.',
        'Seja o primeiro a anunciar um produto na loja Virello.',
        'Sei der Erste, der ein Produkt im Virello Shop listet.',
        'Virello Mağazası\'nda ilk ürünü listeleyen sen ol.',
        'Jadilah yang pertama memasang produk di Toko Virello.',
        'Virello শপে প্রথম পণ্য তালিকাভুক্ত করুন।'
      );
  String get shopSell => _get('Sell', 'بیچیں', 'بِع',
        'बेचें',
        'Vendre',
        'Vender',
        'Vender',
        'Verkaufen',
        'Sat',
        'Jual',
        'বিক্রি করুন'
      );
  String get shopBuyNow => _get('Buy Now', 'ابھی خریدیں', 'اشترِ الآن',
        'अभी खरीदें',
        'Acheter',
        'Comprar ahora',
        'Comprar agora',
        'Jetzt kaufen',
        'Hemen Al',
        'Beli Sekarang',
        'এখনই কিনুন'
      );
  String get shopCheckoutSoon => _get(
        'Checkout via PayPal / Payoneer / Google Pay is being connected. This product page is live — payment opens soon.',
        'PayPal / Payoneer / Google Pay کے ذریعے چیک آؤٹ جلد منسلک ہو رہا ہے۔ یہ پروڈکٹ پیج لائیو ہے — ادائیگی جلد کھلے گی۔',
        'الدفع عبر PayPal / Payoneer / Google Pay قيد الربط. صفحة المنتج نشطة — سيُفتح الدفع قريبًا.',
      
        'PayPal / Payoneer / Google Pay के ज़रिए चेकआउट जुड़ रहा है। यह प्रोडक्ट पेज लाइव है — भुगतान जल्द खुलेगा।',
        'Le paiement via PayPal / Payoneer / Google Pay est en cours de connexion. Cette page produit est en ligne — le paiement arrive bientôt.',
        'Estamos conectando el pago con PayPal / Payoneer / Google Pay. Esta página de producto ya está activa: el pago llegará pronto.',
        'O checkout via PayPal / Payoneer / Google Pay está sendo conectado. Esta página de produto já está no ar — o pagamento abre em breve.',
        'Der Checkout via PayPal / Payoneer / Google Pay wird gerade angebunden. Diese Produktseite ist live — die Zahlung folgt in Kürze.',
        'PayPal / Payoneer / Google Pay ile ödeme bağlanıyor. Bu ürün sayfası yayında — ödeme yakında açılacak.',
        'Checkout via PayPal / Payoneer / Google Pay sedang disambungkan. Halaman produk ini sudah live — pembayaran segera dibuka.',
        'PayPal / Payoneer / Google Pay-এর মাধ্যমে চেকআউট সংযুক্ত করা হচ্ছে। এই পণ্যের পৃষ্ঠা লাইভ — পেমেন্ট শীঘ্রই খুলবে।'
      );
  String get shopInStock => _get('In stock', 'اسٹاک میں', 'متوفر',
        'स्टॉक में',
        'En stock',
        'En stock',
        'Em estoque',
        'Auf Lager',
        'Stokta',
        'Tersedia',
        'স্টকে আছে'
      );
  String get shopOutOfStock => _get('Out of stock', 'اسٹاک ختم', 'نفد المخزون',
        'स्टॉक खत्म',
        'En rupture de stock',
        'Sin stock',
        'Fora de estoque',
        'Ausverkauft',
        'Stokta yok',
        'Stok habis',
        'স্টক শেষ'
      );
  String get shopAvailableOnAmazon => _get('Available on Amazon', 'ایمیزون پر دستیاب', 'متوفر على أمازون',
        'अमेज़न पर उपलब्ध', 'Disponible sur Amazon', 'Disponible en Amazon',
        'Disponível na Amazon', 'Auf Amazon verfügbar', 'Amazon\'da mevcut',
        'Tersedia di Amazon', 'অ্যামাজনে উপলব্ধ'
      );
  String billingPayWith(String p) => _get('Pay with $p', '$p سے ادائیگی کریں',
        'ادفع عبر $p', '$p से भुगतान करें', 'Payer avec $p',
        'Pagar con $p', 'Pagar com $p', 'Mit $p zahlen', '$p ile öde',
        'Bayar dengan $p', '$p দিয়ে পেমেন্ট করুন');
  String billingProviderUnavailable(String p) => _get(
        '$p is not available right now. Try another method.',
        '$p فی الحال دستیاب نہیں۔ کوئی اور طریقہ آزمائیں۔',
        '$p غير متاح حالياً. جرّب طريقة أخرى.',
        '$p अभी उपलब्ध नहीं है। कोई अन्य तरीका आज़माएं।',
        '$p n\'est pas disponible pour le moment. Essayez un autre moyen.',
        '$p no está disponible ahora. Prueba otro método.',
        '$p não está disponível no momento. Tente outro método.',
        '$p ist gerade nicht verfügbar. Versuchen Sie eine andere Methode.',
        '$p şu anda kullanılamıyor. Başka bir yöntem deneyin.',
        '$p tidak tersedia saat ini. Coba metode lain.',
        '$p এখন উপলব্ধ নয়। অন্য পদ্ধতি চেষ্টা করুন।');
  String get billingCouldNotOpenBrowser => _get(
        'Could not open the browser. Please try again.',
        'براؤزر نہیں کھل سکا۔ براہ کرم دوبارہ کوشش کریں۔',
        'تعذر فتح المتصفح. حاول مرة أخرى.',
        'ब्राउज़र नहीं खुल सका। कृपया पुनः प्रयास करें।',
        'Impossible d\'ouvrir le navigateur. Veuillez réessayer.',
        'No se pudo abrir el navegador. Inténtalo de nuevo.',
        'Não foi possível abrir o navegador. Tente novamente.',
        'Browser konnte nicht geöffnet werden. Bitte erneut versuchen.',
        'Tarayıcı açılamadı. Lütfen tekrar deneyin.',
        'Tidak dapat membuka browser. Silakan coba lagi.',
        'ব্রাউজার খোলা যায়নি। আবার চেষ্টা করুন।');
  String get billingProviderError => _get(
        'The payment provider returned an error. Please try again.',
        'ادائیگی فراہم کنندہ نے خرابی ظاہر کی۔ براہ کرم دوبارہ کوشش کریں۔',
        'أعاد مزوّد الدفع خطأً. حاول مرة أخرى.',
        'भुगतान प्रदाता ने त्रुटि दी। कृपया पुनः प्रयास करें।',
        'Le prestataire de paiement a renvoyé une erreur. Veuillez réessayer.',
        'El proveedor de pago devolvió un error. Inténtalo de nuevo.',
        'O provedor de pagamento retornou um erro. Tente novamente.',
        'Der Zahlungsanbieter hat einen Fehler zurückgegeben. Bitte erneut versuchen.',
        'Ödeme sağlayıcı bir hata döndürdü. Lütfen tekrar deneyin.',
        'Penyedia pembayaran mengembalikan kesalahan. Silakan coba lagi.',
        'পেমেন্ট প্রদানকারী একটি ত্রুটি দিয়েছে। আবার চেষ্টা করুন।');
  String get billingInvalidRequest => _get(
        'This purchase could not be started. Please try again.',
        'یہ خریداری شروع نہیں ہو سکی۔ براہ کرم دوبارہ کوشش کریں۔',
        'تعذر بدء هذه العملية. حاول مرة أخرى.',
        'यह खरीदारी शुरू नहीं हो सकी। कृपया पुनः प्रयास करें।',
        'Cet achat n\'a pas pu démarrer. Veuillez réessayer.',
        'Esta compra no pudo iniciarse. Inténtalo de nuevo.',
        'Esta compra não pôde ser iniciada. Tente novamente.',
        'Dieser Kauf konnte nicht gestartet werden. Bitte erneut versuchen.',
        'Bu satın alma başlatılamadı. Lütfen tekrar deneyin.',
        'Pembelian ini tidak dapat dimulai. Silakan coba lagi.',
        'এই ক্রয় শুরু করা যায়নি। আবার চেষ্টা করুন।');
  String get billingSubscribe => _get('Subscribe', 'سبسکرائب کریں', 'اشترك',
        'सब्सक्राइब करें', 'S\'abonner', 'Suscribirse', 'Assinar',
        'Abonnieren', 'Abone ol', 'Berlangganan', 'সাবস্ক্রাইব করুন');
  String get billingBuyNow => _get('Buy Now', 'ابھی خریدیں', 'اشترِ الآن',
        'अभी खरीदें', 'Acheter', 'Comprar ahora', 'Comprar agora',
        'Jetzt kaufen', 'Şimdi al', 'Beli sekarang', 'এখনই কিনুন');
  String get billingChooseProvider => _get('Choose payment method',
        'ادائیگی کا طریقہ منتخب کریں', 'اختر طريقة الدفع',
        'भुगतान विधि चुनें', 'Choisir le mode de paiement',
        'Elige método de pago', 'Escolha a forma de pagamento',
        'Zahlungsmethode wählen', 'Ödeme yöntemi seçin',
        'Pilih metode pembayaran', 'পেমেন্ট পদ্ধতি বেছে নিন');
  String get billingOrderSummary => _get('Order summary', 'آرڈر کا خلاصہ', 'ملخص الطلب',
        'ऑर्डर सारांश', 'Résumé de commande', 'Resumen del pedido',
        'Resumo do pedido', 'Bestellübersicht', 'Sipariş özeti',
        'Ringkasan pesanan', 'অর্ডারের সারাংশ');
  String get billingCompleteInBrowser => _get(
        'Complete your payment in the browser, then come back and tap below.',
        'براؤزر میں اپنی ادائیگی مکمل کریں، پھر واپس آ کر نیچے دبائیں۔',
        'أكمل الدفع في المتصفح، ثم عد واضغط أدناه.',
        'ब्राउज़र में भुगतान पूरा करें, फिर वापस आकर नीचे दबाएं।',
        'Terminez votre paiement dans le navigateur, puis revenez et appuyez ci-dessous.',
        'Completa tu pago en el navegador, luego vuelve y toca abajo.',
        'Conclua o pagamento no navegador e volte para tocar abaixo.',
        'Schließen Sie die Zahlung im Browser ab und tippen Sie dann unten.',
        'Ödemeyi tarayıcıda tamamlayın, ardından geri dönüp aşağıya dokunun.',
        'Selesaikan pembayaran di browser, lalu kembali dan ketuk di bawah.',
        'ব্রাউজারে পেমেন্ট সম্পূর্ণ করুন, তারপর ফিরে এসে নিচে চাপ দিন।');
  String get billingIvePaid => _get('I\'ve Completed Payment',
        'میں نے ادائیگی مکمل کر لی', 'لقد أكملت الدفع',
        'मैंने भुगतान पूरा कर लिया', 'J\'ai terminé le paiement',
        'He completado el pago', 'Concluí o pagamento',
        'Ich habe die Zahlung abgeschlossen', 'Ödemeyi tamamladım',
        'Saya telah menyelesaikan pembayaran', 'আমি পেমেন্ট সম্পন্ন করেছি');
  String get billingVerifying => _get('Verifying payment...',
        'ادائیگی کی تصدیق ہو رہی ہے...', 'جارٍ التحقق من الدفع...',
        'भुगतान सत्यापित हो रहा है...', 'Vérification du paiement...',
        'Verificando el pago...', 'Verificando pagamento...',
        'Zahlung wird überprüft...', 'Ödeme doğrulanıyor...',
        'Memverifikasi pembayaran...', 'পেমেন্ট যাচাই করা হচ্ছে...');
  String get billingPaymentSuccess => _get(
        'Payment successful! Your plan and credits have been updated.',
        'ادائیگی کامیاب! آپ کا پلان اور کریڈٹس اپ ڈیٹ ہو گئے ہیں۔',
        'تم الدفع بنجاح! تم تحديث خطتك واعتماداتك.',
        'भुगतान सफल! आपकी योजना और क्रेडिट अपडेट हो गए हैं।',
        'Paiement réussi ! Votre forfait et vos crédits ont été mis à jour.',
        '¡Pago exitoso! Tu plan y créditos se han actualizado.',
        'Pagamento bem-sucedido! Seu plano e créditos foram atualizados.',
        'Zahlung erfolgreich! Ihr Plan und Ihre Credits wurden aktualisiert.',
        'Ödeme başarılı! Planınız ve kredileriniz güncellendi.',
        'Pembayaran berhasil! Paket dan kredit Anda telah diperbarui.',
        'পেমেন্ট সফল! আপনার প্ল্যান এবং ক্রেডিট আপডেট হয়েছে।');
  String get billingPaymentFailed => _get(
        'Payment could not be verified. If you were charged, contact support.',
        'ادائیگی کی تصدیق نہیں ہو سکی۔ اگر رقم کٹ گئی ہے تو سپورٹ سے رابطہ کریں۔',
        'تعذر التحقق من الدفع. إذا تم الخصم منك، تواصل مع الدعم.',
        'भुगतान सत्यापित नहीं हो सका। यदि शुल्क लिया गया है, तो सहायता से संपर्क करें।',
        'Le paiement n\'a pas pu être vérifié. Si vous avez été débité, contactez l\'assistance.',
        'No se pudo verificar el pago. Si se te cobró, contacta con soporte.',
        'Não foi possível verificar o pagamento. Se foi cobrado, contacte o suporte.',
        'Die Zahlung konnte nicht verifiziert werden. Bei Belastung wenden Sie sich an den Support.',
        'Ödeme doğrulanamadı. Ücret alındıysa destek ile iletişime geçin.',
        'Pembayaran tidak dapat diverifikasi. Jika Anda dikenakan biaya, hubungi dukungan.',
        'পেমেন্ট যাচাই করা যায়নি। টাকা কাটা হলে সাপোর্টের সাথে যোগাযোগ করুন।');
  String get billingTransactionHistory => _get('Transaction history',
        'لین دین کی تاریخ', 'سجل المعاملات',
        'लेनदेन इतिहास', 'Historique des transactions',
        'Historial de transacciones', 'Histórico de transações',
        'Transaktionsverlauf', 'İşlem geçmişi',
        'Riwayat transaksi', 'লেনদেনের ইতিহাস');
  String get billingNoTransactions => _get('No transactions yet.',
        'ابھی کوئی لین دین نہیں۔', 'لا معاملات بعد.',
        'अभी तक कोई लेनदेन नहीं।', 'Aucune transaction pour le moment.',
        'Aún no hay transacciones.', 'Ainda não há transações.',
        'Noch keine Transaktionen.', 'Henüz işlem yok.',
        'Belum ada transaksi.', 'এখনও কোনো লেনদেন নেই।');
  String get billingCancel => _get('Cancel', 'منسوخ کریں', 'إلغاء',
        'रद्द करें', 'Annuler', 'Cancelar', 'Cancelar',
        'Abbrechen', 'İptal', 'Batal', 'বাতিল করুন');

  String get shopLimitedStock =>
      _get('Limited stock', 'محدود اسٹاک', 'مخزون محدود',
        'सीमित स्टॉक',
        'Stock limité',
        'Stock limitado',
        'Estoque limitado',
        'Begrenzter Bestand',
        'Sınırlı stok',
        'Stok terbatas',
        'সীমিত স্টক'
      );
  String get shopNewBadge => _get('New', 'نیا', 'جديد',
        'नया',
        'Nouveau',
        'Nuevo',
        'Novo',
        'Neu',
        'Yeni',
        'Baru',
        'নতুন'
      );
  String get shopAskVirelloAbout => _get(
        'Ask Virello about this',
        'وائریلو سے اس کے بارے میں پوچھیں',
        'اسأل فيريلو عن هذا',
      
        'इसके बारे में Virello से पूछें',
        'Demander à Virello à ce sujet',
        'Preguntar a Virello sobre esto',
        'Perguntar ao Virello sobre isto',
        'Virello dazu fragen',
        'Bunu Virello\'ya sor',
        'Tanya Virello tentang ini',
        'এটি সম্পর্কে Virello-কে জিজ্ঞাসা করুন'
      );
  String get shopRelated =>
      _get('Related products', 'متعلقہ پروڈکٹس', 'منتجات ذات صلة',
        'संबंधित प्रोडक्ट',
        'Produits associés',
        'Productos relacionados',
        'Produtos relacionados',
        'Ähnliche Produkte',
        'Benzer ürünler',
        'Produk terkait',
        'সম্পর্কিত পণ্য'
      );
  String get shopThis => _get('Shop this', 'یہ خریدیں', 'تسوَّق هذا',
        'यह खरीदें',
        'Acheter ceci',
        'Comprar esto',
        'Comprar isto',
        'Das shoppen',
        'Bunu al',
        'Beli ini',
        'এটি কিনুন'
      );
  String get shopThisDesc => _get(
        'Products in the Virello Shop matching this post',
        'اس پوسٹ سے ملتے جلتے وائریلو شاپ کے پروڈکٹس',
        'منتجات متجر فيريلو المطابقة لهذا المنشور',
      
        'इस पोस्ट से मेल खाने वाले Virello शॉप के प्रोडक्ट',
        'Produits de la boutique Virello correspondant à cette publication',
        'Productos de la tienda Virello que coinciden con esta publicación',
        'Produtos da loja Virello que combinam com esta publicação',
        'Produkte aus dem Virello Shop, die zu diesem Post passen',
        'Bu gönderiyle eşleşen Virello Mağazası ürünleri',
        'Produk di Toko Virello yang cocok dengan postingan ini',
        'এই পোস্টের সাথে মিলে যাওয়া Virello শপের পণ্য'
      );
  String get sellTitle =>
      _get('List a product', 'پروڈکٹ لسٹ کریں', 'اعرض منتجًا',
        'प्रोडक्ट लिस्ट करें',
        'Mettre un produit en vente',
        'Publicar un producto',
        'Anunciar um produto',
        'Produkt listen',
        'Ürün listele',
        'Pasang produk',
        'একটি পণ্য তালিকাভুক্ত করুন'
      );
  String get sellTitleHint =>
      _get('Product title', 'پروڈکٹ کا نام', 'اسم المنتج',
        'प्रोडक्ट का नाम',
        'Titre du produit',
        'Título del producto',
        'Título do produto',
        'Produkttitel',
        'Ürün başlığı',
        'Judul produk',
        'পণ্যের শিরোনাম'
      );
  String get sellDescHint => _get(
        'Describe your product…',
        'اپنے پروڈکٹ کی تفصیل لکھیں…',
        'صِف منتجك…',
      
        'अपने प्रोडक्ट का वर्णन करें…',
        'Décrivez votre produit…',
        'Describe tu producto…',
        'Descreva seu produto…',
        'Beschreibe dein Produkt…',
        'Ürününü anlat…',
        'Deskripsikan produkmu…',
        'আপনার পণ্যের বর্ণনা দিন…'
      );
  String get sellPriceHint => _get('Price', 'قیمت', 'السعر',
        'कीमत',
        'Prix',
        'Precio',
        'Preço',
        'Preis',
        'Fiyat',
        'Harga',
        'মূল্য'
      );
  String get sellCurrency => _get('Currency', 'کرنسی', 'العملة',
        'मुद्रा',
        'Devise',
        'Moneda',
        'Moeda',
        'Währung',
        'Para birimi',
        'Mata uang',
        'মুদ্রা'
      );
  String get sellCategory => _get('Category', 'کیٹیگری', 'الفئة',
        'श्रेणी',
        'Catégorie',
        'Categoría',
        'Categoria',
        'Kategorie',
        'Kategori',
        'Kategori',
        'বিভাগ'
      );
  String get sellImagesHint => _get(
        'Image URLs (one per line)',
        'تصویر کے URLs (ہر لائن میں ایک)',
        'روابط الصور (رابط في كل سطر)',
      
        'चित्र URL (प्रत्येक पंक्ति में एक)',
        'URL des images (une par ligne)',
        'URL de imágenes (una por línea)',
        'URLs das imagens (uma por linha)',
        'Bild-URLs (eine pro Zeile)',
        'Görsel URL\'leri (satır başına bir)',
        'URL gambar (satu per baris)',
        'ছবির URL (প্রতি লাইনে একটি)'
      );
  String get sellStockHint =>
      _get('Stock quantity', 'اسٹاک کی تعداد', 'كمية المخزون',
        'स्टॉक मात्रा',
        'Quantité en stock',
        'Cantidad en stock',
        'Quantidade em estoque',
        'Bestandsmenge',
        'Stok miktarı',
        'Jumlah stok',
        'স্টকের পরিমাণ'
      );
  String get sellIsAffiliate => _get(
        'This is an affiliate product',
        'یہ ایفیلی ایٹ پروڈکٹ ہے',
        'هذا منتج تابع',
      
        'यह एक एफ़िलिएट प्रोडक्ट है',
        'Ceci est un produit affilié',
        'Este es un producto de afiliado',
        'Este é um produto de afiliado',
        'Dies ist ein Affiliate-Produkt',
        'Bu bir satış ortaklığı ürünü',
        'Ini produk afiliasi',
        'এটি একটি অ্যাফিলিয়েট পণ্য'
      );
  String get sellAffiliateUrlHint => _get(
        'Affiliate link (https://…)',
        'ایفیلی ایٹ لنک (https://…)',
        'رابط التابع (https://…)',
      
        'एफ़िलिएट लिंक (https://…)',
        'Lien affilié (https://…)',
        'Enlace de afiliado (https://…)',
        'Link de afiliado (https://…)',
        'Affiliate-Link (https://…)',
        'Satış ortaklığı bağlantısı (https://…)',
        'Tautan afiliasi (https://…)',
        'অ্যাফিলিয়েট লিঙ্ক (https://…)'
      );
  String get sellAffiliateProvider =>
      _get('Affiliate provider', 'ایفیلی ایٹ فراہم کنندہ', 'مزوّد التابع',
        'एफ़िलिएट प्रदाता',
        'Fournisseur affilié',
        'Proveedor de afiliado',
        'Provedor de afiliado',
        'Affiliate-Anbieter',
        'Satış ortaklığı sağlayıcısı',
        'Penyedia afiliasi',
        'অ্যাফিলিয়েট প্রদানকারী'
      );
  String get sellSubmit =>
      _get('List product', 'پروڈکٹ لسٹ کریں', 'اعرض المنتج',
        'प्रोडक्ट लिस्ट करें',
        'Mettre en vente',
        'Publicar producto',
        'Anunciar produto',
        'Produkt listen',
        'Ürünü listele',
        'Pasang produk',
        'পণ্য তালিকাভুক্ত করুন'
      );
  String get sellSuccess => _get(
        'Product listed successfully!',
        'پروڈکٹ کامیابی سے لسٹ ہو گیا!',
        'تم عرض المنتج بنجاح!',
      
        'प्रोडक्ट सफलतापूर्वक लिस्ट हो गया!',
        'Produit mis en vente avec succès !',
        '¡Producto publicado con éxito!',
        'Produto anunciado com sucesso!',
        'Produkt erfolgreich gelistet!',
        'Ürün başarıyla listelendi!',
        'Produk berhasil dipasang!',
        'পণ্য সফলভাবে তালিকাভুক্ত হয়েছে!'
      );
  String get sellFailed => _get(
        'Couldn\'t list the product. Check the fields and try again.',
        'پروڈکٹ لسٹ نہ ہو سکا۔ فیلڈز چیک کریں اور دوبارہ کوشش کریں۔',
        'تعذّر عرض المنتج. تحقق من الحقول وحاول مجددًا.',
      
        'प्रोडक्ट लिस्ट नहीं हो सका। फ़ील्ड जाँचें और फिर कोशिश करें।',
        'Impossible de mettre le produit en vente. Vérifiez les champs et réessayez.',
        'No se pudo publicar el producto. Revisa los campos e inténtalo de nuevo.',
        'Não foi possível anunciar o produto. Verifique os campos e tente novamente.',
        'Das Produkt konnte nicht gelistet werden. Prüfe die Felder und versuch es erneut.',
        'Ürün listelenemedi. Alanları kontrol et ve tekrar dene.',
        'Tidak dapat memasang produk. Periksa kolomnya dan coba lagi.',
        'পণ্য তালিকাভুক্ত করা যায়নি। ক্ষেত্রগুলো পরীক্ষা করে আবার চেষ্টা করুন।'
      );
  String get sellNeedTitlePrice => _get(
        'Title and a valid price are required.',
        'نام اور درست قیمت ضروری ہے۔',
        'الاسم والسعر الصحيح مطلوبان.',
      
        'नाम और सही कीमत आवश्यक है।',
        'Le titre et un prix valide sont requis.',
        'Se requieren el título y un precio válido.',
        'Título e preço válido são obrigatórios.',
        'Titel und ein gültiger Preis sind erforderlich.',
        'Başlık ve geçerli bir fiyat gerekli.',
        'Judul dan harga yang valid wajib diisi.',
        'শিরোনাম ও একটি বৈধ মূল্য প্রয়োজন।'
      );
  String get sellNeedAffiliateUrl => _get(
        'An affiliate product needs a valid http(s) affiliate link.',
        'ایفیلی ایٹ پروڈکٹ کے لیے درست http(s) لنک ضروری ہے۔',
        'المنتج التابع يحتاج رابط تابع http(s) صالحًا.',
      
        'एफ़िलिएट प्रोडक्ट के लिए सही http(s) एफ़िलिएट लिंक चाहिए।',
        'Un produit affilié nécessite un lien affilié http(s) valide.',
        'Un producto de afiliado necesita un enlace de afiliado http(s) válido.',
        'Um produto de afiliado precisa de um link de afiliado http(s) válido.',
        'Ein Affiliate-Produkt braucht einen gültigen http(s)-Affiliate-Link.',
        'Satış ortaklığı ürünü için geçerli bir http(s) satış ortaklığı bağlantısı gerekli.',
        'Produk afiliasi memerlukan tautan afiliasi http(s) yang valid.',
        'অ্যাফিলিয়েট পণ্যের জন্য একটি বৈধ http(s) অ্যাফিলিয়েট লিঙ্ক প্রয়োজন।'
      );
  String get shopSortNote => _get(
        'Ranked by product page views (sales tracking coming soon)',
        'پروڈکٹ پیج ویوز کے حساب سے ترتیب (سیلز ٹریکنگ جلد آ رہی ہے)',
        'مرتّبة حسب مشاهدات صفحة المنتج (تتبّع المبيعات قريبًا)',
      
        'प्रोडक्ट पेज व्यू के अनुसार क्रम (बिक्री ट्रैकिंग जल्द आ रही है)',
        'Classé par vues de page produit (suivi des ventes bientôt disponible)',
        'Ordenado por vistas de página del producto (seguimiento de ventas próximamente)',
        'Classificado por visualizações da página do produto (rastreamento de vendas em breve)',
        'Sortiert nach Produktseitenaufrufen (Verkaufs-Tracking kommt bald)',
        'Ürün sayfası görüntülenmelerine göre sıralandı (satış takibi yakında)',
        'Diurutkan berdasarkan tampilan halaman produk (pelacakan penjualan segera hadir)',
        'পণ্য পৃষ্ঠার ভিউ অনুযায়ী সাজানো (বিক্রি ট্র্যাকিং শীঘ্রই আসছে)'
      );

  // ---- Lavish Shop rebuild (Phase 4 UI refresh) ----
  String get shopTitleBar => _get('Shop', 'شاپ', 'المتجر',
        'शॉप',
        'Boutique',
        'Tienda',
        'Loja',
        'Shop',
        'Mağaza',
        'Toko',
        'শপ'
      );
  String get shopCatalogTitle => _get('SHOP', 'شاپ', 'المتجر',
        'शॉप',
        'BOUTIQUE',
        'TIENDA',
        'LOJA',
        'SHOP',
        'MAĞAZA',
        'TOKO',
        'শপ'
      );
  String get shopYouMightLike =>
      _get('You might like', 'آپ کو پسند آ سکتا ہے', 'قد يعجبك',
        'आपको पसंद आ सकता है',
        'Vous aimerez peut-être',
        'Te puede gustar',
        'Você pode gostar',
        'Das könnte dir gefallen',
        'Bunları beğenebilirsin',
        'Kamu mungkin suka',
        'আপনার পছন্দ হতে পারে'
      );
  String get shopViewAll => _get('view all', 'سب دیکھیں', 'عرض الكل',
        'सभी देखें',
        'tout voir',
        'ver todo',
        'ver tudo',
        'alle ansehen',
        'tümünü gör',
        'lihat semua',
        'সব দেখুন'
      );
  String get shopTrending => _get('Trending', 'ٹرینڈنگ', 'الرائج',
        'ट्रेंडिंग',
        'Tendances',
        'Tendencias',
        'Em alta',
        'Trending',
        'Trend',
        'Trending',
        'ট্রেন্ডিং'
      );
  String get shopRecommendedForYou =>
      _get('Recommended for you', 'آپ کے لیے تجویز کردہ', 'موصى به لك',
        'आपके लिए सुझाव',
        'Recommandé pour vous',
        'Recomendado para ti',
        'Recomendado para você',
        'Für dich empfohlen',
        'Senin için önerilenler',
        'Direkomendasikan untukmu',
        'আপনার জন্য প্রস্তাবিত'
      );
  String get shopPostDetails =>
      _get('POST DETAILS', 'پوسٹ کی تفصیلات', 'تفاصيل المنشور',
        'पोस्ट विवरण',
        'DÉTAILS DE LA PUBLICATION',
        'DETALLES DE LA PUBLICACIÓN',
        'DETALHES DA PUBLICAÇÃO',
        'POST-DETAILS',
        'GÖNDERİ DETAYLARI',
        'DETAIL POSTINGAN',
        'পোস্টের বিবরণ'
      );
  String get shopMore => _get('more', 'مزید', 'المزيد',
        'और',
        'plus',
        'más',
        'mais',
        'mehr',
        'daha fazla',
        'lainnya',
        'আরও'
      );
  String get shopVirelloShop =>
      _get('Virello Shop', 'وائریلو شاپ', 'متجر فيريلو',
        'Virello शॉप',
        'Boutique Virello',
        'Tienda Virello',
        'Loja Virello',
        'Virello Shop',
        'Virello Mağazası',
        'Toko Virello',
        'Virello শপ'
      );
  String get shopSortBy => _get('Sort by', 'ترتیب دیں', 'ترتيب حسب',
        'क्रमबद्ध करें',
        'Trier par',
        'Ordenar por',
        'Ordenar por',
        'Sortieren nach',
        'Sırala',
        'Urutkan',
        'অনুযায়ী সাজান'
      );
  String get shopSortNewest => _get('Newest', 'جدید ترین', 'الأحدث',
        'नवीनतम',
        'Plus récents',
        'Más recientes',
        'Mais recentes',
        'Neueste',
        'En yeniler',
        'Terbaru',
        'সর্বশেষ'
      );
  String get shopSortPriceAsc => _get(
        'Price: Low to High',
        'قیمت: کم سے زیادہ',
        'السعر: من الأقل إلى الأعلى',
      
        'कीमत: कम से ज़्यादा',
        'Prix : croissant',
        'Precio: de menor a mayor',
        'Preço: do menor ao maior',
        'Preis: aufsteigend',
        'Fiyat: Düşükten yükseğe',
        'Harga: Rendah ke Tinggi',
        'মূল্য: কম থেকে বেশি'
      );
  String get shopSortPriceDesc => _get(
        'Price: High to Low',
        'قیمت: زیادہ سے کم',
        'السعر: من الأعلى إلى الأقل',
      
        'कीमत: ज़्यादा से कम',
        'Prix : décroissant',
        'Precio: de mayor a menor',
        'Preço: do maior ao menor',
        'Preis: absteigend',
        'Fiyat: Yüksekten düşüğe',
        'Harga: Tinggi ke Rendah',
        'মূল্য: বেশি থেকে কম'
      );
  String get shopSortPopular =>
      _get('Most popular', 'مقبول ترین', 'الأكثر شعبية',
        'सबसे लोकप्रिय',
        'Les plus populaires',
        'Más populares',
        'Mais populares',
        'Beliebteste',
        'En popüler',
        'Terpopuler',
        'সবচেয়ে জনপ্রিয়'
      );
  String get shopCheckPriceAmazon => _get(
        'Check price on Amazon',
        'ایمیزون پر قیمت دیکھیں',
        'تحقق من السعر على أمازون',
      
        'Amazon पर कीमत देखें',
        'Voir le prix sur Amazon',
        'Ver el precio en Amazon',
        'Ver o preço na Amazon',
        'Preis auf Amazon prüfen',
        'Amazon\'da fiyatı gör',
        'Cek harga di Amazon',
        'Amazon-এ মূল্য দেখুন'
      );
  String get shopLinkCopied =>
      _get('Link copied', 'لنک کاپی ہو گیا', 'تم نسخ الرابط',
        'लिंक कॉपी हो गया',
        'Lien copié',
        'Enlace copiado',
        'Link copiado',
        'Link kopiert',
        'Bağlantı kopyalandı',
        'Tautan tersalin',
        'লিঙ্ক কপি হয়েছে'
      );
  String get shopClearFilters =>
      _get('Clear filters', 'فلٹر صاف کریں', 'مسح المرشحات',
        'फ़िल्टर साफ़ करें',
        'Effacer les filtres',
        'Borrar filtros',
        'Limpar filtros',
        'Filter zurücksetzen',
        'Filtreleri temizle',
        'Hapus filter',
        'ফিল্টার মুছুন'
      );
  String get shopCatTech => _get('Tech', 'ٹیک', 'تقنية',
        'टेक',
        'Tech',
        'Tecnología',
        'Tech',
        'Tech',
        'Teknoloji',
        'Teknologi',
        'টেক'
      );
  String get shopCatFashion => _get('Fashion', 'فیشن', 'أزياء',
        'फ़ैशन',
        'Mode',
        'Moda',
        'Moda',
        'Fashion',
        'Moda',
        'Fashion',
        'ফ্যাশন'
      );
  String get shopCatHome => _get('Home', 'گھر', 'المنزل',
        'घर',
        'Maison',
        'Hogar',
        'Casa',
        'Zuhause',
        'Ev',
        'Rumah',
        'বাড়ি'
      );
  String get shopCatFitness => _get('Fitness', 'فٹنس', 'لياقة',
        'फ़िटनेस',
        'Fitness',
        'Fitness',
        'Fitness',
        'Fitness',
        'Fitness',
        'Kebugaran',
        'ফিটনেস'
      );
  String get shopCatBeauty => _get('Beauty', 'بیوٹی', 'جمال',
        'ब्यूटी',
        'Beauté',
        'Belleza',
        'Beleza',
        'Beauty',
        'Güzellik',
        'Kecantikan',
        'বিউটি'
      );
  String get shopCatComputers => _get('Computers', 'کمپیوٹر', 'كمبيوتر',
        'कंप्यूटर',
        'Ordinateurs',
        'Computadoras',
        'Computadores',
        'Computer',
        'Bilgisayarlar',
        'Komputer',
        'কম্পিউটার'
      );
  String get shopCatSmartHome => _get('Smart Home', 'اسمارٹ ہوم', 'المنزل الذكي',
        'स्मार्ट होम',
        'Maison connectée',
        'Hogar inteligente',
        'Casa inteligente',
        'Smart Home',
        'Akıllı Ev',
        'Rumah Pintar',
        'স্মার্ট হোম'
      );
  String get shopCatArtsCrafts => _get('Arts & Crafts', 'آرٹس اور کرافٹس', 'الفنون والحرف',
        'कला और शिल्प',
        'Arts créatifs',
        'Arte y manualidades',
        'Artesanato',
        'Basteln',
        'El Sanatları',
        'Seni & Kerajinan',
        'হস্তশিল্প'
      );
  String get shopCatAutomotive => _get('Automotive', 'آٹوموٹو', 'السيارات',
        'ऑटोमोटिव',
        'Automobile',
        'Automoción',
        'Automotivo',
        'Auto',
        'Otomotiv',
        'Otomotif',
        'অটোমোটিভ'
      );
  String get shopCatBaby => _get('Baby', 'بچے', 'الأطفال',
        'बच्चे',
        'Bébé',
        'Bebé',
        'Bebê',
        'Baby',
        'Bebek',
        'Bayi',
        'শিশু'
      );
  String get shopCatHealth => _get('Health', 'صحت', 'الصحة',
        'स्वास्थ्य',
        'Santé',
        'Salud',
        'Saúde',
        'Gesundheit',
        'Sağlık',
        'Kesehatan',
        'স্বাস্থ্য'
      );
  String get shopCatIndustrial => _get('Industrial', 'صنعتی', 'صناعي',
        'औद्योगिक',
        'Industriel',
        'Industrial',
        'Industrial',
        'Industrie',
        'Endüstriyel',
        'Industri',
        'শিল্প'
      );
  String get shopCatLuggage => _get('Luggage', 'سامان سفر', 'الأمتعة',
        'सामान',
        'Bagages',
        'Equipaje',
        'Bagagem',
        'Gepäck',
        'Bavul',
        'Bagasi',
        'লাগেজ'
      );
  String get shopCatMoviesTv => _get('Movies & TV', 'فلمیں اور ٹی وی', 'أفلام وتلفاز',
        'फिल्में',
        'Films et TV',
        'Cine y TV',
        'Filmes e TV',
        'Filme & TV',
        'Film & TV',
        'Film & TV',
        'সিনেমা'
      );
  String get shopCatPetSupplies => _get('Pet Supplies', 'پالتو سامان', 'مستلزمات الحيوانات',
        'पालतू सामान',
        'Animalerie',
        'Mascotas',
        'Pets',
        'Haustierbedarf',
        'Evcil Hayvan',
        'Hewan Peliharaan',
        'পোষা প্রাণী'
      );
  String get shopCatSoftware => _get('Software', 'سافٹ ویئر', 'برمجيات',
        'सॉफ्टवेयर',
        'Logiciels',
        'Software',
        'Software',
        'Software',
        'Yazılım',
        'Perangkat Lunak',
        'সফটওয়্যার'
      );
  String get shopCatSports => _get('Sports', 'کھیل', 'الرياضة',
        'खेल',
        'Sports',
        'Deportes',
        'Esportes',
        'Sport',
        'Spor',
        'Olahraga',
        'খেলাধুলা'
      );
  String get shopCatTools => _get('Tools', 'اوزار', 'أدوات',
        'उपकरण',
        'Outils',
        'Herramientas',
        'Ferramentas',
        'Werkzeuge',
        'Aletler',
        'Perkakas',
        'যন্ত্রপাতি'
      );
  String get shopCatToys => _get('Toys & Games', 'کھلونے', 'ألعاب',
        'खिलौने',
        'Jouets',
        'Juguetes',
        'Brinquedos',
        'Spielzeug',
        'Oyuncaklar',
        'Mainan',
        'খেলনা'
      );
  String get shopCatVideoGames => _get('Video Games', 'ویڈیو گیمز', 'ألعاب الفيديو',
        'वीडियो गेम',
        'Jeux vidéo',
        'Videojuegos',
        'Videogames',
        'Videospiele',
        'Video Oyunları',
        'Video Game',
        'ভিডিও গেম'
      );
  String get shopCatGrocery => _get('Grocery', 'کریانہ', 'بقالة',
        'किराना',
        'Épicerie',
        'Comestibles',
        'Mercearia',
        'Lebensmittel',
        'Market',
        'Kelontong',
        'মুদি'
      );
  String get shopCatHandmade => _get('Handmade', 'ہاتھ سے بنا', 'مصنوع يدويًا',
        'हस्तनिर्मित',
        'Fait main',
        'Hecho a mano',
        'Artesanal',
        'Handgemacht',
        'El Yapımı',
        'Buatan Tangan',
        'হস্তনির্মিত'
      );
  String get shopCatBooks => _get('Books', 'کتابیں', 'كتب',
        'किताबें',
        'Livres',
        'Libros',
        'Livros',
        'Bücher',
        'Kitaplar',
        'Buku',
        'বই'
      );
  String get shopCatOffice => _get('Office', 'دفتری سامان', 'مستلزمات مكتبية',
        'कार्यालय',
        'Bureau',
        'Oficina',
        'Escritório',
        'Büro',
        'Ofis',
        'Kantor',
        'অফিস'
      );
  String get shopCatPhones => _get('Phones', 'فون', 'هواتف',
        'फोन',
        'Téléphones',
        'Teléfonos',
        'Celulares',
        'Handys',
        'Telefon',
        'Ponsel',
        'ফোন'
      );
  String get shopCatCollectibles => _get('Collectibles', 'نایاب اشیاء', 'مقتنيات',
        'संग्रहणीय',
        'Collections',
        'Coleccionables',
        'Colecionáveis',
        'Sammlerstücke',
        'Koleksiyon',
        'Koleksi',
        'সংগ্রহ'
      );
  String get shopTrendingProducts => _get('Trending Products', 'ٹرینڈنگ پروڈکٹس', 'منتجات رائجة',
        'ट्रेंडिंग उत्पाद', 'Produits tendance', 'Productos en tendencia',
        'Produtos em alta', 'Trendprodukte', 'Trend Ürünler',
        'Produk Tren', 'ট্রেন্ডিং পণ্য');
  String get boardTrendingTopics => _get('Trending Topics', 'ٹرینڈنگ موضوعات', 'مواضيع رائجة',
        'ट्रेंडिंग विषय', 'Sujets tendance', 'Temas en tendencia',
        'Tópicos em alta', 'Trendthemen', 'Trend Konular',
        'Topik Tren', 'ট্রেন্ডিং বিষয়');
  String get shopListYours => _get('List yours', 'اپنا لسٹ کریں', 'اعرض منتجك',
        'अपना लिस्ट करें',
        'Mettez le vôtre en vente',
        'Publica el tuyo',
        'Anuncie o seu',
        'Liste deins',
        'Seninkini listele',
        'Pasang punyamu',
        'আপনারটা তালিকাভুক্ত করুন'
      );
  String get timeNow => _get('now', 'ابھی', 'الآن',
        'अभी',
        'à l\'instant',
        'ahora',
        'agora',
        'gerade eben',
        'şimdi',
        'baru saja',
        'এখন'
      );
  String timeMinAgo(int n) => _get('$n min ago', '$n منٹ پہلے', 'منذ $n دقيقة',
        '$n मिनट पहले',
        'il y a $n min',
        'hace $n min',
        'há $n min',
        'vor $n Min.',
        '$n dk önce',
        '$n mnt lalu',
        '$n মিনিট আগে'
      );
  String timeHoursAgo(int n) =>
      _get('$n hr ago', '$n گھنٹے پہلے', 'منذ $n ساعة',
        '$n घंटे पहले',
        'il y a $n h',
        'hace $n h',
        'há $n h',
        'vor $n Std.',
        '$n sa önce',
        '$n jam lalu',
        '$n ঘণ্টা আগে'
      );
  String timeDaysAgo(int n) => _get('$n days ago', '$n دن پہلے', 'منذ $n يوم',
        '$n दिन पहले',
        'il y a $n j',
        'hace $n días',
        'há $n dias',
        'vor $n Tagen',
        '$n gün önce',
        '$n hari lalu',
        '$n দিন আগে'
      );

  // ---- Discover feed rebuild ----
  String get discoverForYou => _get('For You', 'آپ کے لیے', 'لك',
        'आपके लिए',
        'Pour vous',
        'Para ti',
        'Para você',
        'Für dich',
        'Senin için',
        'Untukmu',
        'আপনার জন্য'
      );
  String get discoverSearchHint =>
      _get('Search posts…', 'پوسٹس تلاش کریں…', 'ابحث في المنشورات…',
        'पोस्ट खोजें…',
        'Rechercher des publications…',
        'Buscar publicaciones…',
        'Buscar publicações…',
        'Posts suchen…',
        'Gönderi ara…',
        'Cari postingan…',
        'পোস্ট খুঁজুন…'
      );
  String get discoverNotifications =>
      _get('Notifications', 'اطلاعات', 'الإشعارات',
        'सूचनाएँ',
        'Notifications',
        'Notificaciones',
        'Notificações',
        'Benachrichtigungen',
        'Bildirimler',
        'Notifikasi',
        'নোটিফিকেশন'
      );
  String get discoverNoNotifications => _get(
        'No notifications yet',
        'ابھی کوئی اطلاع نہیں',
        'لا توجد إشعارات بعد',
      
        'अभी कोई सूचना नहीं',
        'Aucune notification pour le moment',
        'Aún no hay notificaciones',
        'Sem notificações ainda',
        'Noch keine Benachrichtigungen',
        'Henüz bildirim yok',
        'Belum ada notifikasi',
        'এখনও কোনো নোটিফিকেশন নেই'
      );
  String get discoverAskVirello =>
      _get('Ask Virello', 'وائریلو سے پوچھیں', 'اسأل فيريلو',
        'Virello से पूछें',
        'Demander à Virello',
        'Preguntar a Virello',
        'Perguntar ao Virello',
        'Virello fragen',
        'Virello\'ya Sor',
        'Tanya Virello',
        'Virello-কে জিজ্ঞাসা করুন'
      );
  String get discoverSavedTitle => _get('Saved', 'محفوظ شدہ', 'المحفوظة',
        'सेव हो गया',
        'Enregistré',
        'Guardado',
        'Salvo',
        'Gespeichert',
        'Kaydedildi',
        'Tersimpan',
        'সেভ হয়েছে'
      );
  String get discoverLearnPlay =>
      _get('Learn & Play', 'سیکھیں اور کھیلیں', 'تعلّم والعب',
        'सीखें और खेलें',
        'Apprendre et jouer',
        'Aprende y juega',
        'Aprenda e divirta-se',
        'Lernen & Spielen',
        'Öğren ve Oyna',
        'Belajar & Bermain',
        'শিখুন ও খেলুন'
      );

  // ---- 2026-09-29 master board: auth flow (screens 01-06) ----
  String get boardIdeasAmplified => _get(
        'Your ideas. Amplified.',
        'آپ کے خیالات۔ نئی بلندیوں پر۔',
        'أفكارك. بتضخيم.',
      
        'आपके आइडिया। नई ऊँचाइयों पर।',
        'Vos idées. Amplifiées.',
        'Tus ideas. Amplificadas.',
        'Suas ideias. Amplificadas.',
        'Deine Ideen. Verstärkt.',
        'Fikirlerin. Güçlendirildi.',
        'Idemu. Diperkuat.',
        'আপনার আইডিয়া। নতুন উচ্চতায়।'
      );
  String get boardWelcomeTitle => _get(
        'Welcome to Virello AI',
        'Virello AI میں خوش آمدید',
        'مرحباً بك في Virello AI',
      
        'Virello AI में आपका स्वागत है',
        'Bienvenue sur Virello IA',
        'Bienvenido a Virello IA',
        'Bem-vindo ao Virello IA',
        'Willkommen bei Virello KI',
        'Virello YZ\'ye hoş geldin',
        'Selamat datang di Virello AI',
        'Virello AI-তে স্বাগতম'
      );
  String get boardWelcomeDesc => _get(
        'Create amazing content, grow your audience, sell your products and just learn new skills — all in one place.',
        'شاندار مواد بنائیں، اپنے ناظرین بڑھائیں، اپنی مصنوعات بیچیں اور نئی مہارتیں سیکھیں — سب ایک جگہ۔',
        'أنشئ محتوى رائعاً، ونمِّ جمهورك، وبِع منتجاتك، وتعلّم مهارات جديدة — كل ذلك في مكان واحد.',
      
        'शानदार कंटेंट बनाएँ, अपनी ऑडियंस बढ़ाएँ, अपने प्रोडक्ट बेचें और नई स्किल सीखें — सब एक जगह।',
        'Créez du contenu incroyable, développez votre audience, vendez vos produits et apprenez de nouvelles compétences — tout au même endroit.',
        'Crea contenido increíble, haz crecer tu audiencia, vende tus productos y aprende nuevas habilidades, todo en un solo lugar.',
        'Crie conteúdo incrível, aumente seu público, venda seus produtos e aprenda novas habilidades — tudo em um só lugar.',
        'Erstelle großartigen Content, vergrößere deine Zielgruppe, verkaufe deine Produkte und lerne neue Skills — alles an einem Ort.',
        'Harika içerikler oluştur, kitleni büyüt, ürünlerini sat ve yeni beceriler öğren — hepsi tek yerde.',
        'Buat konten luar biasa, kembangkan audiensmu, jual produkmu, dan pelajari keterampilan baru — semuanya di satu tempat.',
        'চমৎকার কনটেন্ট তৈরি করুন, আপনার অডিয়েন্স বাড়ান, আপনার পণ্য বিক্রি করুন এবং নতুন দক্ষতা শিখুন — সব এক জায়গায়।'
      );
  String get boardCreateAccount =>
      _get('Create Account', 'اکاؤنٹ بنائیں', 'إنشاء حساب',
        'खाता बनाएँ',
        'Créer un compte',
        'Crear cuenta',
        'Criar conta',
        'Konto erstellen',
        'Hesap Oluştur',
        'Buat Akun',
        'অ্যাকাউন্ট তৈরি করুন'
      );
  String get boardFullName => _get('Full name', 'پورا نام', 'الاسم الكامل',
        'पूरा नाम',
        'Nom complet',
        'Nombre completo',
        'Nome completo',
        'Vollständiger Name',
        'Ad Soyad',
        'Nama lengkap',
        'পুরো নাম'
      );
  String get boardSelectLanguage =>
      _get('Select Language', 'زبان منتخب کریں', 'اختر اللغة',
        'भाषा चुनें',
        'Choisir la langue',
        'Seleccionar idioma',
        'Selecionar idioma',
        'Sprache wählen',
        'Dil Seç',
        'Pilih Bahasa',
        'ভাষা নির্বাচন করুন'
      );
  String get boardInterestedIn => _get(
        'What are you interested in?',
        'آپ کو کس چیز میں دلچسپی ہے؟',
        'ما الذي يهمك؟',
      
        'आपकी दिलचस्पी किसमें है?',
        'Qu\'est-ce qui vous intéresse ?',
        '¿Qué te interesa?',
        'O que te interessa?',
        'Wofür interessierst du dich?',
        'Nelerle ilgileniyorsun?',
        'Kamu tertarik pada apa?',
        'আপনি কীসে আগ্রহী?'
      );
  String get boardWelcomeBack =>
      _get('Welcome Back', 'واپس خوش آمدید', 'مرحباً بعودتك',
        'वापसी पर स्वागत है',
        'Bon retour',
        'Bienvenido de nuevo',
        'Bem-vindo de volta',
        'Willkommen zurück',
        'Tekrar hoş geldin',
        'Selamat datang kembali',
        'আবার স্বাগতম'
      );

  // ---- 2026-09-29 master board: phase 3 home + main tabs (07-12, 21/22) ----
  String get boardGoodMorning => _get('Good morning', 'صبح بخیر', 'صباح الخير',
        'सुप्रभात',
        'Bonjour',
        'Buenos días',
        'Bom dia',
        'Guten Morgen',
        'Günaydın',
        'Selamat pagi',
        'শুভ সকাল'
      );
  String get boardGoodAfternoon =>
      _get('Good afternoon', 'دوپہر بخیر', 'طاب يومك',
        'शुभ दोपहर',
        'Bon après-midi',
        'Buenas tardes',
        'Boa tarde',
        'Guten Tag',
        'Tünaydın',
        'Selamat siang',
        'শুভ দুপুর'
      );
  String get boardGoodEvening => _get('Good evening', 'شام بخیر', 'مساء الخير',
        'शुभ संध्या',
        'Bonsoir',
        'Buenas noches',
        'Boa noite',
        'Guten Abend',
        'İyi akşamlar',
        'Selamat malam',
        'শুভ সন্ধ্যা'
      );
  String get boardActiveCampaigns =>
      _get('Active Campaigns', 'فعال مہمات', 'الحملات النشطة',
        'सक्रिय अभियान',
        'Campagnes actives',
        'Campañas activas',
        'Campanhas ativas',
        'Aktive Kampagnen',
        'Aktif kampanyalar',
        'Kampanye aktif',
        'সক্রিয় ক্যাম্পেইন'
      );
  String get boardAiRecommendations =>
      _get('AI Recommendations', 'AI تجاویز', 'توصيات الذكاء الاصطناعي',
        'AI सुझाव',
        'Recommandations IA',
        'Recomendaciones de IA',
        'Recomendações de IA',
        'KI-Empfehlungen',
        'YZ önerileri',
        'Rekomendasi AI',
        'AI সুপারিশ'
      );
  String get boardViewAll => _get('View all', 'سب دیکھیں', 'عرض الكل',
        'सभी देखें',
        'Tout voir',
        'Ver todo',
        'Ver tudo',
        'Alle ansehen',
        'Tümünü gör',
        'Lihat semua',
        'সব দেখুন'
      );
  String get boardQuickCreate => _get('Create', 'تخلیق', 'أنشئ',
        'बनाएँ',
        'Créer',
        'Crear',
        'Criar',
        'Erstellen',
        'Oluştur',
        'Buat',
        'তৈরি করুন'
      );
  String get boardQuickCreateDesc =>
      _get('Make content', 'مواد بنائیں', 'أنشئ محتوى',
        'कंटेंट बनाएँ',
        'Créer du contenu',
        'Crear contenido',
        'Criar conteúdo',
        'Content erstellen',
        'İçerik oluştur',
        'Buat konten',
        'কনটেন্ট তৈরি করুন'
      );
  String get boardQuickGrow => _get('Grow', 'گرو', 'نمِّ',
        'ग्रो',
        'Croissance',
        'Crecer',
        'Crescer',
        'Wachstum',
        'Büyüme',
        'Grow',
        'গ্রো'
      );
  String get boardQuickGrowDesc =>
      _get('Boost reach', 'رسائی بڑھائیں', 'عزّز الوصول',
        'रीच बढ़ाएँ',
        'Booster la portée',
        'Impulsa el alcance',
        'Impulsione o alcance',
        'Reichweite boosten',
        'Erişimi artır',
        'Tingkatkan jangkauan',
        'রিচ বাড়ান'
      );
  String get boardQuickShop => _get('Shop', 'شاپ', 'تسوّق',
        'शॉप',
        'Boutique',
        'Tienda',
        'Loja',
        'Shop',
        'Mağaza',
        'Toko',
        'শপ'
      );
  String get boardQuickShopDesc =>
      _get('Buy & sell', 'خریدیں و بیچیں', 'اشترِ وبِع',
        'खरीदें और बेचें',
        'Acheter et vendre',
        'Compra y vende',
        'Compre e venda',
        'Kaufen & verkaufen',
        'Al ve sat',
        'Beli & jual',
        'কিনুন ও বিক্রি করুন'
      );
  String get boardQuickLearn => _get('Learn', 'سیکھیں', 'تعلَّم',
        'सीखें',
        'Apprendre',
        'Aprender',
        'Aprender',
        'Lernen',
        'Öğren',
        'Belajar',
        'শিখুন'
      );
  String get boardQuickLearnDesc =>
      _get('AI Academy', 'AI اکیڈمی', 'أكاديمية الذكاء الاصطناعي',
        'AI अकादमी',
        'Académie IA',
        'Academia IA',
        'Academia IA',
        'KI-Academy',
        'YZ Akademisi',
        'Akademi AI',
        'AI অ্যাকাডেমি'
      );
  String get boardNoActiveCampaigns => _get(
        'No active campaigns yet',
        'ابھی کوئی فعال مہم نہیں',
        'لا توجد حملات نشطة بعد',
      
        'अभी कोई सक्रिय अभियान नहीं',
        'Aucune campagne active pour le moment',
        'Aún no hay campañas activas',
        'Sem campanhas ativas ainda',
        'Noch keine aktiven Kampagnen',
        'Henüz aktif kampanya yok',
        'Belum ada kampanye aktif',
        'এখনও কোনো সক্রিয় ক্যাম্পেইন নেই'
      );
  String get boardStartCampaign =>
      _get('Start a campaign', 'مہم شروع کریں', 'ابدأ حملة',
        'अभियान शुरू करें',
        'Lancer une campagne',
        'Iniciar una campaña',
        'Iniciar uma campanha',
        'Kampagne starten',
        'Kampanya başlat',
        'Mulai kampanye',
        'একটি ক্যাম্পেইন শুরু করুন'
      );
  String get boardWhatToCreate => _get(
        'What do you want to create?',
        'آپ کیا بنانا چاہتے ہیں؟',
        'ماذا تريد أن تنشئ؟',
      
        'आप क्या बनाना चाहते हैं?',
        'Que voulez-vous créer ?',
        '¿Qué quieres crear?',
        'O que você quer criar?',
        'Was möchtest du erstellen?',
        'Ne oluşturmak istiyorsun?',
        'Kamu ingin membuat apa?',
        'আপনি কী তৈরি করতে চান?'
      );
  String get boardAiImage =>
      _get('AI Image', 'AI تصویر', 'صورة بالذكاء الاصطناعي',
        'AI चित्र',
        'Image IA',
        'Imagen IA',
        'Imagem IA',
        'KI-Bild',
        'YZ Görseli',
        'Gambar AI',
        'AI ছবি'
      );
  String get boardAiImageDesc => _get(
        'Generate images with AI',
        'AI سے تصاویر بنائیں',
        'ولّد صوراً بالذكاء الاصطناعي',
      
        'AI से चित्र बनाएँ',
        'Générer des images avec l\'IA',
        'Generar imágenes con IA',
        'Gerar imagens com IA',
        'Bilder mit KI generieren',
        'YZ ile görsel üret',
        'Buat gambar dengan AI',
        'AI দিয়ে ছবি তৈরি করুন'
      );
  String get boardAiVideo =>
      _get('AI Video', 'AI ویڈیو', 'فيديو بالذكاء الاصطناعي',
        'AI वीडियो',
        'Vidéo IA',
        'Video IA',
        'Vídeo IA',
        'KI-Video',
        'YZ Videosu',
        'Video AI',
        'AI ভিডিও'
      );
  String get boardAiVideoDesc => _get(
        'Generate videos with AI',
        'AI سے ویڈیو بنائیں',
        'ولّد فيديو بالذكاء الاصطناعي',
      
        'AI से वीडियो बनाएँ',
        'Générer des vidéos avec l\'IA',
        'Generar videos con IA',
        'Gerar vídeos com IA',
        'Videos mit KI generieren',
        'YZ ile video üret',
        'Buat video dengan AI',
        'AI দিয়ে ভিডিও তৈরি করুন'
      );
  String get boardWriteScript =>
      _get('Write Script', 'اسکرپٹ لکھیں', 'اكتب سيناريو',
        'स्क्रिप्ट लिखें',
        'Écrire un script',
        'Escribir guion',
        'Escrever roteiro',
        'Skript schreiben',
        'Senaryo yaz',
        'Tulis skrip',
        'স্ক্রিপ্ট লিখুন'
      );
  String get boardWriteScriptDesc => _get(
        'Scripts, hooks & captions',
        'اسکرپٹس، ہکس اور کیپشنز',
        'سيناريوهات وخطّافات وتسميات',
      
        'स्क्रिप्ट, हुक और कैप्शन',
        'Scripts, accroches et légendes',
        'Guiones, ganchos y subtítulos',
        'Roteiros, ganchos e legendas',
        'Skripte, Hooks & Captions',
        'Senaryolar, kancalar ve altyazılar',
        'Skrip, hook & caption',
        'স্ক্রিপ্ট, হুক ও ক্যাপশন'
      );
  String get boardAiStory =>
      _get('AI Story', 'AI کہانی', 'قصة بالذكاء الاصطناعي',
        'AI कहानी',
        'Histoire IA',
        'Historia IA',
        'História IA',
        'KI-Story',
        'YZ Hikâyesi',
        'Cerita AI',
        'AI গল্প'
      );
  String get boardAiStoryDesc =>
      _get('Stories & comics', 'کہانیاں اور کامکس', 'قصص ومصوَّرات',
        'कहानियाँ और कॉमिक्स',
        'Histoires et BD',
        'Historias y cómics',
        'Histórias e quadrinhos',
        'Stories & Comics',
        'Hikâyeler ve çizgi romanlar',
        'Cerita & komik',
        'গল্প ও কমিক'
      );
  String get boardUploadContent =>
      _get('Upload Content', 'مواد اپ لوڈ کریں', 'ارفع المحتوى',
        'कंटेंट अपलोड करें',
        'Téléverser du contenu',
        'Subir contenido',
        'Enviar conteúdo',
        'Content hochladen',
        'İçerik yükle',
        'Unggah konten',
        'কনটেন্ট আপলোড করুন'
      );
  String get boardUploadContentDesc => _get(
        'Review & improve media',
        'میڈیا کا جائزہ و بہتری',
        'راجع وحسِّن الوسائط',
      
        'मीडिया की समीक्षा और सुधार',
        'Examiner et améliorer les médias',
        'Revisa y mejora tus medios',
        'Revise e melhore a mídia',
        'Medien prüfen & verbessern',
        'Medyayı incele ve iyileştir',
        'Tinjau & tingkatkan media',
        'মিডিয়া পর্যালোচনা ও উন্নতি'
      );
  String get boardUseTemplate =>
      _get('Use Template', 'ٹیمپلیٹ استعمال کریں', 'استخدم قالباً',
        'टेम्पलेट उपयोग करें',
        'Utiliser un modèle',
        'Usar plantilla',
        'Usar modelo',
        'Vorlage verwenden',
        'Şablon kullan',
        'Gunakan templat',
        'টেমপ্লেট ব্যবহার করুন'
      );
  String get boardUseTemplateDesc => _get(
        'Start from proven formats',
        'آزمودہ فارمیٹس سے شروع کریں',
        'ابدأ من صيغ مُجرَّبة',
      
        'आज़माए हुए फ़ॉर्मेट से शुरू करें',
        'Partez de formats éprouvés',
        'Empieza con formatos probados',
        'Comece com formatos comprovados',
        'Starte mit bewährten Formaten',
        'Kanıtlanmış formatlarla başla',
        'Mulai dari format yang terbukti',
        'প্রমাণিত ফরম্যাট থেকে শুরু করুন'
      );
  String get boardProviderKeyNeeded => _get(
        'Needs an AI provider key — coming soon',
        'AI فراہم کنندہ کی کنجی درکار — جلد آ رہا ہے',
        'يحتاج مفتاح مزوِّد ذكاء اصطناعي — قريباً',
      
        'AI प्रदाता की आवश्यकता है — जल्द आ रहा है',
        'Nécessite une clé de fournisseur IA — bientôt disponible',
        'Necesita una clave de proveedor de IA: próximamente',
        'Precisa de uma chave de provedor de IA — em breve',
        'Benötigt einen KI-Anbieter-Key — kommt bald',
        'YZ sağlayıcı anahtarı gerekli — yakında',
        'Memerlukan kunci penyedia AI — segera hadir',
        'AI প্রদানকারীর কী প্রয়োজন — শীঘ্রই আসছে'
      );
  // ── Phase 9: Create flow (board 21-31) ──
  String get boardCreateHub => _get('Create Hub', 'تخلیق مرکز', 'مركز الإنشاء',
        'क्रिएट हब',
        'Hub de création',
        'Centro de creación',
        'Central de criação',
        'Create Hub',
        'Oluşturma Merkezi',
        'Pusat Kreasi',
        'ক্রিয়েট হাব'
      );
  String get boardCreateImage =>
      _get('Create Image', 'تصویر بنائیں', 'إنشاء صورة',
        'चित्र बनाएँ',
        'Créer une image',
        'Crear imagen',
        'Criar imagem',
        'Bild erstellen',
        'Görsel oluştur',
        'Buat gambar',
        'ছবি তৈরি করুন'
      );
  String get boardCreateVideo =>
      _get('Create Video', 'ویڈیو بنائیں', 'إنشاء فيديو',
        'वीडियो बनाएँ',
        'Créer une vidéo',
        'Crear video',
        'Criar vídeo',
        'Video erstellen',
        'Video oluştur',
        'Buat video',
        'ভিডিও তৈরি করুন'
      );
  String get boardImagePromptHint => _get(
        'Describe your image… e.g. A cozy kitchen scene',
        'اپنی تصویر بیان کریں… مثلاً آرام دہ باورچی خانہ',
        'صِف صورتك… مثال: مشهد مطبخ مريح',
      
        'अपनी छवि का वर्णन करें… जैसे आरामदायक रसोई का दृश्य',
        'Décrivez votre image… ex. une cuisine chaleureuse',
        'Describe tu imagen… p. ej. una cocina acogedora',
        'Descreva sua imagem… ex. uma cozinha aconchegante',
        'Beschreibe dein Bild… z. B. eine gemütliche Küchenszene',
        'Görselini anlat… örn. sıcak bir mutfak sahnesi',
        'Deskripsikan gambarmu… mis. suasana dapur yang nyaman',
        'আপনার ছবির বর্ণনা দিন… যেমন: আরামদায়ক রান্নাঘরের দৃশ্য'
      );
  String get boardStyleRealistic => _get('Realistic', 'حقیقت پسندانہ', 'واقعي',
        'रियलिस्टिक',
        'Réaliste',
        'Realista',
        'Realista',
        'Realistisch',
        'Gerçekçi',
        'Realistis',
        'বাস্তবসম্মত'
      );
  String get boardStyleCartoon => _get('Cartoon', 'کارٹون', 'كرتون',
        'कार्टून',
        'Cartoon',
        'Caricatura',
        'Cartoon',
        'Cartoon',
        'Çizgi film',
        'Kartun',
        'কার্টুন'
      );
  String get boardStyle3d => _get('3D', '3D', 'ثلاثي الأبعاد',
        '3D',
        '3D',
        '3D',
        '3D',
        '3D',
        '3D',
        '3D',
        '3D'
      );
  String get boardGenerate => _get('Generate', 'بنائیں', 'ولّد',
        'जनरेट करें',
        'Générer',
        'Generar',
        'Gerar',
        'Generieren',
        'Oluştur',
        'Hasilkan',
        'তৈরি করুন'
      );
  String get boardImageComingSoon => _get(
        'AI image generation needs a provider key — coming soon. Your prompt is saved below.',
        'AI تصویر بنانے کے لیے فراہم کنندہ کی کنجی درکار ہے — جلد آ رہا ہے۔ آپ کا پرامپٹ نیچے محفوظ ہے۔',
        'توليد الصور يحتاج مفتاح مزوِّد — قريباً. تم حفظ الوصف أدناه.',
      
        'AI इमेज बनाने के लिए प्रदाता कुंजी चाहिए — जल्द आ रहा है। आपका प्रॉम्प्ट नीचे सेव है।',
        'La génération d\'images par IA nécessite une clé de fournisseur — bientôt disponible. Votre description est enregistrée ci-dessous.',
        'La generación de imágenes con IA necesita una clave de proveedor — disponible pronto. Tu descripción está guardada abajo.',
        'A geração de imagens por IA precisa de uma chave de provedor — em breve. Sua descrição está salva abaixo.',
        'Die KI-Bildgenerierung benötigt einen Anbieter-Schlüssel — kommt bald. Dein Prompt ist unten gespeichert.',
        'Yapay zeka ile görsel oluşturmak için sağlayıcı anahtarı gerekli — yakında. İsteminiz aşağıda kaydedildi.',
        'Pembuatan gambar AI membutuhkan kunci penyedia — segera hadir. Prompt Anda tersimpan di bawah.',
        'AI দিয়ে ছবি তৈরির জন্য প্রোভাইডার কী দরকার — শীঘ্রই আসছে। আপনার প্রম্পট নিচে সংরক্ষিত আছে।'
      );
  String get boardImageGenerating => _get(
        'Generating your image…',
        'آپ کی تصویر بن رہی ہے…',
      );
  String get boardImageRegenerate => _get(
        'Regenerate',
        'دوبارہ بنائیں',
      );
  String get boardImageShare => _get(
        'Share',
        'شیئر کریں',
      );
  String get boardImageShareFailed => _get(
        'Could not prepare the image for sharing.',
        'تصویر شیئر کے لیے تیار نہیں ہو سکی۔',
      );
  String get boardImageAiLabel => _get(
        'AI-generated',
        'AI سے بنی',
      );
  String get boardImageFailed => _get(
        'Image generation failed. Please try again.',
        'تصویر بنانے میں ناکامی۔ دوبارہ کوشش کریں۔',
      );
  String get boardScriptDraftLabel => _get(
        'Basic draft',
        'بنیادی مسودہ',
      );
  String get boardSceneEstablishing => _get(
        'Establishing shot',
        'افتتاحی منظر',
      );
  String get boardSceneAction => _get(
        'Action moment',
        'ایکشن لمحہ',
      );
  String get boardSceneFinale => _get(
        'Finale',
        'اختتام',
      );
  String get boardStoryboardTitle => _get(
        'AI Storyboard',
        'AI اسٹوری بورڈ',
      );
  String get boardStoryboardNote => _get(
        'Storyboard preview — full AI video rendering needs a provider key.',
        'اسٹوری بورڈ پیش نظارہ — مکمل AI ویڈیو کے لیے فراہم کنندہ کی کنجی درکار ہے۔',
      );
  String get boardImageRetry => _get(
        'Retry',
        'دوبارہ کوشش',
      );
  String get boardVideoComingSoon => _get(
        'AI video generation needs a provider key — coming soon. Your idea is saved below.',
        'AI ویڈیو بنانے کے لیے فراہم کنندہ کی کنجی درکار ہے — جلد آ رہا ہے۔ آپ کا آئیڈیا نیچے محفوظ ہے۔',
        'توليد الفيديو يحتاج مفتاح مزوِّد — قريباً. تم حفظ فكرتك أدناه.',
      
        'AI वीडियो बनाने के लिए प्रदाता कुंजी चाहिए — जल्द आ रहा है। आपका आइडिया नीचे सेव है।',
        'La génération de vidéos par IA nécessite une clé de fournisseur — bientôt disponible. Votre idée est enregistrée ci-dessous.',
        'La generación de video con IA necesita una clave de proveedor — disponible pronto. Tu idea está guardada abajo.',
        'A geração de vídeos por IA precisa de uma chave de provedor — em breve. Sua ideia está salva abaixo.',
        'Die KI-Videogenerierung benötigt einen Anbieter-Schlüssel — kommt bald. Deine Idee ist unten gespeichert.',
        'Yapay zeka ile video oluşturmak için sağlayıcı anahtarı gerekli — yakında. Fikriniz aşağıda kaydedildi.',
        'Pembuatan video AI membutuhkan kunci penyedia — segera hadir. Ide Anda tersimpan di bawah.',
        'AI দিয়ে ভিডিও তৈরির জন্য প্রোভাইডার কী দরকার — শীঘ্রই আসছে। আপনার আইডিয়া নিচে সংরক্ষিত আছে।'
      );
  String get boardVideoIdeaHint => _get(
        'Describe your video… e.g. Home Decor product',
        'اپنی ویڈیو بیان کریں… مثلاً ہوم ڈیکور پروڈکٹ',
        'صِف الفيديو… مثال: منتج ديكور منزلي',
      
        'अपनी वीडियो का वर्णन करें… जैसे होम डेकोर प्रोडक्ट',
        'Décrivez votre vidéo… ex. produit déco maison',
        'Describe tu video… ej. producto de decoración del hogar',
        'Descreva seu vídeo… ex. produto de decoração',
        'Beschreibe dein Video… z. B. Deko-Produkt',
        'Videonuzu anlatın… örn. ev dekorasyonu ürünü',
        'Jelaskan video Anda… mis. produk dekorasi rumah',
        'আপনার ভিডিও বর্ণনা করুন… যেমন হোম ডেকর পণ্য'
      );
  String get boardScriptPromptHint => _get(
        'e.g. Kitchen towel product script',
        'مثلاً کچن تول پروڈکٹ اسکرپٹ',
        'مثال: سيناريو منتج مناشف المطبخ',
      
        'जैसे किचन टॉवल प्रोडक्ट स्क्रिप्ट',
        'ex. script pour produit essuie-tout',
        'ej. guion para producto de toalla de cocina',
        'ex. roteiro para produto de toalha de cozinha',
        'z. B. Skript für Küchentuch-Produkt',
        'örn. mutfak havlusu ürün senaryosu',
        'mis. skrip produk handuk dapur',
        'যেমন রান্নাঘরের তোয়ালে পণ্যের স্ক্রিপ্ট'
      );
  String get boardToneLabel => _get('Tone', 'لہجہ', 'النبرة',
        'टोन',
        'Ton',
        'Tono',
        'Tom',
        'Ton',
        'Ton',
        'Nada',
        'টোন'
      );
  String get boardToneFriendly => _get('Friendly', 'دوستانہ', 'ودود',
        'फ्रेंडली',
        'Amical',
        'Amable',
        'Amigável',
        'Freundlich',
        'Samimi',
        'Ramah',
        'বন্ধুত্বপূর্ণ'
      );
  String get boardToneProfessional =>
      _get('Professional', 'پیشہ ورانہ', 'احترافي',
        'प्रोफेशनल',
        'Professionnel',
        'Profesional',
        'Profissional',
        'Professionell',
        'Profesyonel',
        'Profesional',
        'পেশাদার'
      );
  String get boardToneFunny => _get('مضحک', 'مزاحیہ', 'مضحك',
        'मज़ाकिया',
        'Drôle',
        'Divertido',
        'Engraçado',
        'Lustig',
        'Komik',
        'Lucu',
        'মজার'
      );
  String get boardStoryPromptHint => _get(
        'e.g. A short suspense story in Urdu',
        'مثلاً اردو میں مختصر سسپنس کہانی',
        'مثال: قصة تشويق قصيرة بالأردية',
      
        'जैसे उर्दू में एक छोटी सस्पेंस कहानी',
        'ex. une courte histoire à suspense en ourdou',
        'ej. una historia corta de suspenso en urdu',
        'ex. uma história curta de suspense em urdu',
        'z. B. eine kurze spannende Geschichte auf Urdu',
        'örn. Urduca kısa bir gerilim hikâyesi',
        'mis. cerita suspense pendek dalam bahasa Urdu',
        'যেমন উর্দুতে একটি ছোট সাসপেন্স গল্প'
      );
  String get boardStoryLength => _get('Length', 'لمبائی', 'الطول',
        'लंबाई',
        'Longueur',
        'Duración',
        'Duração',
        'Länge',
        'Uzunluk',
        'Panjang',
        'দৈর্ঘ্য'
      );
  String get boardLengthShort => _get('Short', 'مختصر', 'قصيرة',
        'छोटी',
        'Courte',
        'Corta',
        'Curta',
        'Kurz',
        'Kısa',
        'Pendek',
        'ছোট'
      );
  String get boardLengthMedium => _get('Medium', 'درمیانی', 'متوسطة',
        'मध्यम',
        'Moyenne',
        'Media',
        'Média',
        'Mittel',
        'Orta',
        'Sedang',
        'মাঝারি'
      );
  String get boardLengthLong => _get('Long', 'طویل', 'طويلة',
        'लंबी',
        'Longue',
        'Larga',
        'Longa',
        'Lang',
        'Uzun',
        'Panjang',
        'লম্বা'
      );
  String get boardUploadTitle => _get('Upload', 'اپ لوڈ', 'رفع',
        'अपलोड',
        'Importer',
        'Subir',
        'Enviar',
        'Hochladen',
        'Yükle',
        'Unggah',
        'আপলোড'
      );
  String get boardTapToSelect => _get(
        'Tap to select a photo or video',
        'تصویر یا ویڈیو منتخب کرنے کے لیے ٹیپ کریں',
        'انقر لاختيار صورة أو فيديو',
      
        'फोटो या वीडियो चुनने के लिए टैप करें',
        'Touchez pour choisir une photo ou une vidéo',
        'Toca para elegir una foto o un video',
        'Toque para escolher uma foto ou um vídeo',
        'Tippe, um ein Foto oder Video auszuwählen',
        'Fotoğraf veya video seçmek için dokunun',
        'Ketuk untuk memilih foto atau video',
        'ছবি বা ভিডিও বাছতে ট্যাপ করুন'
      );
  String get boardAnalyzeUpload =>
      _get('Analyze & Improve', 'تجزیہ و بہتری', 'حلّل وحسِّن',
        'विश्लेषण व सुधारें',
        'Analyser et améliorer',
        'Analizar y mejorar',
        'Analisar e melhorar',
        'Analysieren & verbessern',
        'Analiz Et ve İyileştir',
        'Analisis & Tingkatkan',
        'বিশ্লেষণ ও উন্নতি করুন'
      );
  String get boardEditContent =>
      _get('Edit Content', 'مواد میں ترمیم', 'تحرير المحتوى',
        'कंटेंट एडिट करें',
        'Modifier le contenu',
        'Editar contenido',
        'Editar conteúdo',
        'Inhalt bearbeiten',
        'İçeriği Düzenle',
        'Edit Konten',
        'কন্টেন্ট সম্পাদনা করুন'
      );
  String get boardPreview => _get('Preview', 'پیش نظارہ', 'معاينة',
        'प्रीव्यू',
        'Aperçu',
        'Vista previa',
        'Prévia',
        'Vorschau',
        'Önizleme',
        'Pratinjau',
        'প্রিভিউ'
      );
  String get boardTemplates => _get('Templates', 'ٹیمپلیٹس', 'قوالب',
        'टेम्प्लेट्स',
        'Modèles',
        'Plantillas',
        'Modelos',
        'Vorlagen',
        'Şablonlar',
        'Template',
        'টেমপ্লেট'
      );
  String get boardNoTemplates => _get(
        'No templates yet — check back soon',
        'ابھی کوئی ٹیمپلیٹ نہیں — جلد دوبارہ دیکھیں',
        'لا قوالب بعد — عُد قريباً',
      
        'अभी कोई टेम्प्लेट नहीं — जल्द दोबारा देखें',
        'Aucun modèle pour le moment — revenez bientôt',
        'Aún no hay plantillas — vuelve pronto',
        'Sem modelos ainda — volte em breve',
        'Noch keine Vorlagen — schau bald wieder vorbei',
        'Henüz şablon yok — yakında tekrar kontrol edin',
        'Belum ada template — cek lagi nanti',
        'এখনও কোনো টেমপ্লেট নেই — শীঘ্রই আবার দেখুন'
      );
  String get boardConversion => _get('Conversion', 'تبدیلی', 'تحويل',
        'कन्वर्ज़न',
        'Conversion',
        'Conversión',
        'Conversão',
        'Konversion',
        'Dönüştürme',
        'Konversi',
        'রূপান্তর'
      );
  String get boardConvertInputHint => _get(
        'Paste a link or text to convert…',
        'تبدیل کرنے کے لیے لنک یا متن پیسٹ کریں…',
        'الصق رابطاً أو نصاً للتحويل…',
      
        'कन्वर्ट करने के लिए लिंक या टेक्स्ट पेस्ट करें…',
        'Collez un lien ou un texte à convertir…',
        'Pega un enlace o texto para convertir…',
        'Cole um link ou texto para converter…',
        'Füge einen Link oder Text zum Konvertieren ein…',
        'Dönüştürmek için bir bağlantı veya metin yapıştırın…',
        'Tempel tautan atau teks untuk dikonversi…',
        'রূপান্তরের জন্য লিঙ্ক বা লেখা পেস্ট করুন…'
      );
  String get boardConvert => _get('Convert', 'تبدیل کریں', 'حوّل',
        'कन्वर्ट करें',
        'Convertir',
        'Convertir',
        'Converter',
        'Konvertieren',
        'Dönüştür',
        'Konversi',
        'রূপান্তর করুন'
      );
  String get boardGenerateCaptions =>
      _get('Generate Captions', 'کیپشنز بنائیں', 'توليد تسميات',
        'कैप्शन बनाएं',
        'Générer des légendes',
        'Generar subtítulos',
        'Gerar legendas',
        'Untertitel generieren',
        'Altyazı Oluştur',
        'Buat Caption',
        'ক্যাপশন তৈরি করুন'
      );
  String get boardSelectAll => _get(
        'Select all',
        'سب منتخب کریں',
      );
  String get boardDeselectAll => _get(
        'Deselect all',
        'سب غیر منتخب کریں',
      );
  String get boardFormatVideoScript => _get(
        'Video Script',
        'ویڈیو اسکرپٹ',
      );
  String get boardFormatCarousel => _get(
        'Carousel',
        'کیروسل',
      );
  String get boardFormatThread => _get(
        'Thread',
        'تھریڈ',
      );
  String get boardFormatStoryCaption => _get(
        'Story Caption',
        'اسٹوری کیپشن',
      );
  String get boardTemplateStructure => _get(
        'Structure',
        'ساخت',
      );
  String get boardTemplateExample => _get(
        'Example',
        'مثال',
      );
  String get boardTemplateCopy => _get(
        'Copy',
        'کاپی',
      );
  String get boardTemplateAiFill => _get(
        'AI Fill',
        'AI سے بھرو',
      );
  String get boardTemplateMatchHint => _get(
        'Describe your content idea…',
        'اپنے مواد کا آئیڈیا لکھیں…',
      );
  String get boardTemplateNeedIdea => _get(
        'Type your content idea above first, then AI Fill.',
        'پہلے اوپر اپنا آئیڈیا لکھیں، پھر AI Fill دبائیں۔',
      );
  String get boardSuggestCaptions => _get(
        'Suggest captions with AI',
        'AI سے کیپشن تجویز کروائیں',
      );
  String get boardCaptionTopicHint => _get(
        'What is the caption for…',
        'کیپشن کس کے لیے ہے…',
        'التسمية مخصصة لـ…',
      
        'कैप्शन किसके लिए है…',
        'La légende est pour…',
        'El subtítulo es para…',
        'A legenda é para…',
        'Die Bildunterschrift ist für…',
        'Altyazı ne için…',
        'Caption ini untuk…',
        'ক্যাপশনটি কিসের জন্য…'
      );
  String get boardTabCreators => _get('Creators', 'تخلیق کار', 'منشئون',
        'क्रिएटर्स',
        'Créateurs',
        'Creadores',
        'Criadores',
        'Creator',
        'Üreticiler',
        'Kreator',
        'ক্রিয়েটররা'
      );
  String get boardTabTopics => _get('Topics', 'موضوعات', 'مواضيع',
        'टॉपिक्स',
        'Sujets',
        'Temas',
        'Tópicos',
        'Themen',
        'Konular',
        'Topik',
        'বিষয়'
      );
  String get boardTabAll => _get('All', 'سب', 'الكل',
        'सभी',
        'Tout',
        'Todo',
        'Tudo',
        'Alle',
        'Tümü',
        'Semua',
        'সব'
      );
  String get boardTabTrending => _get('Trending', 'ٹرینڈنگ', 'رائج',
        'ट्रेंडिंग',
        'Tendances',
        'Tendencias',
        'Em alta',
        'Trending',
        'Trendler',
        'Tren',
        'ট্রেন্ডিং'
      );
  String get boardTabData => _get('Data', 'ڈیٹا', 'البيانات',
        'डेटा',
        'Données',
        'Datos',
        'Dados',
        'Daten',
        'Veri',
        'Data',
        'ডেটা'
      );
  String get boardTabComments => _get('Comments', 'تبصرے', 'تعليقات',
        'कमेंट्स',
        'Commentaires',
        'Comentarios',
        'Comentários',
        'Kommentare',
        'Yorumlar',
        'Komentar',
        'মন্তব্য'
      );
  String get boardTabDiscover => _get('Discover', 'دریافت', 'اكتشف',
        'डिस्कवर',
        'Découvrir',
        'Descubrir',
        'Descobrir',
        'Entdecken',
        'Keşfet',
        'Temukan',
        'ডিসকভার'
      );
  String get boardCopy => _get('Copy', 'کاپی', 'نسخ',
        'कॉपी करें',
        'Copier',
        'Copiar',
        'Copiar',
        'Kopieren',
        'Kopyala',
        'Salin',
        'কপি করুন'
      );
  String get boardCopied => _get('Copied', 'کاپی ہو گیا', 'تم النسخ',
        'कॉपी हो गया',
        'Copié',
        'Copiado',
        'Copiado',
        'Kopiert',
        'Kopyalandı',
        'Tersalin',
        'কপি হয়েছে'
      );
  String get boardEnterTextFirst => _get(
        'Type something first',
        'پہلے کچھ لکھیں',
        'اكتب شيئاً أولاً',
      
        'पहले कुछ लिखें',
        'Écrivez quelque chose d\'abord',
        'Escribe algo primero',
        'Digite algo primeiro',
        'Schreib zuerst etwas',
        'Önce bir şey yazın',
        'Ketik sesuatu dulu',
        'আগে কিছু লিখুন'
      );
  String get boardDevHeuristic => _get(
        'Dev preview — heuristic draft',
        'ڈیو پیش نظارہ — ابتدائی مسودہ',
        'معاينة تطويرية — مسودة أولية',
      
        'डेव प्रीव्यू — अनुमानित ड्राफ्ट',
        'Aperçu dev — brouillon heuristique',
        'Vista previa dev — borrador heurístico',
        'Prévia dev — rascunho heurístico',
        'Dev-Vorschau — heuristischer Entwurf',
        'Geliştirici önizlemesi — sezgisel taslak',
        'Pratinjau dev — draf heuristik',
        'ডেভ প্রিভিউ — অনুমানিক খসড়া'
      );
  String get boardNoRecommendations => _get(
        'No recommendations yet — explore Discover',
        'ابھی کوئی تجویز نہیں — Discover دیکھیں',
        'لا توصيات بعد — استكشف ديسكفر',
      
        'अभी कोई सिफारिश नहीं — डिस्कवर देखें',
        'Aucune recommandation pour l\'instant — explorez Découvrir',
        'Sin recomendaciones aún — explora Descubrir',
        'Sem recomendações ainda — explore o Descobrir',
        'Noch keine Empfehlungen — entdecke Entdecken',
        'Henüz öneri yok — Keşfet\'e göz atın',
        'Belum ada rekomendasi — jelajahi Temukan',
        'এখনও কোনো সুপারিশ নেই — ডিসকভার দেখুন'
      );
  String get reachLabel => _get('reach', 'رسائی', 'وصول',
        'रीच',
        'portée',
        'alcance',
        'alcance',
        'Reichweite',
        'erişim',
        'jangkauan',
        'রিচ'
      );
  String get clicksLabel => _get('clicks', 'کلکس', 'نقرات',
        'क्लिक्स',
        'clics',
        'clics',
        'cliques',
        'Klicks',
        'tıklamalar',
        'klik',
        'ক্লিক'
      );
  String get liveLabel => _get('Live', 'لائیو', 'مباشر',
        'लाइव',
        'En direct',
        'En vivo',
        'Ao vivo',
        'Live',
        'Canlı',
        'Live',
        'লাইভ'
      );
  String get campaignFallbackTitle =>
      _get('Untitled campaign', 'بغیر عنوان مہم', 'حملة بلا عنوان',
        'बिना शीर्षक का अभियान',
        'Campagne sans titre',
        'Campaña sin título',
        'Campanha sem título',
        'Kampagne ohne Titel',
        'Başlıksız kampanya',
        'Kampanye tanpa judul',
        'শিরোনামহীন ক্যাম্পেইন'
      );

  // ---- 2026-09-29 master board: phase 4 social screens (13-18) ----
  String get boardFollowing => _get('Following', 'فالوونگ', 'مُتابَعون',
        'फॉलोइंग',
        'Abonnements',
        'Siguiendo',
        'Seguindo',
        'Gefolgt',
        'Takip Edilenler',
        'Mengikuti',
        'ফলোইং'
      );
  String get boardCreators => _get('Creators', 'تخلیق کار', 'المبدعون',
        'क्रिएटर्स',
        'Créateurs',
        'Creadores',
        'Criadores',
        'Creator',
        'Üreticiler',
        'Kreator',
        'ক্রিয়েটররা'
      );
  String get boardTopics => _get('Topics', 'موضوعات', 'المواضيع',
        'टॉपिक्स',
        'Sujets',
        'Temas',
        'Tópicos',
        'Themen',
        'Konular',
        'Topik',
        'বিষয়সমূহ'
      );
  String get boardFollow => _get('Follow', 'فالو کریں', 'تابِع',
        'फॉलो करें',
        'Suivre',
        'Seguir',
        'Seguir',
        'Folgen',
        'Takip Et',
        'Ikuti',
        'ফলো করুন'
      );
  String get boardFollowingBtn =>
      _get('Following', 'فالو کر رہے ہیں', 'تتابعه',
        'फॉलो किया हुआ',
        'Suivi',
        'Siguiendo',
        'Seguindo',
        'Gefolgt',
        'Takip Ediliyor',
        'Mengikuti',
        'ফলো করা হয়েছে'
      );
  String get boardUnfollow => _get('Unfollow', 'ان فالو', 'إلغاء المتابعة',
        'अनफॉलो',
        'Ne plus suivre',
        'Dejar de seguir',
        'Deixar de seguir',
        'Entfolgen',
        'Takibi Bırak',
        'Berhenti Mengikuti',
        'আনফলো'
      );
  String get boardNoFollowing => _get(
        'You are not following anyone yet',
        'آپ ابھی کسی کو فالو نہیں کر رہے',
        'أنت لا تتابع أحداً بعد',
      
        'आप अभी किसी को फॉलो नहीं कर रहे',
        'Vous ne suivez personne pour le moment',
        'Aún no sigues a nadie',
        'Você ainda não segue ninguém',
        'Du folgst noch niemandem',
        'Henüz kimseyi takip etmiyorsunuz',
        'Anda belum mengikuti siapa pun',
        'আপনি এখনও কাউকে ফলো করছেন না'
      );
  String get boardNoTopics => _get(
        'No topics saved yet',
        'ابھی کوئی موضوع محفوظ نہیں',
        'لا مواضيع محفوظة بعد',
      
        'अभी कोई टॉपिक सेव नहीं',
        'Aucun sujet enregistré pour le moment',
        'Sin temas guardados aún',
        'Sem tópicos salvos ainda',
        'Noch keine Themen gespeichert',
        'Henüz kaydedilmiş konu yok',
        'Belum ada topik tersimpan',
        'এখনও কোনো বিষয় সংরক্ষিত নেই'
      );
  String get boardPostDetail =>
      _get('Post Detail', 'پوسٹ کی تفصیل', 'تفاصيل المنشور',
        'पोस्ट डिटेल',
        'Détail de la publication',
        'Detalle de la publicación',
        'Detalhe da publicação',
        'Beitragsdetails',
        'Gönderi Detayı',
        'Detail Postingan',
        'পোস্টের বিবরণ'
      );
  String get boardComments => _get('Comments', 'تبصرے', 'التعليقات',
        'कमेंट्स',
        'Commentaires',
        'Comentarios',
        'Comentários',
        'Kommentare',
        'Yorumlar',
        'Komentar',
        'মন্তব্যসমূহ'
      );
  String get boardWriteComment =>
      _get('Write a comment…', 'تبصرہ لکھیں…', 'اكتب تعليقاً…',
        'कमेंट लिखें…',
        'Écrire un commentaire…',
        'Escribe un comentario…',
        'Escreva um comentário…',
        'Kommentar schreiben…',
        'Yorum yaz…',
        'Tulis komentar…',
        'মন্তব্য লিখুন…'
      );
  String get boardNoComments => _get(
        'No comments yet — be the first',
        'ابھی کوئی تبصرہ نہیں — پہلے آپ کریں',
        'لا تعليقات بعد — كن الأول',
      
        'अभी कोई कमेंट नहीं — सबसे पहले करें',
        'Aucun commentaire pour le moment — soyez le premier',
        'Sin comentarios aún — sé el primero',
        'Sem comentários ainda — seja o primeiro',
        'Noch keine Kommentare — sei der Erste',
        'Henüz yorum yok — ilk siz olun',
        'Belum ada komentar — jadilah yang pertama',
        'এখনও কোনো মন্তব্য নেই — প্রথম হোন'
      );
  String get boardCommentPosted =>
      _get('Comment posted', 'تبصرہ پوسٹ ہو گیا', 'تم نشر التعليق',
        'कमेंट पोस्ट हो गया',
        'Commentaire publié',
        'Comentario publicado',
        'Comentário publicado',
        'Kommentar gepostet',
        'Yorum paylaşıldı',
        'Komentar terkirim',
        'মন্তব্য পোস্ট হয়েছে'
      );
  String get boardCommentDeleted =>
      _get('Comment deleted', 'تبصرہ حذف ہو گیا', 'تم حذف التعليق',
        'कमेंट डिलीट हो गया',
        'Commentaire supprimé',
        'Comentario eliminado',
        'Comentário excluído',
        'Kommentar gelöscht',
        'Yorum silindi',
        'Komentar dihapus',
        'মন্তব্য মুছে ফেলা হয়েছে'
      );
  String get delete => _get('Delete', 'حذف کریں', 'حذف',
        'डिलीट करें',
        'Supprimer',
        'Eliminar',
        'Excluir',
        'Löschen',
        'Sil',
        'Hapus',
        'মুছুন'
      );
  String get boardDeleteCommentConfirm =>
      _get('Delete this comment?', 'یہ تبصرہ حذف کریں؟', 'حذف هذا التعليق؟',
        'यह कमेंट डिलीट करें?',
        'Supprimer ce commentaire ?',
        '¿Eliminar este comentario?',
        'Excluir este comentário?',
        'Diesen Kommentar löschen?',
        'Bu yorum silinsin mi?',
        'Hapus komentar ini?',
        'এই মন্তব্যটি মুছবেন?'
      );
  String get boardActivity => _get('Activity', 'سرگرمی', 'النشاط',
        'एक्टिविटी',
        'Activité',
        'Actividad',
        'Atividade',
        'Aktivitäten',
        'Etkinlik',
        'Aktivitas',
        'অ্যাক্টিভিটি'
      );
  String get boardAll => _get('All', 'سب', 'الكل',
        'सभी',
        'Tout',
        'Todo',
        'Tudo',
        'Alle',
        'Tümü',
        'Semua',
        'সব'
      );
  String get boardLikes => _get('Likes', 'لائکس', 'الإعجابات',
        'लाइक्स',
        'J\'aime',
        'Me gusta',
        'Curtidas',
        'Likes',
        'Beğeniler',
        'Suka',
        'লাইক'
      );
  String get boardLikedPost =>
      _get('You liked this post', 'آپ نے یہ پوسٹ پسند کی', 'أعجبك هذا المنشور',
        'आपको यह पोस्ट पसंद आई',
        'Vous avez aimé cette publication',
        'Te gustó esta publicación',
        'Você curtiu esta publicação',
        'Dir gefällt dieser Beitrag',
        'Bu gönderiyi beğendiniz',
        'Anda menyukai postingan ini',
        'আপনার এই পোস্টটি ভালো লেগেছে'
      );
  String get boardFollows => _get('Follows', 'فالوز', 'المتابَعات',
        'फॉलोज़',
        'Abonnements',
        'Seguidos',
        'Seguidores',
        'Gefolgte',
        'Takipler',
        'Pengikut',
        'ফলো'
      );
  String get boardNoActivity =>
      _get('Nothing here yet', 'یہاں ابھی کچھ نہیں', 'لا شيء هنا بعد',
        'यहां अभी कुछ नहीं',
        'Rien ici pour le moment',
        'Nada aquí aún',
        'Nada aqui ainda',
        'Hier ist noch nichts',
        'Burada henüz bir şey yok',
        'Belum ada apa pun di sini',
        'এখানে এখনও কিছু নেই'
      );
  String get boardCommentedOn =>
      _get('commented on a post', 'نے ایک پوسٹ پر تبصرہ کیا', 'علّق على منشور',
        'ने एक पोस्ट पर कमेंट किया',
        'a commenté une publication',
        'comentó en una publicación',
        'comentou em uma publicação',
        'hat einen Beitrag kommentiert',
        'bir gönderiye yorum yaptı',
        'mengomentari sebuah postingan',
        'একটি পোস্টে মন্তব্য করেছেন'
      );
  String get boardStartedFollowing =>
      _get('You started following', 'آپ نے فالو کرنا شروع کیا', 'بدأت بمتابعة',
        'आपने फॉलो करना शुरू किया',
        'Vous avez commencé à suivre',
        'Empezaste a seguir',
        'Você começou a seguir',
        'Du folgst jetzt',
        'Takip etmeye başladınız',
        'Anda mulai mengikuti',
        'আপনি ফলো করা শুরু করেছেন'
      );
  String get boardCreatorDashboard =>
      _get('Creator Dashboard', 'کریئیٹر ڈیش بورڈ', 'لوحة المبدع',
        'क्रिएटर डैशबोर्ड',
        'Tableau de bord du créateur',
        'Panel del creador',
        'Painel do criador',
        'Creator-Dashboard',
        'Üretici Paneli',
        'Dasbor Kreator',
        'ক্রিয়েটর ড্যাশবোর্ড'
      );
  String get boardTotalReach =>
      _get('Total Reach', 'کل رسائی', 'إجمالي الوصول',
        'कुल रीच',
        'Portée totale',
        'Alcance total',
        'Alcance total',
        'Gesamtreichweite',
        'Toplam Erişim',
        'Total Jangkauan',
        'মোট রিচ'
      );
  String get boardEngagement => _get('Engagement', 'انگیجمنٹ', 'التفاعل',
        'एंगेजमेंट',
        'Engagement',
        'Interacción',
        'Engajamento',
        'Interaktion',
        'Etkileşim',
        'Interaksi',
        'এনগেজমেন্ট'
      );
  String get boardEngagementRate =>
      _get('Engagement Rate', 'انگیجمنٹ ریٹ', 'معدل التفاعل',
        'एंगेजमेंट रेट',
        'Taux d\'engagement',
        'Tasa de interacción',
        'Taxa de engajamento',
        'Interaktionsrate',
        'Etkileşim Oranı',
        'Tingkat Interaksi',
        'এনগেজমেন্ট রেট'
      );
  String get boardClicks => _get('Clicks', 'کلکس', 'النقرات',
        'क्लिक्स',
        'Clics',
        'Clics',
        'Cliques',
        'Klicks',
        'Tıklamalar',
        'Klik',
        'ক্লিক'
      );
  String get boardConversions => _get('Conversions', 'کنورژنز', 'التحويلات',
        'कन्वर्ज़न',
        'Conversions',
        'Conversiones',
        'Conversões',
        'Conversions',
        'Dönüşümler',
        'Konversi',
        'রূপান্তর'
      );
  String get boardNoStatsYet => _get(
        'No stats yet — launch a campaign to see real numbers',
        'ابھی کوئی اعداد نہیں — اصل نمبر دیکھنے کے لیے مہم شروع کریں',
        'لا إحصاءات بعد — أطلق حملة لرؤية أرقام حقيقية',
      
        'अभी कोई आंकड़े नहीं — असली नंबर देखने के लिए अभियान लॉन्च करें',
        'Aucune statistique pour le moment — lancez une campagne pour voir de vrais chiffres',
        'Sin estadísticas aún — lanza una campaña para ver números reales',
        'Sem estatísticas ainda — lance uma campanha para ver números reais',
        'Noch keine Statistiken — starte eine Kampagne für echte Zahlen',
        'Henüz istatistik yok — gerçek sayıları görmek için bir kampanya başlatın',
        'Belum ada statistik — luncurkan kampanye untuk melihat angka nyata',
        'এখনও কোনো পরিসংখ্যান নেই — আসল সংখ্যা দেখতে একটি ক্যাম্পেইন চালু করুন'
      );
  String get boardRecentPosts =>
      _get('Recent Posts', 'حالیہ پوسٹس', 'المنشورات الأخيرة',
        'हालिया पोस्ट्स',
        'Publications récentes',
        'Publicaciones recientes',
        'Publicações recentes',
        'Neueste Beiträge',
        'Son Gönderiler',
        'Postingan Terbaru',
        'সাম্প্রতিক পোস্ট'
      );
  String get untitled => _get('Untitled', 'بلا عنوان', 'بدون عنوان',
        'बिना शीर्षक',
        'Sans titre',
        'Sin título',
        'Sem título',
        'Ohne Titel',
        'Başlıksız',
        'Tanpa Judul',
        'শিরোনামহীন'
      );
  String get boardFollowedSince =>
      _get('Following since', 'سے فالو کر رہے ہیں', 'تتابعه منذ',
        'फॉलो शुरू',
        'Suivi depuis',
        'Siguiendo desde',
        'Seguindo desde',
        'Folgt seit',
        'Takip tarihi',
        'Mengikuti sejak',
        'ফলো শুরুর তারিখ'
      );
  String get boardLike => _get('Like', 'لائک', 'أعجبني',
        'लाइक',
        'J\'aime',
        'Me gusta',
        'Curtir',
        'Like',
        'Beğen',
        'Suka',
        'লাইক'
      );
  String get boardLiked => _get('Liked', 'لائک کیا', 'أعجبك',
        'लाइक किया',
        'Aimé',
        'Te gustó',
        'Curtido',
        'Geliket',
        'Beğenildi',
        'Disukai',
        'লাইক করা হয়েছে'
      );
  String get boardShare => _get('Share', 'شیئر', 'شارك',
        'शेयर करें',
        'Partager',
        'Compartir',
        'Compartilhar',
        'Teilen',
        'Paylaş',
        'Bagikan',
        'শেয়ার করুন'
      );
  String get boardLinkCopied =>
      _get('Link copied to clipboard', 'لنک کاپی ہو گیا', 'تم نسخ الرابط',
        'लिंक कॉपी हो गया',
        'Lien copié',
        'Enlace copiado',
        'Link copiado',
        'Link kopiert',
        'Bağlantı kopyalandı',
        'Tautan disalin',
        'লিঙ্ক কপি হয়েছে'
      );
  String get boardJustNow => _get('just now', 'ابھی', 'الآن',
        'अभी',
        'à l\'instant',
        'ahora mismo',
        'agora mesmo',
        'gerade eben',
        'az önce',
        'baru saja',
        'এইমাত্র'
      );
  String get boardMinutesAgo => _get('min ago', 'منٹ پہلے', 'منذ دقائق',
        'मिनट पहले',
        'il y a min',
        'hace min',
        'há min',
        'vor Min.',
        'dk önce',
        'mnt lalu',
        'মিনিট আগে'
      );
  String get boardHoursAgo => _get('h ago', 'گھنٹے پہلے', 'منذ ساعات',
        'घंटे पहले',
        'il y a h',
        'hace h',
        'há h',
        'vor Std.',
        'sa önce',
        'jam lalu',
        'ঘণ্টা আগে'
      );
  String get boardDaysAgo => _get('d ago', 'دن پہلے', 'منذ أيام',
        'दिन पहले',
        'il y a j',
        'hace d',
        'há d',
        'vor T.',
        'gün önce',
        'hari lalu',
        'দিন আগে'
      );
  String get boardDelete => _get('Delete', 'حذف کریں', 'احذف',
        'डिलीट करें',
        'Supprimer',
        'Eliminar',
        'Excluir',
        'Löschen',
        'Sil',
        'Hapus',
        'মুছে ফেলুন'
      );
  String get deleteCampaignConfirm => _get(
        'Delete this campaign permanently? This cannot be undone.',
        'یہ مہم مستقل طور پر حذف کریں؟ یہ عمل واپس نہیں ہو سکتا۔',
        'حذف هذه الحملة نهائيًا؟ لا يمكن التراجع عن هذا الإجراء.',
      
        'क्या आप वाकई यह अभियान स्थायी रूप से हटाना चाहते हैं? इसे वापस नहीं किया जा सकेगा।',
        'Supprimer définitivement cette campagne ? Cette action est irréversible.',
        '¿Eliminar esta campaña permanentemente? Esta acción no se puede deshacer.',
        'Excluir esta campanha permanentemente? Esta ação não pode ser desfeita.',
        'Diese Kampagne endgültig löschen? Dies kann nicht rückgängig gemacht werden.',
        'Bu kampanya kalıcı olarak silinsin mi? Bu işlem geri alınamaz.',
        'Hapus kampanye ini secara permanen? Tindakan ini tidak dapat dibatalkan.',
        'এই ক্যাম্পেইনটি স্থায়ীভাবে মুছে ফেলবেন? এটি পূর্বাবস্থায় ফেরানো যাবে না।'
      );
  String get deletedToast =>
      _get('Campaign deleted', 'مہم حذف ہو گئی', 'تم حذف الحملة',
        'अभियान हटा दिया गया',
        'Campagne supprimée',
        'Campaña eliminada',
        'Campanha excluída',
        'Kampagne gelöscht',
        'Kampanya silindi',
        'Kampanye dihapus',
        'ক্যাম্পেইন মুছে ফেলা হয়েছে'
      );
  String get deleteFailed =>
      _get('Could not delete. Check your connection and try again.',
        'ڈیلیٹ نہیں ہو سکی۔ اپنا کنکشن چیک کریں اور دوبارہ کوشش کریں۔',
        'تعذر الحذف. تحقق من اتصالك وحاول مرة أخرى.',
        'हटाया नहीं जा सका। अपना कनेक्शन जांचें और पुनः प्रयास करें।',
        'Impossible de supprimer. Vérifiez votre connexion et réessayez.',
        'No se pudo eliminar. Comprueba tu conexión e inténtalo de nuevo.',
        'Não foi possível excluir. Verifique sua conexão e tente novamente.',
        'Löschen fehlgeschlagen. Überprüfen Sie Ihre Verbindung und versuchen Sie es erneut.',
        'Silinemedi. Bağlantınızı kontrol edip tekrar deneyin.',
        'Tidak dapat menghapus. Periksa koneksi Anda dan coba lagi.',
        'মুছে ফেলা যায়নি। আপনার সংযোগ পরীক্ষা করে আবার চেষ্টা করুন।'
      );


  // ---- Board fidelity phase 7: core tabs (07-12) ----
  String get boardCreateSomething => _get(
      'Let\'s create something amazing today!',
      'آج کچھ شاندار بناتے ہیں!',
      'لنصنع شيئًا مذهلاً اليوم!',
        'आज कुछ कमाल बनाते हैं!',
        'Créons quelque chose d\'incroyable aujourd\'hui !',
        '¡Creemos algo increíble hoy!',
        'Vamos criar algo incrível hoje!',
        'Lass uns heute etwas Großartiges schaffen!',
        'Bugün harika bir şey oluşturalım!',
        'Ayo buat sesuatu yang luar biasa hari ini!',
        'আজ অসাধারণ কিছু তৈরি করি!'
      );
  String get boardDiscover => _get('Discover', 'ڈسکور', 'اكتشف',
        'डिस्कवर',
        'Découvrir',
        'Descubrir',
        'Descobrir',
        'Entdecken',
        'Keşfet',
        'Temukan',
        'ডিসকভার'
      );
  String get boardForYou => _get('For You', 'آپ کے لیے', 'لك',
        'आपके लिए',
        'Pour vous',
        'Para ti',
        'Para você',
        'Für dich',
        'Senin İçin',
        'Untukmu',
        'আপনার জন্য'
      );
  String get boardTrending => _get('Trending', 'ٹرینڈنگ', 'الرائج',
        'ट्रेंडिंग',
        'Tendances',
        'Tendencias',
        'Em alta',
        'Trending',
        'Trendler',
        'Tren',
        'ট্রেন্ডিং'
      );
  String get boardAllPosts => _get('All Posts', 'تمام پوسٹس', 'كل المنشورات',
        'सभी पोस्ट्स',
        'Toutes les publications',
        'Todas las publicaciones',
        'Todas as publicações',
        'Alle Beiträge',
        'Tüm Gönderiler',
        'Semua Postingan',
        'সব পোস্ট'
      );
  String get boardSearch => _get('Search', 'تلاش', 'بحث',
        'खोजें',
        'Rechercher',
        'Buscar',
        'Pesquisar',
        'Suchen',
        'Ara',
        'Cari',
        'খুঁজুন'
      );
  String get boardSearchHint => _get('Search...', 'تلاش کریں...', 'ابحث...',
        'खोजें…',
        'Rechercher…',
        'Buscar…',
        'Pesquisar…',
        'Suchen…',
        'Ara…',
        'Cari…',
        'খুঁজুন…'
      );
  String get boardPosts => _get('Posts', 'پوسٹس', 'المنشورات',
        'पोस्ट्स',
        'Publications',
        'Publicaciones',
        'Publicações',
        'Beiträge',
        'Gönderiler',
        'Postingan',
        'পোস্টসমূহ'
      );
  String get boardReels => _get('Reels', 'ریلز', 'ريلز',
        'रील्स',
        'Reels',
        'Reels',
        'Reels',
        'Reels',
        'Reels',
        'Reels',
        'রিলস'
      );
  String get boardShop => _get('Shop', 'شاپ', 'المتجر',
        'शॉप',
        'Boutique',
        'Tienda',
        'Loja',
        'Shop',
        'Mağaza',
        'Toko',
        'শপ'
      );
  String get boardNoCreatorPosts => _get('No posts from this creator yet',
      'اس کریئیٹر کی ابھی کوئی پوسٹ نہیں', 'لا توجد منشورات لهذا المبدع بعد',
        'इस क्रिएटर की अभी कोई पोस्ट नहीं',
        'Aucune publication de ce créateur pour le moment',
        'Este creador aún no tiene publicaciones',
        'Este criador ainda não tem publicações',
        'Dieser Creator hat noch keine Beiträge',
        'Bu üreticinin henüz gönderisi yok',
        'Kreator ini belum memiliki postingan',
        'এই ক্রিয়েটরের এখনও কোনো পোস্ট নেই'
      );
  String get boardProductsTab => _get('Products', 'پراڈکٹس', 'المنتجات',
        'प्रोडक्ट्स',
        'Produits',
        'Productos',
        'Produtos',
        'Produkte',
        'Ürünler',
        'Produk',
        'পণ্যসমূহ'
      );
  String get boardUsers => _get('Users', 'صارفین', 'المستخدمون',
        'यूज़र्स',
        'Utilisateurs',
        'Usuarios',
        'Usuários',
        'Nutzer',
        'Kullanıcılar',
        'Pengguna',
        'ব্যবহারকারী'
      );
  String get boardCategories => _get('Categories', 'کیٹیگریز', 'الفئات',
        'कैटेगरीज़',
        'Catégories',
        'Categorías',
        'Categorias',
        'Kategorien',
        'Kategoriler',
        'Kategori',
        'ক্যাটাগরি'
      );
  String get boardTrendingNow =>
      _get('Trending Now', 'ٹرینڈنگ ناؤ', 'الرائج الآن',
        'अभी ट्रेंडिंग',
        'Tendances actuelles',
        'Tendencias ahora',
        'Em alta agora',
        'Jetzt im Trend',
        'Şimdi Trend',
        'Sedang Tren',
        'এখন ট্রেন্ডিং'
      );
  String get boardNoResults =>
      _get('No results found', 'کوئی نتیجہ نہیں ملا', 'لا توجد نتائج',
        'कोई नतीजा नहीं मिला',
        'Aucun résultat trouvé',
        'Sin resultados',
        'Nenhum resultado encontrado',
        'Keine Ergebnisse gefunden',
        'Sonuç bulunamadı',
        'Tidak ada hasil',
        'কোনো ফলাফল পাওয়া যায়নি'
      );
  String get boardTryDifferent =>
      _get('Try a different search', 'کچھ اور تلاش کریں', 'جرّب بحثًا مختلفًا',
        'कुछ और खोजें',
        'Essayez une autre recherche',
        'Prueba con otra búsqueda',
        'Tente outra pesquisa',
        'Versuche eine andere Suche',
        'Farklı bir arama deneyin',
        'Coba pencarian lain',
        'অন্য কিছু খুঁজুন'
      );
  // Category names (board 10)
  String get boardCatFashion => _get('Fashion', 'فیشن', 'أزياء',
        'फैशन',
        'Mode',
        'Moda',
        'Moda',
        'Mode',
        'Moda',
        'Fashion',
        'ফ্যাশন'
      );
  String get boardCatFood =>
      _get('Food & Recipes', 'کھانے اور ترکیبیں', 'طعام ووصفات',
        'फूड और रेसिपीज़',
        'Cuisine & recettes',
        'Comida y recetas',
        'Comida e receitas',
        'Essen & Rezepte',
        'Yemek & Tarifler',
        'Makanan & Resep',
        'খাবার ও রেসিপি'
      );
  String get boardCatTech =>
      _get('Tech & Gadgets', 'ٹیک اور گیجٹس', 'تقنية وأجهزة',
        'टेक और गैजेट्स',
        'Tech & gadgets',
        'Tecnología y gadgets',
        'Tecnologia e gadgets',
        'Technik & Gadgets',
        'Teknoloji & Aletler',
        'Teknologi & Gadget',
        'টেক ও গ্যাজেট'
      );
  String get boardCatBeauty =>
      _get('Beauty & Skincare', 'بیوٹی اور اسکن کیئر', 'جمال وعناية',
        'ब्यूटी और स्किनकेयर',
        'Beauté & soins',
        'Belleza y cuidado de la piel',
        'Beleza e cuidados com a pele',
        'Beauty & Hautpflege',
        'Güzellik & Cilt Bakımı',
        'Kecantikan & Perawatan Kulit',
        'বিউটি ও স্কিনকেয়ার'
      );
  String get boardCatHome =>
      _get('Home & Living', 'گھر اور رہن سہن', 'منزل ومعيشة',
        'होम और लिविंग',
        'Maison & déco',
        'Hogar y vida',
        'Casa e decoração',
        'Wohnen & Leben',
        'Ev & Yaşam',
        'Rumah & Gaya Hidup',
        'বাড়ি ও জীবনযাপন'
      );
  String get boardCatTravel => _get('Travel', 'سفر', 'سفر',
        'ट्रैवल',
        'Voyage',
        'Viajes',
        'Viagem',
        'Reisen',
        'Seyahat',
        'Wisata',
        'ভ্রমণ'
      );
  String get boardCatEducation => _get('Education', 'تعلیم', 'تعليم',
        'एजुकेशन',
        'Éducation',
        'Educación',
        'Educação',
        'Bildung',
        'Eğitim',
        'Edukasi',
        'শিক্ষা'
      );
  String get boardCatMore => _get('More', 'مزید', 'المزيد',
        'और',
        'Plus',
        'Más',
        'Mais',
        'Mehr',
        'Daha Fazla',
        'Lainnya',
        'আরও'
      );
  String get boardFilterActive => _get('Filter', 'فلٹر', 'تصفية',
        'फ़िल्टर',
        'Filtre',
        'Filtro',
        'Filtro',
        'Filter',
        'Filtre',
        'Filter',
        'ফিল্টার'
      );
  String get boardClearFilter => _get('Clear', 'صاف کریں', 'مسح',
        'साफ़ करें',
        'Effacer',
        'Borrar',
        'Limpar',
        'Zurücksetzen',
        'Temizle',
        'Hapus',
        'মুছুন'
      );
  String get boardTopicsAll =>
      _get('All Topics', 'تمام موضوعات', 'كل المواضيع',
        'सभी टॉपिक्स',
        'Tous les sujets',
        'Todos los temas',
        'Todos os tópicos',
        'Alle Themen',
        'Tüm Konular',
        'Semua Topik',
        'সব বিষয়'
      );

  // ---- Board fidelity phase 10: grow screens (52-84) ----
  String get p10LiveCampaign =>
      _get('Live Campaign', 'لائیو مہم', 'حملة مباشرة',
        'लाइव अभियान',
        'Campagne en cours',
        'Campaña en vivo',
        'Campanha ativa',
        'Live-Kampagne',
        'Canlı Kampanya',
        'Kampanye Live',
        'লাইভ ক্যাম্পেইন'
      );
  String get p10Analyzing =>
      _get('Analyzing...', 'تجزیہ ہو رہا ہے...', 'جارٍ التحليل...',
        'विश्लेषण हो रहा है…',
        'Analyse en cours…',
        'Analizando…',
        'Analisando…',
        'Analysiere…',
        'Analiz ediliyor…',
        'Menganalisis…',
        'বিশ্লেষণ চলছে…'
      );
  String get p10FetchingContent =>
      _get('Fetching content', 'مواد حاصل کیا جا رہا ہے', 'جارٍ جلب المحتوى',
        'कंटेंट लाया जा रहा है',
        'Récupération du contenu',
        'Obteniendo contenido',
        'Buscando conteúdo',
        'Inhalt wird abgerufen',
        'İçerik getiriliyor',
        'Mengambil konten',
        'কন্টেন্ট আনা হচ্ছে'
      );
  String get p10AnalyzingTopicAudience => _get('Analyzing topic & audience',
      'موضوع اور سامعین کا تجزیہ', 'تحليل الموضوع والجمهور',
        'टॉपिक और ऑडियंस का विश्लेषण',
        'Analyse du sujet et de l\'audience',
        'Analizando tema y audiencia',
        'Analisando tema e público',
        'Thema & Zielgruppe werden analysiert',
        'Konu ve kitle analiz ediliyor',
        'Menganalisis topik & audiens',
        'বিষয় ও অডিয়েন্স বিশ্লেষণ করা হচ্ছে'
      );
  String get p10GeneratingInsights =>
      _get('Generating insights', 'بصیرتیں بنائی جا رہی ہیں', 'توليد الرؤى',
        'इनसाइट्स बनाई जा रही हैं',
        'Génération d\'insights',
        'Generando ideas clave',
        'Gerando insights',
        'Erkenntnisse werden erstellt',
        'İçgörüler oluşturuluyor',
        'Membuat wawasan',
        'ইনসাইট তৈরি করা হচ্ছে'
      );
  String get p10PreparingRecommendations => _get(
      'Preparing recommendations', 'سفارشات تیار ہو رہی ہیں', 'تجهيز التوصيات',
        'सिफारिशें तैयार हो रही हैं',
        'Préparation des recommandations',
        'Preparando recomendaciones',
        'Preparando recomendações',
        'Empfehlungen werden vorbereitet',
        'Öneriler hazırlanıyor',
        'Menyiapkan rekomendasi',
        'সুপারিশ প্রস্তুত করা হচ্ছে'
      );
  String get p10ViewDetails =>
      _get('View Details', 'تفصیلات دیکھیں', 'عرض التفاصيل',
        'डिटेल्स देखें',
        'Voir les détails',
        'Ver detalles',
        'Ver detalhes',
        'Details ansehen',
        'Detayları Gör',
        'Lihat Detail',
        'বিস্তারিত দেখুন'
      );
  String get p10AiGrowthAgent =>
      _get('AI Growth Agent', 'AI گروتھ ایجنٹ', 'وكيل النمو بالذكاء الاصطناعي',
        'AI ग्रोथ एजेंट',
        'Agent de croissance IA',
        'Agente de crecimiento IA',
        'Agente de crescimento IA',
        'KI-Wachstumsagent',
        'Yapay Zeka Büyüme Ajanı',
        'Agen Pertumbuhan AI',
        'AI গ্রোথ এজেন্ট'
      );
  String get p10Optimizing =>
      _get('Optimizing', 'بہتر بنایا جا رہا ہے', 'جارٍ التحسين',
        'ऑप्टिमाइज़ हो रहा है',
        'Optimisation en cours',
        'Optimizando',
        'Otimizando',
        'Wird optimiert',
        'Optimize ediliyor',
        'Mengoptimalkan',
        'অপটিমাইজ করা হচ্ছে'
      );
  String get p10AnalyzingPerformance =>
      _get('Analyzing performance', 'کارکردگی کا تجزیہ', 'تحليل الأداء',
        'परफॉर्मेंस का विश्लेषण',
        'Analyse des performances',
        'Analizando el rendimiento',
        'Analisando o desempenho',
        'Leistung wird analysiert',
        'Performans analiz ediliyor',
        'Menganalisis performa',
        'পারফরম্যান্স বিশ্লেষণ করা হচ্ছে'
      );
  String get p10AdjustingBalance =>
      _get('Adjusting balance', 'توازن درست کیا جا رہا ہے', 'ضبط التوازن',
        'बैलेंस एडजस्ट हो रहा है',
        'Ajustement de l\'équilibre',
        'Ajustando el balance',
        'Ajustando o equilíbrio',
        'Balance wird angepasst',
        'Denge ayarlanıyor',
        'Menyesuaikan keseimbangan',
        'ব্যালেন্স সমন্বয় করা হচ্ছে'
      );
  String get p10OptimizingBudget =>
      _get('Optimizing budget', 'بجٹ بہتر بنایا جا رہا ہے', 'تحسين الميزانية',
        'बजट ऑप्टिमाइज़ हो रहा है',
        'Optimisation du budget',
        'Optimizando el presupuesto',
        'Otimizando o orçamento',
        'Budget wird optimiert',
        'Bütçe optimize ediliyor',
        'Mengoptimalkan anggaran',
        'বাজেট অপটিমাইজ করা হচ্ছে'
      );
  String get p10Online => _get('Online', 'آن لائن', 'متصل',
        'ऑनलाइन',
        'En ligne',
        'En línea',
        'Online',
        'Online',
        'Çevrimiçi',
        'Online',
        'অনলাইন'
      );
  String get p10GoLive => _get('Go Live', 'لائیو کریں', 'انشر',
        'लाइव जाएं',
        'Lancer',
        'Lanzar',
        'Lançar',
        'Live gehen',
        'Canlıya Geç',
        'Mulai Live',
        'লাইভ যান'
      );
  String get p10ContentScore =>
      _get('Content Score', 'مواد اسکور', 'نتيجة المحتوى',
        'कंटेंट स्कोर',
        'Score de contenu',
        'Puntuación de contenido',
        'Pontuação de conteúdo',
        'Inhalts-Score',
        'İçerik Puanı',
        'Skor Konten',
        'কন্টেন্ট স্কোর'
      );
  String get p10Video => _get('Video', 'ویڈیو', 'فيديو',
        'वीडियो',
        'Vidéo',
        'Video',
        'Vídeo',
        'Video',
        'Video',
        'Video',
        'ভিডিও'
      );
  String get p10Story => _get('Story', 'اسٹوری', 'قصة',
        'स्टोरी',
        'Story',
        'Historia',
        'Story',
        'Story',
        'Hikâye',
        'Story',
        'স্টোরি'
      );
  String get p10Carousel => _get('Carousel', 'کیروسل', 'دوّار',
        'कैरोसेल',
        'Carrousel',
        'Carrusel',
        'Carrossel',
        'Karussell',
        'Döngü',
        'Korsel',
        'ক্যারোসেল'
      );
  String get p10Recommendations =>
      _get('Recommendations', 'سفارشات', 'التوصيات',
        'सिफारिशें',
        'Recommandations',
        'Recomendaciones',
        'Recomendações',
        'Empfehlungen',
        'Öneriler',
        'Rekomendasi',
        'সুপারিশসমূহ'
      );
  String get p10Creators => _get('Creators', 'کریئیٹرز', 'المبدعون',
        'क्रिएटर्स',
        'Créateurs',
        'Creadores',
        'Criadores',
        'Creator',
        'Üreticiler',
        'Kreator',
        'ক্রিয়েটররা'
      );
  String get p10ApplyAll => _get('Apply All', 'سب لاگو کریں', 'تطبيق الكل',
        'सभी लागू करें',
        'Tout appliquer',
        'Aplicar todo',
        'Aplicar tudo',
        'Alle übernehmen',
        'Tümünü Uygula',
        'Terapkan Semua',
        'সব প্রয়োগ করুন'
      );
  String get p10ApplyAllWhy => _get(
      'Recommendations are applied automatically when the AI optimization agent runs. Use "Go Live" on the AI Growth Agent panel to run it.',
      'AI آپٹیمائزیشن ایجنٹ چلنے پر سفارشات خودکار طور پر لاگو ہوتی ہیں۔ اسے چلانے کے لیے AI گروتھ ایجنٹ پینل پر "Go Live" دبائیں۔',
      'تُطبَّق التوصيات تلقائيًا عند تشغيل وكيل التحسين. اضغط "انشر" في لوحة وكيل النمو لتشغيله.',
        'AI ऑप्टिमाइज़ेशन एजेंट चलने पर सिफारिशें अपने आप लागू होती हैं। इसे चलाने के लिए AI ग्रोथ एजेंट पैनल पर "लाइव जाएं" दबाएं।',
        'Les recommandations sont appliquées automatiquement lorsque l\'agent d\'optimisation IA s\'exécute. Utilisez « Lancer » sur le panneau de l\'agent de croissance IA pour l\'exécuter.',
        'Las recomendaciones se aplican automáticamente cuando se ejecuta el agente de optimización de IA. Usa "Lanzar" en el panel del agente de crecimiento IA para ejecutarlo.',
        'As recomendações são aplicadas automaticamente quando o agente de otimização de IA é executado. Use "Lançar" no painel do agente de crescimento IA para executá-lo.',
        'Empfehlungen werden automatisch angewendet, sobald der KI-Optimierungsagent läuft. Nutze "Live gehen" im KI-Wachstumsagent-Panel, um ihn zu starten.',
        'Yapay zeka optimizasyon ajanı çalıştığında öneriler otomatik olarak uygulanır. Çalıştırmak için Yapay Zeka Büyüme Ajanı panelindeki "Canlıya Geç" düğmesini kullanın.',
        'Rekomendasi diterapkan otomatis saat agen optimasi AI berjalan. Gunakan "Mulai Live" di panel Agen Pertumbuhan AI untuk menjalankannya.',
        'AI অপটিমাইজেশন এজেন্ট চললে সুপারিশগুলো স্বয়ংক্রিয়ভাবে প্রয়োগ হয়। এটি চালাতে AI গ্রোথ এজেন্ট প্যানেলে "লাইভ যান" চাপুন।'
      );
  String p10RecsHeadline(int n) => _get('$n AI recommendations ready',
      '$n AI سفارشات تیار ہیں', '$n توصية جاهزة من الذكاء الاصطناعي',
        '$n AI सिफारिशें तैयार हैं',
        '$n recommandations IA prêtes',
        '$n recomendaciones de IA listas',
        '$n recomendações de IA prontas',
        '$n KI-Empfehlungen bereit',
        '$n yapay zeka önerisi hazır',
        '$n rekomendasi AI siap',
        '$nটি AI সুপারিশ প্রস্তুত'
      );
  String get p10GreatStart =>
      _get('Great progress', 'زبردست پیش رفت', 'تقدم رائع',
        'बढ़िया प्रगति',
        'Beau progrès',
        'Gran progreso',
        'Ótimo progresso',
        'Großartiger Fortschritt',
        'Harika ilerleme',
        'Kemajuan bagus',
        'দারুণ অগ্রগতি'
      );
  String get p10AudienceSegments =>
      _get('Audience Segments', 'سامعین کے طبقات', 'شرائح الجمهور',
        'ऑडियंस सेगमेंट्स',
        'Segments d\'audience',
        'Segmentos de audiencia',
        'Segmentos de público',
        'Zielgruppensegmente',
        'Kitle Segmentleri',
        'Segmen Audiens',
        'অডিয়েন্স সেগমেন্ট'
      );
  String get p10ViewAllSegments =>
      _get('View all segments', 'تمام طبقات دیکھیں', 'عرض كل الشرائح',
        'सभी सेगमेंट देखें',
        'Voir tous les segments',
        'Ver todos los segmentos',
        'Ver todos os segmentos',
        'Alle Segmente ansehen',
        'Tüm Segmentleri Gör',
        'Lihat Semua Segmen',
        'সব সেগমেন্ট দেখুন'
      );
  String get p10NoSegments => _get('No audience segments yet',
      'ابھی کوئی سامعین طبقات نہیں', 'لا توجد شرائح جمهور بعد',
        'अभी कोई ऑडियंस सेगमेंट नहीं',
        'Aucun segment d\'audience pour le moment',
        'Sin segmentos de audiencia aún',
        'Sem segmentos de público ainda',
        'Noch keine Zielgruppensegmente',
        'Henüz kitle segmenti yok',
        'Belum ada segmen audiens',
        'এখনও কোনো অডিয়েন্স সেগমেন্ট নেই'
      );
  String get p10NoSegmentsHint => _get(
      'Audience segments are created from real discovery signals. Run an analysis to start building yours.',
      'سامعین کے طبقات حقیقی دریافت سگنلز سے بنتے ہیں۔ شروع کرنے کے لیے تجزیہ چلائیں۔',
      'تُنشأ شرائح الجمهور من إشارات اكتشاف حقيقية. شغّل تحليلًا للبدء.',
        'ऑडियंस सेगमेंट असली डिस्कवरी सिग्नल्स से बनते हैं। अपना बनाना शुरू करने के लिए विश्लेषण चलाएं।',
        'Les segments d\'audience sont créés à partir de signaux de découverte réels. Lancez une analyse pour commencer à créer les vôtres.',
        'Los segmentos de audiencia se crean a partir de señales de descubrimiento reales. Ejecuta un análisis para empezar a crear los tuyos.',
        'Os segmentos de público são criados a partir de sinais reais de descoberta. Execute uma análise para começar a criar os seus.',
        'Zielgruppensegmente entstehen aus echten Discovery-Signalen. Starte eine Analyse, um deine zu erstellen.',
        'Kitle segmentleri gerçek keşif sinyallerinden oluşturulur. Sizinkini oluşturmaya başlamak için bir analiz çalıştırın.',
        'Segmen audiens dibuat dari sinyal discovery nyata. Jalankan analisis untuk mulai membangun milik Anda.',
        'অডিয়েন্স সেগমেন্ট আসল ডিসকভারি সংকেত থেকে তৈরি হয়। আপনারটি তৈরি শুরু করতে একটি বিশ্লেষণ চালান।'
      );
  String get p10Languages => _get('Languages', 'زبانیں', 'اللغات',
        'भाषाएं',
        'Langues',
        'Idiomas',
        'Idiomas',
        'Sprachen',
        'Diller',
        'Bahasa',
        'ভাষা'
      );
  String get p10Details => _get('Details', 'تفصیلات', 'التفاصيل',
        'डिटेल्स',
        'Détails',
        'Detalles',
        'Detalhes',
        'Details',
        'Detaylar',
        'Detail',
        'বিস্তারিত'
      );
  String get p10LangStatsNote => _get(
      'Audience share per language is not tracked — we never invent percentages. These are the real languages Virello supports.',
      'فی زبان سامعین کا حصہ ٹریک نہیں ہوتا — ہم کبھی فیصد نہیں گھڑتے۔ یہ وہ حقیقی زبانیں ہیں جنہیں Virello سپورٹ کرتا ہے۔',
      'لا نتتبع حصة الجمهور لكل لغة — ولا نخترع النسب أبدًا. هذه هي اللغات الحقيقية التي يدعمها Virello.',
        'प्रति भाषा ऑडियंस शेयर ट्रैक नहीं होता — हम कभी प्रतिशत नहीं गढ़ते। ये वे असली भाषाएं हैं जो Virello सपोर्ट करता है।',
        'La part d\'audience par langue n\'est pas suivie — nous n\'inventons jamais de pourcentages. Voici les vraies langues prises en charge par Virello.',
        'La cuota de audiencia por idioma no se rastrea — nunca inventamos porcentajes. Estos son los idiomas reales que admite Virello.',
        'A parcela de público por idioma não é rastreada — nunca inventamos porcentagens. Estes são os idiomas reais que o Virello suporta.',
        'Der Zielgruppenanteil pro Sprache wird nicht erfasst — wir erfinden niemals Prozentwerte. Das sind die echten Sprachen, die Virello unterstützt.',
        'Dil başına kitle payı takip edilmiyor — asla yüzde uydurmuyoruz. Bunlar Virello\'nun desteklediği gerçek diller.',
        'Pangsa audiens per bahasa tidak dilacak — kami tidak pernah mengarang persentase. Ini adalah bahasa asli yang didukung Virello.',
        'ভাষা অনুযায়ী অডিয়েন্স শেয়ার ট্র্যাক করা হয় না — আমরা কখনও শতাংশ বানাই না। এগুলো হলো আসল ভাষা যেগুলো Virello সমর্থন করে।'
      );
  String get p10ReviewCampaign =>
      _get('Review Campaign', 'مہم کا جائزہ', 'مراجعة الحملة',
        'अभियान की समीक्षा',
        'Examiner la campagne',
        'Revisar campaña',
        'Revisar campanha',
        'Kampagne prüfen',
        'Kampanyayı İncele',
        'Tinjau Kampanye',
        'ক্যাম্পেইন পর্যালোচনা'
      );
  String get p10SelectProducts =>
      _get('Select products...', 'پراڈکٹس منتخب کریں...', 'اختر المنتجات...',
        'प्रोडक्ट्स चुनें…',
        'Sélectionner des produits…',
        'Seleccionar productos…',
        'Selecionar produtos…',
        'Produkte auswählen…',
        'Ürünleri seç…',
        'Pilih produk…',
        'পণ্য বাছুন…'
      );
  String get p10AdSetName =>
      _get('Ad set name', 'ایڈ سیٹ کا نام', 'اسم المجموعة الإعلانية',
        'एड सेट का नाम',
        'Nom de l\'ensemble publicitaire',
        'Nombre del conjunto de anuncios',
        'Nome do conjunto de anúncios',
        'Anzeigengruppenname',
        'Reklam seti adı',
        'Nama set iklan',
        'বিজ্ঞাপন সেটের নাম'
      );
  String get p10CampaignName =>
      _get('Campaign name', 'مہم کا نام', 'اسم الحملة',
        'अभियान का नाम',
        'Nom de la campagne',
        'Nombre de la campaña',
        'Nome da campanha',
        'Kampagnenname',
        'Kampanya adı',
        'Nama kampanye',
        'ক্যাম্পেইনের নাম'
      );
  String get p10NoCampaignToReview => _get(
      'No campaign to review yet. Build a campaign first — it will appear here for your approval.',
      'جائزے کے لیے ابھی کوئی مہم نہیں۔ پہلے مہم بنائیں — وہ منظوری کے لیے یہاں نظر آئے گی۔',
      'لا توجد حملة للمراجعة بعد. أنشئ حملة أولًا — ستظهر هنا لاعتمادها.',
        'समीक्षा के लिए अभी कोई अभियान नहीं। पहले एक अभियान बनाएं — वह आपकी मंज़ूरी के लिए यहां दिखेगा।',
        'Aucune campagne à examiner pour le moment. Créez d\'abord une campagne — elle apparaîtra ici pour votre approbation.',
        'Sin campaña para revisar aún. Crea primero una campaña — aparecerá aquí para tu aprobación.',
        'Sem campanha para revisar ainda. Crie uma campanha primeiro — ela aparecerá aqui para sua aprovação.',
        'Noch keine Kampagne zur Prüfung. Erstelle zuerst eine Kampagne — sie erscheint hier zur Freigabe.',
        'İncelenecek kampanya henüz yok. Önce bir kampanya oluşturun — onayınız için burada görünecek.',
        'Belum ada kampanye untuk ditinjau. Buat kampanye dulu — kampanye akan muncul di sini untuk persetujuan Anda.',
        'পর্যালোচনার জন্য এখনও কোনো ক্যাম্পেইন নেই। প্রথমে একটি ক্যাম্পেইন তৈরি করুন — এটি আপনার অনুমোদনের জন্য এখানে দেখা যাবে।'
      );
  String get p10SubmitApproval =>
      _get('Submit for approval', 'منظوری کے لیے بھیجیں', 'إرسال للاعتماد',
        'मंज़ूरी के लिए भेजें',
        'Soumettre pour approbation',
        'Enviar para aprobación',
        'Enviar para aprovação',
        'Zur Freigabe einreichen',
        'Onay için Gönder',
        'Kirim untuk Persetujuan',
        'অনুমোদনের জন্য জমা দিন'
      );
  String get p10ApprovalNote => _get(
      'Nothing goes live without your approval. Paid boost also needs a verified payment method.',
      'آپ کی منظوری کے بغیر کچھ لائیو نہیں ہوگا۔ پیڈ بوسٹ کے لیے تصدیق شدہ ادائیگی بھی ضروری ہے۔',
      'لا يُنشر شيء دون اعتمادك. يحتاج التعزيز المدفوع أيضًا إلى وسيلة دفع موثّقة.',
        'आपकी मंज़ूरी के बिना कुछ भी लाइव नहीं होगा। पेड बूस्ट के लिए सत्यापित पेमेंट तरीका भी चाहिए।',
        'Rien ne sera publié sans votre approbation. Le boost payant nécessite également un moyen de paiement vérifié.',
        'Nada se publica sin tu aprobación. El impulso pago también necesita un método de pago verificado.',
        'Nada vai ao ar sem sua aprovação. O impulso pago também precisa de um método de pagamento verificado.',
        'Nichts geht ohne deine Freigabe live. Paid Boost braucht außerdem eine verifizierte Zahlungsmethode.',
        'Onayınız olmadan hiçbir şey yayınlanmaz. Ücretli destek için doğrulanmış bir ödeme yöntemi de gerekir.',
        'Tidak ada yang tayang tanpa persetujuan Anda. Boost berbayar juga memerlukan metode pembayaran terverifikasi.',
        'আপনার অনুমোদন ছাড়া কিছুই লাইভ হবে না। পেইড বুস্টের জন্য যাচাইকৃত পেমেন্ট মাধ্যমও দরকার।'
      );
  String get p10CampaignSubmitted => _get('Campaign submitted for approval',
      'مہم منظوری کے لیے بھیج دی گئی', 'أُرسلت الحملة للاعتماد',
        'अभियान मंज़ूरी के लिए भेज दिया गया',
        'Campagne soumise pour approbation',
        'Campaña enviada para aprobación',
        'Campanha enviada para aprovação',
        'Kampagne zur Freigabe eingereicht',
        'Kampanya onaya gönderildi',
        'Kampanye dikirim untuk persetujuan',
        'ক্যাম্পেইন অনুমোদনের জন্য জমা দেওয়া হয়েছে'
      );
  String get p10Services => _get('Services', 'سروسز', 'الخدمات',
        'सर्विसेज़',
        'Services',
        'Servicios',
        'Serviços',
        'Dienste',
        'Hizmetler',
        'Layanan',
        'সেবা'
      );
  String get p10Orders => _get('Orders', 'آرڈرز', 'الطلبات',
        'ऑर्डर्स',
        'Commandes',
        'Pedidos',
        'Pedidos',
        'Bestellungen',
        'Siparişler',
        'Pesanan',
        'অর্ডার'
      );
  String get p10TotalRevenue =>
      _get('Total revenue', 'کل آمدنی', 'إجمالي الإيرادات',
        'कुल रेवेन्यू',
        'Revenu total',
        'Ingresos totales',
        'Receita total',
        'Gesamtumsatz',
        'Toplam Gelir',
        'Total Pendapatan',
        'মোট আয়'
      );
  String get p10NoSalesYet =>
      _get('No sales yet', 'ابھی کوئی فروخت نہیں', 'لا توجد مبيعات بعد',
        'अभी कोई बिक्री नहीं',
        'Aucune vente pour le moment',
        'Sin ventas aún',
        'Sem vendas ainda',
        'Noch keine Verkäufe',
        'Henüz satış yok',
        'Belum ada penjualan',
        'এখনও কোনো বিক্রি নেই'
      );
  String get p10NoSalesHint => _get(
      'When customers buy your products, real revenue appears here. We never invent sales figures.',
      'جب گاہک آپ کی پراڈکٹس خریدیں گے تو حقیقی آمدنی یہاں نظر آئے گی۔ ہم کبھی فروخت کے اعداد نہیں گھڑتے۔',
      'عندما يشتري العملاء منتجاتك، تظهر الإيرادات الحقيقية هنا. لا نخترع أرقام المبيعات أبدًا.',
        'जब ग्राहक आपके प्रोडक्ट्स खरीदेंगे, असली रेवेन्यू यहां दिखेगा। हम कभी बिक्री के आंकड़े नहीं गढ़ते।',
        'Lorsque les clients achètent vos produits, le vrai chiffre d\'affaires apparaît ici. Nous n\'inventons jamais de chiffres de vente.',
        'Cuando los clientes compren tus productos, los ingresos reales aparecerán aquí. Nunca inventamos cifras de ventas.',
        'Quando os clientes comprarem seus produtos, a receita real aparecerá aqui. Nunca inventamos números de vendas.',
        'Wenn Kunden deine Produkte kaufen, erscheint der echte Umsatz hier. Wir erfinden niemals Verkaufszahlen.',
        'Müşteriler ürünlerinizi satın aldığında gerçek gelir burada görünür. Asla satış rakamı uydurmuyoruz.',
        'Saat pelanggan membeli produk Anda, pendapatan nyata akan muncul di sini. Kami tidak pernah mengarang angka penjualan.',
        'গ্রাহকরা আপনার পণ্য কিনলে আসল আয় এখানে দেখা যাবে। আমরা কখনও বিক্রির সংখ্যা বানাই না।'
      );
  String get p10Leads => _get('Leads', 'لیڈز', 'العملاء المحتملون',
        'लीड्स',
        'Prospects',
        'Leads',
        'Leads',
        'Leads',
        'Lead\'ler',
        'Prospek',
        'লিড'
      );
  String get p10Payments => _get('Payments', 'ادائیگیاں', 'المدفوعات',
        'पेमेंट्स',
        'Paiements',
        'Pagos',
        'Pagamentos',
        'Zahlungen',
        'Ödemeler',
        'Pembayaran',
        'পেমেন্ট'
      );
  String get p10NoShipments => _get('No shipments tracked yet',
      'ابھی کوئی شپمنٹ ٹریک نہیں', 'لا توجد شحنات مُتتبَّعة بعد',
        'अभी कोई शिपमेंट ट्रैक नहीं',
        'Aucun envoi suivi pour le moment',
        'Sin envíos rastreados aún',
        'Sem remessas rastreadas ainda',
        'Noch keine Sendungen verfolgt',
        'Henüz takip edilen gönderi yok',
        'Belum ada pengiriman terlacak',
        'এখনও কোনো শিপমেন্ট ট্র্যাক করা হয়নি'
      );
  String get p10NoShipmentsHint => _get(
      'Shipment tracking is not connected. Your real products are listed under Products.',
      'شپمنٹ ٹریکنگ منسلک نہیں۔ آپ کی حقیقی پراڈکٹس Products میں درج ہیں۔',
      'تتبع الشحنات غير متصل. منتجاتك الحقيقية مدرجة تحت المنتجات.',
        'शिपमेंट ट्रैकिंग जुड़ी नहीं है। आपके असली प्रोडक्ट्स Products में लिस्टेड हैं।',
        'Le suivi des envois n\'est pas connecté. Vos vrais produits sont listés sous Produits.',
        'El seguimiento de envíos no está conectado. Tus productos reales están en Productos.',
        'O rastreamento de remessas não está conectado. Seus produtos reais estão listados em Produtos.',
        'Sendungsverfolgung ist nicht verbunden. Deine echten Produkte stehen unter Produkte.',
        'Kargo takibi bağlı değil. Gerçek ürünleriniz Ürünler altında listeleniyor.',
        'Pelacakan pengiriman tidak terhubung. Produk asli Anda terdaftar di Produk.',
        'শিপমেন্ট ট্র্যাকিং সংযুক্ত নয়। আপনার আসল পণ্যগুলো Products-এ তালিকাভুক্ত।'
      );
  String get p10Shipments => _get('Shipments', 'شپمنٹس', 'الشحنات',
        'शिपमेंट्स',
        'Envois',
        'Envíos',
        'Remessas',
        'Sendungen',
        'Gönderiler',
        'Pengiriman',
        'শিপমেন্ট'
      );
  String get p10CheckPriceAmazon => _get('Check price on Amazon',
      'ایمیزون پر قیمت دیکھیں', 'تحقق من السعر على أمازون',
        'Amazon पर कीमत देखें',
        'Voir le prix sur Amazon',
        'Ver el precio en Amazon',
        'Ver o preço na Amazon',
        'Preis auf Amazon prüfen',
        'Amazon\'da fiyatı gör',
        'Cek harga di Amazon',
        'Amazon-এ দাম দেখুন'
      );
  String get p10DayOverview =>
      _get('Day Overview', 'دن کا جائزہ', 'نظرة اليوم',
        'दिन का ओवरव्यू',
        'Aperçu du jour',
        'Resumen del día',
        'Resumo do dia',
        'Tagesübersicht',
        'Gün Özeti',
        'Ringkasan Harian',
        'দিনের সারসংক্ষেপ'
      );
  String get p10AiContentReport => _get(
      'AI Content Report', 'AI مواد رپورٹ', 'تقرير المحتوى بالذكاء الاصطناعي',
        'AI कंटेंट रिपोर्ट',
        'Rapport de contenu IA',
        'Informe de contenido IA',
        'Relatório de conteúdo IA',
        'KI-Inhaltsbericht',
        'Yapay Zeka İçerik Raporu',
        'Laporan Konten AI',
        'AI কন্টেন্ট রিপোর্ট'
      );
  String get p10ReportEmpty => _get(
      'No report data yet. Publish content and grow campaigns — your real numbers will appear here.',
      'ابھی رپورٹ ڈیٹا نہیں۔ مواد شائع کریں اور مہمات بڑھائیں — آپ کے حقیقی اعداد یہاں نظر آئیں گے۔',
      'لا توجد بيانات تقرير بعد. انشر المحتوى ونمِّ الحملات — ستظهر أرقامك الحقيقية هنا.',
        'अभी कोई रिपोर्ट डेटा नहीं। कंटेंट पब्लिश करें और अभियानों को बढ़ाएं — आपके असली नंबर यहां दिखेंगे।',
        'Aucune donnée de rapport pour le moment. Publiez du contenu et développez des campagnes — vos vrais chiffres apparaîtront ici.',
        'Sin datos de informe aún. Publica contenido y haz crecer tus campañas — tus números reales aparecerán aquí.',
        'Sem dados de relatório ainda. Publique conteúdo e faça suas campanhas crescerem — seus números reais aparecerão aqui.',
        'Noch keine Berichtsdaten. Veröffentliche Inhalte und lasse Kampagnen wachsen — deine echten Zahlen erscheinen hier.',
        'Henüz rapor verisi yok. İçerik yayınlayın ve kampanyaları büyütün — gerçek rakamlarınız burada görünecek.',
        'Belum ada data laporan. Publikasikan konten dan kembangkan kampanye — angka nyata Anda akan muncul di sini.',
        'এখনও কোনো রিপোর্ট ডেটা নেই। কন্টেন্ট প্রকাশ করুন এবং ক্যাম্পেইন বাড়ান — আপনার আসল সংখ্যা এখানে দেখা যাবে।'
      );
  String get p10GrowthAI =>
      _get('GrowthAI', 'گروتھ AI', 'نمو الذكاء الاصطناعي',
        'GrowthAI',
        'GrowthAI',
        'GrowthAI',
        'GrowthAI',
        'GrowthAI',
        'GrowthAI',
        'GrowthAI',
        'GrowthAI'
      );
  String get p10Chat => _get('Chat', 'چیٹ', 'دردشة',
        'चैट',
        'Discussion',
        'Chat',
        'Chat',
        'Chat',
        'Sohbet',
        'Chat',
        'চ্যাট'
      );
  String get p10History => _get('History', 'ہسٹری', 'السجل',
        'हिस्ट्री',
        'Historique',
        'Historial',
        'Histórico',
        'Verlauf',
        'Geçmiş',
        'Riwayat',
        'ইতিহাস'
      );
  String get p10CampaignSetup =>
      _get('Campaign Setup', 'مہم سیٹ اپ', 'إعداد الحملة',
        'अभियान सेटअप',
        'Configuration de la campagne',
        'Configuración de la campaña',
        'Configuração da campanha',
        'Kampagnen-Setup',
        'Kampanya Kurulumu',
        'Pengaturan Kampanye',
        'ক্যাম্পেইন সেটআপ'
      );
  String get p10Budget => _get('Budget', 'بجٹ', 'الميزانية',
        'बजट',
        'Budget',
        'Presupuesto',
        'Orçamento',
        'Budget',
        'Bütçe',
        'Anggaran',
        'বাজেট'
      );
  String get p10Duration => _get('Duration', 'مدت', 'المدة',
        'अवधि',
        'Durée',
        'Duración',
        'Duração',
        'Dauer',
        'Süre',
        'Durasi',
        'মেয়াদ'
      );
  String get p10Audience => _get('Audience', 'سامعین', 'الجمهور',
        'ऑडियंस',
        'Audience',
        'Audiencia',
        'Público',
        'Zielgruppe',
        'Kitle',
        'Audiens',
        'অডিয়েন্স'
      );
  String get p10Days => _get('days', 'دن', 'أيام',
        'दिन',
        'jours',
        'días',
        'dias',
        'Tage',
        'gün',
        'hari',
        'দিন'
      );
  String get p10FreeGrowPlan => _get('Free Grow', 'مفت گرو', 'نمو مجاني',
        'फ्री ग्रो',
        'Croissance gratuite',
        'Crecimiento gratis',
        'Crescimento grátis',
        'Kostenloses Wachstum',
        'Ücretsiz Büyüme',
        'Grow Gratis',
        'ফ্রি গ্রো'
      );
  String get p10PaidBoostPlan => _get('Paid Boost', 'پیڈ بوسٹ', 'تعزيز مدفوع',
        'पेड बूस्ट',
        'Boost payant',
        'Impulso pago',
        'Impulso pago',
        'Paid Boost',
        'Ücretli Destek',
        'Boost Berbayar',
        'পেইড বুস্ট'
      );
  String get p10CreateCampaign =>
      _get('Create Campaign', 'مہم بنائیں', 'أنشئ الحملة',
        'अभियान बनाएं',
        'Créer une campagne',
        'Crear campaña',
        'Criar campanha',
        'Kampagne erstellen',
        'Kampanya Oluştur',
        'Buat Kampanye',
        'ক্যাম্পেইন তৈরি করুন'
      );
  String get p10CampaignCreated => _get(
      'Campaign created — review and approve it to go live.',
      'مہم بن گئی — لائیو کرنے کے لیے جائزہ لیں اور منظور کریں۔',
      'تم إنشاء الحملة — راجعها واعتمدها للنشر.',
        'अभियान बन गया — लाइव करने के लिए समीक्षा करें और मंज़ूरी दें।',
        'Campagne créée — examinez-la et approuvez-la pour la publier.',
        'Campaña creada — revísala y apruébala para publicarla.',
        'Campanha criada — revise-a e aprove-a para lançá-la.',
        'Kampagne erstellt — prüfe und genehmige sie, damit sie live geht.',
        'Kampanya oluşturuldu — yayınlanması için inceleyin ve onaylayın.',
        'Kampanye dibuat — tinjau dan setujui agar tayang.',
        'ক্যাম্পেইন তৈরি হয়েছে — লাইভ করতে এটি পর্যালোচনা ও অনুমোদন করুন।'
      );
  String get p10DevHeuristicNote => _get(
      'Dev preview: heuristic AI until a production provider is connected.',
      'ڈیو پریویو: پروڈکشن فراہم کنندہ منسلک ہونے تک ہیورسٹک AI۔',
      'معاينة تطويرية: ذكاء اصطناعي إرشادي حتى توصيل مزوّد الإنتاج.',
        'डेव प्रीव्यू: प्रोडक्शन प्रदाता कनेक्ट होने तक अनुमान-आधारित AI।',
        'Aperçu dev : IA heuristique jusqu\'à la connexion d\'un fournisseur de production.',
        'Vista previa dev: IA heurística hasta que se conecte un proveedor de producción.',
        'Prévia dev: IA heurística até um provedor de produção ser conectado.',
        'Dev-Vorschau: heuristische KI, bis ein Produktionsanbieter verbunden ist.',
        'Geliştirici önizlemesi: üretim sağlayıcısı bağlanana kadar sezgisel yapay zeka.',
        'Pratinjau dev: AI heuristik hingga penyedia produksi terhubung.',
        'ডেভ প্রিভিউ: প্রোডাকশন প্রোভাইডার সংযুক্ত না হওয়া পর্যন্ত অনুমানভিত্তিক AI।'
      );
  String get p10EstimatedReach =>
      _get('Estimated reach', 'متوقع رسائی', 'الوصول المتوقع',
        'अनुमानित रीच',
        'Portée estimée',
        'Alcance estimado',
        'Alcance estimado',
        'Geschätzte Reichweite',
        'Tahmini Erişim',
        'Perkiraan Jangkauan',
        'আনুমানিক রিচ'
      );
  String get p10EstimateNote => _get('Estimate — not a guarantee.',
      'تخمینہ — ضمانت نہیں۔', 'تقدير — ليس ضمانًا.',
        'अनुमान — गारंटी नहीं।',
        'Estimation — pas une garantie.',
        'Estimación — no es una garantía.',
        'Estimativa — não é uma garantia.',
        'Schätzung — keine Garantie.',
        'Tahmin — garanti değil.',
        'Perkiraan — bukan jaminan.',
        'আনুমানিক — গ্যারান্টি নয়।'
      );
  String get p10Status => _get('Status', 'حیثیت', 'الحالة',
        'स्टेटस',
        'Statut',
        'Estado',
        'Status',
        'Status',
        'Durum',
        'Status',
        'অবস্থা'
      );
  String get p10Approved => _get('Approved', 'منظور شدہ', 'معتمدة',
        'मंज़ूर',
        'Approuvée',
        'Aprobada',
        'Aprovada',
        'Genehmigt',
        'Onaylandı',
        'Disetujui',
        'অনুমোদিত'
      );
  String get p10PendingApproval =>
      _get('Pending approval', 'منظوری زیر التواء', 'بانتظار الاعتماد',
        'मंज़ूरी लंबित',
        'En attente d\'approbation',
        'Pendiente de aprobación',
        'Aguardando aprovação',
        'Ausstehende Freigabe',
        'Onay bekliyor',
        'Menunggu persetujuan',
        'অনুমোদনের অপেক্ষায়'
      );
  String get p10Draft => _get('Draft', 'مسودہ', 'مسودة',
        'ड्राफ्ट',
        'Brouillon',
        'Borrador',
        'Rascunho',
        'Entwurf',
        'Taslak',
        'Draf',
        'খসড়া'
      );
  String get p10Active => _get('Active', 'فعال', 'نشطة',
        'एक्टिव',
        'Active',
        'Activa',
        'Ativa',
        'Aktiv',
        'Aktif',
        'Aktif',
        'সক্রিয়'
      );
  String get p10ApproveAndLaunch =>
      _get('Approve & Launch', 'منظور کریں اور لانچ کریں', 'اعتمد وانشر',
        'मंज़ूर करें और लॉन्च करें',
        'Approuver et lancer',
        'Aprobar y lanzar',
        'Aprovar e lançar',
        'Genehmigen & starten',
        'Onayla ve Yayınla',
        'Setujui & Luncurkan',
        'অনুমোদন ও চালু করুন'
      );
  String get p10PaidNeedsPayment => _get(
      'Paid Boost needs a verified payment method first. Add one in Plan & Billing, then approve this campaign.',
      'پیڈ بوسٹ کے لیے پہلے تصدیق شدہ ادائیگی کا طریقہ ضروری ہے۔ Plan & Billing میں شامل کریں، پھر اس مہم کو منظور کریں۔',
      'يحتاج التعزيز المدفوع إلى وسيلة دفع موثّقة أولًا. أضف واحدة في الخطة والفوترة، ثم اعتمد هذه الحملة.',
        'पेड बूस्ट के लिए पहले सत्यापित पेमेंट तरीका चाहिए। Plan & Billing में एक जोड़ें, फिर इस अभियान को मंज़ूर करें।',
        'Le boost payant nécessite d\'abord un moyen de paiement vérifié. Ajoutez-en un dans Plan & Facturation, puis approuvez cette campagne.',
        'El impulso pago necesita primero un método de pago verificado. Agrega uno en Plan y Facturación, luego aprueba esta campaña.',
        'O impulso pago precisa primeiro de um método de pagamento verificado. Adicione um em Plano e Faturamento e aprove esta campanha.',
        'Paid Boost braucht zuerst eine verifizierte Zahlungsmethode. Füge eine unter Plan & Abrechnung hinzu und genehmige dann diese Kampagne.',
        'Ücretli Destek için önce doğrulanmış bir ödeme yöntemi gerekir. Plan ve Faturalandırma\'da bir tane ekleyin, ardından bu kampanyayı onaylayın.',
        'Boost berbayar memerlukan metode pembayaran terverifikasi terlebih dahulu. Tambahkan di Paket & Penagihan, lalu setujui kampanye ini.',
        'পেইড বুস্টের জন্য প্রথমে যাচাইকৃত পেমেন্ট মাধ্যম দরকার। Plan & Billing-এ একটি যোগ করুন, তারপর এই ক্যাম্পেইন অনুমোদন করুন।'
      );
  String get p10ConfirmGoLive => _get(
      'This will submit the campaign for approval. Nothing launches without your explicit approval.',
      'اس سے مہم منظوری کے لیے بھیجی جائے گی۔ آپ کی واضح منظوری کے بغیر کچھ لانچ نہیں ہوگا۔',
      'سيُرسل هذا الحملة للاعتماد. لا يُنشر شيء دون اعتمادك الصريح.',
        'इससे अभियान मंज़ूरी के लिए भेजा जाएगा। आपकी स्पष्ट मंज़ूरी के बिना कुछ भी लॉन्च नहीं होगा।',
        'Cela soumettra la campagne pour approbation. Rien ne sera lancé sans votre approbation explicite.',
        'Esto enviará la campaña para su aprobación. Nada se lanza sin tu aprobación explícita.',
        'Isso enviará a campanha para aprovação. Nada é lançado sem sua aprovação explícita.',
        'Dadurch wird die Kampagne zur Freigabe eingereicht. Nichts startet ohne deine ausdrückliche Genehmigung.',
        'Bu, kampanyayı onaya gönderecek. Açık onayınız olmadan hiçbir şey yayınlanmaz.',
        'Ini akan mengirim kampanye untuk persetujuan. Tidak ada yang diluncurkan tanpa persetujuan eksplisit Anda.',
        'এটি ক্যাম্পেইনটি অনুমোদনের জন্য জমা দেবে। আপনার স্পষ্ট অনুমোদন ছাড়া কিছুই চালু হবে না।'
      );
  String get p10Confirm => _get('Confirm', 'تصدیق کریں', 'تأكيد',
        'कन्फर्म करें',
        'Confirmer',
        'Confirmar',
        'Confirmar',
        'Bestätigen',
        'Onayla',
        'Konfirmasi',
        'নিশ্চিত করুন'
      );
  String get p10Cancel => _get('Cancel', 'منسوخ کریں', 'إلغاء',
        'रद्द करें',
        'Annuler',
        'Cancelar',
        'Cancelar',
        'Abbrechen',
        'İptal',
        'Batal',
        'বাতিল করুন'
      );
  String get p10Launched =>
      _get('Campaign is live', 'مہم لائیو ہو گئی', 'الحملة منشورة الآن',
        'अभियान लाइव हो गया',
        'La campagne est en ligne',
        'La campaña está en vivo',
        'A campanha está no ar',
        'Die Kampagne ist live',
        'Kampanya yayında',
        'Kampanye sudah tayang',
        'ক্যাম্পেইন লাইভ হয়েছে'
      );
  String get p10MoreGrowTools =>
      _get('More Grow tools', 'مزید گرو ٹولز', 'المزيد من أدوات النمو',
        'और ग्रो टूल्स',
        'Plus d\'outils de croissance',
        'Más herramientas de crecimiento',
        'Mais ferramentas de crescimento',
        'Weitere Wachstumstools',
        'Daha Fazla Büyüme Aracı',
        'Alat Grow lainnya',
        'আরও গ্রো টুলস'
      );
  String get p10ProductPanel =>
      _get('AI Growth Agent', 'AI گروتھ ایجنٹ', 'وكيل النمو بالذكاء الاصطناعي',
        'AI ग्रोथ एजेंट',
        'Agent de croissance IA',
        'Agente de crecimiento IA',
        'Agente de crescimento IA',
        'KI-Wachstumsagent',
        'Yapay Zeka Büyüme Ajanı',
        'Agen Pertumbuhan AI',
        'AI গ্রোথ এজেন্ট'
      );
  String get p10OptRecommendations => _get(
      'Optimization Recommendations', 'آپٹیمائزیشن سفارشات', 'توصيات التحسين',
        'ऑप्टिमाइज़ेशन सिफारिशें',
        'Recommandations d\'optimisation',
        'Recomendaciones de optimización',
        'Recomendações de otimização',
        'Optimierungsempfehlungen',
        'Optimizasyon Önerileri',
        'Rekomendasi Optimasi',
        'অপটিমাইজেশন সুপারিশ'
      );
  String get p10Sales => _get('Sales', 'فروخت', 'المبيعات',
        'बिक्री',
        'Ventes',
        'Ventas',
        'Vendas',
        'Verkäufe',
        'Satışlar',
        'Penjualan',
        'বিক্রি'
      );
  String get p10AiReport =>
      _get('AI Content Report', 'AI مواد رپورٹ', 'تقرير المحتوى',
        'AI कंटेंट रिपोर्ट',
        'Rapport de contenu IA',
        'Informe de contenido IA',
        'Relatório de conteúdo IA',
        'KI-Inhaltsbericht',
        'Yapay Zeka İçerik Raporu',
        'Laporan Konten AI',
        'AI কন্টেন্ট রিপোর্ট'
      );
  String get p10ShipmentDashboard =>
      _get('Shipment Dashboard', 'شپمنٹ ڈیش بورڈ', 'لوحة الشحنات',
        'शिपमेंट डैशबोर्ड',
        'Tableau de bord des envois',
        'Panel de envíos',
        'Painel de remessas',
        'Sendungs-Dashboard',
        'Gönderi Paneli',
        'Dasbor Pengiriman',
        'শিপমেন্ট ড্যাশবোর্ড'
      );
  String get p10Multilingual => _get(
      'Multilingual Audience', 'کثیر لسانی سامعین', 'الجمهور متعدد اللغات',
        'बहुभाषी ऑडियंस',
        'Audience multilingue',
        'Audiencia multilingüe',
        'Público multilíngue',
        'Mehrsprachige Zielgruppe',
        'Çok Dilli Kitle',
        'Audiens Multibahasa',
        'বহুভাষী অডিয়েন্স'
      );
  String get p10CampaignFilterNote =>
      _get('Filter your campaigns', 'اپنی مہمات فلٹر کریں', 'صفِّ حملاتك',
        'अपने अभियान फ़िल्टर करें',
        'Filtrez vos campagnes',
        'Filtra tus campañas',
        'Filtre suas campanhas',
        'Filtere deine Kampagnen',
        'Kampanyalarınızı filtreleyin',
        'Filter kampanye Anda',
        'আপনার ক্যাম্পেইন ফিল্টার করুন'
      );
  String get p10Reach => _get('Reach', 'رسائی', 'الوصول',
        'रीच',
        'Portée',
        'Alcance',
        'Alcance',
        'Reichweite',
        'Erişim',
        'Jangkauan',
        'রিচ'
      );
  String get p10Engagement => _get('Engagement', 'انگیجمنٹ', 'التفاعل',
        'एंगेजमेंट',
        'Engagement',
        'Interacción',
        'Engajamento',
        'Interaktion',
        'Etkileşim',
        'Interaksi',
        'এনগেজমেন্ট'
      );
  String get p10Impressions => _get('Impressions', 'امپریشنز', 'مرات الظهور',
        'इम्प्रेशन्स',
        'Impressions',
        'Impresiones',
        'Impressões',
        'Impressionen',
        'Gösterimler',
        'Tayangan',
        'ইমপ্রেশন'
      );
  String get p10Clicks => _get('Clicks', 'کلکس', 'النقرات',
        'क्लिक्स',
        'Clics',
        'Clics',
        'Cliques',
        'Klicks',
        'Tıklamalar',
        'Klik',
        'ক্লিক'
      );
  String get p10SelectCampaignFirst => _get(
      'Select one of your campaigns first to run the AI Growth Agent.',
      'AI گروتھ ایجنٹ چلانے کے لیے پہلے اپنی ایک مہم منتخب کریں۔',
      'اختر إحدى حملاتك أولًا لتشغيل وكيل النمو.',
        'AI ग्रोथ एजेंट चलाने के लिए पहले अपना एक अभियान चुनें।',
        'Sélectionnez d\'abord l\'une de vos campagnes pour exécuter l\'agent de croissance IA.',
        'Selecciona primero una de tus campañas para ejecutar el agente de crecimiento IA.',
        'Selecione primeiro uma de suas campanhas para executar o agente de crescimento IA.',
        'Wähle zuerst eine deiner Kampagnen, um den KI-Wachstumsagenten zu starten.',
        'Yapay Zeka Büyüme Ajanı\'nı çalıştırmak için önce kampanyalarınızdan birini seçin.',
        'Pilih salah satu kampanye Anda terlebih dahulu untuk menjalankan Agen Pertumbuhan AI.',
        'AI গ্রোথ এজেন্ট চালাতে প্রথমে আপনার একটি ক্যাম্পেইন বেছে নিন।'
      );
  String get p10RunOptimization =>
      _get('Run Optimization', 'آپٹیمائزیشن چلائیں', 'تشغيل التحسين',
        'ऑप्टिमाइज़ेशन चलाएं',
        'Lancer l\'optimisation',
        'Ejecutar optimización',
        'Executar otimização',
        'Optimierung starten',
        'Optimizasyonu Çalıştır',
        'Jalankan Optimasi',
        'অপটিমাইজেশন চালান'
      );
  String get p10OptimizationDone => _get(
      'Optimization run complete — decisions are audited below.',
      'آپٹیمائزیشن مکمل — فیصلے نیچے آڈٹ شدہ ہیں۔',
      'اكتمل تشغيل التحسين — القرارات مدققة أدناه.',
        'ऑप्टिमाइज़ेशन पूरा — फैसले नीचे ऑडिटेड हैं।',
        'Optimisation terminée — les décisions sont auditées ci-dessous.',
        'Optimización completada — las decisiones están auditadas abajo.',
        'Otimização concluída — as decisões estão auditadas abaixo.',
        'Optimierung abgeschlossen — die Entscheidungen sind unten geprüft.',
        'Optimizasyon tamamlandı — kararlar aşağıda denetleniyor.',
        'Optimasi selesai — keputusan diaudit di bawah.',
        'অপটিমাইজেশন সম্পূর্ণ — সিদ্ধান্তগুলো নিচে নিরীক্ষিত।'
      );
  String get p10NoDecisionsYet => _get(
      'No optimization decisions yet. Run the optimizer to generate audited decisions from real campaign data.',
      'ابھی کوئی آپٹیمائزیشن فیصلے نہیں۔ حقیقی مہم ڈیٹا سے آڈٹ شدہ فیصلے بنانے کے لیے آپٹیمائزر چلائیں۔',
      'لا توجد قرارات تحسين بعد. شغّل المحسِّن لتوليد قرارات مدققة من بيانات الحملة الحقيقية.',
        'अभी कोई ऑप्टिमाइज़ेशन फैसला नहीं। असली अभियान डेटा से ऑडिटेड फैसले बनाने के लिए ऑप्टिमाइज़र चलाएं।',
        'Aucune décision d\'optimisation pour le moment. Lancez l\'optimiseur pour générer des décisions auditées à partir de données réelles.',
        'Sin decisiones de optimización aún. Ejecuta el optimizador para generar decisiones auditadas con datos reales de la campaña.',
        'Sem decisões de otimização ainda. Execute o otimizador para gerar decisões auditadas a partir de dados reais da campanha.',
        'Noch keine Optimierungsentscheidungen. Starte den Optimierer, um geprüfte Entscheidungen aus echten Kampagnendaten zu erzeugen.',
        'Henüz optimizasyon kararı yok. Gerçek kampanya verilerinden denetlenmiş kararlar üretmek için optimize ediciyi çalıştırın.',
        'Belum ada keputusan optimasi. Jalankan pengoptimal untuk menghasilkan keputusan yang diaudit dari data kampanye nyata.',
        'এখনও কোনো অপটিমাইজেশন সিদ্ধান্ত নেই। আসল ক্যাম্পেইন ডেটা থেকে নিরীক্ষিত সিদ্ধান্ত তৈরি করতে অপটিমাইজার চালান।'
      );
  String p10StepOf(int i, int n) =>
      _get('Step $i of $n', 'مرحلہ $i از $n', 'الخطوة $i من $n',
        '$n में से चरण $i',
        'Étape $i sur $n',
        'Paso $i de $n',
        'Etapa $i de $n',
        'Schritt $i von $n',
        '$n adımın $i.\'si',
        'Langkah $i dari $n',
        '$n-এর মধ্যে ধাপ $i'
      );
  String get p10PickProduct =>
      _get('Pick a product', 'پراڈکٹ چنیں', 'اختر منتجًا',
        'प्रोडक्ट चुनें',
        'Choisir un produit',
        'Elige un producto',
        'Escolha um produto',
        'Produkt wählen',
        'Bir ürün seç',
        'Pilih produk',
        'একটি পণ্য বাছুন'
      );
  String get p10NoProductsForCampaign => _get(
      'No products yet. Add products in the Shop tab to promote them.',
      'ابھی کوئی پراڈکٹ نہیں۔ پروموٹ کرنے کے لیے Shop ٹیب میں پراڈکٹس شامل کریں۔',
      'لا توجد منتجات بعد. أضف منتجات في تبويب المتجر للترويج لها.',
        'अभी कोई प्रोडक्ट नहीं। प्रमोट करने के लिए Shop टैब में प्रोडक्ट्स जोड़ें।',
        'Aucun produit pour le moment. Ajoutez des produits dans l\'onglet Boutique pour les promouvoir.',
        'Sin productos aún. Agrega productos en la pestaña Tienda para promocionarlos.',
        'Sem produtos ainda. Adicione produtos na aba Loja para promovê-los.',
        'Noch keine Produkte. Füge Produkte im Shop-Tab hinzu, um sie zu bewerben.',
        'Henüz ürün yok. Tanıtmak için Mağaza sekmesinde ürün ekleyin.',
        'Belum ada produk. Tambahkan produk di tab Toko untuk mempromosikannya.',
        'এখনও কোনো পণ্য নেই। প্রচারের জন্য Shop ট্যাবে পণ্য যোগ করুন।'
      );
  String get p10SetAdName => _get('Give your ad set a name',
      'اپنے ایڈ سیٹ کو نام دیں', 'سمِّ مجموعتك الإعلانية',
        'अपने एड सेट को नाम दें',
        'Donnez un nom à votre ensemble publicitaire',
        'Ponle un nombre a tu conjunto de anuncios',
        'Dê um nome ao seu conjunto de anúncios',
        'Gib deiner Anzeigengruppe einen Namen',
        'Reklam setinize bir ad verin',
        'Beri nama set iklan Anda',
        'আপনার বিজ্ঞাপন সেটের নাম দিন'
      );
  String get p10AnalysisFailed =>
      _get('Analysis failed', 'تجزیہ ناکام ہوا', 'فشل التحليل',
        'विश्लेषण विफल',
        'Analyse échouée',
        'Análisis fallido',
        'Análise falhou',
        'Analyse fehlgeschlagen',
        'Analiz başarısız oldu',
        'Analisis gagal',
        'বিশ্লেষণ ব্যর্থ হয়েছে'
      );
  String get p10Retype => _get('Try again', 'دوبارہ کوشش کریں', 'حاول مجددًا',
        'दोबारा कोशिश करें',
        'Réessayer',
        'Intentar de nuevo',
        'Tentar novamente',
        'Erneut versuchen',
        'Tekrar Dene',
        'Coba lagi',
        'আবার চেষ্টা করুন'
      );

  // ---- Phase 11: board fidelity — remaining screens ----
  String get p11Messages => _get('Messages', 'پیغامات', 'الرسائل',
        'मैसेजेज़',
        'Messages',
        'Mensajes',
        'Mensagens',
        'Nachrichten',
        'Mesajlar',
        'Pesan',
        'বার্তা'
      );
  String get p11TabAll => _get('All', 'سب', 'الكل',
        'सभी',
        'Tout',
        'Todo',
        'Tudo',
        'Alle',
        'Tümü',
        'Semua',
        'সব'
      );
  String get p11TabCreators => _get('Creators', 'کریئیٹرز', 'المبدعون',
        'क्रिएटर्स',
        'Créateurs',
        'Creadores',
        'Criadores',
        'Creator',
        'Üreticiler',
        'Kreator',
        'ক্রিয়েটররা'
      );
  String get p11TabCustomers => _get('Customers', 'گاہک', 'العملاء',
        'कस्टमर्स',
        'Clients',
        'Clientes',
        'Clientes',
        'Kunden',
        'Müşteriler',
        'Pelanggan',
        'গ্রাহক'
      );
  String get p11RecentChats =>
      _get('Recent chats', 'حالیہ چیٹس', 'الدردشات الأخيرة',
        'हालिया चैट्स',
        'Discussions récentes',
        'Chats recientes',
        'Conversas recentes',
        'Letzte Chats',
        'Son Sohbetler',
        'Chat Terbaru',
        'সাম্প্রতিক চ্যাট'
      );
  String get p11NoMessages =>
      _get('No messages yet.', 'ابھی کوئی پیغام نہیں۔', 'لا رسائل بعد.',
        'अभी कोई मैसेज नहीं।',
        'Aucun message pour le moment.',
        'Sin mensajes aún.',
        'Sem mensagens ainda.',
        'Noch keine Nachrichten.',
        'Henüz mesaj yok.',
        'Belum ada pesan.',
        'এখনও কোনো বার্তা নেই।'
      );
  String get p11NoMessagesSub => _get(
        'Collab requests from creators and product leads from customers will appear here.',
        'کریئیٹرز کی تعاون کی درخواستیں اور گاہکوں کی پراڈکٹ لیڈز یہاں نظر آئیں گی۔',
        'ستظهر هنا طلبات التعاون والعملاء المحتملون لمنتجاتك.',
      
        'क्रिएटर्स से कोलैब रिक्वेस्ट और कस्टमर्स से प्रोडक्ट लीड्स यहां दिखेंगे।',
        'Les demandes de collaboration des créateurs et les prospects de produits des clients apparaîtront ici.',
        'Las solicitudes de colaboración de creadores y los leads de productos de clientes aparecerán aquí.',
        'Solicitações de colaboração de criadores e leads de produtos de clientes aparecerão aqui.',
        'Collab-Anfragen von Creatorn und Produkt-Leads von Kunden erscheinen hier.',
        'Üreticilerden işbirliği istekleri ve müşterilerden ürün adayları burada görünecek.',
        'Permintaan kolaborasi dari kreator dan prospek produk dari pelanggan akan muncul di sini.',
        'ক্রিয়েটরদের কোলাব অনুরোধ ও গ্রাহকদের পণ্য লিড এখানে দেখা যাবে।'
      );
  String get p11NoCreators => _get('No collab requests yet.',
      'ابھی کوئی تعاون کی درخواست نہیں۔', 'لا طلبات تعاون بعد.',
        'अभी कोई कोलैब रिक्वेस्ट नहीं।',
        'Aucune demande de collaboration pour le moment.',
        'Sin solicitudes de colaboración aún.',
        'Sem solicitações de colaboração ainda.',
        'Noch keine Collab-Anfragen.',
        'Henüz işbirliği isteği yok.',
        'Belum ada permintaan kolaborasi.',
        'এখনও কোনো কোলাব অনুরোধ নেই।'
      );
  String get p11NoCustomers => _get('No customer leads yet.',
      'ابھی کوئی گاہک لیڈ نہیں۔', 'لا عملاء محتملين بعد.',
        'अभी कोई कस्टमर लीड नहीं।',
        'Aucun prospect client pour le moment.',
        'Sin leads de clientes aún.',
        'Sem leads de clientes ainda.',
        'Noch keine Kunden-Leads.',
        'Henüz müşteri adayı yok.',
        'Belum ada prospek pelanggan.',
        'এখনও কোনো গ্রাহক লিড নেই।'
      );
  String get p11CollabRequest =>
      _get('Collab request', 'تعاون کی درخواست', 'طلب تعاون',
        'कोलैब रिक्वेस्ट',
        'Demande de collaboration',
        'Solicitud de colaboración',
        'Solicitação de colaboração',
        'Collab-Anfrage',
        'İşbirliği İsteği',
        'Permintaan Kolaborasi',
        'কোলাব অনুরোধ'
      );
  String get p11ProductLead => _get('Product lead', 'پراڈکٹ لیڈ', 'عميل محتمل',
        'प्रोडक्ट लीड',
        'Prospect produit',
        'Lead de producto',
        'Lead de produto',
        'Produkt-Lead',
        'Ürün Adayı',
        'Prospek Produk',
        'পণ্য লিড'
      );
  String get p11Accept => _get('Accept', 'قبول کریں', 'قبول',
        'स्वीकार करें',
        'Accepter',
        'Aceptar',
        'Aceitar',
        'Annehmen',
        'Kabul Et',
        'Terima',
        'গ্রহণ করুন'
      );
  String get p11Decline => _get('Decline', 'مسترد کریں', 'رفض',
        'अस्वीकार करें',
        'Refuser',
        'Rechazar',
        'Recusar',
        'Ablehnen',
        'Reddet',
        'Tolak',
        'প্রত্যাখ্যান করুন'
      );
  String get p11StatusPending => _get('Pending', 'زیر التواء', 'قيد الانتظار',
        'लंबित',
        'En attente',
        'Pendiente',
        'Pendente',
        'Ausstehend',
        'Beklemede',
        'Tertunda',
        'মুলতুবি'
      );
  String get p11StatusAccepted => _get('Accepted', 'قبول شدہ', 'مقبول',
        'स्वीकार किया गया',
        'Acceptée',
        'Aceptada',
        'Aceita',
        'Angenommen',
        'Kabul Edildi',
        'Diterima',
        'গৃহীত'
      );
  String get p11StatusDeclined => _get('Declined', 'مسترد شدہ', 'مرفوض',
        'अस्वीकार किया गया',
        'Refusée',
        'Rechazada',
        'Recusada',
        'Abgelehnt',
        'Reddedildi',
        'Ditolak',
        'প্রত্যাখ্যাত'
      );
  String get p11RequestUpdated =>
      _get('Request updated.', 'درخواست اپ ڈیٹ ہو گئی۔', 'تم تحديث الطلب.',
        'रिक्वेस्ट अपडेट हो गई।',
        'Demande mise à jour.',
        'Solicitud actualizada.',
        'Solicitação atualizada.',
        'Anfrage aktualisiert.',
        'İstek güncellendi.',
        'Permintaan diperbarui.',
        'অনুরোধ আপডেট হয়েছে।'
      );
  String get p11LeadProduct => _get('Product', 'پراڈکٹ', 'المنتج',
        'प्रोडक्ट',
        'Produit',
        'Producto',
        'Produto',
        'Produkt',
        'Ürün',
        'Produk',
        'পণ্য'
      );
  String get p11LeadSource => _get('Source', 'ذریعہ', 'المصدر',
        'सोर्स',
        'Source',
        'Fuente',
        'Fonte',
        'Quelle',
        'Kaynak',
        'Sumber',
        'উৎস'
      );
  String get p11LeadStatus => _get('Status', 'حیثیت', 'الحالة',
        'स्टेटस',
        'Statut',
        'Estado',
        'Status',
        'Status',
        'Durum',
        'Status',
        'অবস্থা'
      );
  String get p11RequestFrom =>
      _get('Request from', 'درخواست کنندہ', 'مقدِّم الطلب',
        'रिक्वेस्ट भेजने वाला',
        'Demande de',
        'Solicitud de',
        'Solicitação de',
        'Anfrage von',
        'İsteği gönderen',
        'Permintaan dari',
        'অনুরোধকারী'
      );
  String get p11PostLink => _get('Post link', 'پوسٹ کا لنک', 'رابط المنشور',
        'पोस्ट लिंक',
        'Lien de la publication',
        'Enlace de la publicación',
        'Link da publicação',
        'Beitragslink',
        'Gönderi Bağlantısı',
        'Tautan Postingan',
        'পোস্টের লিঙ্ক'
      );
  String get p11FilterUnread => _get('Unread', 'ان پڑھ', 'غير المقروءة',
        'अनपढ़ा',
        'Non lu',
        'No leído',
        'Não lido',
        'Ungelesen',
        'Okunmadı',
        'Belum dibaca',
        'অপঠিত'
      );
  String get p11NoUnread => _get('No unread notifications.',
      'کوئی ان پڑھی اطلاع نہیں۔', 'لا إشعارات غير مقروءة.',
        'कोई अनपढ़ी नोटिफिकेशन नहीं।',
        'Aucune notification non lue.',
        'Sin notificaciones sin leer.',
        'Sem notificações não lidas.',
        'Keine ungelesenen Benachrichtigungen.',
        'Okunmamış bildirim yok.',
        'Tidak ada notifikasi yang belum dibaca.',
        'কোনো অপঠিত বিজ্ঞপ্তি নেই।'
      );
  String get p11SellerDashboard =>
      _get('Seller Dashboard', 'سیلر ڈیش بورڈ', 'لوحة البائع',
        'सेलर डैशबोर्ड',
        'Tableau de bord vendeur',
        'Panel del vendedor',
        'Painel do vendedor',
        'Verkäufer-Dashboard',
        'Satıcı Paneli',
        'Dasbor Penjual',
        'বিক্রেতা ড্যাশবোর্ড'
      );
  String get p11GoLive => _get('Go Live', 'لائیو جائیں', 'بث مباشر',
        'लाइव जाएं',
        'Passer en direct',
        'Transmitir en vivo',
        'Transmitir ao vivo',
        'Live gehen',
        'Canlı Yayınla',
        'Siaran Langsung',
        'লাইভে যান'
      );
  String get p11StatProducts => _get('Products', 'پراڈکٹس', 'المنتجات',
        'प्रोडक्ट्स',
        'Produits',
        'Productos',
        'Produtos',
        'Produkte',
        'Ürünler',
        'Produk',
        'পণ্য'
      );
  String get p11StatLeads => _get('Leads', 'لیڈز', 'العملاء المحتملون',
        'लीड्स',
        'Prospects',
        'Leads',
        'Leads',
        'Leads',
        'Lead\'ler',
        'Prospek',
        'লিড'
      );
  String get p11StatAvgLeads =>
      _get('Avg leads / product', 'اوسط لیڈز / پراڈکٹ', 'متوسط العملاء / منتج',
        'औसत लीड्स / प्रोडक्ट',
        'Prospects moy. / produit',
        'Leads prom. / producto',
        'Leads méd. / produto',
        'Ø Leads / Produkt',
        'Ort. lead / ürün',
        'Rata-rata prospek / produk',
        'গড় লিড / পণ্য'
      );
  String get p11LeadsPerProduct =>
      _get('Leads per product', 'فی پراڈکٹ لیڈز', 'العملاء لكل منتج',
        'प्रति प्रोडक्ट लीड्स',
        'Prospects par produit',
        'Leads por producto',
        'Leads por produto',
        'Leads pro Produkt',
        'Ürün başına lead',
        'Prospek per produk',
        'পণ্য প্রতি লিড'
      );
  String get p11NoProductsYet =>
      _get('No products yet.', 'ابھی کوئی پراڈکٹ نہیں۔', 'لا منتجات بعد.',
        'अभी कोई प्रोडक्ट नहीं।',
        'Aucun produit pour le moment.',
        'Sin productos aún.',
        'Sem produtos ainda.',
        'Noch keine Produkte.',
        'Henüz ürün yok.',
        'Belum ada produk.',
        'এখনও কোনো পণ্য নেই।'
      );
  String get p11NoProductsSub => _get(
        'Add your first product in the Shop to see your seller stats here.',
        'اپنے سیلر اعداد یہاں دیکھنے کے لیے Shop میں اپنی پہلی پراڈکٹ شامل کریں۔',
        'أضف منتجك الأول في المتجر لرؤية إحصاءاتك هنا.',
      
        'अपने सेलर स्टैट्स यहां देखने के लिए Shop में अपना पहला प्रोडक्ट जोड़ें।',
        'Ajoutez votre premier produit dans la Boutique pour voir vos statistiques vendeur ici.',
        'Agrega tu primer producto en la Tienda para ver tus estadísticas de vendedor aquí.',
        'Adicione seu primeiro produto na Loja para ver suas estatísticas de vendedor aqui.',
        'Füge dein erstes Produkt im Shop hinzu, um hier deine Verkäuferstatistiken zu sehen.',
        'Satıcı istatistiklerinizi burada görmek için Mağaza\'da ilk ürününüzü ekleyin.',
        'Tambahkan produk pertama Anda di Toko untuk melihat statistik penjual Anda di sini.',
        'আপনার বিক্রেতা পরিসংখ্যান এখানে দেখতে Shop-এ আপনার প্রথম পণ্য যোগ করুন।'
      );
  String get p11AddProduct =>
      _get('Add product', 'پراڈکٹ شامل کریں', 'أضف منتجًا',
        'प्रोडक्ट जोड़ें',
        'Ajouter un produit',
        'Agregar producto',
        'Adicionar produto',
        'Produkt hinzufügen',
        'Ürün Ekle',
        'Tambah Produk',
        'পণ্য যোগ করুন'
      );
  String get p11LiveSoon => _get(
        'Live selling is not available yet — add products in the Shop instead.',
        'لائیو سیلنگ ابھی دستیاب نہیں — اس کے بجائے Shop میں پراڈکٹس شامل کریں۔',
        'البيع المباشر غير متاح بعد — أضف المنتجات في المتجر بدلًا من ذلك.',
      
        'लाइव सेलिंग अभी उपलब्ध नहीं — इसके बजाय Shop में प्रोडक्ट्स जोड़ें।',
        'La vente en direct n\'est pas encore disponible — ajoutez plutôt des produits dans la Boutique.',
        'La venta en vivo aún no está disponible — agrega productos en la Tienda.',
        'A venda ao vivo ainda não está disponível — adicione produtos na Loja.',
        'Live-Verkauf ist noch nicht verfügbar — füge stattdessen Produkte im Shop hinzu.',
        'Canlı satış henüz kullanılamıyor — bunun yerine Mağaza\'da ürün ekleyin.',
        'Penjualan live belum tersedia — tambahkan produk di Toko saja.',
        'লাইভ বিক্রি এখনও চালু হয়নি — পরিবর্তে Shop-এ পণ্য যোগ করুন।'
      );
  String get p11LanguageAnalytics =>
      _get('Language Analytics', 'زبان کے تجزیات', 'تحليلات اللغة',
        'भाषा एनालिटिक्स',
        'Analytique des langues',
        'Análisis de idiomas',
        'Análise de idiomas',
        'Sprachen-Analytik',
        'Dil Analitiği',
        'Analitik Bahasa',
        'ভাষা বিশ্লেষণ'
      );
  String get p11Languages => _get('Languages', 'زبانیں', 'اللغات',
        'भाषाएं',
        'Langues',
        'Idiomas',
        'Idiomas',
        'Sprachen',
        'Diller',
        'Bahasa',
        'ভাষা'
      );
  String p11LangsSupported(int n) =>
      _get('$n languages supported', '$n زبانیں معاون ہیں', '$n لغة مدعومة',
        '$n भाषाएं समर्थित',
        '$n langues prises en charge',
        '$n idiomas admitidos',
        '$n idiomas suportados',
        '$n Sprachen unterstützt',
        '$n dil destekleniyor',
        '$n bahasa didukung',
        '$nটি ভাষা সমর্থিত'
      );
  String get p11CoverageNote => _get(
        'App UI translation coverage across the real supported languages — never usage estimates.',
        'حقیقی معاون زبانوں میں ایپ UI ترجمہ کوریج — کبھی استعمال کے اندازے نہیں۔',
        'تغطية ترجمة واجهة التطبيق عبر اللغات المدعومة فعليًا — وليست تقديرات استخدام.',
      
        'असली समर्थित भाषाओं में ऐप UI अनुवाद कवरेज — कभी उपयोग के अनुमान नहीं।',
        'Couverture de traduction de l\'interface dans les vraies langues prises en charge — jamais d\'estimations d\'utilisation.',
        'Cobertura de traducción de la interfaz en los idiomas reales admitidos — nunca estimaciones de uso.',
        'Cobertura de tradução da interface nos idiomas reais suportados — nunca estimativas de uso.',
        'UI-Übersetzungsabdeckung über die echten unterstützten Sprachen — niemals Nutzungs-Schätzungen.',
        'Gerçek desteklenen dillerde uygulama arayüzü çeviri kapsamı — asla kullanım tahmini değil.',
        'Cakupan terjemahan UI aplikasi di seluruh bahasa yang benar-benar didukung — bukan perkiraan penggunaan.',
        'আসল সমর্থিত ভাষাগুলোতে অ্যাপ UI অনুবাদ কভারেজ — ব্যবহারের অনুমান কখনই নয়।'
      );
  String get p11FullUi => _get('Full app UI', 'مکمل ایپ UI', 'واجهة كاملة',
        'पूरा ऐप UI',
        'Interface complète',
        'Interfaz completa',
        'Interface completa',
        'Vollständige App-Oberfläche',
        'Tam uygulama arayüzü',
        'UI aplikasi penuh',
        'সম্পূর্ণ অ্যাপ UI'
      );
  String get p11ContentOnly => _get('Content', 'مواد', 'المحتوى',
        'कंटेंट',
        'Contenu',
        'Contenido',
        'Conteúdo',
        'Inhalte',
        'İçerik',
        'Konten',
        'কন্টেন্ট'
      );
  String get p11ContentOnlyNote => _get(
        'Content language: AI detection and audience matching supported; app UI stays in your chosen language.',
        'مواد کی زبان: AI شناخت اور سامعین کی مطابقت معاون؛ ایپ UI آپ کی منتخب زبان میں رہتا ہے۔',
        'لغة المحتوى: الكشف والمطابقة بالذكاء الاصطناعي مدعومان؛ تبقى واجهة التطبيق بلغتك المختارة.',
      
        'कंटेंट भाषा: AI पहचान और ऑडियंस मैचिंग समर्थित; ऐप UI आपकी चुनी भाषा में रहता है।',
        'Langue du contenu : détection IA et correspondance d\'audience prises en charge ; l\'interface reste dans la langue choisie.',
        'Idioma del contenido: detección IA y coincidencia de audiencia admitidas; la interfaz permanece en tu idioma elegido.',
        'Idioma do conteúdo: detecção por IA e correspondência de público suportadas; a interface permanece no seu idioma escolhido.',
        'Inhaltssprache: KI-Erkennung und Zielgruppen-Matching unterstützt; die App-Oberfläche bleibt in deiner gewählten Sprache.',
        'İçerik dili: yapay zeka algılama ve kitle eşleştirme desteklenir; uygulama arayüzü seçtiğiniz dilde kalır.',
        'Bahasa konten: deteksi AI dan pencocokan audiens didukung; UI aplikasi tetap dalam bahasa pilihan Anda.',
        'কন্টেন্টের ভাষা: AI শনাক্তকরণ ও অডিয়েন্স ম্যাচিং সমর্থিত; অ্যাপ UI আপনার বেছে নেওয়া ভাষায় থাকে।'
      );
  String get p11Company => _get('Company', 'کمپنی', 'الشركة',
        'कंपनी',
        'Entreprise',
        'Empresa',
        'Empresa',
        'Unternehmen',
        'Şirket',
        'Perusahaan',
        'কোম্পানি'
      );
  String get p11AboutVirello =>
      _get('About Virello', 'Virello کے بارے میں', 'عن Virello',
        'Virello के बारे में',
        'À propos de Virello',
        'Acerca de Virello',
        'Sobre o Virello',
        'Über Virello',
        'Virello Hakkında',
        'Tentang Virello',
        'Virello সম্পর্কে'
      );
  String get p11WhatVirelloDoes =>
      _get('What Virello does', 'Virello کیا کرتا ہے', 'ماذا يفعل Virello',
        'Virello क्या करता है',
        'Ce que fait Virello',
        'Qué hace Virello',
        'O que o Virello faz',
        'Was Virello macht',
        'Virello ne yapar',
        'Apa yang dilakukan Virello',
        'Virello কী করে'
      );
  String get p11CompanyDesc => _get(
        'Virello AI is your AI growth manager. It matches your content with genuinely interested audiences through legitimate discovery — AI content analysis, audience insights, and AI-managed growth across organic and paid channels.',
        'Virello AI آپ کا AI گروتھ مینیجر ہے۔ یہ آپ کے مواد کو حقیقی دلچسپی رکھنے والے سامعین سے جائز دریافت کے ذریعے ملاتا ہے — AI مواد کا تجزیہ، سامعین کی بصیرت، اور آرگینک و پیڈ چینلز میں AI کے زیر انتظام گروتھ۔',
        'Virello AI هو مدير النمو بالذكاء الاصطناعي. يطابق المحتوى مع جمهور مهتم فعلًا عبر الاكتشاف المشروع — تحليل المحتوى، ورؤى الجمهور، والنمو المُدار بالذكاء الاصطناعي عبر القنوات المجانية والمدفوعة.',
      
        'Virello AI आपका AI ग्रोथ मैनेजर है। यह आपके कंटेंट को वैध डिस्कवरी के ज़रिए सच में दिलचस्पी रखने वाले ऑडियंस से मिलाता है — AI कंटेंट विश्लेषण, ऑडियंस इनसाइट्स, और ऑर्गेनिक व पेड चैनलों में AI-प्रबंधित ग्रोथ।',
        'Virello AI est votre gestionnaire de croissance IA. Il associe votre contenu à des audiences réellement intéressées grâce à une découverte légitime — analyse de contenu par IA, insights d\'audience et croissance gérée par IA sur les canaux organiques et payants.',
        'Virello AI es tu gestor de crecimiento con IA. Conecta tu contenido con audiencias realmente interesadas mediante descubrimiento legítimo — análisis de contenido con IA, insights de audiencia y crecimiento gestionado por IA en canales orgánicos y pagos.',
        'O Virello AI é seu gerente de crescimento com IA. Ele combina seu conteúdo com públicos genuinamente interessados por meio de descoberta legítima — análise de conteúdo por IA, insights de público e crescimento gerenciado por IA em canais orgânicos e pagos.',
        'Virello AI ist dein KI-Wachstumsmanager. Er verbindet deine Inhalte mit wirklich interessierten Zielgruppen durch legitime Discovery — KI-Inhaltsanalyse, Zielgruppen-Einblicke und KI-gesteuertes Wachstum über organische und bezahlte Kanäle.',
        'Virello AI, yapay zeka büyüme yöneticinizdir. İçeriğinizi, meşru keşif yoluyla gerçekten ilgili kitlelerle eşleştirir — yapay zeka içerik analizi, kitle içgörüleri ve organik ile ücretli kanallarda yapay zeka yönetimli büyüme.',
        'Virello AI adalah manajer pertumbuhan AI Anda. Ia mencocokkan konten Anda dengan audiens yang benar-benar tertarik melalui discovery yang sah — analisis konten AI, wawasan audiens, dan pertumbuhan yang dikelola AI di kanal organik dan berbayar.',
        'Virello AI আপনার AI গ্রোথ ম্যানেজার। এটি বৈধ ডিসকভারির মাধ্যমে আপনার কন্টেন্টকে সত্যিকারের আগ্রহী অডিয়েন্সের সাথে মেলায় — AI কন্টেন্ট বিশ্লেষণ, অডিয়েন্স ইনসাইট, এবং অর্গানিক ও পেইড চ্যানেলে AI-পরিচালিত গ্রোথ।'
      );
  String get p11WhatWeNeverDo =>
      _get('What we never do', 'ہم کیا کبھی نہیں کرتے', 'ما لا نفعله أبدًا',
        'हम क्या कभी नहीं करते',
        'Ce que nous ne faisons jamais',
        'Lo que nunca hacemos',
        'O que nunca fazemos',
        'Was wir niemals tun',
        'Asla yapmadıklarımız',
        'Yang tidak pernah kami lakukan',
        'আমরা যা কখনও করি না'
      );
  String get p11ContactSupport =>
      _get('Contact support', 'سپورٹ سے رابطہ کریں', 'تواصل مع الدعم',
        'सपोर्ट से संपर्क करें',
        'Contacter l\'assistance',
        'Contactar soporte',
        'Falar com o suporte',
        'Support kontaktieren',
        'Destek ile İletişim',
        'Hubungi dukungan',
        'সাপোর্টে যোগাযোগ করুন'
      );
  String get p11MyStories => _get('My Stories', 'میری کہانیاں', 'قصصي',
        'मेरी स्टोरीज़',
        'Mes stories',
        'Mis historias',
        'Meus stories',
        'Meine Stories',
        'Hikâyelerim',
        'Story Saya',
        'আমার স্টোরিগুলো'
      );
  String get p11NoStoriesYet => _get(
      'No stories yet — generate your first story idea below.',
      'ابھی کوئی کہانی نہیں — نیچے اپنی پہلی کہانی کا آئیڈیا بنائیں۔',
      'لا قصص بعد — ولّد فكرة قصتك الأولى أدناه.',
        'अभी कोई स्टोरी नहीं — नीचे अपना पहला स्टोरी आइडिया बनाएं।',
        'Aucune story pour le moment — générez votre première idée de story ci-dessous.',
        'Sin historias aún — genera tu primera idea de historia abajo.',
        'Sem stories ainda — gere sua primeira ideia de story abaixo.',
        'Noch keine Stories — erstelle unten deine erste Story-Idee.',
        'Henüz hikâye yok — aşağıda ilk hikâye fikrinizi oluşturun.',
        'Belum ada story — buat ide story pertama Anda di bawah.',
        'এখনও কোনো স্টোরি নেই — নিচে আপনার প্রথম স্টোরি আইডিয়া তৈরি করুন।'
      );
  String get p11IdeasThisSession =>
      _get('ideas this session', 'اس سیشن کے آئیڈیاز', 'أفكار هذه الجلسة',
        'इस सेशन के आइडियाज़',
        'idées cette session',
        'ideas esta sesión',
        'ideias nesta sessão',
        'Ideen diese Sitzung',
        'bu oturumdaki fikirler',
        'ide sesi ini',
        'এই সেশনের আইডিয়া'
      );

  // ---------------- AI Growth Engine: Mission Control ----------------
  String get engineAgentNetwork => _get(
        'AI Agent Network',
        'AI ایجنٹ نیٹ ورک',
        'شبكة وكلاء الذكاء الاصطناعي',
        'AI एजेंट नेटवर्क',
        'Réseau d\u2019agents IA',
        'Red de agentes de IA',
        'Rede de agentes de IA',
        'KI-Agenten-Netzwerk',
        'YZ Ajan Ağı',
        'Jaringan Agen AI',
        'AI এজেন্ট নেটওয়ার্ক',
      );
  String get engineLiveActivity => _get(
        'Live Activity',
        'براہِ راست سرگرمی',
        'النشاط المباشر',
        'लाइव गतिविधि',
        'Activité en direct',
        'Actividad en vivo',
        'Atividade ao vivo',
        'Live-Aktivität',
        'Canlı Etkinlik',
        'Aktivitas Langsung',
        'লাইভ কার্যকলাপ',
      );
  String get engineProposalTitle => _get(
        'AI Proposal Ready',
        'AI تجویز تیار ہے',
        'مقترح الذكاء الاصطناعي جاهز',
        'AI प्रस्ताव तैयार है',
        'Proposition IA prête',
        'Propuesta de IA lista',
        'Proposta de IA pronta',
        'KI-Vorschlag bereit',
        'YZ Önerisi Hazır',
        'Proposal AI Siap',
        'AI প্রস্তাব প্রস্তুত',
      );
  String get engineProposalBody => _get(
        'The AI analyzed your content and prepared a growth plan. Approve to launch the engine.',
        'AI نے آپ کے مواد کا تجزیہ کیا اور گروتھ پلان تیار کیا ہے۔ انجن لانچ کرنے کے لیے منظور کریں۔',
        'حلّل الذكاء الاصطناعي محتواك وأعدّ خطة نمو. اعتمد لإطلاق المحرك.',
        'AI ने आपकी सामग्री का विश्लेषण किया और ग्रोथ प्लान तैयार किया है। इंजन लॉन्च करने के लिए स्वीकृति दें।',
        'L\u2019IA a analysé votre contenu et préparé un plan de croissance. Approuvez pour lancer le moteur.',
        'La IA analizó tu contenido y preparó un plan de crecimiento. Aprueba para lanzar el motor.',
        'A IA analisou seu conteúdo e preparou um plano de crescimento. Aprove para lançar o motor.',
        'Die KI hat deine Inhalte analysiert und einen Wachstumsplan erstellt. Genehmige, um die Engine zu starten.',
        'YZ içeriğinizi analiz etti ve bir büyüme planı hazırladı. Motoru başlatmak için onaylayın.',
        'AI telah menganalisis konten Anda dan menyiapkan rencana pertumbuhan. Setujui untuk meluncurkan mesin.',
        'AI আপনার কন্টেন্ট বিশ্লেষণ করেছে এবং একটি গ্রোথ প্ল্যান তৈরি করেছে। ইঞ্জিন চালু করতে অনুমোদন দিন।',
      );
  String get engineApproveLaunch => _get(
        'Approve & Launch',
        'منظور کریں اور لانچ کریں',
        'اعتماد وإطلاق',
        'स्वीकार करें और लॉन्च करें',
        'Approuver et lancer',
        'Aprobar y lanzar',
        'Aprovar e lançar',
        'Genehmigen & starten',
        'Onayla ve Başlat',
        'Setujui & Luncurkan',
        'অনুমোদন ও চালু করুন',
      );
  String get engineApproved => _get(
        'Proposal approved — engine is running',
        'تجویز منظور — انجن چل رہا ہے',
        'تم اعتماد المقترح — المحرك يعمل الآن',
        'प्रस्ताव स्वीकृत — इंजन चल रहा है',
        'Proposition approuvée — le moteur tourne',
        'Propuesta aprobada — el motor está en marcha',
        'Proposta aprovada — o motor está funcionando',
        'Vorschlag genehmigt — Engine läuft',
        'Öneri onaylandı — motor çalışıyor',
        'Proposal disetujui — mesin berjalan',
        'প্রস্তাব অনুমোদিত — ইঞ্জিন চলছে',
      );
  String get engineWaitingApproval => _get(
        'Waiting for your approval',
        'آپ کی منظوری کا انتظار ہے',
        'بانتظار موافقتك',
        'आपकी स्वीकृति की प्रतीक्षा है',
        'En attente de votre approbation',
        'Esperando tu aprobación',
        'Aguardando sua aprovação',
        'Wartet auf deine Genehmigung',
        'Onayınızı bekliyor',
        'Menunggu persetujuan Anda',
        'আপনার অনুমোদনের অপেক্ষায়',
      );
  String get engineNoActivity => _get(
        'No agent activity yet',
        'ابھی کوئی ایجنٹ سرگرمی نہیں',
        'لا نشاط للوكلاء بعد',
        'अभी कोई एजेंट गतिविधि नहीं',
        'Aucune activité d\u2019agent pour le moment',
        'Aún no hay actividad de agentes',
        'Nenhuma atividade de agente ainda',
        'Noch keine Agenten-Aktivität',
        'Henüz ajan etkinliği yok',
        'Belum ada aktivitas agen',
        'এখনও কোনো এজেন্ট কার্যকলাপ নেই',
      );
  String get engineStandby => _get(
        'Standby',
        'اسٹینڈ بائی',
        'استعداد',
        'स्टैंडबाय',
        'En attente',
        'En espera',
        'Em espera',
        'Bereit',
        'Hazır',
        'Siaga',
        'স্ট্যান্ডবাই',
      );
  String get engineWorking => _get(
        'Working',
        'کام جاری ہے',
        'يعمل',
        'कार्यरत',
        'En cours',
        'Trabajando',
        'Trabalhando',
        'Aktiv',
        'Çalışıyor',
        'Bekerja',
        'কাজ চলছে',
      );
  String get engineDone => _get(
        'Done',
        'مکمل',
        'تم',
        'पूर्ण',
        'Terminé',
        'Listo',
        'Concluído',
        'Fertig',
        'Tamam',
        'Selesai',
        'সম্পন্ন',
      );
  String get agentContent => _get(
        'Content Analysis',
        'مواد کا تجزیہ',
        'تحليل المحتوى',
        'सामग्री विश्लेषण',
        'Analyse de contenu',
        'Análisis de contenido',
        'Análise de conteúdo',
        'Inhaltsanalyse',
        'İçerik Analizi',
        'Analisis Konten',
        'কন্টেন্ট বিশ্লেষণ',
      );
  String get agentAudience => _get(
        'Audience',
        'سامعین',
        'الجمهور',
        'दर्शक',
        'Audience',
        'Audiencia',
        'Público',
        'Zielgruppe',
        'Hedef Kitle',
        'Audiens',
        'দর্শক',
      );
  String get agentMarket => _get(
        'Market Research',
        'مارکیٹ ریسرچ',
        'أبحاث السوق',
        'बाज़ार अनुसंधान',
        'Étude de marché',
        'Investigación de mercado',
        'Pesquisa de mercado',
        'Marktforschung',
        'Pazar Araştırması',
        'Riset Pasar',
        'বাজার গবেষণা',
      );
  String get agentCreative => _get(
        'Creative',
        'تخلیقی',
        'الإبداع',
        'रचनात्मक',
        'Créatif',
        'Creativo',
        'Criativo',
        'Kreativ',
        'Yaratıcı',
        'Kreatif',
        'সৃজনশীল',
      );
  String get agentCampaign => _get(
        'Campaign',
        'مہم',
        'الحملة',
        'अभियान',
        'Campagne',
        'Campaña',
        'Campanha',
        'Kampagne',
        'Kampanya',
        'Kampanye',
        'ক্যাম্পেইন',
      );
  String get agentAnalytics => _get(
        'Analytics',
        'تجزیات',
        'التحليلات',
        'एनालिटिक्स',
        'Analytique',
        'Analítica',
        'Análise',
        'Analyse',
        'Analitik',
        'Analitik',
        'অ্যানালিটিক্স',
      );
  String get agentOptimization => _get(
        'Optimization',
        'بہتری',
        'التحسين',
        'अनुकूलन',
        'Optimisation',
        'Optimización',
        'Otimização',
        'Optimierung',
        'Optimizasyon',
        'Optimasi',
        'অপ্টিমাইজেশন',
      );
  String get agentBudget => _get(
        'Budget',
        'بجٹ',
        'الميزانية',
        'बजट',
        'Budget',
        'Presupuesto',
        'Orçamento',
        'Budget',
        'Bütçe',
        'Anggaran',
        'বাজেট',
      );
  String get agentFraud => _get(
        'Fraud & Safety',
        'فراڈ اور حفاظت',
        'الاحتيال والسلامة',
        'धोखाधड़ी और सुरक्षा',
        'Fraude et sécurité',
        'Fraude y seguridad',
        'Fraude e segurança',
        'Betrug & Sicherheit',
        'Dolandırıcılık ve Güvenlik',
        'Penipuan & Keamanan',
        'প্রতারণা ও নিরাপত্তা',
      );
  String get agentSupport => _get(
        'AI Support',
        'AI سپورٹ',
        'دعم الذكاء الاصطناعي',
        'AI सहायता',
        'Assistance IA',
        'Soporte IA',
        'Suporte de IA',
        'KI-Support',
        'YZ Desteği',
        'Dukungan AI',
        'AI সহায়তা',
      );
  String get engineSafetyArmed => _get(
        'Safety rails armed',
        'حفاظتی انتظامات فعال ہیں',
        'تدابير السلامة مفعّلة',
        'सुरक्षा उपाय सक्रिय हैं',
        'Garde-fous activés',
        'Protecciones activadas',
        'Proteções ativadas',
        'Sicherungen aktiv',
        'Güvenlik önlemleri aktif',
        'Pengaman aktif',
        'নিরাপত্তা ব্যবস্থা সক্রিয়',
      );
  String get engineSupportStandby => _get(
        'Here when you need help',
        'مدد چاہیے ہو تو حاضر ہے',
        'موجود عندما تحتاج المساعدة',
        'मदद चाहिए तो हाज़िर है',
        'Là quand vous avez besoin d\u2019aide',
        'Aquí cuando necesites ayuda',
        'Aqui quando precisar de ajuda',
        'Da, wenn du Hilfe brauchst',
        'Yardıma ihtiyacınız olduğunda burada',
        'Siap saat Anda butuh bantuan',
        'সাহায্য লাগলে হাজির',
      );

  // ---- Create Phase A: local tools (on-device, no account needed) ----
  String get imageTools => _get(
        'Image Tools',
        'امیج ٹولز',
        'أدوات الصور',
      );
  String get imageToolsDesc => _get(
        'Crop, filters, text & more — on your phone',
        'کراپ، فلٹرز، ٹیکسٹ اور مزید — آپ کے فون پر',
        'قصّ وفلترة ونصوص والمزيد — على هاتفك',
      );
  String get teleprompter => _get(
        'Teleprompter',
        'ٹیلی پرامپٹر',
        'المُلقِّن',
      );
  String get teleprompterDesc => _get(
        'Read your script hands-free while recording',
        'ریکارڈنگ کے دوران اسکرپٹ ہاتھ آزاد پڑھیں',
        'اقرأ النص أثناء التسجيل دون استخدام يديك',
      );
  String get voiceover => _get(
        'Voiceover',
        'وائس اوور',
        'التعليق الصوتي',
      );
  String get voiceoverDesc => _get(
        'Turn text into speech with your phone\u2019s voice',
        'متن کو اپنے فون کی آواز میں بدلیں',
        'حوّل النص إلى كلام بصوت هاتفك',
      );
  String get pickImage => _get('Pick an image', 'تصویر منتخب کریں');
  String get filters => _get('Filters', 'فلٹرز');
  String get cropSquare => _get('Square crop', 'مربع کراپ');
  String get rotate => _get('Rotate', 'گھمائیں');
  String get flipH => _get('Flip', 'پلٹائیں');
  String get brightness => _get('Brightness', 'چمک');
  String get contrast => _get('Contrast', 'کنٹراسٹ');
  String get saturation => _get('Saturation', 'سیچوریشن');
  String get addText => _get('Add text', 'متن شامل کریں');
  String get watermark => _get('Watermark', 'واٹر مارک');
  String get reelsFrame => _get('9:16 Reels frame', '9:16 ریلز فریم');
  String get saveImage => _get('Save image', 'تصویر محفوظ کریں');
  String get imageSaved => _get('Image saved', 'تصویر محفوظ ہو گئی');
  String get noImagePicked =>
      _get('Pick an image first', 'پہلے تصویر منتخب کریں');
  String get enterText => _get('Enter text', 'متن لکھیں');
  String get teleprompterSpeed => _get('Speed', 'رفتار');
  String get scriptHint => _get(
        'Paste or write your script here…',
        'اپنا اسکرپٹ یہاں لکھیں یا پیسٹ کریں…',
      );
  String get voiceoverTextHint => _get(
        'Type what the voice should say…',
        'وہ متن لکھیں جو آواز بولے…',
      );
  String get voice => _get('Voice', 'آواز');
  String get pitch => _get('Pitch', 'سُر');
  String get speak => _get('Speak', 'بولیں');
  String get stop => _get('Stop', 'روکیں');
  String get exportAudio => _get('Export audio', 'آڈیو ایکسپورٹ کریں');
  String get audioExported => _get('Audio exported', 'آڈیو ایکسپورٹ ہو گیا');
  String get ttsUnavailable => _get(
        'Voice not available on this device',
        'اس ڈیوائس پر آواز دستیاب نہیں',
      );
  String get projectPlan => _get('Project plan', 'پروجیکٹ پلان');
  String get shotList => _get('Shot list', 'شاٹ لسٹ');
  String get buildPlan => _get('Build plan', 'پلان بنائیں');
  String get captionTiming => _get('Timing & SRT', 'ٹائمنگ اور SRT');
  String get wordsPerSecond => _get('Words per second', 'الفاظ فی سیکنڈ');
  String get exportSrt => _get('Export SRT', 'SRT ایکسپورٹ کریں');
  String get srtCopied => _get('SRT copied', 'SRT کاپی ہو گیا');
  String get selectCaptionFirst =>
      _get('Select a caption first', 'پہلے کوئی کیپشن منتخب کریں');
  // --- Phase B: on-device video engine (ffmpeg) ---
  String get videoTools => _get(
        'Video tools',
        'ویڈیو ٹولز',
        'أدوات الفيديو',
        'वीडियो टूल्स',
        'Outils vidéo',
        'Herramientas de video',
        'Ferramentas de vídeo',
        'Videotools',
        'Video araçları',
        'Alat video',
        'ভিডিও টুলস',
      );
  String get storyVideo => _get(
        'Story Video',
        'اسٹوری ویڈیو',
        'فيديو القصة',
        'स्टोरी वीडियो',
        'Vidéo story',
        'Video de historia',
        'Vídeo de story',
        'Story-Video',
        'Hikaye videosu',
        'Video cerita',
        'স্টোরি ভিডিও',
      );
  String get storyVideoDesc => _get(
        'Turn photos into a 9:16 story video with music',
        'تصویروں سے میوزک والی 9:16 اسٹوری ویڈیو بنائیں',
        'حوّل الصور إلى فيديو قصة 9:16 مع موسيقى',
        'तस्वीरों से म्यूज़िक वाली 9:16 स्टोरी वीडियो बनाएं',
        'Transformez des photos en story vidéo 9:16 avec musique',
        'Convierte fotos en un video de historia 9:16 con música',
        'Transforme fotos em um vídeo de story 9:16 com música',
        'Mache aus Fotos ein 9:16-Story-Video mit Musik',
        'Fotoğraflardan müzikli 9:16 hikaye videosu oluşturun',
        'Ubah foto menjadi video cerita 9:16 dengan musik',
        'ছবি থেকে মিউজিকসহ 9:16 স্টোরি ভিডিও বানান',
      );
  String get renderVideo => _get(
        'Render video',
        'ویڈیو رینڈر کریں',
        'إنشاء الفيديو',
        'वीडियो रेंडर करें',
        'Générer la vidéo',
        'Generar video',
        'Gerar vídeo',
        'Video rendern',
        'Videoyu oluştur',
        'Render video',
        'ভিডিও রেন্ডার করুন',
      );
  String get pickVideo => _get(
        'Pick a video',
        'ویڈیو چنیں',
        'اختر فيديو',
        'वीडियो चुनें',
        'Choisir une vidéo',
        'Elige un video',
        'Escolha um vídeo',
        'Video wählen',
        'Video seçin',
        'Pilih video',
        'ভিডিও বেছে নিন',
      );
  String get pickImages => _get(
        'Pick photos',
        'تصویریں چنیں',
        'اختر الصور',
        'तस्वीरें चुनें',
        'Choisir des photos',
        'Elige fotos',
        'Escolha fotos',
        'Fotos wählen',
        'Fotoğraf seçin',
        'Pilih foto',
        'ছবি বেছে নিন',
      );
  String get pickAudio => _get(
        'Pick audio',
        'آڈیو چنیں',
        'اختر الصوت',
        'ऑडियो चुनें',
        'Choisir un audio',
        'Elige audio',
        'Escolha áudio',
        'Audio wählen',
        'Ses seçin',
        'Pilih audio',
        'অডিও বেছে নিন',
      );
  String get photosPicked => _get(
        'photos selected',
        'تصویریں منتخب',
        'صور محددة',
        'तस्वीरें चुनी गईं',
        'photos sélectionnées',
        'fotos seleccionadas',
        'fotos selecionadas',
        'Fotos ausgewählt',
        'fotoğraf seçildi',
        'foto dipilih',
        'ছবি নির্বাচিত',
      );
  String get toolTrim => _get(
        'Trim',
        'تراشیں',
        'قص',
        'ट्रिम करें',
        'Rogner',
        'Recortar',
        'Cortar',
        'Zuschneiden',
        'Kırp',
        'Pangkas',
        'ছাঁটুন',
      );
  String get toolCompress => _get(
        'Compress',
        'کمپریس کریں',
        'ضغط',
        'कंप्रेस करें',
        'Compresser',
        'Comprimir',
        'Comprimir',
        'Komprimieren',
        'Sıkıştır',
        'Kompres',
        'কম্প্রেস করুন',
      );
  String get toolAddMusic => _get(
        'Add music',
        'میوزک ڈالیں',
        'أضف موسيقى',
        'म्यूज़िक जोड़ें',
        'Ajouter de la musique',
        'Añadir música',
        'Adicionar música',
        'Musik hinzufügen',
        'Müzik ekle',
        'Tambah musik',
        'মিউজিক যোগ করুন',
      );
  String get toolVoiceover => _get(
        'Voiceover mix',
        'وائس اوور مکس',
        'مزيج التعليق الصوتي',
        'वॉयसओवर मिक्स',
        'Mix voix off',
        'Mezcla de voz en off',
        'Mix de narração',
        'Voiceover-Mix',
        'Seslendirme miksi',
        'Campuran sulih suara',
        'ভয়েসওভার মিক্স',
      );
  String get toolBurnCaptions => _get(
        'Burn captions',
        'کیپشنز جلائیں',
        'دمج الترجمة',
        'कैप्शन जलाएं',
        'Incruster les sous-titres',
        'Incrustar subtítulos',
        'Incrustar legendas',
        'Untertitel einbrennen',
        'Altyazıları göm',
        'Bakar teks',
        'ক্যাপশন বসান',
      );
  String get toolSpeed => _get(
        'Speed',
        'رفتار',
        'السرعة',
        'गति',
        'Vitesse',
        'Velocidad',
        'Velocidade',
        'Tempo',
        'Hız',
        'Kecepatan',
        'গতি',
      );
  String get toolAspect => _get(
        'Aspect ratio',
        'پہلو کا تناسب',
        'نسبة العرض',
        'आस्पेक्ट रेशियो',
        'Format d\u2019image',
        'Relación de aspecto',
        'Proporção',
        'Seitenverhältnis',
        'En-boy oranı',
        'Rasio aspek',
        'আসপেক্ট রেশিও',
      );
  String get toolThumbnail => _get(
        'Thumbnail',
        'تھمب نیل',
        'صورة مصغرة',
        'थंबनेल',
        'Vignette',
        'Miniatura',
        'Miniatura',
        'Vorschaubild',
        'Küçük resim',
        'Gambar mini',
        'থাম্বনেইল',
      );
  String get toolGif => _get(
        'GIF preview',
        'GIF پیش منظر',
        'معاينة GIF',
        'GIF प्रीव्यू',
        'Aperçu GIF',
        'Vista previa GIF',
        'Prévia GIF',
        'GIF-Vorschau',
        'GIF önizleme',
        'Pratinjau GIF',
        'GIF প্রিভিউ',
      );
  String get processingVideo => _get(
        'Processing video…',
        'ویڈیو پروسیس ہو رہی ہے…',
        'جارٍ معالجة الفيديو…',
        'वीडियो प्रोसेस हो रहा है…',
        'Traitement de la vidéo…',
        'Procesando video…',
        'Processando vídeo…',
        'Video wird verarbeitet…',
        'Video işleniyor…',
        'Memproses video…',
        'ভিডিও প্রসেস হচ্ছে…',
      );
  String get videoReady => _get(
        'Video ready',
        'ویڈیو تیار ہے',
        'الفيديو جاهز',
        'वीडियो तैयार है',
        'Vidéo prête',
        'Video listo',
        'Vídeo pronto',
        'Video fertig',
        'Video hazır',
        'Video siap',
        'ভিডিও তৈরি',
      );
  String get processingFailed => _get(
        'Processing failed — please try again.',
        'پروسیسنگ ناکام — دوبارہ کوشش کریں۔',
        'فشلت المعالجة — حاول مرة أخرى.',
        'प्रोसेसिंग विफल — कृपया पुनः प्रयास करें।',
        'Échec du traitement — réessayez.',
        'Falló el procesamiento — inténtalo de nuevo.',
        'Falha no processamento — tente novamente.',
        'Verarbeitung fehlgeschlagen — bitte erneut versuchen.',
        'İşleme başarısız — lütfen tekrar deneyin.',
        'Pemrosesan gagal — silakan coba lagi.',
        'প্রসেসিং ব্যর্থ — আবার চেষ্টা করুন।',
      );
  String get useVideo => _get(
        'Use this video',
        'یہ ویڈیو استعمال کریں',
        'استخدم هذا الفيديو',
        'यह वीडियो इस्तेमाल करें',
        'Utiliser cette vidéo',
        'Usar este video',
        'Usar este vídeo',
        'Dieses Video verwenden',
        'Bu videoyu kullan',
        'Gunakan video ini',
        'এই ভিডিও ব্যবহার করুন',
      );
  String get startTimeSec => _get(
        'Start (seconds)',
        'آغاز (سیکنڈ)',
        'البداية (ثوانٍ)',
        'शुरुआत (सेकंड)',
        'Début (secondes)',
        'Inicio (segundos)',
        'Início (segundos)',
        'Start (Sekunden)',
        'Başlangıç (saniye)',
        'Mulai (detik)',
        'শুরু (সেকেন্ড)',
      );
  String get endTimeSec => _get(
        'End (seconds)',
        'اختتام (سیکنڈ)',
        'النهاية (ثوانٍ)',
        'अंत (सेकंड)',
        'Fin (secondes)',
        'Fin (segundos)',
        'Fim (segundos)',
        'Ende (Sekunden)',
        'Bitiş (saniye)',
        'Selesai (detik)',
        'শেষ (সেকেন্ড)',
      );
  String get qualityLabel => _get(
        'Quality',
        'کوالٹی',
        'الجودة',
        'क्वालिटी',
        'Qualité',
        'Calidad',
        'Qualidade',
        'Qualität',
        'Kalite',
        'Kualitas',
        'কোয়ালিটি',
      );
  String get assembleStory => _get(
        'Assemble story video',
        'اسٹوری ویڈیو بنائیں',
        'إنشاء فيديو القصة',
        'स्टोरी वीडियो बनाएं',
        'Assembler la story vidéo',
        'Crear video de historia',
        'Montar vídeo de story',
        'Story-Video erstellen',
        'Hikaye videosu oluştur',
        'Rakit video cerita',
        'স্টোরি ভিডিও বানান',
      );
  String get secondsPerPhoto => _get(
        'Seconds per photo',
        'فی تصویر سیکنڈ',
        'ثوانٍ لكل صورة',
        'प्रति तस्वीर सेकंड',
        'Secondes par photo',
        'Segundos por foto',
        'Segundos por foto',
        'Sekunden pro Foto',
        'Fotoğraf başına saniye',
        'Detik per foto',
        'প্রতি ছবিতে সেকেন্ড',
      );
  String get openingTitle => _get(
        'Opening title (optional)',
        'ابتدائی عنوان (اختیاری)',
        'العنوان الافتتاحي (اختياري)',
        'शुरुआती शीर्षक (वैकल्पिक)',
        'Titre d\u2019ouverture (facultatif)',
        'Título inicial (opcional)',
        'Título inicial (opcional)',
        'Anfangstitel (optional)',
        'Açılış başlığı (isteğe bağlı)',
        'Judul pembuka (opsional)',
        'শুরুর শিরোনাম (ঐচ্ছিক)',
      );
  String get burnIntoVideo => _get(
        'Burn into video',
        'ویڈیو میں جلائیں',
        'دمج في الفيديو',
        'वीडियो में जलाएं',
        'Incruster dans la vidéo',
        'Incrustar en el video',
        'Incrustar no vídeo',
        'Ins Video einbrennen',
        'Videoya göm',
        'Bakar ke video',
        'ভিডিওতে বসান',
      );
  String get rewards => _get('Wallet', 'والیٹ', 'المحفظة');
  String get virelloPoints =>
      _get('Virello Points', 'ویریلو پوائنٹس', 'نقاط Virello');
  String get pointsBalance =>
      _get('Points balance', 'پوائنٹس بیلنس', 'رصيد النقاط');
  String get howToEarn => _get('How to earn', 'کمائیں کیسے', 'كيفية الكسب');
  String get redeemPoints =>
      _get('Redeem points', 'پوائنٹس ریڈیم کریں', 'استبدال النقاط');
  String get enterPoints =>
      _get('Enter points', 'پوائنٹس درج کریں', 'أدخل النقاط');
  String get redeem => _get('Redeem', 'ریڈیم کریں', 'استبدال');
  String get history => _get('History', 'ہسٹری', 'السجل');
  String get leaderboard =>
      _get('Leaderboard', 'لیڈر بورڈ', 'لوحة الصدارة');
  String get weeklyRace =>
      _get("This week's race", 'اس ہفتے کی دوڑ', 'سباق هذا الأسبوع');
  String get monthlyRace =>
      _get("This month's race", 'اس ماہ کی دوڑ', 'سباق هذا الشهر');
  String get endsIn => _get('Ends in', 'اختتام میں باقی', 'ينتهي بعد');
  String get pastWinners =>
      _get('Past winners', 'پچھلے فاتحین', 'الفائزون السابقون');
  String get noWinnersYet => _get(
        'No winners yet — announced after each race ends.',
        'ابھی کوئی فاتح نہیں — ہر ریس ختم ہونے کے بعد اعلان کیا جائے گا۔',
        'لا يوجد فائزون بعد — يُعلن عنهم بعد انتهاء كل سباق.',
      );
  String get noRacersYet => _get(
        'No racers yet — be the first to post!',
        'ابھی کوئی ریسلر نہیں — سب سے پہلے پوسٹ کریں!',
        'لا يوجد متسابقون بعد — كن أول من ينشر!',
      );
  String get tagProducts =>
      _get('Tag products', 'مصنوعات ٹیگ کریں', 'وسم المنتجات');
  String get searchProducts =>
      _get('Search products', 'مصنوعات تلاش کریں', 'ابحث عن المنتجات');
  String get addProducts =>
      _get('Add products', 'مصنوعات شامل کریں', 'أضف منتجات');
  String get shareToFeed =>
      _get('Share to Feed', 'فیڈ پر شیئر کریں', 'شارك في الخلاصة');
  String get shareToFeedTitle => _get(
        'Share to the discovery feed',
        'ڈسکوری فیڈ پر شیئر کریں',
        'شارك في خلاصة الاكتشاف',
      );
  String get selectTopics =>
      _get('Select topics', 'موضوعات چنیں', 'اختر المواضيع');
  String pointsEarnedSnackbar(int points) => _get(
        '$points points earned!',
        '$points پوائنٹس حاصل ہوئے!',
        'حصلت على $points نقطة!',
      );
  String get checkPriceOnAmazon => _get(
        'Check price on Amazon',
        'ایمیزون پر قیمت دیکھیں',
        'تحقق من السعر على أمازون',
      );
  String get level => _get('Level', 'لیول', 'المستوى');
  String get toNextLevel =>
      _get('to next level', 'اگلے لیول تک', 'إلى المستوى التالي');

  // ----------------------------- Wallet (HYBRID) -----------------------------
  String get wallet => _get('Wallet', 'والیٹ', 'المحفظة');
  String get walletTagline => _get(
        'Post to earn points. Share & sell to earn cash.',
        'پوسٹ کرو ← پوائنٹس۔ شیئر کرو، بکواؤ ← کیش۔',
        'انشر لتربح نقاطًا. شارك وبِع لتربح نقدًا.',
      );
  String get cashWallet => _get('Cash Wallet', 'کیش والیٹ', 'محفظة النقد');
  String get cashBalance => _get('Cash balance', 'کیش بیلنس', 'الرصيد النقدي');
  String get convertToCash =>
      _get('Convert to Cash', 'کیش میں بدلیں', 'تحويل إلى نقد');
  String get getCredits => _get('Get Credits', 'کریڈٹس لیں', 'الحصول على أرصدة');
  String convertRate(String rate) =>
      _get('Rate: $rate', 'ریٹ: $rate', 'السعر: $rate');
  String convertHint(int minPts) => _get(
        'Minimum $minPts points per conversion',
        'تبدیلی کے لیے کم از کم $minPts پوائنٹس',
        'الحد الأدنى $minPts نقطة لكل تحويل',
      );
  String get convertConfirm =>
      _get('How many points to convert?', 'کتنے پوائنٹس تبدیل کریں؟',
          'كم عدد النقاط التي تريد تحويلها؟');
  String convertSuccess(String cash) => _get(
        'Converted — +$cash cash',
        'تبدیل ہو گئے — +$cash کیش',
        'تم التحويل — +$cash نقدًا',
      );
  String get withdraw => _get('Withdraw', 'نکالیں', 'سحب');
  String get withdrawCash =>
      _get('Withdraw cash', 'کیش نکالیں', 'سحب النقد');
  String get withdrawAmount => _get(
        'Amount (USD)',
        'رقم (ڈالر)',
        'المبلغ (دولار)',
      );
  String get bankName => _get('Bank name', 'بینک کا نام', 'اسم البنك');
  String get accountTitle =>
      _get('Account title', 'اکاؤنٹ کا نام', 'اسم صاحب الحساب');
  String get iban => _get('IBAN', 'آئی بین', 'الآيبان');
  String get ageConfirmLabel => _get(
        'I confirm I am 18 years or older',
        'میں تصدیق کرتا/کرتی ہوں کہ میری عمر 18 سال یا اس سے زیادہ ہے',
        'أؤكد أن عمري 18 عامًا أو أكثر',
      );
  String get submitWithdrawal =>
      _get('Submit withdrawal', 'نکاسی کی درخواست دیں', 'تقديم طلب السحب');
  String get withdrawalSubmitted => _get(
        'Withdrawal submitted — it will be reviewed, usually within 7 days.',
        'نکاسی کی درخواست موصول ہو گئی — عام طور پر 7 دن کے اندر جائزہ لیا جائے گا۔',
        'تم تقديم طلب السحب — ستتم مراجعته عادةً خلال 7 أيام.',
      );
  String get pendingWithdrawal => _get(
        'Withdrawal pending review',
        'نکاسی جائزے کے لیے زیرِ التوا ہے',
        'طلب السحب قيد المراجعة',
      );
  String get minWithdrawalNote =>
      _get('Minimum withdrawal: \$10.00', 'کم از کم نکاسی: \$10.00',
          'الحد الأدنى للسحب: \$10.00');
  String get withdrawalReviewNote => _get(
        'Reviewed & paid manually, usually within 7 days',
        'دستی جائزہ اور ادائیگی، عام طور پر 7 دن کے اندر',
        'تتم المراجعة والدفع يدويًا، عادةً خلال 7 أيام',
      );
  String errWithdraw(String reason) =>
      _get('Withdrawal failed: $reason', 'نکاسی ناکام: $reason',
          'فشل السحب: $reason');
  String get errBelowMinimum =>
      _get('Amount is below the \$10.00 minimum', 'رقم \$10.00 کم از کم سے کم ہے',
          'المبلغ أقل من الحد الأدنى \$10.00');
  String get errAgeNotConfirmed =>
      _get('Please confirm you are 18 or older', 'براہ کرم 18+ کی تصدیق کریں',
          'يرجى تأكيد أن عمرك 18 عامًا أو أكثر');
  String get errEmailNotVerified =>
      _get('Verify your email first', 'پہلے اپنا ای میل تصدیق کریں',
          'تحقق من بريدك الإلكتروني أولًا');
  String get errAccountTooNew => _get(
        'Your account must be at least 7 days old',
        'آپ کا اکاؤنٹ کم از کم 7 دن پرانا ہونا چاہیے',
        'يجب أن يكون حسابك أقدم من 7 أيام على الأقل',
      );
  String get errProfileIncomplete =>
      _get('Complete your profile first', 'پہلے اپنا پروفائل مکمل کریں',
          'أكمل ملفك الشخصي أولًا');
  String get errPendingExists => _get(
        'You already have a pending withdrawal',
        'آپ کی ایک درخواست پہلے سے زیرِ التوا ہے',
        'لديك بالفعل طلب سحب قيد الانتظار',
      );
  String get errInsufficientCash =>
      _get('Not enough cash balance', 'کیش بیلنس ناکافی ہے',
          'الرصيد النقدي غير كافٍ');
  String get errInvalidMethod =>
      _get('Check your bank details', 'اپنی بینک تفصیلات چیک کریں',
          'تحقق من تفاصيل حسابك البنكي');
  String get topSellers =>
      _get('Top Sellers', 'ٹاپ سیلرز', 'أفضل البائعين');
  String get verifiedClicks =>
      _get('verified clicks', 'تصدیق شدہ کلکس', 'نقرات موثقة');
  String clicksCount(int n) =>
      _get('$n clicks', '$n کلکس', '$n نقرة');
  String get weeklyPrize =>
      _get('Weekly prize', 'ہفتہ وار انعام', 'الجائزة الأسبوعية');
  String get monthlyPrize =>
      _get('Monthly prize', 'ماہانہ انعام', 'الجائزة الشهرية');
  String get volumeBonus =>
      _get('Volume bonus', 'والیوم بونس', 'مكافأة الحجم');
  String get sellerWinners =>
      _get('Seller winners', 'سیلر فاتحین', 'الفائزون من البائعين');
  String get shareEarnHint =>
      _get('Share & earn \$0.05', 'شیئر کریں اور \$0.05 کمائیں',
          'شارك واربح \$0.05');
  String shareEarned(String cash) => _get(
        '+$cash earned for sharing!',
        'شیئر کرنے پر +$cash حاصل ہوئے!',
        '+$cash ربحتها من المشاركة!',
      );
  String get shareFailed =>
      _get('Could not start sharing', 'شیئر شروع نہیں ہو سکا',
          'تعذر بدء المشاركة');
  // Proof-based share rewards (screenshot + admin approval).
  String shareToEarn(String display) => _get(
        'Share to earn $display',
        'شیئر کر کے $display کمائیں',
        'شارك لتربح $display',
      );
  String get shareToEarnDesc => _get(
        'Share this post with the system share sheet, then upload a screenshot of the shared post. After admin review, the cash is credited to your wallet.',
        'یہ پوسٹ سسٹم شیئر شیٹ سے شیئر کریں، پھر شیئر کی گئی پوسٹ کا اسکرین شاٹ اپ لوڈ کریں۔ ایڈمن کے جائزے کے بعد کیش آپ کے والیٹ میں آ جائے گا۔',
        'شارك هذه المشاركة عبر ورقة المشاركة، ثم ارفع لقطة شاشة للمنشور المشترك. بعد مراجعة المشرف، تُضاف النقود إلى محفظتك.',
      );
  String get shareNow =>
      _get('Share now', 'ابھی شیئر کریں', 'شارك الآن');
  String uploadProofToEarn(String display) => _get(
        'Upload proof to earn $display',
        'ثبوت اپ لوڈ کریں اور $display کمائیں',
        'ارفع الدليل لتربح $display',
      );
  String get proofSheetHint => _get(
        'Take a screenshot of your shared post, then pick it here. JPG, PNG, WEBP or GIF, max 5MB.',
        'اپنی شیئر کی گئی پوسٹ کا اسکرین شاٹ لیں، پھر یہاں منتخب کریں۔ JPG، PNG، WEBP یا GIF، زیادہ سے زیادہ 5MB۔',
        'التقط لقطة شاشة لمنشورك المشترك، ثم اخترها هنا. JPG أو PNG أو WEBP أو GIF، بحد أقصى 5 ميجابايت.',
      );
  String get pickScreenshot => _get(
      'Pick screenshot', 'اسکرین شاٹ منتخب کریں', 'اختر لقطة الشاشة');
  String get noProofPicked => _get('Pick a screenshot first',
      'پہلے اسکرین شاٹ منتخب کریں', 'اختر لقطة الشاشة أولًا');
  String get submitClaim => _get('Submit claim', 'دعویٰ جمع کریں', 'تقديم المطالبة');
  String get proofTooBig => _get('Image must be under 5MB',
      'تصویر 5MB سے کم ہونی چاہیے', 'يجب أن تكون الصورة أقل من 5 ميجابايت');
  String get proofInvalidType => _get('Only image files up to 5MB are accepted',
      'صرف 5MB تک کی تصویریں قبول ہیں', 'تُقبل ملفات الصور حتى 5 ميجابايت فقط');
  String get proofRequiredMsg => _get('A screenshot proof is required',
      'اسکرین شاٹ کا ثبوت ضروری ہے', 'يلزم دليل لقطة الشاشة');
  String get alreadyClaimedPost => _get(
      'Already claimed for this post',
      'اس پوسٹ کے لیے پہلے ہی دعویٰ جمع ہو چکا ہے',
      'تم تقديم مطالبة لهذه المشاركة من قبل');
  String get underReview => _get('Under review', 'زیرِ جائزہ', 'قيد المراجعة');
  String get claimFailedMsg => _get('Could not submit the claim',
      'دعویٰ جمع نہیں ہو سکا', 'تعذر تقديم المطالبة');
  String get myClaims =>
      _get('My claims', 'میرے دعوے', 'مطالباتي');
  String get noClaimsYet => _get(
      'No claims yet — share a post to earn.',
      'ابھی کوئی دعویٰ نہیں — کمانے کے لیے پوسٹ شیئر کریں۔',
      'لا توجد مطالبات بعد — شارك منشورًا للربح.');
  String get terms => _get('Terms', 'شرائط', 'الشروط');
  String get rewardsTerms =>
      _get('Rewards Terms', 'انعامی شرائط', 'شروط المكافآت');
  String get viewFullTerms =>
      _get('View full terms', 'مکمل شرائط دیکھیں', 'عرض الشروط الكاملة');
  String get termsAgree => _get('I agree', 'میں متفق ہوں', 'أوافق');
  String get walletAgreeTitle =>
      _get('Before you use Cash Wallet', 'کیش والیٹ استعمال سے پہلے',
          'قبل استخدام محفظة النقد');
  String get agree1 =>
      _get('Cash rewards are 18+ only.', 'کیش انعامات صرف 18+ کے لیے ہیں۔',
          'المكافآت النقدية لمن هم 18 عامًا فأكثر فقط.');
  String get agree2 =>
      _get('Minimum withdrawal is \$10.00.', 'کم از کم نکاسی \$10.00 ہے۔',
          'الحد الأدنى للسحب هو \$10.00.');
  String get agree3 => _get(
        'Withdrawals are reviewed & paid manually, usually within 7 days.',
        'نکاسی کی دستی جائزہ اور ادائیگی ہوتی ہے، عام طور پر 7 دن کے اندر۔',
        'تتم مراجعة طلبات السحب ودفعها يدويًا، عادةً خلال 7 أيام.',
      );
  String get agree4 => _get(
        'Genuine activity only — no bots, fake accounts, or self-clicks.',
        'صرف حقیقی سرگرمی — کوئی بوٹس، جعلی اکاؤنٹس یا خود کلکس نہیں۔',
        'النشاط الحقيقي فقط — لا روبوتات ولا حسابات مزيفة ولا نقرات ذاتية.',
      );
  String get noSellersYet =>
      _get('No sellers yet — share a product to join the race!',
          'ابھی کوئی سیلر نہیں — ریس میں شامل ہونے کے لیے کوئی پروڈکٹ شیئر کریں!',
          'لا يوجد بائعون بعد — شارك منتجًا للانضمام إلى السباق!');
  String get noVolumeYet =>
      _get('Share products to start unlocking volume bonuses.',
          'والیوم بونس حاصل کرنے کے لیے پروڈکٹس شیئر کریں۔',
          'شارك المنتجات لبدء فتح مكافآت الحجم.');
  String volumeRow(String progress, String bonus) => _get(
        '$progress clicks → $bonus bonus',
        '$progress کلکس ← $bonus بونس',
        '$progress نقرة ← مكافأة $bonus',
      );
  String get convert => _get('Convert', 'تبدیل کریں', 'تحويل');
  String get status => _get('Status', 'حیثیت', 'الحالة');
  String get pending => _get('Pending', 'زیرِ التوا', 'قيد الانتظار');
  String get approved => _get('Approved', 'منظور شدہ', 'مقبول');
  String get rejected => _get('Rejected', 'مسترد', 'مرفوض');
  String get wdPaidStatus => _get('Paid', 'ادا شدہ', 'مدفوع');
  String get myWithdrawals =>
      _get('My withdrawals', 'میری نکاسیاں', 'طلبات السحب الخاصة بي');
  String get walletHistoryEmpty => _get(
        'No cash activity yet — share products to earn.',
        'ابھی کوئی کیش سرگرمی نہیں — کمانے کے لیے پروڈکٹس شیئر کریں۔',
        'لا يوجد نشاط نقدي بعد — شارك المنتجات للربح.',
      );
  // Rewards terms (short, bundled in-app). Canonical numbers mirror
  // ~/workspace/virello/store_listing/rewards_terms.html.
  String get rtSummary => _get(
        'Earn Points for posting and engaging, and Cash (USD) for sharing products that lead to real shopping clicks. You never pay anything to participate — no wagering, no entry fee, no purchase necessary.',
        'پوسٹنگ اور شرکت پر پوائنٹس، اور پروڈکٹس شیئر کرنے پر کیش (USD) کمائیں جس سے حقیقی خریداری کلکس ہوں۔ شرکت کے لیے آپ کو کچھ نہیں دینا — کوئی شرط، کوئی فیس، کوئی خریداری ضروری نہیں۔',
        'اربح نقاطًا للنشر والتفاعل، ونقدًا (دولار أمريكي) لمشاركة المنتجات التي تؤدي إلى نقرات تسوق حقيقية. لا تدفع شيئًا أبدًا للمشاركة — لا مراهنة ولا رسوم دخول ولا شراء مطلوب.',
      );
  String get rtEligibilityT => _get('1. Eligibility', '1. اہلیت', '1. الأهلية');
  String get rtEligibility => _get(
        'Cash rewards and withdrawals require you to be 18 years or older (or the age of majority in your country). Verify your email, complete your profile, and hold your account for at least 7 days before your first withdrawal. One account per person — duplicate or fake accounts forfeit all rewards.',
        'کیش انعامات اور نکاسی کے لیے آپ کی عمر 18 سال یا اس سے زیادہ ہونی چاہیے (یا آپ کے ملک میں بالغ ہونے کی عمر)۔ پہلی نکاسی سے پہلے اپنا ای میل تصدیق کریں، پروفائل مکمل کریں اور اکاؤنٹ کم از کم 7 دن پرانا ہو۔ ایک شخص ایک اکاؤنٹ — نقل یا جعلی اکاؤنٹس کے تمام انعامات ضبط۔',
        'تتطلب المكافآت النقدية والسحوبات أن يكون عمرك 18 عامًا أو أكثر (أو سن الرشد في بلدك). تحقق من بريدك الإلكتروني وأكمل ملفك الشخصي واحتفظ بحسابك لمدة 7 أيام على الأقل قبل أول سحب. حساب واحد لكل شخص — الحسابات المكررة أو المزيفة تفقد جميع المكافآت.',
      );
  String get rtPointsT => _get('2. Points', '2. پوائنٹس', '2. النقاط');
  String get rtPoints => _get(
        'Points are a non-monetary engagement score with no cash value — they cannot be sold or transferred. 100 Points = 10 Grow credits (in-app features), or convert points into Cash at the rate shown in the Wallet (currently 1,000 pts = \$1.00, minimum 1,000 pts).',
        'پوائنٹس غیر مالی مصروفیتی اسکور ہیں جن کی کوئی نقد قیمت نہیں — انہیں بیچا یا منتقل نہیں کیا جا سکتا۔ 100 پوائنٹس = 10 گرو کریڈٹس (ان-ایپ فیچرز)، یا والیٹ میں دکھائے گئے ریٹ پر کیش میں بدلیں (فی الحال 1,000 پوائنٹس = \$1.00، کم از کم 1,000 پوائنٹس)۔',
        'النقاط هي درجة تفاعل غير نقدية بلا قيمة نقدية — لا يمكن بيعها أو نقلها. 100 نقطة = 10 أرصدة نمو (ميزات داخل التطبيق)، أو حوّل النقاط إلى نقد بالسعر المعروض في المحفظة (حاليًا 1,000 نقطة = \$1.00، بحد أدنى 1,000 نقطة).',
      );
  String get rtCashT => _get('3. Cash rewards', '3. کیش انعامات', '3. المكافآت النقدية');
  String get rtCash => _get(
        'Cash is earned only for actions that can generate real shopping activity: \$0.05 per product shared via your personal link (max 20/day), \$0.03 per verified click on your shared link (max 50/day, no self-clicks), volume bonuses of \$2.00 at 100 and \$10.00 at 500 verified clicks in 7 days. Rates may change with notice in the app; shown earnings are estimates until clicks are verified. Share rewards need a screenshot proof and admin approval.',
        'کیش صرف ان اقدامات پر ملتا ہے جن سے حقیقی خریداری سرگرمی ہو: آپ کے ذاتی لنک سے ہر پروڈکٹ شیئر پر \$0.05 (زیادہ سے زیادہ 20/دن)، آپ کے شیئرڈ لنک پر ہر تصدیق شدہ کلک پر \$0.03 (زیادہ سے زیادہ 50/دن، خود کلک نہیں)، 7 دن میں 100 تصدیق شدہ کلکس پر \$2.00 اور 500 پر \$10.00 والیوم بونس۔ ریٹس ایپ میں اطلاع کے ساتھ بدل سکتے ہیں؛ دکھائی گئی آمدنی کلکس کی تصدیق تک تخمینہ ہے۔ شیئر انعامات کے لیے اسکرین شاٹ کا ثبوت اور ایڈمن کی منظوری ضروری ہے۔',
        'تُربح النقود فقط مقابل إجراءات يمكن أن تولد نشاط تسوق حقيقي: \$0.05 لكل منتج تتم مشاركته عبر رابطك الشخصي (بحد أقصى 20/يوم)، و\$0.03 لكل نقرة موثقة على رابطك (بحد أقصى 50/يوم، دون نقرات ذاتية)، ومكافآت حجم بقيمة \$2.00 عند 100 نقرة و\$10.00 عند 500 نقرة موثقة خلال 7 أيام. قد تتغير الأسعار بإشعار في التطبيق؛ الأرباح المعروضة تقديرية حتى يتم التحقق من النقرات. مكافآت المشاركة تتطلب لقطة شاشة كدليل وموافقة المشرف.',
      );
  String get rtContestsT =>
      _get('4. Contests (skill-based)', '4. مقابلے (مہارت پر مبنی)', '4. المسابقات (قائمة على المهارة)');
  String get rtContests => _get(
        'Weekly Top Seller (most verified share-clicks, Mon–Sun): \$10.00 cash. Monthly Top Seller (calendar month): \$50.00 cash. Weekly/Monthly Top Poster (most Points): 500 / 300 / 150 and 2000 / 1000 / 500 Points. Winners are decided purely by measured activity — never by random draw. Ties go to the earlier achiever. No lottery, no wagering, no purchase necessary — ever.',
        'ہفتہ وار ٹاپ سیلر (سب سے زیادہ تصدیق شدہ شیئر کلکس، پیر–اتوار): \$10.00 کیش۔ ماہانہ ٹاپ سیلر (کیلنڈر مہینہ): \$50.00 کیش۔ ہفتہ وار/ماہانہ ٹاپ پوسٹر (سب سے زیادہ پوائنٹس): 500 / 300 / 150 اور 2000 / 1000 / 500 پوائنٹس۔ فاتحین صرف ناپی گئی سرگرمی سے طے ہوتے ہیں — کبھی قرعہ اندازی سے نہیں۔ برابر ہونے پر پہلے حاصل کرنے والا جیتتا ہے۔ کوئی لاٹری، کوئی شرط، کوئی خریداری ضروری نہیں — کبھی نہیں۔',
        'أفضل بائع أسبوعي (أكثر النقرات الموثقة، الاثنين–الأحد): \$10.00 نقدًا. أفضل بائع شهري (الشهر الميلادي): \$50.00 نقدًا. أفضل ناشر أسبوعي/شهري (أكثر النقاط): 500 / 300 / 150 و2000 / 1000 / 500 نقطة. يُحدد الفائزون بالنشاط المقاس فقط — أبدًا بالسحب العشوائي. عند التعادل يفوز الأسبق. لا يانصيب ولا مراهنة ولا شراء مطلوب — أبدًا.',
      );
  String get rtWithdrawT => _get('5. Withdrawals', '5. نکاسی', '5. السحوبات');
  String get rtWithdraw => _get(
        'Minimum withdrawal: \$10.00 USD. Withdrawals are paid by manual bank transfer to the bank details you provide. Every withdrawal is manually reviewed, usually within 7 days — we may ask for identity verification. One pending withdrawal at a time. You are responsible for any taxes on your earnings in your country.',
        'کم از کم نکاسی: \$10.00 USD۔ نکاسی آپ کی دی گئی بینک تفصیلات پر دستی بینک ٹرانسفر سے ادا کی جاتی ہے۔ ہر نکاسی کا دستی جائزہ لیا جاتا ہے، عام طور پر 7 دن کے اندر — ہم شناخت کی تصدیق مانگ سکتے ہیں۔ ایک وقت میں ایک زیرِ التوا درخواست۔ آپ اپنے ملک میں اپنی آمدنی پر ٹیکس کے ذمہ دار ہیں۔',
        'الحد الأدنى للسحب: \$10.00 دولار أمريكي. تُدفع السحوبات بتحويل بنكي يدوي إلى التفاصيل البنكية التي تقدمها. تتم مراجعة كل سحب يدويًا، عادةً خلال 7 أيام — وقد نطلب التحقق من الهوية. طلب سحب واحد قيد الانتظار في كل مرة. أنت مسؤول عن أي ضرائب على أرباحك في بلدك.',
      );
  String get rtFairPlayT => _get('6. Fair play', '6. منصفانہ کھیل', '6. اللعب النظيف');
  String get rtFairPlay => _get(
        'Rewards are for genuine activity only. The following forfeit earnings and may lead to account suspension: fake accounts, bots, click farms or automated clicking/sharing; clicking your own links or coordinating reciprocal clicks; spam — mass-sharing to uninterested audiences; anything that violates Virello\u2019s no-fake-engagement rule. We use automated limits and manual review. Decisions on abuse are final.',
        'انعامات صرف حقیقی سرگرمی کے لیے ہیں۔ درج ذیل سے آمدنی ضبط ہوتی ہے اور اکاؤنٹ معطل ہو سکتا ہے: جعلی اکاؤنٹس، بوٹس، کلک فارمز یا خودکار کلکنگ/شیئرنگ؛ اپنے لنکس پر خود کلک یا باہمی کلکس؛ اسپام — غیر دلچسپی رکھنے والے سامعین کو بڑے پیمانے پر شیئرنگ؛ Virello کے جعلی مصروفیت مخالف اصول کی کوئی بھی خلاف ورزی۔ ہم خودکار حدود اور دستی جائزہ استعمال کرتے ہیں۔ بدسلوکی پر فیصلے حتمی ہیں۔',
        'المكافآت للنشاط الحقيقي فقط. ما يلي يؤدي إلى مصادرة الأرباح وقد يؤدي إلى تعليق الحساب: الحسابات المزيفة والروبوتات ومزارع النقرات أو النقر/المشاركة الآلية؛ النقر على روابطك الخاصة أو تنسيق النقرات المتبادلة؛ البريد المزعج — المشاركة الجماعية لجمهور غير مهتم؛ أي شيء ينتهك قاعدة Virello ضد التفاعل المزيف. نستخدم حدودًا آلية ومراجعة يدوية. قرارات إساءة الاستخدام نهائية.',
      );
  String get rtChangesT => _get('7. Changes & contact', '7. تبدیلیاں اور رابطہ', '7. التغييرات والتواصل');
  String get rtChanges => _get(
        'We may change rates, limits, or these terms with reasonable notice in the app. Continued use after changes means you accept them. We may end the rewards program with 30 days\u2019 notice; earned Cash balances above the withdrawal minimum will still be payable. Questions: privacy@virello.com.',
        'ہم ایپ میں معقول اطلاع کے ساتھ ریٹس، حدود یا یہ شرائط بدل سکتے ہیں۔ تبدیلیوں کے بعد استعمال جاری رکھنا قبولیت ہے۔ ہم 30 دن کی اطلاع کے ساتھ انعامی پروگرام ختم کر سکتے ہیں؛ نکاسی کی کم از کم رقم سے زیادہ کیش بیلنس پھر بھی قابلِ ادائیگی ہو گا۔ سوالات: privacy@virello.com۔',
        'قد نغير الأسعار أو الحدود أو هذه الشروط بإشعار معقول في التطبيق. استمرار الاستخدام بعد التغييرات يعني قبولك لها. قد ننهي برنامج المكافآت بإشعار 30 يومًا؛ ستظل أرصدة النقد المكتسبة فوق الحد الأدنى للسحب مستحقة الدفع. للأسئلة: privacy@virello.com.',
      );
}
