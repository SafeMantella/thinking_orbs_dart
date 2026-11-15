// Port para Dart da geometria de thinking-orbs (MIT, © 2026 Jakub Antalik).
// Original: https://github.com/Jakubantalik/thinking-orbs (src/engine/*.ts).
// Licença em LICENSE.
//
// Matemática pura, sem Flutter: cada modo devolve a lista final de pontos
// (já cortada, com raio mínimo e ordenada por z) e de linhas. Verificado
// contra spec/orbs-golden.json em test/thinking_orb_test.dart.

import 'dart:math' as math;

import 'orb_presets.dart';

class Dot {
  double x, y, z, r, white, a;
  Dot(this.x, this.y, this.z, this.r, this.white, [this.a = 1]);
}

class Line {
  final double x1, y1, x2, y2, white, a, w;
  const Line(this.x1, this.y1, this.x2, this.y2, this.white, this.a, this.w);
}

class OrbFrame {
  final List<Dot> dots;
  final List<Line> lines;
  const OrbFrame(this.dots, this.lines);
}

typedef Opts = Map<String, double>;
typedef _P3 = (double, double, double);
typedef _Proj = _P3 Function(double x, double y, double z);

double _o(Opts o, String k, double d) => o[k] ?? d;

/// As nove ações que a IA pode estar fazendo.
enum OrbState {
  working('orbits', 'Trabalhando…'),
  searching('globe', 'Pesquisando…'),
  solving('rubik', 'Resolvendo…'),
  listening('wave', 'Ouvindo…'),
  connecting('web', 'Conectando…'),
  weaving('braid', 'Tecendo…'),
  composing('ribbon', 'Compondo…'),
  breathing('ring', 'Pensando…'),
  shaping('morph', 'Formando…');

  final String mode;
  final String label;
  const OrbState(this.mode, this.label);
}

/// Dois tamanhos calibrados (não é um fator de escala).
enum OrbSize {
  large(64),
  small(20);

  final int px;
  const OrbSize(this.px);
}

/// Velocidade base do preset (multiplica o relógio).
double orbSpeed(OrbState s, OrbSize z) => kOrbSpeed['${s.name}-${z.px}']!;

/// Geometria de um instante. [t] já inclui a velocidade do preset.
OrbFrame orbFrame(OrbState state, OrbSize size, double t) {
  final o = kOrbOpts['${state.name}-${size.px}']!;
  final s = size.px.toDouble();
  switch (state.mode) {
    case 'orbits':
      return _frameOrbits(s, t, o);
    case 'globe':
      return _frameGlobe(s, t, o);
    case 'rubik':
      return _frameRubik(s, t, o);
    case 'wave':
      return _frameWave(s, t, o);
    case 'web':
      return _frameWeb(s, t, o);
    case 'braid':
      return _frameBraid(s, t, o);
    case 'ribbon':
    case 'ring':
      return _frameRibbon(s, t, o);
    default:
      return _frameMorph(s, t, o);
  }
}

// --- primitivas -------------------------------------------------------

double _lerp(double a, double b, double f) => a + (b - a) * f;
double _frac(double x) => x - x.floorToDouble();

double _hashD(double a, double b) {
  final h = math.sin(a * 12.9898 + b * 78.233) * 43758.5453;
  return h - h.floorToDouble();
}

double _vnoise(double x, double y) {
  final xi = x.floorToDouble();
  final yi = y.floorToDouble();
  var fx = x - xi;
  var fy = y - yi;
  fx = fx * fx * (3 - 2 * fx);
  fy = fy * fy * (3 - 2 * fy);
  final a = _hashD(xi, yi);
  final b = _hashD(xi + 1, yi);
  final c = _hashD(xi, yi + 1);
  final d = _hashD(xi + 1, yi + 1);
  return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy;
}

_P3 _fibDir(int i, int n) {
  final golden = math.pi * (3 - math.sqrt(5));
  final y = 1 - (2 * (i + 0.5)) / n;
  final rad = math.sqrt(1 - y * y);
  final a = i * golden;
  return (rad * math.cos(a), y, rad * math.sin(a));
}

double _angleDelta(double a, double b) =>
    math.atan2(math.sin(a - b), math.cos(a - b));

_Proj _makeProj(double yaw, double tilt, double cx, double cy, double scale) {
  final st = math.sin(tilt), ct = math.cos(tilt);
  final sy = math.sin(yaw), cyw = math.cos(yaw);
  return (x, y, z) {
    final x1 = x * cyw + z * sy;
    final z1 = -x * sy + z * cyw;
    final y1 = y * ct - z1 * st;
    final z2 = y * st + z1 * ct;
    return (cx + x1 * scale, cy - y1 * scale, z2);
  };
}

double _radiusScale(double size, double pow) =>
    math.pow(size / 300, pow).toDouble();

/// Corta marcas invisíveis, aplica o raio mínimo e ordena por z (estável,
/// como o sort do JS).
OrbFrame _finalize(List<Dot> dots, List<Line> lines, double rMin) {
  final visible = <Dot>[];
  for (final d in dots) {
    if (d.a < 0.02) continue;
    d.r = math.max(rMin, d.r);
    visible.add(d);
  }
  final idx = List<int>.generate(visible.length, (i) => i);
  idx.sort((a, b) {
    final d = visible[a].z - visible[b].z;
    if (d != 0) return d < 0 ? -1 : 1;
    return a.compareTo(b);
  });
  return OrbFrame(
    [for (final i in idx) visible[i]],
    [for (final l in lines) if (l.a >= 0.02) l],
  );
}

// --- orbits (working) -------------------------------------------------

OrbFrame _frameOrbits(double size, double t, Opts o) {
  final cx = size / 2, cy = size / 2;
  final R = (size / 2) * 0.82;
  final pt = _makeProj(t * 0.12, 0.3, cx, cy, 1);
  final rs = _radiusScale(size, _o(o, 'rsPow', 0.6));

  final dots = <Dot>[];
  final orbitN = _o(o, 'orbitN', 12).toInt();
  final ghostN = _o(o, 'ghostN', 40).toInt();
  final particles = _o(o, 'particles', 3).toInt();

  for (var orb = 0; orb < orbitN; orb++) {
    final h1 = _hashD(orb.toDouble(), 1.7);
    final h2 = _hashD(orb.toDouble(), 5.2);
    final h3 = _hashD(orb.toDouble(), 8.9);
    final ro = R * (0.45 + 0.52 * h1);
    final th = h1 * 2 * math.pi;
    final phi = math.acos(2 * h2 - 1);
    final nx = math.sin(phi) * math.cos(th);
    final ny = math.cos(phi);
    final nz = math.sin(phi) * math.sin(th);
    var ux = -ny;
    var uy = nx;
    const uz = 0.0;
    final ul = math.max(1e-6, math.sqrt(ux * ux + uy * uy));
    ux /= ul;
    uy /= ul;
    final vx = ny * uz - nz * uy;
    final vy = nz * ux - nx * uz;
    final vz = nx * uy - ny * ux;
    final speed = (0.25 + 0.55 * h3) * (h3 > 0.5 ? 1 : -1);

    for (var k = 0; k < ghostN; k++) {
      final a = (k / ghostN) * 2 * math.pi;
      final (px, py, z) = pt(
        (ux * math.cos(a) + vx * math.sin(a)) * ro,
        (uy * math.cos(a) + vy * math.sin(a)) * ro,
        (uz * math.cos(a) + vz * math.sin(a)) * ro,
      );
      final depth = (z / ro + 1) / 2;
      dots.add(Dot(px, py, z, _o(o, 'ghostR', 0.9) * rs, 0.72,
          _o(o, 'ghostA', 0.5) * (0.4 + 0.6 * depth)));
    }
    for (var m = 0; m < particles; m++) {
      final a = t * speed + (m / particles) * 2 * math.pi + h2 * 6;
      final (px, py, z) = pt(
        (ux * math.cos(a) + vx * math.sin(a)) * ro,
        (uy * math.cos(a) + vy * math.sin(a)) * ro,
        (uz * math.cos(a) + vz * math.sin(a)) * ro,
      );
      final depth = (z / ro + 1) / 2;
      dots.add(Dot(
          px,
          py,
          z,
          (_o(o, 'partR', 1.2) + _o(o, 'partRDepth', 1.6) * depth) * rs,
          0.3 - 0.22 * depth));
    }
  }
  return _finalize(dots, const [], _o(o, 'rMin', 0.3));
}

// --- braid (weaving) --------------------------------------------------

OrbFrame _frameBraid(double size, double t, Opts o) {
  final cx = size / 2, cy = size / 2;
  final R = (size / 2) * 0.76;
  final pt = _makeProj(t * 0.4, 0.3, cx, cy, 1);
  final rs = _radiusScale(size, _o(o, 'rsPow', 0.6));

  final dots = <Dot>[];
  final ghostN = _o(o, 'ghostN', 150).toInt();
  for (var i = 0; i < ghostN; i++) {
    final d = _fibDir(i, ghostN);
    final (px, py, z) = pt(d.$1 * R, d.$2 * R, d.$3 * R);
    final depth = (z / R + 1) / 2;
    dots.add(Dot(px, py, z, 0.8 * rs, 0.78, 0.1 + 0.22 * depth));
  }

  final strandN = _o(o, 'strandN', 52).toInt();
  final turns = _o(o, 'turns', 3);
  for (var s = 0; s < 3; s++) {
    final phase = (s / 3) * 2 * math.pi;
    for (var i = 0; i < strandN; i++) {
      final u = (_frac(i / strandN + t * 0.045) * 2 - 1) * 0.96;
      final surf = math.sqrt(math.max(0, 1 - u * u));
      final endFade = math.min(1.0, (1 - u.abs()) / 0.1);
      final a = u * math.pi * turns + phase;
      final weave =
          1 + 0.075 * math.sin(u * math.pi * turns * 2 + phase * 2 + t * 0.8);
      final rr = surf * R * weave;
      final (px, py, zr) =
          pt(math.cos(a) * rr, u * R * weave, math.sin(a) * rr);
      final depth = (zr / R + 1) / 2;
      dots.add(Dot(
        px,
        py,
        zr,
        (_o(o, 'rBase', 1.2) + _o(o, 'rDepth', 1.8) * depth) * rs,
        0.55 - 0.45 * depth,
        endFade * (0.45 + 0.55 * depth),
      ));
    }
  }
  return _finalize(dots, const [], _o(o, 'rMin', 0.3));
}

// --- lattice: globe, rubik, wave --------------------------------------

class _Move {
  final int axis;
  final double lo, hi, ang;
  const _Move(this.axis, this.lo, this.hi, this.ang);
}

(List<double>, int) _solveCycle(
    double time, int count, double slotDur, double rest) {
  final cyc = 2 * count * slotDur + rest;
  final tc = time % cyc;
  final amount = List<double>.filled(count, 0);
  var active = -1;
  if (tc < 2 * count * slotDur) {
    final slot = (tc / slotDur).floor();
    final p = (tc - slot * slotDur) / slotDur;
    final cl = math.min(1.0, p / 0.7);
    final ep = 1 - math.pow(1 - cl, 3).toDouble();
    if (slot < count) {
      for (var i = 0; i < slot; i++) {
        amount[i] = 1;
      }
      amount[slot] = ep;
      active = slot;
    } else {
      final u = 2 * count - 1 - slot;
      for (var i = 0; i < u; i++) {
        amount[i] = 1;
      }
      amount[u] = 1 - ep;
      active = u;
    }
  }
  return (amount, active);
}

(double, double, double, bool) _applyMoves(
    _P3 p, List<_Move> moves, List<double> amount, int active) {
  var (x, y, z) = p;
  var inActive = false;
  for (var i = 0; i < moves.length; i++) {
    if (amount[i] <= 0) continue;
    final mv = moves[i];
    final coord = mv.axis == 0 ? x : (mv.axis == 1 ? y : z);
    if (coord < mv.lo || coord >= mv.hi) continue;
    if (i == active) inActive = true;
    final a = mv.ang * amount[i];
    final ca = math.cos(a), sa = math.sin(a);
    if (mv.axis == 0) {
      final y2 = y * ca - z * sa;
      z = y * sa + z * ca;
      y = y2;
    } else if (mv.axis == 1) {
      final x2 = x * ca + z * sa;
      z = -x * sa + z * ca;
      x = x2;
    } else {
      final x2 = x * ca - y * sa;
      y = x * sa + y * ca;
      x = x2;
    }
  }
  return (x, y, z, inActive);
}

List<_Move> _makeMoves(int count) {
  final moves = <_Move>[];
  for (var i = 0; i < count; i++) {
    final axis = math.min(2, (_hashD(i.toDouble(), 2.3) * 3).floor());
    final lo = -1.0 + 0.5 * math.min(3, (_hashD(i.toDouble(), 5.9) * 4).floor());
    final dir = _hashD(i.toDouble(), 7.7) < 0.5 ? 1 : -1;
    moves.add(_Move(axis, lo, lo + 0.5, dir * math.pi / 2));
  }
  return moves;
}

OrbFrame _frameGlobe(double size, double t, Opts o) {
  const spin = 0.5;
  final cx = size / 2, cy = size / 2;
  final radius = (size / 2) * 0.82;
  final tilt = 0.4 + 0.06 * math.sin(t * 0.35);
  final pt = _makeProj(t * spin, tilt, cx, cy, radius);
  final scan = t * (spin + (1.7 - spin) * _o(o, 'scanMul', 1));
  final rs = _radiusScale(size, _o(o, 'rsPow', 0.6));
  final dimBase = _o(o, 'dimBase', 1);

  final dots = <Dot>[];
  final latRings = _o(o, 'latRings', 17).toInt();
  final lonDensity = _o(o, 'lonDensity', 44);
  for (var li = 0; li <= latRings; li++) {
    final lat = -math.pi / 2 + (li / latRings) * math.pi;
    final cosLat = math.cos(lat), sinLat = math.sin(lat);
    final lonCount = math.max(1, (cosLat.abs() * lonDensity).round());
    for (var lj = 0; lj < lonCount; lj++) {
      final lon = (lj / lonCount) * 2 * math.pi;
      final (px, py, z) =
          pt(cosLat * math.cos(lon), sinLat, cosLat * math.sin(lon));
      final depth = (z + 1) / 2;
      final d = _angleDelta(lon + t * spin, scan);
      final boost = math.exp(-(d * d) / 0.18) * math.max(0, z);
      dots.add(Dot(
        px,
        py,
        z,
        (_o(o, 'rBase', 0.6) +
                _o(o, 'rDepth', 1.7) * depth +
                _o(o, 'rBoost', 1) * boost) *
            rs,
        _o(o, 'inkFar', 0.62) - _o(o, 'inkSpan', 0.54) * depth,
        dimBase + (1 - dimBase) * math.min(1.0, boost),
      ));
    }
  }
  return _finalize(dots, const [], _o(o, 'rMin', 0.3));
}

OrbFrame _frameRubik(double size, double t, Opts o) {
  final cx = size / 2, cy = size / 2;
  final R = (size / 2) * 0.82;
  final pt = _makeProj(t * 0.55, 0.35 + 0.1 * math.sin(t * 0.9), cx, cy, R);
  final rs = _radiusScale(size, _o(o, 'rsPow', 0.6));
  final moveCount = _o(o, 'moveCount', 14).toInt();
  final moves = _makeMoves(moveCount);
  final (amount, active) = _solveCycle(t, moveCount, 0.42, 1.2);

  final dots = <Dot>[];
  final latRings = _o(o, 'latRings', 15).toInt();
  final lonDensity = _o(o, 'lonDensity', 40);
  for (var li = 0; li <= latRings; li++) {
    final lat = -math.pi / 2 + (li / latRings) * math.pi;
    final cosLat = math.cos(lat), sinLat = math.sin(lat);
    final lonCount = math.max(1, (cosLat.abs() * lonDensity).round());
    for (var lj = 0; lj < lonCount; lj++) {
      final lon = (lj / lonCount) * 2 * math.pi;
      final (x, y, z, inActive) = _applyMoves(
          (cosLat * math.cos(lon), sinLat, cosLat * math.sin(lon)),
          moves,
          amount,
          active);
      final (px, py, zr) = pt(x, y, z);
      final depth = (zr + 1) / 2;
      dots.add(Dot(
        px,
        py,
        zr,
        (_o(o, 'rBase', 0.6) +
                _o(o, 'rDepth', 1.7) * depth +
                (inActive ? _o(o, 'rActive', 0.3) : 0)) *
            rs,
        _o(o, 'inkFar', 0.62) -
            _o(o, 'inkSpan', 0.54) * depth -
            (inActive ? 0.14 : 0),
      ));
    }
  }
  return _finalize(dots, const [], _o(o, 'rMin', 0.3));
}

OrbFrame _frameWave(double size, double t, Opts o) {
  final cx = size / 2, cy = size / 2;
  final R = (size / 2) * 0.874;
  final pt = _makeProj(t * 0.18, 0.38, cx, cy, 1);
  final rs = _radiusScale(size, _o(o, 'rsPow', 0.6));

  final dots = <Dot>[];
  final rings = _o(o, 'rings', 15).toInt();
  final lonDensity = _o(o, 'lonDensity', 40);
  for (var ri = 0; ri <= rings; ri++) {
    final lat = -math.pi / 2 + (ri / rings) * math.pi;
    final cosLat = math.cos(lat), sinLat = math.sin(lat);
    final w = 0.62 * math.sin(t * 2.1 - ri * 0.52) +
        0.38 * math.sin(t * 1.27 + ri * 0.83);
    final rr = R * (0.88 + 0.105 * w);
    final lonCount = math.max(1, (cosLat.abs() * lonDensity).round());
    for (var lj = 0; lj < lonCount; lj++) {
      final lon = (lj / lonCount) * 2 * math.pi;
      final (px, py, z) = pt(cosLat * math.cos(lon) * rr, sinLat * rr,
          cosLat * math.sin(lon) * rr);
      final depth = (z / R + 1) / 2;
      final crest = math.max(0.0, w);
      dots.add(Dot(
        px,
        py,
        z,
        (_o(o, 'rBase', 0.6) + _o(o, 'rDepth', 1.7) * depth) *
            (1 + 0.4 * crest) *
            rs,
        0.66 - 0.56 * depth - 0.1 * crest,
      ));
    }
  }
  return _finalize(dots, const [], _o(o, 'rMin', 0.3));
}

// --- ribbon / ring (composing, breathing) -----------------------------

OrbFrame _frameRibbon(double size, double t, Opts o) {
  final cx = size / 2, cy = size / 2;
  final R = (size / 2) * 0.78;
  final spin = _o(o, 'spin', 1);
  const camTilt = 0.3;
  final pt = _makeProj(t * 0.1 * spin, camTilt, cx, cy, 1);
  final rs = _radiusScale(size, _o(o, 'rsPow', 0.6));
  final faceOn = (o['faceOn'] ?? 0) != 0;

  final dots = <Dot>[];
  final ghostN = _o(o, 'ghostN', 150).toInt();
  for (var i = 0; i < ghostN; i++) {
    final d = _fibDir(i, ghostN);
    final (px, py, z) = pt(d.$1 * R, d.$2 * R, d.$3 * R);
    final depth = (z / R + 1) / 2;
    dots.add(Dot(px, py, z, 0.8 * rs, 0.78, 0.1 + 0.22 * depth));
  }

  final ya = t * 0.24 * spin;
  final ta = faceOn ? -camTilt : 0.55 + 0.3 * math.sin(t * 0.18) * spin;
  final ux = math.cos(ya);
  const uy = 0.0;
  final uz = math.sin(ya);
  final vx = -uz * math.sin(ta);
  final vy = math.cos(ta);
  final vz = ux * math.sin(ta);
  final nx = uy * vz - uz * vy;
  final ny = uz * vx - ux * vz;
  final nz = ux * vy - uy * vx;

  final wobMul = _o(o, 'wobMul', 1);
  final wobAmp = 0.23 * wobMul;
  final baseR = faceOn ? R / (1 + 0.85 * wobAmp) : R;

  final baseLanes = _o(o, 'lanes', 5);
  final segs = _o(o, 'segs', 88).toInt();
  final lanes = math.max(1, (baseLanes * _o(o, 'bandMul', 1)).round());
  for (var w = 0; w < lanes; w++) {
    final laneOff = (w - (lanes - 1) / 2) * 0.075;
    final edge =
        ((w - (lanes - 1) / 2).abs()) / math.max(1.0, (lanes - 1) / 2);
    for (var k = 0; k < segs; k++) {
      final a = (k / segs) * 2 * math.pi;
      final wob = (0.16 * math.sin(a * 3 - t * 1.7 + w * 0.22) +
              0.07 * math.sin(a * 5 + t * 1.1)) *
          wobMul;
      final radial = faceOn ? 1 + wob : 1.0;
      final off = faceOn ? laneOff : laneOff + wob;
      final x = ux * math.cos(a) + vx * math.sin(a) + nx * off;
      final y = uy * math.cos(a) + vy * math.sin(a) + ny * off;
      final z = uz * math.cos(a) + vz * math.sin(a) + nz * off;
      final l = math.sqrt(x * x + y * y + z * z);
      final rr = baseR * radial;
      final (px, py, zr) = pt((x / l) * rr, (y / l) * rr, (z / l) * rr);
      final depth = (zr / R + 1) / 2;
      dots.add(Dot(
        px,
        py,
        zr,
        (_o(o, 'rBase', 1.1) + _o(o, 'rDepth', 1.7) * depth) *
            (1 - 0.25 * edge) *
            rs,
        0.52 - 0.44 * depth + 0.18 * edge,
        0.4 + 0.6 * depth,
      ));
    }
  }
  return _finalize(dots, const [], _o(o, 'rMin', 0.3));
}

// --- web (connecting) -------------------------------------------------

OrbFrame _frameWeb(double size, double t, Opts o) {
  final cx = size / 2, cy = size / 2;
  final R = (size / 2) * 0.8 * _o(o, 'spread', 1);
  final pt = _makeProj(t * 0.12, 0.32, cx, cy, R);
  final rs = _radiusScale(size, _o(o, 'rsPow', 0.6));

  final nodeN = _o(o, 'nodeN', 30).toInt();
  final thr = _o(o, 'thr', 0.72);
  final nodeR = _o(o, 'nodeR', 1.4);
  final nodeRDepth = _o(o, 'nodeRDepth', 1.8);

  final nodes = <_P3>[];
  for (var i = 0; i < nodeN; i++) {
    final d = _fibDir(i, nodeN);
    final x = d.$1 + 0.3 * (_vnoise(i * 0.31 + 9, t * 0.24) - 0.5) * 2;
    final y = d.$2 + 0.3 * (_vnoise(i * 0.53 + 27, t * 0.21) - 0.5) * 2;
    final z = d.$3 + 0.3 * (_vnoise(i * 0.77 + 55, t * 0.27) - 0.5) * 2;
    final l = math.sqrt(x * x + y * y + z * z);
    nodes.add((x / l, y / l, z / l));
  }

  final lines = <Line>[];
  final dots = <Dot>[];

  for (var i = 0; i < nodeN; i++) {
    for (var j = i + 1; j < nodeN; j++) {
      final dx = nodes[i].$1 - nodes[j].$1;
      final dy = nodes[i].$2 - nodes[j].$2;
      final dz = nodes[i].$3 - nodes[j].$3;
      final dist = math.sqrt(dx * dx + dy * dy + dz * dz);
      if (dist >= thr) continue;
      final (x1, y1, z1) = pt(nodes[i].$1, nodes[i].$2, nodes[i].$3);
      final (x2, y2, z2) = pt(nodes[j].$1, nodes[j].$2, nodes[j].$3);
      final depth = ((z1 + z2) / 2 + 1) / 2;
      lines.add(Line(
        x1,
        y1,
        x2,
        y2,
        0.42,
        (1 - dist / thr) * (0.3 + 0.55 * depth),
        math.max(0.6, _o(o, 'lineW', 0.8) * rs),
      ));
    }
  }

  for (var i = 0; i < nodeN; i++) {
    final (px, py, z) = pt(nodes[i].$1, nodes[i].$2, nodes[i].$3);
    final depth = (z + 1) / 2;
    final pulse = 1 + 0.25 * math.sin(t * 1.4 + i * 2.7);
    dots.add(Dot(px, py, z, (nodeR + nodeRDepth * depth) * pulse * rs,
        0.55 - 0.45 * depth));
  }

  final signals = _o(o, 'signals', 5).toInt();
  for (var s = 0; s < signals; s++) {
    final seg = (t * 0.55 + s * 7.31).floorToDouble();
    final a = (_hashD(seg, s * 3.1 + 1.7) * nodeN).floor();
    final b = (_hashD(seg, s * 5.7 + 4.2) * nodeN).floor();
    if (a == b) continue;
    final f = _frac(t * 0.55 + s * 7.31);
    final x = _lerp(nodes[a].$1, nodes[b].$1, f);
    final y = _lerp(nodes[a].$2, nodes[b].$2, f);
    final z = _lerp(nodes[a].$3, nodes[b].$3, f);
    final l = math.max(1e-6, math.sqrt(x * x + y * y + z * z));
    final (px, py, zr) = pt(x / l, y / l, z / l);
    final depth = (zr + 1) / 2;
    dots.add(Dot(px, py, zr, (nodeR * 1.5 + nodeRDepth * depth) * rs, 0.05,
        0.5 + 0.5 * depth));
  }

  return _finalize(dots, lines, _o(o, 'rMin', 0.3));
}

// --- morph (shaping) --------------------------------------------------

typedef _Path = (double, double) Function(double f);

double _smoothE(double x) => x * x * (3 - 2 * x);

_Path _polyPath(List<(double, double)> verts) {
  final v = verts.length;
  final lens = <double>[];
  var total = 0.0;
  for (var i = 0; i < v; i++) {
    final a = verts[i], b = verts[(i + 1) % v];
    final l = math.sqrt(
        (b.$1 - a.$1) * (b.$1 - a.$1) + (b.$2 - a.$2) * (b.$2 - a.$2));
    lens.add(l);
    total += l;
  }
  return (f) {
    var target = f * total;
    var i = 0;
    while (target > lens[i] && i < v - 1) {
      target -= lens[i];
      i++;
    }
    final a = verts[i], b = verts[(i + 1) % v];
    final ff = lens[i] != 0 ? math.min(1.0, target / lens[i]) : 0.0;
    return (a.$1 + (b.$1 - a.$1) * ff, a.$2 + (b.$2 - a.$2) * ff);
  };
}

(double, double) _circle(double f) {
  final a = -math.pi / 2 + f * 2 * math.pi;
  return (math.cos(a) * 0.24, math.sin(a) * 0.24);
}

final _triangle = _polyPath(const [(0.0, -0.26), (0.24, 0.16), (-0.24, 0.16)]);
final _square = _polyPath(const [
  (0.0, -0.2),
  (0.2, -0.2),
  (0.2, 0.2),
  (-0.2, 0.2),
  (-0.2, -0.2),
]);
final List<_Path> _cycle = [_circle, _triangle, _square];

const _hold = 1.4;
const _morph = 0.9;
const _seg = _hold + _morph;

OrbFrame _frameMorph(double size, double t, Opts o) {
  final k = _cycle.length;
  final tc = t % (_seg * k);
  final ki = (tc / _seg).floor();
  final local = tc - ki * _seg;
  final m = local > _hold ? _smoothE((local - _hold) / _morph) : 0.0;
  final sprd = _o(o, 'spread', 1);

  final pA = _cycle[ki];
  final pB = _cycle[(ki + 1) % k];
  const mm = 160;
  final pts = <(double, double)>[];
  for (var i = 0; i < mm; i++) {
    final f = i / mm;
    final a = pA(f), b = pB(f);
    pts.add(((a.$1 + (b.$1 - a.$1) * m) * sprd,
        (a.$2 + (b.$2 - a.$2) * m) * sprd));
  }
  final lens = <double>[];
  var total = 0.0;
  for (var i = 0; i < mm; i++) {
    final a = pts[i], b = pts[(i + 1) % mm];
    final l = math.sqrt(
        (b.$1 - a.$1) * (b.$1 - a.$1) + (b.$2 - a.$2) * (b.$2 - a.$2));
    lens.add(l);
    total += l;
  }

  final n = math.max(6, (34 * _o(o, 'iconD', 1)).round());
  final re = _o(o, 'rDot', 0.021) * 1.35 * sprd;
  final pulse = 1 + 0.02 * math.sin(local * 3.1);

  final dots = <Dot>[];
  final c2 = size / 2;
  var seg = 0;
  var acc = 0.0;
  for (var k2 = 0; k2 < n; k2++) {
    final target = (k2 / n) * total;
    while (acc + lens[seg] < target && seg < mm - 1) {
      acc += lens[seg];
      seg++;
    }
    final a = pts[seg], b = pts[(seg + 1) % mm];
    final f = lens[seg] != 0 ? math.min(1.0, (target - acc) / lens[seg]) : 0.0;
    final x = (a.$1 + (b.$1 - a.$1) * f) * pulse;
    final y = (a.$2 + (b.$2 - a.$2) * f) * pulse;
    dots.add(Dot(c2 + x * size, c2 + y * size, 0,
        math.max(0.35, re * size), 0.1));
  }
  return _finalize(dots, const [], _o(o, 'rMin', 0.3));
}
