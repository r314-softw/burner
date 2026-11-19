import 'package:burner/config/firebase_config.dart';
import 'package:burner/models/drop.dart';
import 'package:burner/services/auth_service.dart';
import 'package:burner/services/drop_service.dart';
import 'package:burner/services/firestore_client.dart';
import 'package:burner/services/storage_client.dart';
import 'package:burner/ui/services_scope.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

ServicesScope scope(String webUrl) {
  final config = FirebaseConfig(
      apiKey: 'k', projectId: 'p', storageBucket: 'b', webUrl: webUrl);
  final auth = AuthService(config);
  return ServicesScope(
    config: config,
    auth: auth,
    drops: DropService(
      auth: auth,
      firestore: FirestoreClient(config, auth.idToken),
      storage: StorageClient(config, auth.idToken),
      publicFirestore: FirestoreClient.anonymous(config),
      publicStorage: StorageClient.anonymous(config),
    ),
    child: const SizedBox(),
  );
}

Drop drop(String code, {bool isPublic = false}) => Drop(
      code: code,
      ownerUid: 'u',
      text: 'x',
      files: const [],
      createdAt: DateTime(2026),
      expiresAt: DateTime(2026, 1, 2),
      burnAfterRead: isPublic,
      isPublic: isPublic,
    );

void main() {
  test('share links go to the /s preview page', () {
    expect(scope('https://b.web.app').linkFor(drop('ABC234')),
        'https://b.web.app/s?code=ABC234');
    expect(scope('https://b.web.app/').linkFor(drop('a' * 24, isPublic: true)),
        'https://b.web.app/s?p=${'a' * 24}');
  });

  test('share links respect a sub-path', () {
    expect(scope('https://x.dev/burner/').linkFor(drop('ABC234')),
        'https://x.dev/burner/s?code=ABC234');
    expect(scope('https://x.dev/burner').linkFor(drop('ABC234')),
        'https://x.dev/burner/s?code=ABC234');
  });
}
