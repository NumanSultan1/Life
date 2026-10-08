import 'package:flutter_test/flutter_test.dart';
import 'package:vortextech_appdev_week4/assistant/intent_parser.dart';
import 'package:vortextech_appdev_week4/assistant/lang_util.dart';
import 'package:vortextech_appdev_week4/assistant/time_parser.dart';

// Thursday 8 Oct 2026, 10:00.
final now = DateTime(2026, 10, 8, 10, 0);
const habits = ['Gym', 'Read 10 pages', 'Namaz'];
const meds = ['Panadol', 'Vitamin D'];

ChatIntent p(String s) => parseIntent(s, habits: habits, medicines: meds, now: now);

void main() {
  group('reminders', () {
    final cases = <String, (String, DateTime)>{
      'Remind me to call Abu tomorrow at 6': ('Call Abu', DateTime(2026, 10, 9, 18)),
      'remind me to take medicine at 9 pm': ('Take medicine', DateTime(2026, 10, 8, 21)),
      'remind me to pray in 20 minutes': ('Pray', DateTime(2026, 10, 8, 10, 20)),
      'kal subah 7 baje yaad dilana gym jana hai': ('Gym jana hai', DateTime(2026, 10, 9, 7)),
      'mujhe shaam 5 baje yaad dilana ammi ko call karna': ('Ammi ko call karna', DateTime(2026, 10, 8, 17)),
      'کل شام چھ بجے یاد دلانا دوائی لینی ہے': ('دوائی لینی ہے', DateTime(2026, 10, 9, 18)),
      'سبا سهار اته بجې را یاد کړه چې ښوونځي ته لاړ شم': ('ښوونځي ته لاړ شم', DateTime(2026, 10, 9, 8)),
      'ماښام ۷ بجې راته یاد کړه مور ته زنګ ووهم': ('مور ته زنګ ووهم', DateTime(2026, 10, 8, 19)),
    };
    cases.forEach((input, expected) {
      test(input, () {
        final i = p(input);
        expect(i.type, IntentType.reminder);
        expect(i.params['when'], expected.$2);
        expect(i.params['title'], expected.$1);
      });
    });

    test('a reminder without a time asks for one', () {
      final i = p('remind me to buy bread');
      expect(i.type, IntentType.reminder);
      expect(i.params['hasTime'], isFalse);
      expect(i.params['title'], 'Buy bread');
    });
  });

  group('tasks', () {
    test('english', () {
      final i = p('add a task buy milk');
      expect(i.type, IntentType.task);
      expect(i.params['title'], 'Buy milk');
    });
    test('english with time', () {
      final i = p('I need to submit the assignment tomorrow at 10 am');
      expect(i.type, IntentType.task);
      expect(i.params['title'], 'Submit the assignment');
      expect(i.params['when'], DateTime(2026, 10, 9, 10));
    });
    test('pashto', () {
      final i = p('نوی کار کتاب واخلم');
      expect(i.type, IntentType.task);
      expect(i.params['title'], 'کتاب واخلم');
    });
  });

  group('logging', () {
    test('water english', () {
      final i = p('I drank 2 glasses of water');
      expect(i.type, IntentType.water);
      expect(i.params['glasses'], 2);
    });
    test('water roman urdu', () => expect(p('teen glass paani piya').params['glasses'], 3));
    test('water pashto', () {
      final i = p('ما دوه ګیلاسه اوبه وڅښلې');
      expect(i.type, IntentType.water);
      expect(i.params['glasses'], 2);
    });
    test('expense english', () {
      final i = p('I spent 500 on lunch');
      expect(i.type, IntentType.expense);
      expect(i.params['amount'], 500);
      expect(i.params['category'], 'food');
    });
    test('expense roman urdu', () {
      final i = p('rickshaw par 200 rupay kharch kiye');
      expect(i.params['amount'], 200);
      expect(i.params['category'], 'transport');
    });
    test('expense pashto', () {
      final i = p('ما د ډوډۍ لپاره ۳۰۰ روپۍ ولګولې');
      expect(i.type, IntentType.expense);
      expect(i.params['amount'], 300);
      expect(i.params['category'], 'food');
    });
    test('expense in thousands', () => expect(p('paid 2k for the electricity bill').params['amount'], 2000));
    test('habit done', () {
      final i = p('done with gym today');
      expect(i.type, IntentType.habitDone);
      expect(i.params['name'], 'Gym');
    });
    test('habit done roman urdu', () => expect(p('namaz parh li ho gaya').params['name'], 'Namaz'));
    test('medicine taken', () {
      final i = p('I took my panadol');
      expect(i.type, IntentType.medicineTaken);
      expect(i.params['name'], 'Panadol');
    });
    test('mood english', () => expect(p("I'm feeling tired").params['emoji'], '😔'));
    test('feeling pashto (also logged as mood)', () => expect(p('زه نن ډېر خوشحاله یم').params['kind'], 'happy'));
  });

  group('memory and style', () {
    test('remember a fact', () {
      final i = p('remember that Abu is my father');
      expect(i.type, IntentType.rememberFact);
      expect(i.params['text'], 'Abu is my father');
    });
    test('journal note', () {
      final i = p('note that today the cricket match was amazing');
      expect(i.type, IntentType.journal);
      expect(i.params['content'], 'today the cricket match was amazing');
    });
    test('call me', () => expect(p('call me Numan').params['name'], 'Numan'));
    test('talk less', () => expect(p('please talk less').params['short'], isTrue));
  });

  group('questions and chat', () {
    test('today', () => expect(p("what's left for today").type, IntentType.askToday));
    test('today pashto', () => expect(p('نن څه لرم').type, IntentType.askToday));
    test('steps', () => expect(p('how many steps did I walk?').type, IntentType.askSteps));
    test('spending', () => expect(p('how much did I spend this month').type, IntentType.askSpending));
    test('greeting', () => expect(p('salam').type, IntentType.greeting));
    test('thanks pashto', () => expect(p('ډېره مننه').type, IntentType.thanks));
    test('unknown', () => expect(p('the sky looked strange').type, IntentType.unknown));
  });

  group('language', () {
    test('detects', () {
      expect(detectLang('Remind me to call Abu'), ChatLang.en);
      expect(detectLang('mujhe kal yaad dilana'), ChatLang.romanUrdu);
      expect(detectLang('مجھے کل یاد دلانا'), ChatLang.ur);
      expect(detectLang('سبا را یاد کړه'), ChatLang.ps);
    });
  });

  test('times without am/pm', () {
    expect(parseTime('at 4', now: now)!.when, DateTime(2026, 10, 8, 16));
    expect(parseTime('at 9', now: now)!.when, DateTime(2026, 10, 8, 21));
    expect(parseTime('at 11', now: now)!.when, DateTime(2026, 10, 8, 11));
    expect(parseTime('on friday', now: now)!.when.day, 9);
  });

  group('typed in English letters', () {
    test('Roman Pashto and Roman Urdu are told apart', () {
      expect(detectLang('Za kha yama ta sanga ye'), ChatLang.romanPashto);
      expect(detectLang('me thek ho tum kese ho'), ChatLang.romanUrdu);
      expect(detectLang('saba sahar 8 bajy rata yaad kra'), ChatLang.romanPashto);
      expect(detectLang('kal subah 7 baje yaad dilana'), ChatLang.romanUrdu);
      expect(detectLang('I am fine, how are you'), ChatLang.en);
    });
    test('small talk', () {
      expect(p('Za kha yama ta sanga ye').params['kind'], 'both');
      expect(p('me thek ho tum kese ho').params['kind'], 'both');
      expect(p('ta sanga ye').params['kind'], 'asked');
      expect(p('tum kese ho').params['kind'], 'asked');
      expect(p('za kha yam').params['kind'], 'fine');
      expect(p('ta tsok ye').params['kind'], 'who');
      expect(p('pa makha de kha').params['kind'], 'bye');
    });
    test('Roman Pashto reminder', () {
      final i = p('saba sahar 8 bajy rata yaad kra che mor ta zang wawaham');
      expect(i.type, IntentType.reminder);
      expect(i.params['when'], DateTime(2026, 10, 9, 8));
      expect(i.params['title'], 'Mor ta zang wawaham');
    });
    test('Roman Pashto water and spending', () {
      expect(p('ma dwa gilasa oba wskale').params['glasses'], 2);
      final e = p('rickshaw ta 200 rupay me warkral');
      expect(e.type, IntentType.expense);
      expect(e.params['amount'], 200);
    });
  });

  group('teaching meanings', () {
    test('phrase = English meaning', () {
      expect(parseTeachMeaning('kitab rawra = add a task bring the book'), ('kitab rawra', 'add a task bring the book'));
      expect(parseTeachMeaning('teach: za starray yam = I am tired'), ('za starray yam', 'I am tired'));
    });
    test('phrase means / matlab', () {
      expect(parseTeachMeaning('mor ta zang wawaha means call my mother'), ('mor ta zang wawaha', 'call my mother'));
      expect(parseTeachMeaning('chalo chalte hain ka matlab let us go'), ('chalo chalte hain', 'let us go'));
    });
    test('ordinary English with "means" is not a lesson', () {
      expect(parseTeachMeaning('this means a lot to me'), isNull);
    });
  });

  group('lessons with replies', () {
    test('the sentence from the screenshot', () {
      final l = parseTeach('sanga chal de means how are you and you should reply like za hm kha yama ta sanga ye means that I am fine how are you');
      expect(l, const TeachLesson('sanga chal de', meaning: 'how are you', reply: 'za hm kha yama ta sanga ye'));
    });
    test('other ways to teach a reply', () {
      expect(parseTeach('when I say salam yara reply walaikum salam yara'), const TeachLesson('salam yara', reply: 'walaikum salam yara'));
      expect(parseTeach('kya scene hai = what is up, reply: sab set hai'), const TeachLesson('kya scene hai', meaning: 'what is up', reply: 'sab set hai'));
      expect(parseTeach('sanga chal de means how are you'), const TeachLesson('sanga chal de', meaning: 'how are you'));
    });
  });

  group('everyday conversation', () {
    final cases = {
      'ta sa kawe': 'whatDoing', 'kya kar rahe ho': 'whatDoing', 'nan dera stray yam': 'tired', 'zma sar khuge': 'sick', 'mujhe neend aa rahi hai': 'sleepy',
      'mujhe bhook lagi hai': 'hungry', 'aaj bohat kaam tha': 'busy', 'kal milte hain': 'seeYou', 'za pohegam': 'understand', 'yaw toki wawaya': 'joke',
      'acha theek hai': 'ack', 'sha sha': 'ack', 'nahi yaar': 'no', 'alhamdulillah': 'alhamdulillah',
    };
    cases.forEach((input, kind) {
      test(input, () {
        final i = p(input);
        expect(i.type, IntentType.smallTalk);
        expect(i.params['kind'], kind);
      });
    });
    test('"ok thanks" is thanks, not a mood', () => expect(p('ok thanks').type, IntentType.thanks));
    test('short Pashto without English is Roman Pashto', () {
      expect(detectLang('kha da'), ChatLang.romanPashto);
      expect(detectLang('sa kawe'), ChatLang.romanPashto);
    });
  });

  group('income', () {
    test('english', () {
      final i = p('I got 25000 salary today');
      expect(i.type, IntentType.income);
      expect(i.params['amount'], 25000);
    });
    test('roman urdu', () => expect(p('salary mili 50000').type, IntentType.income));
    test('roman pashto', () => expect(p('rata 3000 rupay rasedal').type, IntentType.income));
    test('spending is still spending', () => expect(p('I spent 500 on lunch').type, IntentType.expense));
  });
}
