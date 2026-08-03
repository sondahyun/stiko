import 'package:flutter/foundation.dart';

/// True on desktop platforms (macOS, Windows, Linux), where the sticky window
/// chrome and always-on-top behavior apply.
bool get isDesktop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux);
