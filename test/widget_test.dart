import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:worksphere/app/di/providers.dart';
import 'package:worksphere/app/app.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late Directory hiveDirectory;
  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('worksphere-test-');
    Hive.init(hiveDirectory.path);
    await Supabase.initialize(
      url: 'https://worksphere-test.supabase.co',
      publishableKey: 'test-publishable-key',
      authOptions: FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: const EmptyLocalStorage(),
        pkceAsyncStorage: _MemoryAuthStorage(),
      ),
    );
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  testWidgets('WorkSphereApp initial render test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectivityStatusProvider.overrideWith(
            (ref) => Stream.value(const [ConnectivityResult.wifi]),
          ),
        ],
        child: const WorkSphereApp(),
      ),
    );
    expect(find.byType(WorkSphereApp), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
  });
}

class _MemoryAuthStorage extends GotrueAsyncStorage {
  final Map<String, String> _items = {};

  @override
  Future<String?> getItem({required String key}) async => _items[key];

  @override
  Future<void> setItem({required String key, required String value}) async {
    _items[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _items.remove(key);
  }
}
