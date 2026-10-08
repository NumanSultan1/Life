import 'package:flutter/material.dart';

/// One daily rule of a challenge ("Train 45 minutes").
class ArcRule {
  final String id;
  final String title;
  final String detail;
  final IconData icon;

  const ArcRule({required this.id, required this.title, this.detail = '', this.icon = Icons.check_circle_outline_rounded});

  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'detail': detail, 'icon': icon.codePoint};

  factory ArcRule.fromMap(Map map) => ArcRule(
        id: map['id'] as String,
        title: map['title'] as String,
        detail: (map['detail'] ?? '') as String,
        icon: ruleIcons.firstWhere((i) => i.codePoint == map['icon'], orElse: () => Icons.check_circle_outline_rounded),
      );

  ArcRule copyWith({String? title, String? detail, IconData? icon}) =>
      ArcRule(id: id, title: title ?? this.title, detail: detail ?? this.detail, icon: icon ?? this.icon);
}

/// Icons a user can pick for rules and challenges (kept const so the
/// icon font isn't tree-shaken away).
const ruleIcons = <IconData>[
  Icons.check_circle_outline_rounded,
  Icons.alarm_rounded,
  Icons.fitness_center_rounded,
  Icons.directions_walk_rounded,
  Icons.directions_run_rounded,
  Icons.water_drop_rounded,
  Icons.no_food_rounded,
  Icons.menu_book_rounded,
  Icons.edit_note_rounded,
  Icons.bedtime_rounded,
  Icons.phone_disabled_rounded,
  Icons.wb_sunny_rounded,
  Icons.shower_rounded,
  Icons.self_improvement_rounded,
  Icons.school_rounded,
  Icons.pool_rounded,
  Icons.camera_alt_rounded,
  Icons.local_bar_rounded,
  Icons.lock_rounded,
  Icons.eco_rounded,
  Icons.ac_unit_rounded,
  Icons.bolt_rounded,
  Icons.emoji_events_rounded,
  Icons.favorite_rounded,
  Icons.smoke_free_rounded,
];

/// Colour themes a custom challenge can use.
const challengePalettes = <List<Color>>[
  [Color(0xFF0B1B4D), Color(0xFF1E4FD8), Color(0xFF7CC4FF)],
  [Color(0xFF7A1F5C), Color(0xFFE0559E), Color(0xFFFFB3D6)],
  [Color(0xFF0E4D3A), Color(0xFF1FA67A), Color(0xFF9BE8C8)],
  [Color(0xFF6B2A00), Color(0xFFE07A1F), Color(0xFFFFD08A)],
  [Color(0xFF2A1458), Color(0xFF7B3AE6), Color(0xFFC9B5F0)],
  [Color(0xFF1A1A1A), Color(0xFF8B0000), Color(0xFFFF6B6B)],
];

/// Photos a custom challenge can use as its background.
const challengePhotos = <String>[
  'assets/arcs/winter/snow.jpg',
  'assets/arcs/summer/sprint.jpg',
  'assets/arcs/spring/blossom.jpg',
  'assets/arcs/lockin/leaves.jpg',
  'assets/arcs/hard/dumbbell.jpg',
  'assets/arcs/soft/run.jpg',
  'assets/arcs/winter/ropes.jpg',
  'assets/arcs/lockin/study.jpg',
  'assets/arcs/spring/park.jpg',
  'assets/arcs/hard/ropes.jpg',
];

enum ChallengeKind { seasonal, anytime, custom }

/// A challenge: seasonal arcs repeat every year between fixed dates;
/// anytime and custom challenges run for [days] from whenever you start.
class ArcDefinition {
  final String id;
  final String name;
  final String tagline;
  final String summary;
  final ChallengeKind kind;
  final int startMonth, startDay, endMonth, endDay; // seasonal only
  final int? days; // anytime/custom length
  final bool strict;
  final List<Color> colors;
  final IconData icon;
  final String background;
  final List<String> stills;
  final List<int> reel; // Mixkit clip ids, downloaded on first play
  final List<String> reelLines;
  final List<String> motivation;
  final List<ArcRule> rules;

  const ArcDefinition({
    required this.id,
    required this.name,
    required this.tagline,
    this.summary = '',
    this.kind = ChallengeKind.seasonal,
    this.startMonth = 1,
    this.startDay = 1,
    this.endMonth = 1,
    this.endDay = 1,
    this.days,
    this.strict = true,
    required this.colors,
    required this.icon,
    required this.background,
    this.stills = const [],
    this.reel = const [],
    this.reelLines = const [],
    this.motivation = const [],
    required this.rules,
  });

  bool get seasonal => kind == ChallengeKind.seasonal;

  /// This year's (or the next) season window around [now].
  DateTimeRange seasonFor(DateTime now) {
    var start = DateTime(now.year, startMonth, startDay);
    var end = DateTime(now.year, endMonth, endDay);
    if (end.isBefore(DateTime(now.year, now.month, now.day))) {
      start = DateTime(now.year + 1, startMonth, startDay);
      end = DateTime(now.year + 1, endMonth, endDay);
    }
    return DateTimeRange(start: start, end: end);
  }

  int get lengthDays => days ?? DateTime(2025, endMonth, endDay).difference(DateTime(2025, startMonth, startDay)).inDays + 1;

  bool inSeason(DateTime now) {
    if (!seasonal) return false;
    final s = seasonFor(now);
    final d = DateTime(now.year, now.month, now.day);
    return !d.isBefore(s.start) && !d.isAfter(s.end);
  }

  // --- Custom challenges are stored as maps ---

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'tagline': tagline,
        'days': days,
        'strict': strict,
        'palette': challengePalettes.indexWhere((p) => p.first == colors.first),
        'icon': icon.codePoint,
        'background': background,
        'rules': rules.map((r) => r.toMap()).toList(),
      };

  factory ArcDefinition.fromMap(Map map) {
    final palette = (map['palette'] as int?) ?? 0;
    return ArcDefinition(
      id: map['id'] as String,
      name: map['name'] as String,
      tagline: (map['tagline'] ?? '') as String,
      summary: 'Your own challenge.',
      kind: ChallengeKind.custom,
      days: (map['days'] as int?) ?? 30,
      strict: (map['strict'] as bool?) ?? true,
      colors: challengePalettes[palette.clamp(0, challengePalettes.length - 1)],
      icon: ruleIcons.firstWhere((i) => i.codePoint == map['icon'], orElse: () => Icons.emoji_events_rounded),
      background: (map['background'] as String?) ?? challengePhotos.first,
      reelLines: ['${map['name']}.', '${map['days'] ?? 30} days.', 'Your rules.', 'No excuses.'],
      motivation: const [
        'You made the rules. Now keep them.',
        'Discipline is remembering what you want.',
        'Small promises kept make big people.',
        'One more day. Then one more.',
        'Your future self is counting on today.',
      ],
      rules: ((map['rules'] as List?) ?? const []).map((r) => ArcRule.fromMap(r as Map)).toList(),
    );
  }
}

/// Built-in challenges. Seasonal rules follow the common "arc" format
/// (about 90 days, a handful of daily non-negotiables across movement,
/// nutrition, mind and lifestyle). 75 Hard/Soft follow their published
/// rules. All are strict: miss one rule and you start again at Day 1.
const arcDefinitions = <ArcDefinition>[
  ArcDefinition(
    id: 'winter',
    name: 'Winter Arc',
    tagline: 'While others hibernate, you build.',
    summary: 'Oct–Dec · train, eat clean, read and sleep well through the dark months.',
    startMonth: 10,
    startDay: 1,
    endMonth: 12,
    endDay: 31,
    colors: [Color(0xFF0B1B4D), Color(0xFF1E4FD8), Color(0xFF7CC4FF)],
    icon: Icons.ac_unit_rounded,
    background: 'assets/arcs/winter/snow.jpg',
    stills: ['assets/arcs/winter/ropes.jpg', 'assets/arcs/winter/boxer.jpg'],
    reel: [45874, 52317, 3352],
    reelLines: ['The days get shorter.', 'The excuses get longer.', 'Not this year.', '92 days. No days off.', 'This is your Winter Arc.'],
    motivation: [
      'Discipline is choosing what you want most over what you want now.',
      'Cold mornings build warm results.',
      'Nobody is coming to do it for you. Get up.',
      'Silent work. Loud results.',
      'Winter does not care how you feel. Show up anyway.',
      'Become the person you said you would be in January, before January.',
      'Every rep in the dark counts in the light.',
      'Comfort is the enemy of the arc.',
    ],
    rules: [
      ArcRule(id: 'w_wake', title: 'Wake up by 6:30 AM', detail: 'No snooze. Feet on the floor.', icon: Icons.alarm_rounded),
      ArcRule(id: 'w_nophone', title: 'No phone for the first 30 minutes', detail: 'Start the day on your terms.', icon: Icons.phone_disabled_rounded),
      ArcRule(id: 'w_train', title: 'Train for 45 minutes', detail: 'Gym, run or home workout.', icon: Icons.fitness_center_rounded),
      ArcRule(id: 'w_steps', title: 'Walk 10,000 steps', detail: 'Ticked automatically when your step count gets there.', icon: Icons.directions_walk_rounded),
      ArcRule(id: 'w_water', title: 'Drink 3 litres of water', detail: 'Log it in the water tracker.', icon: Icons.water_drop_rounded),
      ArcRule(id: 'w_food', title: 'No junk food, sugar or energy drinks', detail: 'Eat real food.', icon: Icons.no_food_rounded),
      ArcRule(id: 'w_read', title: 'Read 10 pages', detail: 'Non-fiction or anything that grows you.', icon: Icons.menu_book_rounded),
      ArcRule(id: 'w_journal', title: 'Journal for 5 minutes', detail: 'Write in the Journal tab.', icon: Icons.edit_note_rounded),
      ArcRule(id: 'w_sleep', title: 'In bed by 11 PM, no screens', detail: 'Recovery is part of the arc.', icon: Icons.bedtime_rounded),
    ],
  ),
  ArcDefinition(
    id: 'spring',
    name: 'Spring Reset',
    tagline: 'Fresh start. Clean slate. New you.',
    summary: 'Mar–May · declutter, move outside, eat fresh and build new routines.',
    startMonth: 3,
    startDay: 1,
    endMonth: 5,
    endDay: 31,
    colors: [Color(0xFF0E4D3A), Color(0xFF1FA67A), Color(0xFFFFB3D6)],
    icon: Icons.eco_rounded,
    background: 'assets/arcs/spring/blossom.jpg',
    stills: ['assets/arcs/spring/park.jpg', 'assets/arcs/spring/warmup.jpg'],
    reel: [722, 583, 44970],
    reelLines: ['Everything is growing again.', 'So are you.', 'Reset your body.', 'Reset your mind.', 'This is your Spring Reset.'],
    motivation: [
      'Spring is proof that starting again is possible.',
      'Clear the clutter, clear the mind.',
      'New season, new standards.',
      'Grow at your own pace, but grow every day.',
      'Fresh air is free therapy.',
      'Plant the habits now; enjoy the harvest in summer.',
    ],
    rules: [
      ArcRule(id: 'p_outside', title: 'Move outside for 30 minutes', detail: 'Walk, run or ride in the fresh air.', icon: Icons.directions_run_rounded),
      ArcRule(id: 'p_steps', title: 'Walk 10,000 steps', detail: 'Ticked automatically when your step count gets there.', icon: Icons.directions_walk_rounded),
      ArcRule(id: 'p_declutter', title: 'Declutter one thing', detail: 'A drawer, a shelf, an inbox.', icon: Icons.check_circle_outline_rounded),
      ArcRule(id: 'p_fresh', title: 'Eat 5 portions of fruit and veg', detail: 'Fresh and in season.', icon: Icons.eco_rounded),
      ArcRule(id: 'p_water', title: 'Drink 2.5 litres of water', icon: Icons.water_drop_rounded),
      ArcRule(id: 'p_stretch', title: 'Stretch or do yoga for 10 minutes', icon: Icons.self_improvement_rounded),
      ArcRule(id: 'p_plan', title: 'Plan tomorrow tonight', detail: 'Add tomorrow\'s tasks in Plan.', icon: Icons.edit_note_rounded),
    ],
  ),
  ArcDefinition(
    id: 'summer',
    name: 'Summer Arc',
    tagline: 'Summer Shred: long days, big energy, bigger results.',
    summary: 'Jun–Aug · early starts, outdoor training, clean eating and cold showers.',
    startMonth: 6,
    startDay: 1,
    endMonth: 8,
    endDay: 31,
    colors: [Color(0xFF8A2E0E), Color(0xFFFF7A59), Color(0xFFFFE29A)],
    icon: Icons.wb_sunny_rounded,
    background: 'assets/arcs/summer/sprint.jpg',
    stills: ['assets/arcs/summer/track.jpg', 'assets/arcs/summer/sunset.jpg'],
    reel: [32809, 32813, 4851],
    reelLines: ['The sun is up early.', 'So are you.', 'Train while the world sleeps in.', '92 days of your best summer.', 'This is your Summer Arc.'],
    motivation: [
      'Summer bodies are built in the heat of commitment.',
      'Use the long days. They will not last.',
      'Sweat now, shine later.',
      'Rise with the sun and race the day.',
      'Hot days, cold showers, clear mind.',
      'Finish the summer stronger than you started it.',
    ],
    rules: [
      ArcRule(id: 's_wake', title: 'Up with the sun: wake by 6:00 AM', detail: 'Beat the heat and the crowd.', icon: Icons.wb_sunny_rounded),
      ArcRule(id: 's_train', title: '45-minute workout, outdoors if you can', detail: 'Run, swim, ride or lift.', icon: Icons.directions_run_rounded),
      ArcRule(id: 's_steps', title: 'Walk 10,000 steps', detail: 'Ticked automatically when your step count gets there.', icon: Icons.directions_walk_rounded),
      ArcRule(id: 's_water', title: 'Drink 3.5 litres of water', detail: 'Hot days need more.', icon: Icons.water_drop_rounded),
      ArcRule(id: 's_food', title: 'Eat clean: no fried food, sugar or soda', detail: 'Fruit, protein, vegetables.', icon: Icons.no_food_rounded),
      ArcRule(id: 's_social', title: 'No social media before noon', detail: 'Mornings are for you.', icon: Icons.phone_disabled_rounded),
      ArcRule(id: 's_cold', title: 'Cold shower or a swim', detail: 'Reset your body and mind.', icon: Icons.shower_rounded),
    ],
  ),
  ArcDefinition(
    id: 'lockin',
    name: 'The Great Lock In',
    tagline: 'Autumn Ramp: lock in before the year ends.',
    summary: 'Sep–Nov · deep work, study, training and zero distractions.',
    startMonth: 9,
    startDay: 1,
    endMonth: 11,
    endDay: 30,
    colors: [Color(0xFF3A1A06), Color(0xFFC0561B), Color(0xFFFFC27A)],
    icon: Icons.lock_rounded,
    background: 'assets/arcs/lockin/leaves.jpg',
    stills: ['assets/arcs/lockin/study.jpg', 'assets/arcs/lockin/pushups.jpg'],
    reel: [33237, 4761, 40248],
    reelLines: ['The leaves are falling.', 'Your focus isn\'t.', 'Lock in.', 'Finish the year strong.', 'This is The Great Lock In.'],
    motivation: [
      'Lock in now so you can celebrate later.',
      'Focus is a superpower in a distracted world.',
      'The ramp starts today. Every day a little steeper.',
      'Deep work beats busy work.',
      'Quiet phone, loud progress.',
      'Finish what you started this year.',
    ],
    rules: [
      ArcRule(id: 'l_deep', title: '2 hours of deep work or study', detail: 'Phone in another room.', icon: Icons.school_rounded),
      ArcRule(id: 'l_train', title: 'Train for 45 minutes', icon: Icons.fitness_center_rounded),
      ArcRule(id: 'l_steps', title: 'Walk 10,000 steps', detail: 'Ticked automatically when your step count gets there.', icon: Icons.directions_walk_rounded),
      ArcRule(id: 'l_screen', title: 'Under 1 hour of social media', detail: 'Use App time limits in Profile.', icon: Icons.phone_disabled_rounded),
      ArcRule(id: 'l_read', title: 'Read 10 pages', icon: Icons.menu_book_rounded),
      ArcRule(id: 'l_plan', title: 'Plan tomorrow tonight', icon: Icons.edit_note_rounded),
      ArcRule(id: 'l_sleep', title: '7+ hours of sleep', icon: Icons.bedtime_rounded),
    ],
  ),
  ArcDefinition(
    id: 'hard75',
    name: '75 Hard',
    tagline: 'No compromises. No substitutions.',
    summary: 'Anytime · 75 days · two workouts, strict diet, a gallon of water, reading and a progress photo, every single day.',
    kind: ChallengeKind.anytime,
    days: 75,
    colors: [Color(0xFF111111), Color(0xFF8B0000), Color(0xFFFF6B6B)],
    icon: Icons.bolt_rounded,
    background: 'assets/arcs/hard/dumbbell.jpg',
    stills: ['assets/arcs/hard/ropes.jpg', 'assets/arcs/hard/rope.jpg'],
    reel: [52079, 40788, 23056],
    reelLines: ['75 days.', 'Two workouts a day.', 'No cheat meals. No smoking.', 'Miss one thing, start over.', 'This is 75 Hard.'],
    motivation: [
      'Hard is the point.',
      'You are tougher than your excuses.',
      'Day 1 or one day. You decide.',
      'Mental toughness is built one rule at a time.',
      'Do it when you don\'t feel like it. That\'s the whole game.',
      'Comfort is a slow death. Choose hard.',
    ],
    rules: [
      ArcRule(id: 'h_work1', title: 'Workout 1: 45 minutes', icon: Icons.fitness_center_rounded),
      ArcRule(id: 'h_work2', title: 'Workout 2: 45 minutes, outdoors', detail: 'Rain or shine.', icon: Icons.directions_run_rounded),
      ArcRule(id: 'h_diet', title: 'Follow your diet, no cheat meals', icon: Icons.no_food_rounded),
      ArcRule(id: 'h_alcohol', title: 'No smoking', detail: 'No cigarettes, vapes, naswar or shisha.', icon: Icons.smoke_free_rounded),
      ArcRule(id: 'h_water', title: 'Drink a gallon (3.8 L) of water', icon: Icons.water_drop_rounded),
      ArcRule(id: 'h_read', title: 'Read 10 pages of non-fiction', icon: Icons.menu_book_rounded),
      ArcRule(id: 'h_photo', title: 'Take a progress photo', icon: Icons.camera_alt_rounded),
    ],
  ),
  ArcDefinition(
    id: 'soft75',
    name: '75 Soft',
    tagline: 'Consistent, not crushing.',
    summary: 'Anytime · 75 days · one workout (one rest day a week), eat well, 3 L of water and 10 pages.',
    kind: ChallengeKind.anytime,
    days: 75,
    colors: [Color(0xFF14325C), Color(0xFF3F8CFF), Color(0xFFA8D4FF)],
    icon: Icons.favorite_rounded,
    background: 'assets/arcs/soft/run.jpg',
    stills: ['assets/arcs/soft/stretch.jpg', 'assets/arcs/soft/bridge.jpg'],
    reel: [7587, 780, 40766],
    reelLines: ['75 days.', 'Move every day.', 'Eat well. Drink water. Read.', 'Kind to yourself, hard on excuses.', 'This is 75 Soft.'],
    motivation: [
      'Consistency beats intensity.',
      'Gentle, but every day.',
      'Progress you can keep is progress that lasts.',
      'Rest is part of the plan, quitting isn\'t.',
      'Small steps, 75 times, change everything.',
    ],
    rules: [
      ArcRule(id: 'o_move', title: '45 minutes of exercise', detail: 'Active recovery (walk, yoga) counts one day a week.', icon: Icons.directions_run_rounded),
      ArcRule(id: 'o_eat', title: 'Eat well and cut down on smoking', icon: Icons.smoke_free_rounded),
      ArcRule(id: 'o_water', title: 'Drink 3 litres of water', icon: Icons.water_drop_rounded),
      ArcRule(id: 'o_read', title: 'Read 10 pages', icon: Icons.menu_book_rounded),
    ],
  ),
];
