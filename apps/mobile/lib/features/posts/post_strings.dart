/// Localized strings for user post / campaign edit-delete.
///
/// Kept in its own file (same EN/UR/AR convention as AppStrings) so the
/// three-dots edit/delete feature stays self-contained.
class MyPostStrings {
  final String code;
  const MyPostStrings(this.code);

  bool get _ur => code == 'ur';
  bool get _ar => code == 'ar';

  String get myPosts => _ur
      ? 'میری پوسٹس'
      : _ar
          ? 'منشوراتي'
          : 'My Posts';
  String get edit => _ur
      ? 'ایڈٹ کریں'
      : _ar
          ? 'تعديل'
          : 'Edit';
  String get editPost => _ur
      ? 'پوسٹ ایڈٹ کریں'
      : _ar
          ? 'تعديل المنشور'
          : 'Edit post';
  String get deletePost => _ur
      ? 'پوسٹ ڈیلیٹ کریں'
      : _ar
          ? 'حذف المنشور'
          : 'Delete post';
  String get deletePostConfirm => _ur
      ? 'کیا یہ پوسٹ ڈیلیٹ کریں؟ یہ فیڈ سے ہٹ جائے گی۔'
      : _ar
          ? 'حذف هذا المنشور؟ ستتم إزالته من الخلاصة.'
          : 'Delete this post? It will be removed from the feed.';
  String get postUpdated => _ur
      ? 'پوسٹ اپڈیٹ ہو گئی'
      : _ar
          ? 'تم تحديث المنشور'
          : 'Post updated';
  String get postDeleted => _ur
      ? 'پوسٹ ڈیلیٹ ہو گئی'
      : _ar
          ? 'تم حذف المنشور'
          : 'Post deleted';
  String get editCampaign => _ur
      ? 'کیمپین ایڈٹ کریں'
      : _ar
          ? 'تعديل الحملة'
          : 'Edit campaign';
  String get campaignUpdated => _ur
      ? 'کیمپین اپڈیٹ ہو گئی'
      : _ar
          ? 'تم تحديث الحملة'
          : 'Campaign updated';
  String get noPosts => _ur
      ? 'ابھی کوئی پوسٹ نہیں — فیڈ میں نظر آنے کے لیے کوئی کیمپین شیئر کریں۔'
      : _ar
          ? 'لا توجد منشورات بعد — شارك حملة في الخلاصة لرؤيتها هنا.'
          : 'No posts yet — share a campaign to the feed to see it here.';
  String get topicsHint => _ur
      ? 'ٹاپکس (کاما سے الگ کریں، زیادہ سے زیادہ 5)'
      : _ar
          ? 'المواضيع (افصل بفاصلة، بحد أقصى 5)'
          : 'Topics (comma separated, max 5)';
  String get titleLabel => _ur
      ? 'عنوان'
      : _ar
          ? 'العنوان'
          : 'Title';
  String get goalLabel => _ur
      ? 'مقصد'
      : _ar
          ? 'الهدف'
          : 'Goal';
  String get saveFailed => _ur
      ? 'محفوظ نہیں ہو سکا، دوبارہ کوشش کریں'
      : _ar
          ? 'تعذر الحفظ، حاول مرة أخرى'
          : "Couldn't save, please try again";
  String get resubmittedNote => _ur
      ? 'پوسٹ دوبارہ ریویو کے لیے بھیج دی گئی'
      : _ar
          ? 'تمت إعادة إرسال المنشور للمراجعة'
          : 'Post resubmitted for review';
}
