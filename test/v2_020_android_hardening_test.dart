import 'dart:io';

import 'package:batak_app/models/card_model.dart';
import 'package:batak_app/providers/game_provider.dart';
import 'package:batak_app/providers/store_provider.dart';
import 'package:batak_app/screens/game_screen.dart';
import 'package:batak_app/services/api_service.dart';
import 'package:batak_app/services/sound_service.dart';
import 'package:batak_app/services/websocket_service.dart';
import 'package:batak_app/widgets/exposed_dummy_hand.dart';
import 'package:batak_app/widgets/fanned_hand_view.dart';
import 'package:batak_app/widgets/game_action_panels.dart';
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
  final hand = <PlayingCard>[
    for (final suit in Suit.values)
      for (final rank in Rank.values)
        PlayingCard(suit: suit, rank: rank),
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
          'PAS, 8+5/8+8 hand and dummy at ${size.width.toInt()}x${size.height.toInt()} / $scale',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              padding: const EdgeInsets.only(top: 24, bottom: 24),
              textScaler: TextScaler.linear(scale),
            ),
            child: Scaffold(
              body: SafeArea(
                child: SingleChildScrollView(
                  child: Column(children: [
                    BiddingKeypadWidget(
                      currentHighestBid: 5,
                      onBidSelected: (_) {},
                      onPass: () {},
                    ),
                    SizedBox(
                      width: size.width - 16,
                      child: FannedHandView(
                        hand: hand.take(13).toList(),
                        isMyTurn: true,
                        isCardValid: (_) => true,
                        onPlayCard: (_) {},
                      ),
                    ),
                    SizedBox(
                      width: size.width - 16,
                      child: FannedHandView(
                        hand: hand.take(16).toList(),
                        isMyTurn: true,
                        isCardValid: (_) => true,
                        onPlayCard: (_) {},
                      ),
                    ),
                    SizedBox(
                      width: size.width - 36,
                      child: ExposedDummyHand(
                        hand: hand.take(13).toList(),
                        isActive: true,
                        sideSeat: false,
                        validMoves: hand.take(13).toSet(),
                        onPlayCard: (_) {},
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ));

        final pass = find.text('PAS');
        expect(pass, findsOneWidget);
        expect(tester.getSize(pass).height, greaterThan(0));
        // Render errors are reported by the test binding with their widget path.
      });
    }
  }
}
