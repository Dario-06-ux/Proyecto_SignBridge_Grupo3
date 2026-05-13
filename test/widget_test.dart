import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Importamos nuestro archivo principal
import 'package:detector_senas/main.dart';

void main() {
  testWidgets('SignBridge AI smoke test', (WidgetTester tester) async {
    // 1. Construimos nuestra app. 
    // Al usar Riverpod, es OBLIGATORIO envolver la app en ProviderScope también en los tests.
    await tester.pumpWidget(
      const ProviderScope(
        child: SignBridgeApp(),
      ),
    );

    // 2. Dejamos que la animación inicial termine
    await tester.pumpAndSettle();

    // 3. Verificamos que la interfaz cargó correctamente buscando 
    // las etiquetas de nuestra barra de navegación inferior.
    expect(find.text('Traductor'), findsOneWidget);
    expect(find.text('Chatbot'), findsOneWidget);
  });
}