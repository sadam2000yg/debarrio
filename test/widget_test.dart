import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:d_barrio/main.dart';
import 'package:d_barrio/features/auth/presentation/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      Supabase.instance;
    } catch (_) {
      await Supabase.initialize(
        url: 'https://example.supabase.co',
        publishableKey: 'test-key',
      );
    }
  });

  testWidgets('Carga la aplicación correctamente y muestra login', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
        ],
        child: const DBarrioApp(),
      ),
    );
    expect(find.text("¡Bienvenido a D'BARRIO!"), findsOneWidget);
  });
}
