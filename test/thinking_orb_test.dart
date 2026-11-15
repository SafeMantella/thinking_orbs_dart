// Compara a geometria do port Dart com o golden do thinking-orbs (MIT):
// 72 casos (9 estados × 2 tamanhos × 4 instantes), ponto a ponto.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinking_orbs_dart/src/orb_engine.dart';
import 'package:thinking_orbs_dart/src/thinking_orb.dart';

void main() {
  final g = jsonDecode(File('test/fixtures/orbs-golden.json').readAsStringSync())
      as Map<String, dynamic>;
  final tol = (g['tolerance'] as num).toDouble();
  final cases = (g['cases'] as List).cast<Map<String, dynamic>>();

  widgetTests();
  test('golden tem os 72 casos', () => expect(cases.length, 72));

  for (final c in cases) {
    test('golden ${c['key']}', () {
      final state = OrbState.values.byName(c['state'] as String);
      final size = OrbSize.values.firstWhere(
        (s) => s.px == int.parse('${c['size']}'),
      );
      final frame = orbFrame(state, size, (c['t'] as num).toDouble());
      final dots = (c['dots'] as List).cast<num>();
      final lines = (c['lines'] as List).cast<num>();

      expect(frame.dots.length, c['dotCount']);
      expect(frame.lines.length, c['lineCount']);
      for (var i = 0; i < frame.dots.length; i++) {
        final d = frame.dots[i];
        final e = dots.sublist(i * 6, i * 6 + 6);
        final got = [d.x, d.y, d.z, d.r, d.white, d.a];
        for (var k = 0; k < 6; k++) {
          expect(got[k], closeTo(e[k].toDouble(), tol), reason: 'dot $i campo $k');
        }
      }
      for (var i = 0; i < frame.lines.length; i++) {
        final l = frame.lines[i];
        final e = lines.sublist(i * 7, i * 7 + 7);
        final got = [l.x1, l.y1, l.x2, l.y2, l.white, l.a, l.w];
        for (var k = 0; k < 7; k++) {
          expect(got[k], closeTo(e[k].toDouble(), tol), reason: 'linha $i campo $k');
        }
      }
    });
  }
}

// Widget: desenha todos os estados sem erro e expõe o rótulo.
void widgetTests() {
  for (final s in OrbState.values) {
    testWidgets('ThinkingOrb ${s.name} desenha e tem rótulo', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Center(child: ThinkingOrb(state: s))),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.bySemanticsLabel(s.label), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
