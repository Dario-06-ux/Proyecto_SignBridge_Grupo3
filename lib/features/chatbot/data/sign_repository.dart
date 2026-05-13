/// Result of looking up a phrase in the local sign dictionary.
enum SignLookupKind { match, noMatch }

class SignLookupResult {
  const SignLookupResult._({
    required this.kind,
    required this.normalizedPhrase,
    this.assetPath,
  });

  const SignLookupResult.match({
    required String normalizedPhrase,
    required String assetPath,
  }) : this._(
          kind: SignLookupKind.match,
          normalizedPhrase: normalizedPhrase,
          assetPath: assetPath,
        );

  const SignLookupResult.noMatch({required String normalizedPhrase})
      : this._(
          kind: SignLookupKind.noMatch,
          normalizedPhrase: normalizedPhrase,
          assetPath: null,
        );

  final SignLookupKind kind;
  final String normalizedPhrase;
  final String? assetPath;

  bool get isMatch => kind == SignLookupKind.match;
}

/// Maps written phrases to GIF asset paths. Extend [_entries] or load from JSON later.
class SignRepository {
  SignRepository();

  /// Single `assets/` prefix for [Image.asset] / bundle loads (avoids `assets/assets/...`).
  static String normalizeBundleAssetPath(String path) {
    const prefix = 'assets/';
    var out = path.trim();
    while (out.startsWith('$prefix$prefix')) {
      out = out.substring(prefix.length);
    }
    return out;
  }

  static const List<String> knownPhrases = ['hola', 'gracias', 'por favor', 'ayuda'];

  static const Map<String, String> _entries = {
    'hola': 'assets/gifs/hola.gif',
    'gracias': 'assets/gifs/gracias.gif',
    'por favor': 'assets/gifs/por_favor.gif',
    'ayuda': 'assets/gifs/ayuda.gif',
  };

  SignLookupResult lookup(String phrase) {
    final key = phrase.toLowerCase().trim();
    final path = _entries[key];
    if (path != null) {
      return SignLookupResult.match(normalizedPhrase: key, assetPath: path);
    }
    return SignLookupResult.noMatch(normalizedPhrase: key.isEmpty ? phrase.trim() : key);
  }
}
