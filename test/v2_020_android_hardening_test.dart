import 'dart:io';

import 'package:batak_app/providers/game_provider.dart';
import 'package:batak_app/providers/store_provider.dart';
import 'package:batak_app/screens/game_screen.dart';
import 'package:batak_app/services/api_service.dart';
import 'package:batak_app/services/sound_service.dart';
import 'package:batak_app/services/websocket_service.dart';
import 'package:batak_app/widgets/exposed_dummy_hand.dart';
import 'package:batak_app/widgets/realistic_playing_card.dart';
import 'package:batak_app/widgets/fanned_hand_view.dart';
import 'package:batak_app/widgets/scoreboard_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _VipStore extends ChangeNotifier implements StoreProvider {
  @override
  bool isVip = true;
  @override
  bool vipStatusLoaded = true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('scoreboard fits in landscape at 1.5x text',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final game = GameProvider()..startNewGame();
    addTearDown(game.dispose);
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(844, 390),
          textScaler: TextScaler.linear(1.5),
          padding: EdgeInsets.only(top: 24, bottom: 24),
        ),
        child: Scaffold(
          body: Center(child: ScoreboardWidget(provider: game)),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
  });

  testWidgets('game toolbar and system back each return once', (tester) async {
    SharedPreferences.setMockInitialValues({});
    SoundService.soundEnabled = false;
    final game = GameProvider()..startNewGame();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(game.dispose);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<GameProvider>.value(value: game),
        ChangeNotifierProvider<StoreProvider>(create: (_) => _VipStore()),
      ],
      child: MaterialApp(home: Builder(builder: (context) {
        return Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BatakGameScreen()),
              ),
              child: const Text('Open game'),
            ),
          ),
        );
      })),
    ));

    await tester.tap(find.text('Open game'));
    await tester.pumpAndSettle();
    expect(find.byType(BatakGameScreen), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();
    expect(find.byType(BatakGameScreen), findsNothing);
    expect(await GameSaveService.loadGame(), isNotNull);

    await tester.tap(find.text('Open game'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(BatakGameScreen), findsNothing);
    expect(await GameSaveService.loadGame(), isNotNull);
    expect(tester.takeException(), isNull);
  });

  test('Android manifest blocks cleartext and declares game and round icon', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:usesCleartextTraffic="false"'));
    expect(manifest, contains('android:roundIcon="@mipmap/ic_launcher_round"'));
    expect(manifest, contains('android:appCategory="game"'));
    expect(ApiService.endpoint('/leaderboard').scheme, 'https');
    expect(WebSocketService.endpoint('test').scheme, 'wss');
  });

  test('adaptive, round, and monochrome icon resources exist', () {
    for (final name in ['ic_launcher.xml', 'ic_launcher_round.xml']) {
      final xml = File('android/app/src/main/res/mipmap-anydpi-v26/$name')
          .readAsStringSync();
      expect(xml, contains('<adaptive-icon'));
      expect(xml, contains('@drawable/ic_launcher_monochrome'));
      expect(xml, contains('@drawable/ic_launcher_foreground'));
    }
    for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      expect(
        File('android/app/src/main/res/mipmap-$density/ic_launcher_round.png')
            .existsSync(),
        isTrue,
      );
    }
  });

  final sizes = <Size>[
    const Size(344, 780),
    const Size(390, 844),
    const Size(430, 932),
    const Size(600, 960),
    const Size(800, 1280),
    const Size(844, 390),
    const Size(1280, 800),
  ];
  for (final size in sizes) {
    for (final scale in [1.0, 1.3, 1.5]) {
      testWidgets(
          'game screen at ${size.width.toInt()}x${size.height.toInt()} / $scale',
          (tester) async {
        SharedPreferences.setMockInitialValues({});
        SoundService.soundEnabled = false;
        final game = GameProvider()..startNewGame();
        addTearDown(game.dispose);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<GameProvider>.value(value: game),
            ChangeNotifierProvider<StoreProvider>(create: (_) => _VipStore()),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                padding: const EdgeInsets.only(top: 24, bottom: 24),
              ),
              child: child!,
            ),
            home: const BatakGameScreen(),
          ),
        ));
        await tester.pump();
        expect(find.byType(BatakGameScreen), findsOneWidget);
        if (game.currentPhase == GamePhase.bidding &&
            game.biddingTurnIndex == 0) {
          expect(find.text('PAS').hitTestable(), findsWidgets);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final size in sizes) {
    for (final scale in [1.0, 1.3, 1.5]) {
      testWidgets(
          'real screen PAS, 13/16 cards, human dummy at ${size.width.toInt()}x${size.height.toInt()} / $scale',
          (tester) async {
        SharedPreferences.setMockInitialValues({});
        SoundService.soundEnabled = false;
        final game = GameProvider()..gameMode = BatakGameMode.partner;
        game.startNewGame();
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<GameProvider>.value(value: game),
            ChangeNotifierProvider<StoreProvider>(create: (_) => _VipStore()),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                padding: const EdgeInsets.only(top: 24, bottom: 24),
              ),
              child: child!,
            ),
            home: const BatakGameScreen(),
          ),
        ));
        await tester.pump();
        expect(find.byType(BatakGameScreen), findsOneWidget);
        expect(find.text('PAS').hitTestable(), findsWidgets);
        expect(tester.takeException(), isNull);

        // Switch the same real screen to a human-controlled playing turn.
        game.currentPhase = GamePhase.playing;
        game.bidderIndex = 0;
        game.currentTurnIndex = 0;
        game.notifyListeners();
        await tester.pump();
        final ownHand = find.descendant(
          of: find.byType(FannedHandView),
          matching: find.byType(RealisticPlayingCardWidget),
        );
        final topLayer = find.byWidgetPredicate((widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('top_'));
        final bottomLayer = find.byWidgetPredicate((widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('bottom_'));
        expect(ownHand, findsNWidgets(13));
        expect(topLayer, findsNWidgets(8));
        expect(bottomLayer, findsNWidgets(5));
        expect(find.byType(ExposedDummyHand), findsOneWidget);
        expect(ownHand.last.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);

        // A 16-card hand is a layout stress state, not a dealt game state.
        game.players[0].hand.addAll(game.players[1].hand.take(3).toList());
        game.players[1].hand.removeRange(0, 3);
        game.notifyListeners();
        await tester.pump();
        expect(ownHand, findsNWidgets(16));
        expect(topLayer, findsNWidgets(8));
        expect(bottomLayer, findsNWidgets(8));
        expect(ownHand.last.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Human declarer controls the exposed partner hand on partner's turn.
        game.currentTurnIndex = 2;
        game.notifyListeners();
        await tester.pump();
        final dummy = tester.widget<ExposedDummyHand>(find.byType(ExposedDummyHand));
        expect(dummy.isActive, isTrue);
        expect(dummy.validMoves, isNotEmpty);
        final dummyCards = find.descendant(
          of: find.byType(ExposedDummyHand),
          matching: find.byType(RealisticPlayingCardWidget),
        );
        expect(dummyCards, findsNWidgets(13));
        expect(dummyCards.last.hitTestable(), findsOneWidget);
        await tester.tap(dummyCards.last);
        await tester.pump();
        expect(game.players[2].hand, hasLength(12));
        expect(tester.takeException(), isNull);
        game.dispose();
      });
    }
  }
}
