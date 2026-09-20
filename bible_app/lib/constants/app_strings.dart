/// Lightweight UI strings for the two supported app languages.
/// Bible / hymn / commentary source names intentionally remain unchanged so
/// imported file names are displayed exactly as supplied by the user.
enum AppLanguage { korean, english }

class AppStrings {
  final AppLanguage appLanguage;

  const AppStrings(this.appLanguage);

  bool get isKorean => appLanguage == AppLanguage.korean;

  // Bottom navigation
  String get bible => isKorean ? '성경' : 'Bible';
  String get compareTab => isKorean ? '역본대조' : 'Compare';
  String get hymns => isKorean ? '찬송가' : 'Hymns';
  String get responsiveReading => isKorean ? '교독문' : 'Reading';
  String get commentary => isKorean ? '주석' : 'Commentary';
  String get settings => isKorean ? '설정' : 'Settings';

  // Common actions / state
  String get cancel => isKorean ? '취소' : 'Cancel';
  String get delete => isKorean ? '삭제' : 'Delete';
  String get save => isKorean ? '저장' : 'Save';
  String get edit => isKorean ? '수정' : 'Edit';
  String get close => isKorean ? '닫기' : 'Close';
  String get apply => isKorean ? '적용' : 'Apply';
  String get previous => isKorean ? '이전' : 'Previous';
  String get next => isKorean ? '다음' : 'Next';
  String get noData => isKorean ? '데이터가 없습니다' : 'No data available';

  // Bible reader
  String get previousChapter => isKorean ? '이전 장' : 'Previous chapter';
  String get nextChapter => isKorean ? '다음 장' : 'Next chapter';
  String get translationCompareSettings =>
      isKorean ? '번역/비교 설정' : 'Translation / comparison';
  String get bibleSearch => isKorean ? '성경 검색' : 'Bible search';
  String get searchHint =>
      isKorean ? '단어 또는 구절 검색...' : 'Search a word or phrase...';
  String get translation => isKorean ? '번역' : 'Translation';
  String get enterSearchQuery =>
      isKorean ? '검색어를 입력하세요' : 'Enter a search term';
  String resultsFound(int count) =>
      isKorean ? '$count건 검색됨' : '$count results found';
  String currentBookOnly(String book) => isKorean ? '$book만' : '$book only';
  String get translationSelection => isKorean ? '번역 선택' : 'Select translation';
  String get compareTranslationSelection =>
      isKorean ? '대조 역본 선택' : 'Select translations to compare';
  String get compare => isKorean ? '비교' : 'Compare';
  String get layout => isKorean ? '레이아웃: ' : 'Layout: ';
  String get layoutTooltip =>
      isKorean ? '좌우 / 상하 전환' : 'Toggle side-by-side / top-bottom';
  String get sideBySide => isKorean ? '좌우' : 'Side by side';
  String get topBottom => isKorean ? '상하' : 'Top / bottom';
  String get singleSelectionHint => isKorean
      ? '읽을 성경 역본을 하나 선택하세요.'
      : 'Choose the translation to read.';
  String get compareSelectionHint => isKorean
      ? '대조할 역본을 여러 개 선택하세요. 최대 4개까지 선택할 수 있습니다.'
      : 'Pick several translations to compare. Up to four.';
  String get maxCompareReached => isKorean
      ? '성경 비교는 최대 4개까지 선택할 수 있습니다.'
      : 'You can compare up to four Bibles.';

  // Verse selection
  String get verseSelectionTitle => isKorean ? '절 선택' : 'Select verse';

  // Book selector
  String get oldTestament => isKorean ? '구약' : 'Old Testament';
  String get newTestament => isKorean ? '신약' : 'New Testament';

  String chapterLabel(int chapter) => isKorean ? '$chapter장' : 'Ch. $chapter';
  String verseLabel(int verse) => isKorean ? '$verse절' : 'V. $verse';
  String errorLabel(String message) =>
      isKorean ? '오류: $message' : 'Error: $message';

  /// Full book label. English Bible source names additionally show both the
  /// Korean and English book names, as requested.
  String bookLabel(
      {required String korean,
      required String english,
      bool showBoth = false}) {
    if (showBoth) return '$korean / $english';
    return isKorean ? korean : english;
  }

  bool isEnglishSourceName(String name) =>
      name.isNotEmpty && name.runes.every((rune) => rune <= 127);

  // Hymns
  String get hymnSearchHint =>
      isKorean ? '찬송가 번호 또는 제목 검색...' : 'Search hymn number or title...';
  String get noActiveHymns => isKorean ? '활성화된 찬송가 없음' : 'No hymnals enabled';
  String get noResults => isKorean ? '결과 없음' : 'No results';
  String get sheetMusic => isKorean ? '악보' : 'Sheet music';
  String get lyrics => isKorean ? '가사' : 'Lyrics';
  String get cannotLoadSheetMusic =>
      isKorean ? '악보 이미지를 불러올 수 없습니다' : 'Unable to load sheet music';
  String get addHymnFile =>
      isKorean ? '찬송가 파일 추가 (.hdb)' : 'Add hymnal file (.hdb)';
  String get addReadingFile => isKorean
      ? '교독문 파일 추가 (.hdb)'
      : 'Add responsive reading file (.hdb)';
  String get cmpCopied => isKorean
      ? '동일한 이름의 .cmp 악보 파일도 추가되었습니다.'
      : 'The matching .cmp sheet-music file was also added.';
  String get cmpMissing => isKorean
      ? '악보 파일(.cmp)이 함께 있으면 자동으로 추가됩니다.'
      : 'A matching .cmp file in the same folder is added automatically.';

  // Commentary
  String get noActiveCommentaries => isKorean
      ? '활성화된 주석이 없습니다.\n설정에서 주석을 추가하세요.'
      : 'No commentaries enabled.\nAdd one in Settings.';
  String get noCommentary => isKorean ? '주석 없음' : 'No commentary';
  String get addCommentaryFile =>
      isKorean ? '주석 파일 추가 (.cdb)' : 'Add commentary file (.cdb)';

  // Settings
  String get appTitle => isKorean ? '성경' : 'Bible';
  String get appearance => isKorean ? '보기' : 'Appearance';
  String get fontSize => isKorean ? '본문 글자 크기' : 'Content font size';
  String get menuFontSize => isKorean ? '메뉴 글자 크기' : 'Menu font size';
  String get menuFontHint => isKorean
      ? '메뉴·제목·버튼 등 화면 UI 글자 크기 (기본값의 90~110%)'
      : 'Size of menus, titles and buttons (90–110% of default)';
  String get fontPreview => isKorean
      ? '태초에 하나님이 천지를 창조하시니라. (창 1:1)'
      : 'In the beginning God created the heaven and the earth. (Genesis 1:1)';
  String get theme => isKorean ? '테마' : 'Theme';
  String get systemTheme => isKorean ? '시스템 설정' : 'System';
  String get lightTheme => isKorean ? '밝은 테마' : 'Light';
  String get darkTheme => isKorean ? '어두운 테마' : 'Dark';
  String get language => isKorean ? '언어' : 'Language';
  String get koreanLanguage => isKorean ? '한국어' : 'Korean';
  String get englishLanguage => isKorean ? '영어' : 'English';
  String get bibleTranslations => isKorean ? '성경 번역' : 'Bible translations';
  String get addBibleFile =>
      isKorean ? '성경 파일 추가 (.bdb / .sdb)' : 'Add Bible file (.bdb / .sdb)';
  String get commentarySources => isKorean ? '주석' : 'Commentaries';
  String get hymnSources => isKorean ? '찬송가' : 'Hymnals';
  String get readingSources =>
      isKorean ? '교독문' : 'Responsive readings';
  String get builtIn => isKorean ? '기본 제공' : 'Built in';
  String deleteSourceConfirm(String name) => isKorean
      ? '$name을(를) 삭제하시겠습니까?\n앱에 복사된 데이터는 삭제되고, 원본 파일은 그대로 남습니다.'
      : 'Delete $name?\nThe app\'s copied data will be removed; the original file stays.';
  String fileTypeAllowed(String extensions) => isKorean
      ? '$extensions 파일만 지원됩니다'
      : 'Only $extensions files are supported';
  String sourceAdded(String name) => isKorean ? '$name 추가됨' : '$name added';
  String get cannotDeleteLastBible =>
      isKorean ? '성경은 최소 한 개는 남아 있어야 합니다.' : 'At least one Bible must remain.';
  String get cannotDisableLastSource => isKorean
      ? '각 메뉴에는 최소 하나의 항목이 활성화되어 있어야 합니다.'
      : 'At least one item must remain enabled for each menu.';
  String get cannotDeleteDefaultSource => isKorean
      ? '기본 찬송가/주석은 삭제할 수 없습니다.'
      : 'The default hymnal and commentary cannot be deleted.';
  String get madeBy => '최준영 제작';

  // Notes
  String get notes => isKorean ? '노트' : 'Notes';
  String get addNote => isKorean ? '노트 추가' : 'Add note';
  String get noteHint =>
      isKorean ? '노트를 입력하세요...' : 'Write your note...';
  String get noteEdit => isKorean ? '노트 수정' : 'Edit note';
  String noteForVerses(int from, int to) => from == to
      ? (isKorean ? '$from절 노트' : 'Verse $from note')
      : (isKorean ? '$from~$to절 노트' : 'Verses $from–$to note');
  String noteForMultipleVerses(int count) =>
      isKorean ? '선택한 $count절 노트' : 'Note for $count selected verses';
  String selectedVersesCount(int count) =>
      isKorean ? '$count절 선택됨' : '$count verses selected';
  String get exportNotes =>
      isKorean ? '노트 내보내기 (CSV)' : 'Export notes (CSV)';
  String get chooseExportFolder =>
      isKorean ? '내보내기할 폴더 선택' : 'Choose export folder';
  String get exportNotesFailed =>
      isKorean ? '노트 내보내기에 실패했습니다.' : 'Failed to export notes.';
  String get exportNotesCancelled =>
      isKorean ? '노트 내보내기가 취소됐습니다.' : 'Export cancelled.';
  String get importNotes =>
      isKorean ? '노트 가져오기 (CSV)' : 'Import notes (CSV)';
  String notesExported(String path) => isKorean
      ? '노트를 내보내어습니다:\n$path'
      : 'Notes exported to:\n$path';
  String notesImported(int count) => isKorean
      ? '$count개의 노트를 가져왔습니다.'
      : 'Imported $count notes.';
  String get notesImportFailed =>
      isKorean ? '노트 가져오기에 실패했습니다.' : 'Failed to import notes.';
  String get noNotes => isKorean ? '저장된 노트가 없습니다.' : 'No notes saved yet.';
}
