import 'package:flutter/widgets.dart';

import '../config/firebase_config.dart';
import '../models/drop.dart';
import '../services/auth_service.dart';
import '../services/drop_service.dart';

/// Makes the app services available to the widget tree.
class ServicesScope extends InheritedWidget {
  const ServicesScope({
    super.key,
    required this.config,
    required this.auth,
    required this.drops,
    required super.child,
  });

  final FirebaseConfig config;
  final AuthService auth;
  final DropService drops;

  static ServicesScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ServicesScope>();
    assert(scope != null, 'ServicesScope not found in context');
    return scope!;
  }

  /// Shareable link for [drop], or null when no web URL is known.
  ///
  /// Links go to `/s` (served by `web/share.html`), which gives messengers a
  /// "Someone sent you a burner" preview and then forwards to the app.
  /// Private drops use `?code=`, public ones `?p=<token>`.
  String? linkFor(Drop drop) {
    final query = {drop.isPublic ? 'p' : 'code': drop.code};
    final base = config.webUrl.trim();
    if (base.isNotEmpty) {
      final uri = Uri.parse(base);
      return uri
          .replace(path: _sharePath(uri.path), queryParameters: query)
          .toString();
    }
    final here = Uri.base;
    if (here.scheme == 'http' || here.scheme == 'https') {
      return Uri(
        scheme: here.scheme,
        host: here.host,
        port: here.hasPort ? here.port : null,
        path: _sharePath(here.path),
        queryParameters: query,
      ).toString();
    }
    return null;
  }

  /// `/` -> `/s`, `/app/` -> `/app/s`, `/s` -> `/s` (already on the share page).
  static String _sharePath(String basePath) {
    var dir = basePath;
    if (dir.endsWith('/s') || dir.endsWith('/share.html')) {
      dir = dir.substring(0, dir.lastIndexOf('/') + 1);
    }
    if (!dir.endsWith('/')) dir = '$dir/';
    return '${dir}s';
  }

  @override
  bool updateShouldNotify(ServicesScope oldWidget) =>
      config != oldWidget.config ||
      auth != oldWidget.auth ||
      drops != oldWidget.drops;
}
