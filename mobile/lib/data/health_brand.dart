import 'dart:io' show Platform;

import 'package:flutter/painting.dart' show Color;

/// Apple Health's own red/pink and Health Connect's own blue -- shared by
/// every "connect to X" affordance in the app (dashboard card, Settings,
/// onboarding) so all three always agree on the same color/name instead of
/// each hand-rolling its own copy. Deliberately not either platform's
/// actual trademarked badge/icon artwork -- see the callers for why.
const Color kAppleHealthColor = Color(0xFFFC3158);
const Color kHealthConnectColor = Color(0xFF4285F4);

Color healthBrandColor() => Platform.isIOS ? kAppleHealthColor : kHealthConnectColor;

String healthBrandName() => Platform.isIOS ? 'Apple Health' : 'Health Connect';
