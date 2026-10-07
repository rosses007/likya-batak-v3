// LIKYA-V2-012 | Main menu visual preview sheets (dev-only).
// Renders real production MainMenuScreen to PNG under artifacts/visual_checks/v2_012/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:batak_app/providers/game_provider.dart';
import 'package:batak_app/providers/store_provider.dart';
import 'package:batak_app/screens/main_menu_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _out = 'artifacts/visual_checks/v2_012';
const double _dpr = 3.0;

class FakeStore extends ChangeNotifier implements StoreProvider {
  @override
  bool isVip = false;
  @override
  bool vipStatusLoaded = true;
  @override
  List<ProductDetails> products = [];
  @override
  void buyVip() {}
  @override
  Future<void> restorePurchases() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _loadFonts() async {
  const root = 'C:/src/bin/cache/artifacts/material_fonts';
  Future<ByteData> bytes(String path) async =>
      ByteData.sublistView(await File(path).readAsBytes());

  final roboto = FontLoader('Roboto');
  for (final f in [
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
    'roboto-black.ttf',
  ]) {
    roboto.addFont(bytes('$root/$f'));
  }
  await roboto.load();

  final icons = FontLoader('MaterialIcons');
  icons.addFont(bytes('$root/materialicons-regular.otf'));
  await icons.load();
}

Widget _wrap(Size size, GlobalKey key, Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData(size: size),
        child: Theme(
          data: ThemeData(
            fontFamily: 'Roboto',
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF14492B)),
          ),
          child: Material(
            child: RepaintBoundary(
              key: key,
              child: SizedBox.fromSize(size: size, child: child),
            ),
          ),
        ),
      ),
    );

Future<void> _shoot(
  WidgetTester tester,
  String name,
  Size size,
) async {
  tester.view.physicalSize = size * _dpr;
  tester.view.devicePixelRatio = _dpr;
  final key = GlobalKey();
  final widget = MultiProvider(
    providers: [
      ChangeNotifierProvider<GameProvider>(create: (_) => GameProvider()),
      ChangeNotifierProvider<StoreProvider>(create: (_) => FakeStore()),
    ],
    child: const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MainMenuScreen(),
    ),
  );

  await tester.pumpWidget(_wrap(size, key, widget));
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: _dpr);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$_out/$name');
    await f.create(recursive: true);
    await f.writeAsBytes(data!.buffer.asUint8List());
  });
  expect(tester.takeException(), isNull);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({'player_name': 'Erkan'});
    await _loadFonts();
  });

  testWidgets('01_main_menu_344.png', (tester) async {
    addTearDown(tester.view.reset);
    await _shoot(tester, '01_main_menu_344.png', const Size(344, 760));
  });

  testWidgets('02_main_menu_390.png', (tester) async {
    addTearDown(tester.view.reset);
    await _shoot(tester, '02_main_menu_390.png', const Size(390, 844));
  });

  testWidgets('03_main_menu_430.png', (tester) async {
    addTearDown(tester.view.reset);
    await _shoot(tester, '03_main_menu_430.png', const Size(430, 932));
  });
}
