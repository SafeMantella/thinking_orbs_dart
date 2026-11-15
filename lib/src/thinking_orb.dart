// Indicador "a IA está agindo": orbes de pontos (thinking-orbs, MIT,
// © 2026 Jakub Antalik). Geometria em orb_engine.dart.
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'orb_engine.dart';

export 'orb_engine.dart' show OrbState, OrbSize;

/// Relógio único: todas as instâncias ficam em fase.
final Stopwatch _clock = Stopwatch()..start();

class ThinkingOrb extends StatefulWidget {
  final OrbState state;
  final OrbSize size;
  final double speed;
  final bool paused;

  /// Cor da tinta (padrão off-white). A profundidade escurece a cor.
  final Color color;
  final String? semanticLabel;

  const ThinkingOrb({
    super.key,
    this.state = OrbState.working,
    this.size = OrbSize.large,
    this.speed = 1,
    this.paused = false,
    this.color = const Color(0xFFF2EFE8),
    this.semanticLabel,
  });

  @override
  State<ThinkingOrb> createState() => _ThinkingOrbState();
}

class _ThinkingOrbState extends State<ThinkingOrb>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _t = ValueNotifier(0.6);
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration _) {
    if (widget.paused || _reduced) return;
    _t.value = _clock.elapsedMicroseconds /
        1e6 *
        orbSpeed(widget.state, widget.size) *
        widget.speed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.of(context).disableAnimations;
    if (_reduced) _t.value = 0.6; // um quadro estático representativo
  }

  @override
  void dispose() {
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final px = widget.size.px.toDouble();
    return Semantics(
      image: true,
      label: widget.semanticLabel ?? widget.state.label,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size(px, px),
            painter: _OrbPainter(widget.state, widget.size, widget.color, _t),
          ),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  final OrbState state;
  final OrbSize size;
  final Color color;
  final ValueNotifier<double> t;

  _OrbPainter(this.state, this.size, this.color, this.t) : super(repaint: t);

  Color _ink(double white, double alpha) {
    // tema escuro: tinta espelhada (perto = claro), como na biblioteca
    final f = 1 - white.clamp(0.0, 1.0);
    return Color.from(
      alpha: alpha.clamp(0.0, 1.0),
      red: color.r * f,
      green: color.g * f,
      blue: color.b * f,
    );
  }

  @override
  void paint(Canvas canvas, Size _) {
    final frame = orbFrame(state, size, t.value);
    final line = Paint()..style = PaintingStyle.stroke;
    for (final l in frame.lines) {
      line
        ..color = _ink(l.white, l.a)
        ..strokeWidth = l.w;
      canvas.drawLine(Offset(l.x1, l.y1), Offset(l.x2, l.y2), line);
    }
    final fill = Paint();
    for (final d in frame.dots) {
      fill.color = _ink(d.white, d.a);
      canvas.drawCircle(Offset(d.x, d.y), d.r, fill);
    }
  }

  @override
  bool shouldRepaint(_OrbPainter o) =>
      o.state != state || o.size != size || o.color != color;
}
