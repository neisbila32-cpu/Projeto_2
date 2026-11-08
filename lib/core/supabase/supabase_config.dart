import 'dart:convert';

class SupabaseConfig {
  const SupabaseConfig({required this.url, required this.publishableKey});

  factory SupabaseConfig.fromEnvironment({
    String? url,
    String? publishableKey,
  }) {
    return SupabaseConfig(
      url: url ?? const String.fromEnvironment('SUPABASE_URL'),
      publishableKey:
          publishableKey ??
          const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
    );
  }

  final String url;
  final String publishableKey;

  String get normalizedUrl => url.trim().replaceFirst(RegExp(r'/+$'), '');
  String get normalizedPublishableKey => publishableKey.trim();

  bool get hasAnyValue =>
      url.trim().isNotEmpty || publishableKey.trim().isNotEmpty;

  String? get validationError {
    if (!hasAnyValue) return null;
    if (normalizedUrl.isEmpty || normalizedPublishableKey.isEmpty) {
      return 'Informe a URL e a chave publicável do Supabase.';
    }

    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null ||
        !uri.isAbsolute ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      return 'A URL do Supabase não é válida.';
    }

    final isLocalHost = const {
      'localhost',
      '127.0.0.1',
      '::1',
      '10.0.2.2',
    }.contains(uri.host.toLowerCase());
    if (uri.scheme != 'https' && !(uri.scheme == 'http' && isLocalHost)) {
      return 'Use HTTPS. HTTP é permitido somente para o Supabase local.';
    }

    if (!_isPublicKey(normalizedPublishableKey)) {
      return 'Use uma chave publicável Supabase; chaves secretas não são aceitas no aplicativo.';
    }

    return null;
  }

  bool _isPublicKey(String key) {
    if (key.startsWith('sb_secret_') ||
        key.toLowerCase().contains('service_role')) {
      return false;
    }
    if (key.startsWith('sb_publishable_')) {
      return key.length > 'sb_publishable_'.length;
    }

    // Compatibilidade com chaves anon JWT legadas: só aceita papel anon.
    final partes = key.split('.');
    if (partes.length != 3) return false;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(partes[1]))),
      );
      return payload is Map<String, dynamic> && payload['role'] == 'anon';
    } on FormatException {
      return false;
    }
  }
}
