import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../tools/simulations/run_ai_simulation.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('LIKYA-V2-007D — 600-Round Deterministic Simulation Suite', () {
    test('600 complete multi-mode rounds execute with 0 illegal moves and 0 crashes', () async {
      final results = await AiSimulationRunner.runAll();

      int totalCompleted = 0;
      int totalIllegal = 0;
      int totalDuplicates = 0;
      int totalDeadlocks = 0;
      int totalCrashes = 0;
      int totalScoringErrors = 0;
      int totalTrickErrors = 0;

      for (final r in results) {
        totalCompleted += r.completedRounds;
        totalIllegal += r.illegalMoves;
        totalDuplicates += r.duplicateCards;
        totalDeadlocks += r.deadlocks;
        totalCrashes += r.crashes;
        totalScoringErrors += r.scoringErrors;
        totalTrickErrors += r.trickCountErrors;

        expect(r.completedRounds, equals(r.requestedRounds),
            reason: '${r.mode} - ${r.difficulty} rounds incomplete');
        expect(r.illegalMoves, equals(0),
            reason: '${r.mode} - ${r.difficulty} had illegal moves');
        expect(r.duplicateCards, equals(0),
            reason: '${r.mode} - ${r.difficulty} had duplicate cards');
        expect(r.deadlocks, equals(0),
            reason: '${r.mode} - ${r.difficulty} had deadlocks');
        expect(r.crashes, equals(0),
            reason: '${r.mode} - ${r.difficulty} had crashes');
        expect(r.scoringErrors, equals(0),
            reason: '${r.mode} - ${r.difficulty} had scoring errors');
        expect(r.trickCountErrors, equals(0),
            reason: '${r.mode} - ${r.difficulty} had trick count errors');

        // Performance sanity: p95 under 10 milliseconds (10,000 µs)
        expect(r.p95CardMicros, lessThan(10000));
      }

      expect(totalCompleted, equals(600));
      expect(totalIllegal, equals(0));
      expect(totalDuplicates, equals(0));
      expect(totalDeadlocks, equals(0));
      expect(totalCrashes, equals(0));
      expect(totalScoringErrors, equals(0));
      expect(totalTrickErrors, equals(0));
    });
  });
}
