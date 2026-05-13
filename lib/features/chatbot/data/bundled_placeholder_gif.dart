import 'dart:convert';
import 'dart:typed_data';

/// 1×1 transparent GIF used when a dictionary asset is missing or not declared in pubspec.
final Uint8List kBundledPlaceholderGifBytes = Uint8List.fromList(
  base64Decode(
    'R0lGODlhAQABAIABAP///wAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==',
  ),
);
