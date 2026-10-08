import 'lang_util.dart';
import 'time_parser.dart';

/// Something the assistant should do in the app.
enum IntentType {
  reminder,
  task,
  water,
  mood,
  expense,
  income,
  habitDone,
  medicineTaken,
  journal,
  rememberFact,
  style,
  askToday,
  askSteps,
  askSpending,
  askMemory,
  greeting,
  smallTalk,
  thanks,
  help,
  unknown,
}

class ChatIntent {
  final IntentType type;
  final Map<String, dynamic> params;

  const ChatIntent(this.type, [this.params = const {}]);

  @override
  String toString() => '$type $params';
}

// Trigger phrases per intent (English, Roman Urdu, Urdu, Pashto).
const _reminder = [  'yaad ra kra', 'yad ra kra', 'rata yaad kra', 'rata yad kra', 'ma ta yaad kra', 'mata yaad kra', 'yaad me kra', 'yaad rakra', 'yaad kra', 'yaadawana',

  'remind me', 'reminder', "don't let me forget", 'dont let me forget', 'set an alarm', 'alarm',
  'yaad dilana', 'yaad dila', 'yad dilana', 'yaad karwana', 'yaad dila dena', 'reminder lagao',
  'یاد دلانا', 'یاد دلا', 'یاد دہانی', 'یاد کروانا',
  'را یاد کړه', 'راته یاد کړه', 'یاد راکړه', 'یادونه', 'یاد مې کړه',
];
const _task = [  'kaar zyat kra', 'kar zyat kra', 'naway kaar', 'nawe kaar', 'kaar olika', 'kaar wlika', 'bayad wakram', 'bayad okram',

  'add a task', 'add task', 'new task', 'to do', 'todo', 'i need to', 'i have to', 'i must', 'put on my list',
  'task add', 'kaam add', 'task likho', 'mujhe karna hai', 'karna hai',
  'کام شامل', 'نیا کام', 'مجھے کرنا ہے', 'کرنا ہے',
  'کار ور زیات کړه', 'نوی کار', 'کار اضافه', 'باید وکړم', 'کار ولیکه',
];
const _journal = [  'diary ke wlika', 'daire ke wlika', 'wlika', 'olika', 'yaad dasht',

  'note that', 'write down', 'write in my journal', 'journal', 'dear diary', 'save this', 'note down',
  'diary mein likho', 'likh lo', 'likh do', 'diary',
  'ڈائری', 'لکھ لو', 'لکھ دو', 'نوٹ کر',
  'ډایري', 'ولیکه', 'یادداشت', 'ثبت یې کړه',
];
const _remember = [  'pa yaad sata', 'pa yad sata', 'yaad sata', 'yaad lara', 'pa yaad ye lara',

  'remember that', 'remember', 'keep in mind', 'yaad rakhna', 'yaad rakho',
  'یاد رکھنا', 'یاد رکھو', 'په یاد ولره', 'یاد ساته',
];
const _water = ['oba', 'obe', 'obu', 'gilas', 'gilasa', 'water', 'glass of water', 'glasses', 'paani', 'pani', 'پانی', 'اوبه', 'اوبو', 'ګیلاس'];
const _drank = ['wskal', 'wskale', 'wsklay', 'ochkal', 'chakal', 'me wskal', 'drank', 'had', 'drink', 'drunk', 'piya', 'pi liya', 'pee liya', 'پیا', 'پی لیا', 'وڅښلې', 'وڅښل', 'مې وڅښلې', 'log'];
const _spent = [
  'lagawal', 'olagawal', 'olagawale', 'wlagawal', 'warkral', 'rawakhistal', 'wakhistal',

  'spent', 'paid', 'bought', 'cost', 'kharch', 'kharcha', 'kharch kiye', 'diye', 'kharide',
  'خرچ', 'خریدا', 'ادا کیے', 'لګښت', 'ولګول', 'ولګولې', 'واخیست', 'ورکړې',
];
const _income = [
  'got', 'received', 'earned', 'income', 'salary', 'got paid', 'paid me', 'profit', 'bonus',
  'mila', 'mili', 'mile', 'mil gaye', 'aaye', 'tankhwa', 'tankhwah', 'kamaye', 'kamai',
  'rasedal', 'raseda', 'rakral', 'tankha', 'wakhistal me',
  'ملے', 'ملی', 'ملا', 'تنخواہ', 'کمائی', 'راورسېدل', 'ترلاسه', 'معاش',
];
const _money = ['rupai', 'rupaye', 'rupay', 'rs', 'rupees', 'rupay', 'rupaye', 'pkr', 'روپے', 'روپیہ', 'روپۍ', 'روپئ', 'افغانۍ', r'$', 'dollars'];
const _done = [
  'me wakro', 'me okro', 'me wakra', 'me okra', 'khlas sho', 'pura sho', 'wosho', 'wsho',

  'done with', 'finished', 'completed', 'i did', 'did my', 'done',
  'kar liya', 'kar li', 'ho gaya', 'ho gayi', 'mukammal',
  'کر لیا', 'کر لی', 'ہو گیا', 'مکمل',
  'مې وکړ', 'مې وکړه', 'وشو', 'خلاص شو', 'پوره شو',
];
const _took = ['me okhwara', 'me wakhwara', 'wakhwara', 'okhwara', 'took', 'taken', 'take my', 'le li', 'le liya', 'kha li', 'khali', 'لے لی', 'کھا لی', 'وخوړه', 'مې وخوړه', 'واخیسته'];
const _greet = ['staray me she', 'starrey ma she', 'pakhair', 'hi', 'hello', 'hey', 'salam', 'salaam', 'assalam', 'aoa', 'سلام', 'السلام', 'ښه راغلې', 'good morning', 'good evening'];
const _thanks = ['manana', 'dera manana', 'mehrabani', 'thanks', 'thank you', 'thx', 'shukriya', 'meharbani', 'شکریہ', 'مہربانی', 'مننه', 'ډېره مننه'];
const _help = ['tsa kawali shay', 'sa kawali shay', 'sa kawalay she', 'help', 'what can you do', 'kya kar sakte', 'آپ کیا کر سکتے', 'ته څه کولی شې', 'مرسته'];
const _askToday = [
  'nan tsa laram', 'nan sa laram', 'nan sa pate di', 'nan tsa pate', 'zma wraz',

  "what's left", 'whats left', 'what do i have', 'my day', 'today plan', 'what is left',
  'aaj kya hai', 'aaj ka kaam', 'kya baqi', 'آج کیا ہے', 'کیا باقی', 'نن څه لرم', 'نن څه پاتې', 'زما ورځ',
];
const _askSteps = ['gamuna', 'ghamuna', 'steps', 'how much did i walk', 'qadam', 'kadam', 'قدم', 'ګامونه', 'ګام'];
const _askSpend = [
  'somra me lagawal', 'tsomra me lagawal',

  'how much did i spend', 'how much have i spent', 'my spending', 'kitna kharch', 'kitne paise',
  'کتنا خرچ', 'څومره مې ولګول', 'لګښت مې څومره',
];
const _askMemory = ['what do you know about me', 'what do you remember', 'tum kya jante ho', 'آپ کیا جانتے', 'ته زما په اړه څه پوهېږې'];

// Small talk.
const _howAreYou = [
  'how are you', 'how r u', 'how are u', 'hows it going', "how's it going", 'how is it going', 'how you doing',
  'kese ho', 'kaise ho', 'kesay ho', 'kaisay ho', 'kesi ho', 'kaisi ho', 'kya haal', 'kya hal', 'kese hain', 'kaise hain', 'kesy ho',
  'sanga ye', 'tsanga ye', 'singa ye', 'senga ye', 'sanga yei', 'sanga yast', 'sa haal de', 'sa hal de', 'tsa hal de', 'kha ye', 'kha yi', 'jor ye', 'jor yi',
  'کیسے ہو', 'کیسے ہیں', 'کیا حال', 'کیسی ہو', 'څنګه یې', 'څنګه یاست', 'ښه یې', 'جوړ یې', 'څه حال دی',
];
const _imFine = [
  "i'm fine", 'i am fine', "i'm good", 'i am good', "i'm ok", 'i am ok', "i'm great", 'im fine', 'im good', 'im ok', 'i am doing well', "i'm doing well",
  'me thek', 'me theek', 'main theek', 'mai theek', 'main thik', 'me thik', 'mai thek', 'theek hoon', 'thek hoon', 'theek hun', 'thek hun', 'thek ho', 'acha hoon', 'thik hoon',
  'za kha yam', 'za kha yama', 'kha yam', 'kha yama', 'za jor yam', 'jor yam', 'za theek yam', 'za kho yam',
  'میں ٹھیک', 'ٹھیک ہوں', 'زه ښه یم', 'ښه یم', 'جوړ یم',
];
const _whoAreYou = [
  'who are you', 'what is your name', "what's your name", 'whats your name', 'tum kon ho', 'tum kaun ho', 'aap kon', 'aap kaun', 'apka naam', 'tumhara naam',
  'ta tsok ye', 'ta sok ye', 'sta num', 'sta noom', 'sta nom', 'تم کون ہو', 'آپ کون', 'ته څوک یې', 'ستا نوم',
];
const _bye = [
  'bye', 'goodbye', 'see you', 'khuda hafiz', 'allah hafiz', 'alvida', 'pa makha de kha', 'pa makha mo kha', 'khuda pa aman', 'da khuday pa aman',
  'خدا حافظ', 'اللہ حافظ', 'په مخه دې ښه', 'خدای پامان',
];
/// Everyday conversation: kind → phrases (English, Roman Urdu, Roman
/// Pashto, Urdu, Pashto).
const _chat = <String, List<String>>{
  'whatDoing': ['what are you doing', 'what r u doing', 'wyd', 'kya kar rahe ho', 'kia kar rahe ho', 'kya kar rahi ho', 'kya kar rahe hain', 'sa kawe', 'tsa kawe', 'ta sa kawe', 'ta tsa kawe', 'sa kawi', 'کیا کر رہے ہو', 'ته څه کوې', 'څه کوې'],
  'tired': ["i'm tired", 'i am tired', 'so tired', 'exhausted', 'thak gaya', 'thak gayi', 'thaka hua', 'thaki hui', 'thakan', 'za stray yam', 'stray yam', 'staray yam', 'starray yam', 'stary yam', 'stray shwe', 'dera stray', 'ستړی یم', 'ستړې یم', 'تھک گیا', 'تھکا ہوا', 'تھک گئی'],
  'sleepy': ['sleepy', 'need sleep', 'want to sleep', 'neend aa rahi', 'neend aa', 'sona hai', 'khob raghle', 'khob rata raghle', 'khob me raghe', 'oweda kegam', 'نیند آ رہی', 'خوب راځي', 'خوب راغلی'],
  'hungry': ['hungry', 'starving', 'bhook lagi', 'bhuk lagi', 'bhook', 'wagay yam', 'wazgay yam', 'wazhay yam', 'bhook lag rahi', 'بھوک', 'وږی یم'],
  'sick': ['sick', 'not well', 'unwell', 'fever', 'headache', 'head hurts', 'sar dard', 'bukhar', 'tabiyat kharab', 'tabiat kharab', 'bemar', 'naragh yam', 'naroogh yam', 'sar me khuge', 'zma sar khuge', 'sar khuge', 'tabe', 'بخار', 'سر درد', 'بیمار', 'ناروغ یم', 'سر مې خوږېږي'],
  'bored': ['bored', 'boring', 'bore ho', 'bore ho raha', 'bore ho rahi', 'za tang yam', 'tang yam', 'بور ہو', 'ستړی شوم له'],
  'sad': ["i'm sad", 'i am sad', 'feeling sad', 'feeling down', 'udaas', 'pareshan', 'dukhi', 'khafa yam', 'za khafa yam', 'zrah me tang', 'اداس', 'پریشان ہوں', 'خفه یم'],
  'happy': ["i'm happy", 'i am happy', 'so happy', 'feeling great', 'khush hoon', 'bohat khush', 'za khushala yam', 'khushala yam', 'dera khushala', 'خوش ہوں', 'خوشحاله یم'],
  'stressed': ['stressed', 'stress', 'tension', 'anxious', 'worried', 'fikar', 'pareshani', 'fikr', 'tashweesh', 'فکر', 'ٹینشن', 'اندېښنه'],
  'busy': ['busy', 'so much work', 'lots of work', 'bohat kaam', 'bahut kaam', 'kaam zyada', 'masroof', 'dera kaar', 'der kaar', 'bokht', 'مصروف', 'ډېر کار'],
  'seeYou': ['see you', 'see ya', 'talk later', 'kal milte', 'phir milte', 'baad mein baat', 'saba ba sara wogoro', 'biya ba sara wogoro', 'biya ba wogoro', 'پھر ملتے', 'بیا به سره ووینو'],
  'alhamdulillah': ['alhamdulillah', 'alhamdolillah', 'alhumdulillah', 'shukar hai', 'shukr hai', 'الحمدللہ', 'الحمدلله'],
  'joke': ['joke', 'tell me something funny', 'make me laugh', 'latifa', 'lateefa', 'mazaq', 'toki', 'yaw toki', 'لطیفہ', 'ټوکه'],
  'understand': ['i understand', 'got it', 'samajh gaya', 'samajh gayi', 'samajh aa gaya', 'za pohegam', 'poh shwam', 'pohegam', 'سمجھ گیا', 'پوه شوم'],
  'love': ['i love you', 'love you', 'mujhe tum se pyar', 'tum se pyar', 'za tana mena kawam', 'mena dar sara kawam', 'مجھے تم سے پیار', 'زه تا سره مینه لرم'],
};
const _ack = ['ok', 'okay', 'k', 'yes', 'yeah', 'yep', 'sure', 'fine', 'alright', 'cool', 'nice', 'haan', 'han', 'ji', 'jee', 'acha', 'achha', 'theek hai', 'thik hai', 'sahi', 'sha', 'sha sha', 'ho', 'kha', 'kha da', 'sama da', 'ٹھیک ہے', 'اچھا', 'جی', 'هو', 'سمه ده', 'ښه'];
const _ackWords = {'ok', 'okay', 'k', 'acha', 'achha', 'theek', 'thik', 'hai', 'sha', 'haan', 'han', 'ji', 'jee', 'sahi', 'kha', 'da', 'sama', 'ho', 'yes', 'sure', 'fine', 'cool', 'alright', 'yeah'};
const _noWords = {'no', 'nope', 'nah', 'nahi', 'nahin', 'na', 'nishta'};
const _addressWords = {'yara', 'yaara', 'yaar', 'yar', 'bhai', 'bhaijan', 'dost', 'wrora', 'janana', 'jani', 'jaani', 'lala'};
const _no = ['no', 'nope', 'nah', 'not now', 'nahi', 'nahin', 'na', 'nishta', 'ye na', 'نہیں', 'نه', 'نشته'];

const _goodNight = ['good night', 'goodnight', 'shab bakhair', 'shabba khair', 'shpa de pa khair', 'shpa mo pa khair', 'شب بخیر', 'شپه مو پخیر', 'شپه دې پخیر'];

/// A lesson from the user: what their words mean, and optionally how the
/// assistant should answer them.
class TeachLesson {
  final String phrase;
  final String? meaning;
  final String? reply;

  const TeachLesson(this.phrase, {this.meaning, this.reply});

  @override
  bool operator ==(Object other) => other is TeachLesson && other.phrase == phrase && other.meaning == meaning && other.reply == reply;

  @override
  int get hashCode => Object.hash(phrase, meaning, reply);

  @override
  String toString() => 'TeachLesson($phrase, meaning: $meaning, reply: $reply)';
}

final _replyClause = RegExp(
  r"^(.*?)[\s,.;]*(?:\band\b|\baur\b|\bor\b|او)?\s*(?:you should |u should |you have to |please |then )?(?:reply|answer|respond|say back|jawab|jawab do|jawab dena|ځواب)\s*(?:like|with|as|by saying|ke|kay|ki|sa|da|:|-)?\s*(.+)$",
  caseSensitive: false,
);

String _cleanQuote(String? s) => (s ?? '').trim().replaceAll(RegExp('^["\'“”‘’]+|["\'“”‘’.,]+\$'), '').trim();

/// "phrase = meaning", "phrase means meaning", "phrase means X and you
/// should reply like Y", "when I say X reply Y", "X → reply: Y".
TeachLesson? parseTeach(String raw) {
  final text = raw.trim().replaceFirst(RegExp(r'^(teach|learn|sikho|seekho|zda kra|zda ka|sikh lo)\s*[:,-]?\s*', caseSensitive: false), '');

  // "when I say X reply/answer Y" (no meaning).
  final when = RegExp(r"^(?:when i say|if i say|jab main kahun|jab mein kahun|che za wayam|ka za wayam)\s+(.+?)\s*,?\s*(?:you should |then |to )?(?:reply|answer|respond|say|jawab do|jawab|ځواب)\s*(?:with|like|:|ke|sa)?\s*(.+)$", caseSensitive: false).firstMatch(text);
  if (when != null) {
    final p = _cleanQuote(when.group(1)), r = _cleanQuote(when.group(2));
    return p.isEmpty || r.isEmpty ? null : TeachLesson(p, reply: r);
  }

  String? phrase, rest;
  final eq = RegExp(r'^(.+?)\s*(?:=|→|->)\s*(.+)$').firstMatch(text);
  if (eq != null) {
    phrase = eq.group(1);
    rest = eq.group(2);
  } else {
    final m = RegExp(r'^(.+?)\s+(?:means|ka matlab hai|ka matlab|matlab hai|matlab|mana|maana|yani|یعنی|مطلب)\s+(.+)$', caseSensitive: false).firstMatch(text);
    // Only words in another language explained in English.
    if (m != null && detectLang(m.group(1)!) != ChatLang.en) {
      phrase = m.group(1);
      rest = m.group(2);
    }
  }
  if (phrase == null || rest == null) return null;

  String? meaning = rest, reply;
  final rc = _replyClause.firstMatch(rest);
  if (rc != null) {
    meaning = rc.group(1);
    reply = rc.group(2);
    // "reply like za hm kha yama ... means that I am fine": keep only the reply itself.
    reply = reply?.split(RegExp(r'\s+(?:means|which means|yani|matlab|ka matlab)\s+', caseSensitive: false)).first;
  }
  final p = _cleanQuote(phrase), mn = _cleanQuote(meaning), r = _cleanQuote(reply);
  if (p.isEmpty || p.length > 120 || mn.length > 200 || r.length > 300) return null;
  if (mn.isEmpty && r.isEmpty) return null;
  return TeachLesson(p, meaning: mn.isEmpty ? null : mn, reply: r.isEmpty ? null : r);
}

/// Backwards-compatible: (phrase, meaning) for simple lessons.
(String, String)? parseTeachMeaning(String raw) {
  final l = parseTeach(raw);
  return l == null || l.meaning == null ? null : (l.phrase, l.meaning!);
}

const _moods = <String, List<String>>{
  '😄': ['dera khushala', 'der khushala', 'great', 'amazing', 'awesome', 'fantastic', 'excellent', 'bohat khush', 'bahut khush', 'بہت خوش', 'ډېر خوشحاله'],
  '😊': ['khushala', 'khoshala', 'happy', 'good', 'fine', 'khush', 'acha', 'achha', 'theek', 'خوش', 'اچھا', 'خوشحاله', 'ښه'],
  '😐': ['okay', 'ok', 'meh', 'so so', 'normal', 'theek thaak', 'ٹھیک', 'عادي', 'سم'],
  '😔': ['khafa', 'staray', 'stary', 'starray', 'sad', 'tired', 'down', 'stressed', 'upset', 'low', 'udaas', 'pareshan', 'thaka', 'اداس', 'پریشان', 'تھکا', 'خفه', 'ستړی', 'ستړې'],
  '😭': ['dera khafa', 'jaram', 'terrible', 'awful', 'depressed', 'crying', 'very sad', 'bohat udaas', 'بہت اداس', 'ډېر خفه', 'ژاړم'],
};
const _feel = ['za ', 'zma hal', 'i feel', 'i am feeling', "i'm feeling", 'feeling', 'mood', 'i am', "i'm", 'mehsoos', 'محسوس', 'زه', 'احساس'];

const _expenseCategories = <String, List<String>>{
  'food': ['food', 'lunch', 'dinner', 'breakfast', 'groceries', 'khana', 'khaana', 'kھانا', 'کھانا', 'ډوډۍ', 'خوراک', 'سودا', 'sabzi', 'restaurant'],
  'transport': ['bus', 'taxi', 'rickshaw', 'fuel', 'petrol', 'uber', 'careem', 'kiraya', 'کرایہ', 'پٹرول', 'کرایه', 'تیل', 'موټر'],
  'bills': ['bill', 'electricity', 'gas bill', 'internet', 'rent', 'bijli', 'بجلی', 'بل', 'برېښنا', 'کرایه کور'],
  'shopping': ['clothes', 'shoes', 'shopping', 'kapray', 'kapde', 'کپڑے', 'جامې', 'بوټونه'],
  'health': ['medicine', 'doctor', 'hospital', 'dawai', 'dawa', 'دوائی', 'دوا', 'ډاکټر', 'درمل'],
  'education': ['book', 'books', 'fees', 'fee', 'school', 'kitab', 'کتاب', 'فیس', 'ښوونځی'],
  'family': ['family', 'gift', 'ammi', 'abu', 'ghar', 'گھر', 'کور', 'تحفه'],
};

/// Turns one sentence into an intent. [habits] and [medicines] are the
/// user's names, so "done with gym" can find the right habit.
ChatIntent parseIntent(String raw, {List<String> habits = const [], List<String> medicines = const [], DateTime? now}) {
  final text = normalizeDigits(raw);
  final lower = text.toLowerCase();
  final words = tokens(text);
  if (words.isEmpty) return const ChatIntent(IntentType.unknown);

  // Style requests.
  final style = _parseStyle(lower);
  if (style != null) return ChatIntent(IntentType.style, style);

  if (hasAny(lower, _askMemory)) return const ChatIntent(IntentType.askMemory);

  // "remember that ..." (but not "remind me").
  if (hasAny(lower, _remember) && !hasAny(lower, _reminder)) {
    final fact = removeAny(text, _remember).replaceFirst(RegExp(r'^(that|ke|کہ|چې)\s+', caseSensitive: false), '');
    if (fact.length > 2) return ChatIntent(IntentType.rememberFact, {'text': _capitalise(fact)});
  }

  if (hasAny(lower, _reminder)) {
    final t = parseTime(removeAny(text, _reminder), now: now);
    final title = _cleanTitle(t?.rest ?? removeAny(text, _reminder));
    return ChatIntent(IntentType.reminder, {'title': title, 'when': t?.when, 'hasTime': t?.hasTime ?? false});
  }

  if (hasAny(lower, _journal)) {
    final content = removeAny(text, _journal).replaceFirst(RegExp(r'^(that|ke|کہ|چې|in my)\s+', caseSensitive: false), '');
    if (content.length > 2) return ChatIntent(IntentType.journal, {'content': content});
  }

  // Income: a number + "got / received / salary / mila / rasedal".
  final amount = _amount(text);
  if (amount != null && hasAny(lower, _income) && !hasAny(lower, _spent)) {
    final note = _cleanTitle(removeAny(text.replaceAll(RegExp(r'\d+([.,]\d+)?\s*(k\b|hazar|hazaar|ہزار|زره)?', caseSensitive: false), ' '), [..._money, 'i', 'me', 'my', 'ko', 'mujhe', 'rata', 'ma ta', 'aaj', 'today', 'nan']));
    return ChatIntent(IntentType.income, {'amount': amount, 'note': note});
  }

  // Expense: a number + a spending or money word.
  if (amount != null && (hasAny(lower, _spent) || hasAny(lower, _money))) {
    var category = 'other';
    for (final c in _expenseCategories.entries) {
      if (hasAny(lower, c.value)) {
        category = c.key;
        break;
      }
    }
    final note = _cleanTitle(removeAny(text.replaceAll(RegExp(r'\d+([.,]\d+)?'), ' '), [..._spent, ..._money, 'on', 'for', 'par', 'pe', 'پر', 'په', 'ke liye']));
    return ChatIntent(IntentType.expense, {'amount': amount, 'category': category, 'note': note});
  }

  // Water.
  if (hasAny(lower, _water) && (hasAny(lower, _drank) || words.any((w) => parseNumber(w) != null))) {
    final n = words.map(parseNumber).whereType<int>().where((n) => n > 0 && n <= 12).firstOrNull ?? 1;
    return ChatIntent(IntentType.water, {'glasses': n});
  }

  // Medicine taken.
  if (medicines.isNotEmpty && hasAny(lower, _took)) {
    final med = _findName(lower, medicines);
    if (med != null) return ChatIntent(IntentType.medicineTaken, {'name': med});
  }

  // Habit done.
  if (habits.isNotEmpty && hasAny(lower, _done)) {
    final habit = _findName(lower, habits);
    if (habit != null) return ChatIntent(IntentType.habitDone, {'name': habit});
  }

  // Task (with optional time → reminder).
  if (hasAny(lower, _task)) {
    final t = parseTime(removeAny(text, _task), now: now);
    final title = _cleanTitle(t?.rest ?? removeAny(text, _task));
    if (title.isNotEmpty) return ChatIntent(IntentType.task, {'title': title, 'when': t?.when, 'hasTime': t?.hasTime ?? false});
  }

  // Questions.
  if (hasAny(lower, _askSpend)) return const ChatIntent(IntentType.askSpending);
  if (hasAny(lower, _askToday)) return const ChatIntent(IntentType.askToday);
  if (hasAny(lower, _askSteps) && (lower.contains('?') || lower.contains('؟') || hasAny(lower, ['how many', 'kitne', 'کتنے', 'څومره']))) {
    return const ChatIntent(IntentType.askSteps);
  }

  if (hasAny(lower, _thanks) && words.length <= 4) return const ChatIntent(IntentType.thanks);

  // Small talk ("za kha yam, ta sanga ye?", "me theek hoon, tum kese ho").
  final asked = hasAny(lower, _howAreYou);
  final fine = hasAny(lower, _imFine);
  if (asked || fine) return ChatIntent(IntentType.smallTalk, {'kind': asked && fine ? 'both' : asked ? 'asked' : 'fine'});
  if (hasAny(lower, _whoAreYou)) return const ChatIntent(IntentType.smallTalk, {'kind': 'who'});
  if (hasAny(lower, _goodNight)) return const ChatIntent(IntentType.smallTalk, {'kind': 'night'});
  if (words.length <= 6 && hasAny(lower, _bye)) return const ChatIntent(IntentType.smallTalk, {'kind': 'bye'});
  for (final c in _chat.entries) {
    if (hasAny(lower, c.value)) return ChatIntent(IntentType.smallTalk, {'kind': c.key});
  }
  // A bare "ok" / "acha theek hai" / "sha sha" or "no" / "nahi yaar".
  final core = words.where((w) => !_addressWords.contains(w)).toList();
  if (core.isNotEmpty && core.length <= 3) {
    if (_ack.contains(core.join(' ')) || core.every(_ackWords.contains)) return const ChatIntent(IntentType.smallTalk, {'kind': 'ack'});
    if (_no.contains(core.join(' ')) || core.every((w) => _noWords.contains(w) || w == 'hai' || w == 'de')) {
      return const ChatIntent(IntentType.smallTalk, {'kind': 'no'});
    }
  }

  // Mood.
  if (hasAny(lower, _feel) || words.length <= 3) {
    for (final m in _moods.entries) {
      if (hasAny(lower, m.value)) return ChatIntent(IntentType.mood, {'emoji': m.key});
    }
  }

  if (hasAny(lower, _thanks)) return const ChatIntent(IntentType.thanks);
  if (hasAny(lower, _help)) return const ChatIntent(IntentType.help);
  if (words.length <= 4 && hasAny(lower, _greet)) return const ChatIntent(IntentType.greeting);
  return const ChatIntent(IntentType.unknown);
}

Map<String, dynamic>? _parseStyle(String lower) {
  final call = RegExp(r"(?:call me|mujhe .+ bulao|mera naam|my name is)\s*([a-zA-Z؀-ۿ]+)", caseSensitive: false).firstMatch(lower);
  if (call != null && !lower.contains('remind')) return {'name': _capitalise(call.group(1)!)};
  final ps = RegExp(r'ما ته (\S+) ووایه|زما نوم (\S+) دی').firstMatch(lower);
  if (ps != null) return {'name': ps.group(1) ?? ps.group(2)};
  if (hasAny(lower, ['talk less', 'shorter answers', 'be brief', 'short replies', 'kam bolo', 'mukhtasar', 'لږ خبرې', 'مختصر'])) return {'short': true};
  if (hasAny(lower, ['talk more', 'more detail', 'longer answers', 'zyada batao', 'تفصیل', 'تفصیل سره'])) return {'short': false};
  if (hasAny(lower, ['no emoji', 'stop using emoji', 'without emoji'])) return {'emoji': false};
  if (hasAny(lower, ['use emoji', 'more emoji'])) return {'emoji': true};
  if (hasAny(lower, ['be formal', 'more respectful', 'ادب', 'respect se'])) return {'casual': false};
  if (hasAny(lower, ['be casual', 'be friendly', 'be funny', 'dost ki tarah', 'یار'])) return {'casual': true};
  if (hasAny(lower, ['stop talking', "don't speak", 'mute', 'awaz band', 'آواز بند', 'غږ بند'])) return {'speak': false};
  if (hasAny(lower, ['speak to me', 'talk to me out loud', 'awaz on', 'unmute', 'آواز کھول', 'غږ پرانیزه'])) return {'speak': true};
  return null;
}

double? _amount(String text) {
  final m = RegExp(r'(\d+(?:[.,]\d+)?)\s*(k\b|hazar|hazaar|ہزار|زره)?', caseSensitive: false).firstMatch(text);
  if (m == null) return null;
  var v = double.tryParse(m.group(1)!.replaceAll(',', '')) ?? 0;
  if (m.group(2) != null) v *= 1000;
  return v > 0 ? v : null;
}

String? _findName(String lower, List<String> names) {
  String? best;
  for (final n in names) {
    final nl = n.toLowerCase();
    if (nl.isEmpty) continue;
    if (lower.contains(nl) || tokens(nl).any((w) => w.length > 2 && tokens(lower).contains(w))) {
      if (best == null || nl.length > best.length) best = n;
    }
  }
  return best;
}

const _fillers = [
  'to', 'me', 'please', 'pls', 'that', 'about', 'for', 'ke', 'ki', 'ko', 'mujhe', 'zara', 'plz',
  'che', 'chi', 'rata', 'mata',
  'مجھے', 'کو', 'کہ', 'کے', 'ما', 'ماته', 'راته', 'چې', 'ته',
];

String _cleanTitle(String s) {
  var words = s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  while (words.isNotEmpty && _fillers.contains(words.first.toLowerCase())) {
    words = words.sublist(1);
  }
  while (words.isNotEmpty && _fillers.contains(words.last.toLowerCase())) {
    words = words.sublist(0, words.length - 1);
  }
  return _capitalise(words.join(' ').replaceAll(RegExp(r'^[,.\s]+|[,.\s]+$'), ''));
}

String _capitalise(String s) => s.isEmpty || !RegExp(r'^[a-z]').hasMatch(s) ? s : s[0].toUpperCase() + s.substring(1);
