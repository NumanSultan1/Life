import 'package:flutter/foundation.dart';

/// Bumped when something outside a screen changes stored data (e.g. the
/// assistant logs water), so cards that read storage directly refresh.
final lifeDataVersion = ValueNotifier<int>(0);

void notifyLifeDataChanged() => lifeDataVersion.value++;
