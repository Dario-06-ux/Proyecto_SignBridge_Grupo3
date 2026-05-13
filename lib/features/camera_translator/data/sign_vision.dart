export 'sign_vision_types.dart';
import 'sign_vision_types.dart';

import 'sign_vision_io.dart' if (dart.library.html) 'sign_vision_web.dart'
    as _platform;

/// Entry point used by the camera UI.
SignVision createSignVision() => _platform.createSignVisionFromPlatform();
