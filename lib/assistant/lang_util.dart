/// Language helpers for the assistant: English, Roman Urdu, Urdu and Pashto.
/// Roman Urdu / Roman Pashto are Urdu / Pashto typed in English letters
/// ("me theek hoon", "za kha yam"); replies come back the same way.
enum ChatLang { en, romanUrdu, romanPashto, ur, ps }

/// Letters used in Pashto but not Urdu.
final _pashtoOnly = RegExp('[ټډړږښځڅګڼېۍ]');

/// Letters used in Urdu but not Pashto (ے ں ہ ھ ٹ ڈ ڑ).
final _urduOnly = RegExp('[ےںہھٹڈڑ]');
final _arabicScript = RegExp(r'[؀-ۿ]');

const _romanUrduWords = {
  'mujhe', 'mujh', 'mein', 'main', 'hai', 'hain', 'karna', 'kar', 'kal', 'aaj', 'baje', 'yaad', 'dilana', 'dila', 'paani', 'pani', 'piya',
  'kharch', 'kharcha', 'rupay', 'rupaye', 'liya', 'gaya', 'kya', 'kyun', 'acha', 'achha', 'theek', 'shukriya', 'karo', 'nahi', 'nahin',
  'bohat', 'bahut', 'khush', 'udaas', 'subah', 'shaam', 'raat', 'ghante', 'baad', 'likh', 'lo', 'mera', 'meri', 'ko', 'mai', 'thek',
  'thik', 'ho', 'hoon', 'hun', 'hu', 'tum', 'tu', 'ap', 'aap', 'kese', 'kaise', 'kaisay', 'kesay', 'kesi', 'kaisi', 'haal', 'hal', 'bhi',
  'bhe', 'sab', 'ji', 'jee', 'haan', 'han', 'yaar', 'bhai', 'raha', 'rahi', 'rahe', 'chahiye', 'tera', 'teri', 'apna', 'apni', 'abhi',
  'phir', 'kyunke', 'lekin', 'magar', 'aur', 'ki', 'ke', 'se', 'wala', 'wali', 'kaam', 'kuch', 'koi', 'batao', 'bataen', 'suno', 'chalo',
  'shukria', 'meharbani', 'kon', 'kaun', 'kahan', 'kab', 'kyon', 'kitna', 'kitne', 'gaye', 'gayi', 'tha', 'thi', 'hua', 'hui',
};

/// Words that mark Pashto typed in English letters.
const _romanPashtoWords = {
  'za', 'zma', 'zama', 'sta', 'ta', 'tha', 'sanga', 'tsanga', 'singa', 'senga', 'ye', 'yei', 'yi', 'yam', 'yama', 'yum', 'kha', 'kho',
  'khu', 'manana', 'mannana', 'dera', 'dery', 'dere', 'der', 'saba', 'sabaa', 'nan', 'rata', 'rta', 'mata', 'wakra', 'okra', 'wakro',
  'okro', 'kawa', 'kawam', 'kram', 'kawi', 'ghwaram', 'ghwarm', 'okhom', 'wakhom', 'oba', 'obe', 'obu', 'dodai', 'dodei', 'kor', 'che',
  'chi', 'pa', 'sa', 'tsa', 'tsok', 'sok', 'khabara', 'khabare', 'sahar', 'makham', 'maakham', 'shpa', 'shpe', 'bajy', 'baji', 'staray',
  'stary', 'starrey', 'khushala', 'khoshala', 'khafa', 'wale', 'wali', 'olay', 'shta', 'nishta', 'sha', 'sho', 'shwa', 'shwe', 'wsklay',
  'wskal', 'wakhwara', 'okhwara', 'raka', 'rakra', 'zyat', 'zyaat', 'kaar', 'kar', 'yaad', 'yad', 'starr', 'janana', 'yara', 'warora',
  'khor', 'mor', 'plar', 'wror', 'zoy', 'lur', 'ghwa', 'ghwakhay',
};

/// Strongly Pashto words (not used in Roman Urdu or English).
const _romanPashtoStrong = {
  'kawe', 'kawi', 'pohegam', 'wazgay', 'khuge', 'stray', 'khob', 'naragh', 'naroogh', 'wogoro', 'osegam', 'wrora', 'shwe', 'raghle',
  'za', 'zma', 'zama', 'sanga', 'tsanga', 'yama', 'manana', 'saba', 'sabaa', 'rata', 'wakra', 'okra', 'kawa', 'ghwaram', 'okhom', 'oba',
  'obu', 'dodai', 'tsok', 'khabara', 'makham', 'maakham', 'shpa', 'staray', 'khushala', 'khoshala', 'nishta', 'shta', 'wsklay', 'wskal',
  'okhwara', 'rakra', 'zyat', 'janana', 'warora', 'plar', 'wror', 'ghwakhay', 'kram',
};

/// Very common English words: a message mostly made of these is English.
const englishCommon = {
  'i', 'me', 'my', 'you', 'your', 'we', 'he', 'she', 'it', 'they', 'is', 'am', 'are', 'was', 'were', 'be', 'been', 'do', 'does', 'did', 'have', 'has',
  'had', 'the', 'a', 'an', 'and', 'or', 'but', 'to', 'of', 'in', 'on', 'at', 'for', 'with', 'from', 'about', 'what', 'how', 'why', 'when', 'where',
  'who', 'this', 'that', 'these', 'those', 'not', 'no', 'yes', 'ok', 'okay', 'please', 'thanks', 'thank', 'good', 'bad', 'today', 'tomorrow', 'now',
  'can', 'could', 'will', 'would', 'should', 'want', 'need', 'feel', 'feeling', 'tired', 'happy', 'sad', 'just', 'so', 'very', 'really', 'too', 'all',
  'some', 'any', 'more', 'much', 'many', 'go', 'going', 'went', 'get', 'got', 'make', 'made', 'take', 'call', 'remind', 'add', 'task', 'water', 'drank',
  'spent', 'done', 'time', 'day', 'night', 'morning', 'evening', 'work', 'home', 'doing', 'there', 'here', 'hello', 'hi', 'hey', 'bye', 'sure', 'fine',
  'great', 'nice', 'well', 'know', 'think', 'like', 'love', 'tell', 'joke', 'name', 'up', 'out', 'again', 'still', 'yet', 'also', 'then', 'than', 'if',
};

/// Words the user has used in Roman Pashto / Roman Urdu before, so their
/// own spellings are recognised too (filled in by the assistant's memory).
Set<String> learnedRomanPashto = {};
Set<String> learnedRomanUrdu = {};

ChatLang detectLang(String text) {
  if (_pashtoOnly.hasMatch(text)) return ChatLang.ps;
  if (_arabicScript.hasMatch(text)) {
    // Common Pashto words without Pashto-only letters.
    if (RegExp(r'(^|\s)(زه|زما|سبا|نن|کړه|کوم|وکړه|دي|ده|هم|ولې)(\s|$)').hasMatch(text) && !_urduOnly.hasMatch(text)) return ChatLang.ps;
    return ChatLang.ur;
  }
  final words = text.toLowerCase().split(RegExp(r'[^a-z]+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return ChatLang.en;
  final urdu = words.where((w) => _romanUrduWords.contains(w) || learnedRomanUrdu.contains(w)).length;
  final pashto = words.where((w) => _romanPashtoWords.contains(w) || learnedRomanPashto.contains(w)).length;
  final strong = words.where(_romanPashtoStrong.contains).length;
  final english = words.where(englishCommon.contains).length;
  if (strong >= 1 && pashto >= urdu) return ChatLang.romanPashto;
  if (pashto >= 2 && pashto > urdu) return ChatLang.romanPashto;
  if (urdu >= 2 || (urdu == 1 && words.length <= 3 && english == 0)) return ChatLang.romanUrdu;
  // Short messages with a Pashto word and no English, e.g. "kha da".
  if (pashto >= 1 && english == 0 && urdu == 0) return ChatLang.romanPashto;
  return ChatLang.en;
}

/// True when most words are everyday English (so it's really English, not
/// an unfamiliar Roman Pashto/Urdu spelling).
bool looksEnglish(String text) {
  final words = text.toLowerCase().split(RegExp(r'[^a-z]+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return false;
  return words.where(englishCommon.contains).length * 2 >= words.length;
}

/// Turns Urdu/Pashto/Arabic digits into 0-9 and trims spaces.
String normalizeDigits(String s) {
  const eastern = '۰۱۲۳۴۵۶۷۸۹', arabic = '٠١٢٣٤٥٦٧٨٩';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = eastern.indexOf(ch), j = arabic.indexOf(ch);
    b.write(i >= 0 ? '$i' : j >= 0 ? '$j' : ch);
  }
  return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Number words (1-12 and a few more) in all four languages.
const numberWords = <String, int>{
  // English
  'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10, 'eleven': 11, 'twelve': 12,
  'a': 1, 'an': 1, 'half': 0,
  // Roman Urdu
  'ek': 1, 'aik': 1, 'do': 2, 'teen': 3, 'char': 4, 'chaar': 4, 'panch': 5, 'paanch': 5, 'chay': 6, 'chhe': 6, 'che': 6, 'saat': 7,
  'aath': 8, 'aat': 8, 'nau': 9, 'das': 10, 'gyarah': 11, 'gyara': 11, 'barah': 12, 'bara': 12,
  // Urdu
  'ایک': 1, 'دو': 2, 'تین': 3, 'چار': 4, 'پانچ': 5, 'چھ': 6, 'سات': 7, 'آٹھ': 8, 'نو': 9, 'دس': 10, 'گیارہ': 11, 'بارہ': 12,
  // Roman Pashto
  'yaw': 1, 'yo': 1, 'yow': 1, 'dwa': 2, 'dwe': 2, 'dre': 3, 'dray': 3, 'tsalor': 4, 'salor': 4, 'pinza': 5, 'pinzah': 5, 'shpag': 6, 'shpug': 6,
  'owa': 7, 'uwa': 7, 'ata': 8, 'atta': 8, 'naha': 9, 'nahah': 9, 'las': 10, 'yawolas': 11, 'dolas': 12,
  // Pashto
  'یو': 1, 'یوه': 1, 'دوه': 2, 'درې': 3, 'دری': 3, 'څلور': 4, 'پنځه': 5, 'شپږ': 6, 'اووه': 7, 'اوه': 7, 'اته': 8, 'نهه': 9, 'نه': 9,
  'لس': 10, 'یوولس': 11, 'دولس': 12,
};

/// Reads a number written as digits or a word; null if it isn't one.
int? parseNumber(String token) {
  final t = token.toLowerCase();
  final n = int.tryParse(t);
  if (n != null) return n;
  if (t == 'a' || t == 'an' || t == 'half') return null; // too ambiguous alone
  return numberWords[t];
}

/// Splits into words, keeping Arabic-script and Latin words.
List<String> tokens(String s) => s.toLowerCase().split(RegExp(r'[\s,.!?؟،۔:;]+')).where((w) => w.isNotEmpty).toList();

/// True if [text] contains any of [phrases] (as whole words for Latin).
bool hasAny(String text, Iterable<String> phrases) {
  final lower = ' ${text.toLowerCase()} ';
  for (final p in phrases) {
    if (RegExp(r'[a-z]').hasMatch(p)) {
      if (RegExp('(^|[^a-z])${RegExp.escape(p)}([^a-z]|\$)').hasMatch(lower)) return true;
    } else if (lower.contains(p)) {
      return true;
    }
  }
  return false;
}

/// Removes the first matching phrase from [text].
String removeAny(String text, Iterable<String> phrases) {
  var out = text;
  for (final p in phrases) {
    if (RegExp(r'[a-z]').hasMatch(p)) {
      out = out.replaceAll(RegExp('(^|(?<=[^a-zA-Z]))${RegExp.escape(p)}(?=[^a-zA-Z]|\$)', caseSensitive: false), ' ');
    } else {
      out = out.replaceAll(p, ' ');
    }
  }
  return out.replaceAll(RegExp(r'\s+'), ' ').trim();
}
