import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

// ===================================================================
// BIKE RIDER - scene data + painter
// The page (bike_game_page.dart) updates a BikeScene every frame and
// BikePainter draws it: scenery, road, traffic, coins, power-ups,
// particles, day/night, the motorbike and the shield.
// ===================================================================

enum VehicleKind { sedan, sports, taxi, truck, bus }

enum PickupKind { shield, magnet }

class Vehicle {
  final int lane;
  final VehicleKind kind;
  final Color color;
  final double len; // length factor (x carH)
  final double wf; // width factor (x carW)
  double y;

  Vehicle(this.lane, this.y, this.kind, this.color, this.len, this.wf);
}

class Coin {
  double x;
  double y;

  Coin(this.x, this.y);
}

class Pickup {
  final int lane;
  final PickupKind kind;
  double y;

  Pickup(this.lane, this.y, this.kind);
}

class Particle {
  double x;
  double y;
  double vx;
  double vy;
  double life;
  double size;
  final double maxLife;
  final double grow;
  final double gravity;
  final double scroll;
  final Color color;
  final bool glow;

  Particle(
    this.x,
    this.y,
    this.vx,
    this.vy,
    double life,
    this.size,
    this.color, {
    this.glow = true,
    this.grow = 0,
    this.gravity = 0,
    this.scroll = 0.5,
  })  : life = life,
        maxLife = life;
}

class FloatText {
  double x;
  double y;
  double life = 0.9;
  final String text;
  final Color color;

  FloatText(this.x, this.y, this.text, this.color);
}

class BikeScene {
  double roadLeft = 0;
  double roadW = 0;
  double laneW = 0;
  double bikeX = 0;
  double bikeTop = 0;
  double bikeW = 0;
  double bikeH = 0;
  double carW = 0;
  double carH = 0;
  double coinR = 0;
  double lean = 0;
  bool boosting = false;
  bool bikeVisible = true;
  bool shield = false;
  bool magnet = false;
  double worldDist = 0;
  double night = 0;
  double speedFx = 0;
  double clock = 0;
  Offset shake = Offset.zero;

  final List<Vehicle> vehicles = <Vehicle>[];
  final List<Coin> coins = <Coin>[];
  final List<Pickup> pickups = <Pickup>[];
  final List<Particle> particles = <Particle>[];
  final List<FloatText> floats = <FloatText>[];

  double laneCenter(int lane) => roadLeft + laneW * (lane + 0.5);
}

double _hash(int k, int salt) {
  var x = (k * 374761393 + salt * 668265263) & 0x7fffffff;
  x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff;
  x = x ^ (x >> 16);
  return (x & 0xffff) / 65535.0;
}

class BikePainter extends CustomPainter {
  final BikeScene s;

  BikePainter(this.s);

  // names used by the bike drawing code below
  double get bikeW => s.bikeW;
  double get bikeH => s.bikeH;
  double get bikeX => s.bikeX;
  double get bikeTop => s.bikeTop;
  double get lean => s.lean;
  bool get boosting => s.boosting;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(s.shake.dx, s.shake.dy);

    _drawGround(canvas, size);
    _drawScenery(canvas, size);
    _drawRoad(canvas, size);
    _drawCoins(canvas);
    _drawPickups(canvas);

    for (final v in s.vehicles) {
      _drawVehicle(canvas, v);
    }

    if (s.bikeVisible) _drawBike(canvas);
    if (s.shield) _drawShield(canvas);

    _drawParticles(canvas);
    _drawNight(canvas, size);
    _drawSpeedLines(canvas, size);
    _drawFloats(canvas);

    canvas.restore();
  }

  // ---------------------------------------------------------------
  // GROUND + SCENERY
  // ---------------------------------------------------------------

  void _drawGround(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xFF2E7D32);

    canvas.drawRect(
      Rect.fromLTWH(-30, -30, size.width + 60, size.height + 60),
      p,
    );

    p.color = const Color(0x16FFFFFF);

    for (double y = (s.worldDist % 180.0) - 180.0;
        y < size.height + 30;
        y += 180) {
      canvas.drawRect(Rect.fromLTWH(-30, y, size.width + 60, 90), p);
    }
  }

  void _drawTree(Canvas canvas, Offset c, double r) {
    final p = Paint();

    p.color = const Color(0x44000000);
    canvas.drawCircle(c + const Offset(4, 5), r, p);

    p.color = const Color(0xFF1B5E20);
    canvas.drawCircle(c, r, p);

    p.color = const Color(0xFF388E3C);
    canvas.drawCircle(c + Offset(-r * 0.1, -r * 0.1), r * 0.8, p);

    p.color = const Color(0xFF7CB342);
    canvas.drawCircle(c + Offset(-r * 0.28, -r * 0.28), r * 0.4, p);
  }

  void _drawScenery(Canvas canvas, Size size) {
    final left = s.roadLeft;
    final right = s.roadLeft + s.roadW;
    final p = Paint();

    // guard rails
    p.color = const Color(0xFF90A4AE);
    canvas.drawRect(Rect.fromLTWH(left - 10, -30, 5, size.height + 60), p);
    canvas.drawRect(Rect.fromLTWH(right + 5, -30, 5, size.height + 60), p);

    p.color = const Color(0xFF455A64);

    for (double y = (s.worldDist % 40.0) - 40.0; y < size.height + 30; y += 40) {
      canvas.drawRect(Rect.fromLTWH(left - 11, y, 7, 4), p);
      canvas.drawRect(Rect.fromLTWH(right + 4, y, 7, 4), p);
    }

    const spacing = 110.0;

    final k0 = ((s.worldDist - size.height - 120) / spacing).floor();
    final k1 = ((s.worldDist + 120) / spacing).ceil();

    for (var k = k0; k <= k1; k++) {
      final y0 = s.worldDist - k * spacing;

      // trees (only if there is room beside the road)
      for (final side in const [-1, 1]) {
        final h = _hash(k, side + 3);

        if (h < 0.4) continue;

        final r = math.min(6 + _hash(k, side + 7) * 8, (left - 24) / 2);

        if (r < 4) continue;

        final cx = side < 0 ? left - 17 - r : right + 17 + r;
        final cy = y0 + _hash(k, side + 11) * 40 - 20;

        _drawTree(canvas, Offset(cx, cy), r);
      }

      // street lamps
      if (k % 3 == 0) {
        p.color = const Color(0xFFFFF8E1);
        canvas.drawCircle(Offset(left - 7.5, y0), 3.4, p);
        canvas.drawCircle(Offset(right + 7.5, y0), 3.4, p);
      }
    }
  }

  // ---------------------------------------------------------------
  // ROAD
  // ---------------------------------------------------------------

  void _drawRoad(Canvas canvas, Size size) {
    final left = s.roadLeft;
    final right = s.roadLeft + s.roadW;
    final road = Rect.fromLTWH(left, -30, s.roadW, size.height + 60);

    canvas.drawRect(
      road,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(left, 0),
          Offset(right, 0),
          const [Color(0xFF2F383D), Color(0xFF3C484E), Color(0xFF2F383D)],
          const [0.0, 0.5, 1.0],
        ),
    );

    final p = Paint();

    // tyre marks
    p.color = const Color(0x12000000);

    for (var i = 0; i < 3; i++) {
      final cx = left + s.laneW * (i + 0.5);

      canvas.drawRect(Rect.fromLTWH(cx - s.laneW * 0.26, -30, 9, size.height + 60), p);
      canvas.drawRect(Rect.fromLTWH(cx + s.laneW * 0.26 - 9, -30, 9, size.height + 60), p);
    }

    // red / white rumble strips
    for (double y = (s.worldDist % 60.0) - 60.0; y < size.height + 30; y += 60) {
      p.color = const Color(0xFFE53935);
      canvas.drawRect(Rect.fromLTWH(left - 5, y, 5, 30), p);
      canvas.drawRect(Rect.fromLTWH(right, y, 5, 30), p);

      p.color = Colors.white;
      canvas.drawRect(Rect.fromLTWH(left - 5, y + 30, 5, 30), p);
      canvas.drawRect(Rect.fromLTWH(right, y + 30, 5, 30), p);
    }

    // solid edge lines
    p.color = Colors.white.withValues(alpha: 0.85);
    canvas.drawRect(Rect.fromLTWH(left + 5, -30, 3, size.height + 60), p);
    canvas.drawRect(Rect.fromLTWH(right - 8, -30, 3, size.height + 60), p);

    // moving lane dashes
    p.color = Colors.white.withValues(alpha: 0.7);

    for (var i = 1; i <= 2; i++) {
      final x = left + s.laneW * i - 2;

      for (double y = (s.worldDist % 80.0) - 80.0; y < size.height; y += 80) {
        canvas.drawRect(Rect.fromLTWH(x, y, 4, 40), p);
      }
    }
  }

  // ---------------------------------------------------------------
  // COINS + POWER-UPS
  // ---------------------------------------------------------------

  void _drawCoins(Canvas canvas) {
    final r = s.coinR;

    for (final c in s.coins) {
      final center = Offset(c.x, c.y);
      final sx = 0.3 + 0.7 * math.cos(s.clock * 5 + c.y * 0.015).abs();

      canvas.drawCircle(center, r * 1.9, Paint()..color = const Color(0x33FFC107));

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(sx, 1.0);

      canvas.drawCircle(Offset.zero, r, Paint()..color = const Color(0xFFFFB300));
      canvas.drawCircle(
        Offset.zero,
        r * 0.76,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.24
          ..color = const Color(0xFFFFE082),
      );
      canvas.drawCircle(Offset.zero, r * 0.3, Paint()..color = const Color(0xFFFFF8E1));

      canvas.restore();
    }
  }

  void _drawPickups(Canvas canvas) {
    for (final pk in s.pickups) {
      final center = Offset(s.laneCenter(pk.lane), pk.y);
      final r = s.coinR * 1.9 * (1 + 0.08 * math.sin(s.clock * 6));
      final col = pk.kind == PickupKind.shield
          ? const Color(0xFF29B6F6)
          : const Color(0xFFEF5350);

      canvas.drawCircle(
        center,
        r * 1.8,
        Paint()
          ..color = col.withValues(alpha: 0.28)
          ..blendMode = BlendMode.plus,
      );

      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = ui.Gradient.radial(
            center,
            r,
            [Colors.white, col],
            const [0.0, 1.0],
          ),
      );

      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = Colors.white,
      );

      final u = r * 0.55;
      final ip = Paint()..color = col;

      canvas.save();
      canvas.translate(center.dx, center.dy);

      if (pk.kind == PickupKind.shield) {
        final path = Path()
          ..moveTo(0, -u)
          ..lineTo(u * 0.9, -u * 0.55)
          ..lineTo(u * 0.8, u * 0.2)
          ..quadraticBezierTo(u * 0.6, u * 0.8, 0, u * 1.05)
          ..quadraticBezierTo(-u * 0.6, u * 0.8, -u * 0.8, u * 0.2)
          ..lineTo(-u * 0.9, -u * 0.55)
          ..close();

        canvas.drawPath(path, ip..color = const Color(0xFF0277BD));
      } else {
        final st = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * 0.5
          ..color = const Color(0xFFC62828);

        canvas.drawArc(
          Rect.fromCenter(center: Offset(0, u * 0.1), width: u * 1.5, height: u * 1.5),
          math.pi,
          math.pi,
          false,
          st,
        );
        canvas.drawLine(Offset(-u * 0.75, u * 0.1), Offset(-u * 0.75, u * 0.75), st);
        canvas.drawLine(Offset(u * 0.75, u * 0.1), Offset(u * 0.75, u * 0.75), st);

        final tip = Paint()..color = Colors.white;

        canvas.drawRect(Rect.fromLTWH(-u, u * 0.55, u * 0.5, u * 0.3), tip);
        canvas.drawRect(Rect.fromLTWH(u * 0.5, u * 0.55, u * 0.5, u * 0.3), tip);
      }

      canvas.restore();
    }
  }

  // ---------------------------------------------------------------
  // TRAFFIC
  // ---------------------------------------------------------------

  void _drawVehicle(Canvas canvas, Vehicle v) {
    final c = Offset(s.laneCenter(v.lane), v.y);
    final w = s.carW * v.wf;
    final h = s.carH * v.len;
    final paint = Paint();

    RRect rr(Offset center, double bw, double bh, double rad) =>
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: bw, height: bh),
          Radius.circular(rad),
        );

    final body = rr(c, w, h, w * 0.2);

    // shadow
    paint.color = const Color(0x55000000);
    canvas.drawRRect(body.shift(const Offset(4, 5)), paint);

    // wheels (stick out of the sides)
    paint.color = const Color(0xFF111111);

    final long = v.kind == VehicleKind.truck || v.kind == VehicleKind.bus;
    final wys = long ? [-0.36, 0.3] : [-0.28, 0.28];

    for (final f in wys) {
      for (final sd in const [-1.0, 1.0]) {
        canvas.drawRRect(
          rr(Offset(c.dx + sd * w * 0.5, c.dy + h * f), w * 0.16, s.carH * 0.22, 3),
          paint,
        );
      }
    }
    if (v.kind == VehicleKind.truck) {
      for (final sd in const [-1.0, 1.0]) {
        canvas.drawRRect(
          rr(Offset(c.dx + sd * w * 0.5, c.dy + h * 0.2), w * 0.16, s.carH * 0.22, 3),
          paint,
        );
      }
    }

    const glass = Color(0xFF1E2A32);

    switch (v.kind) {
      case VehicleKind.truck:
        final cabH = h * 0.27;

        // trailer
        paint.color = const Color(0xFFECEFF1);
        canvas.drawRRect(
          rr(Offset(c.dx, c.dy + cabH / 2 + h * 0.01), w * 0.94, h - cabH - h * 0.02, w * 0.08),
          paint,
        );
        paint.color = const Color(0x22000000);

        for (var i = 1; i < 6; i++) {
          canvas.drawRect(
            Rect.fromLTWH(c.dx - w * 0.47, c.dy - h / 2 + cabH + i * (h - cabH) / 6, w * 0.94, 2),
            paint,
          );
        }

        paint.color = v.color.withValues(alpha: 0.9);
        canvas.drawRect(
          Rect.fromCenter(center: Offset(c.dx, c.dy + h * 0.1), width: w * 0.16, height: h * 0.5),
          paint,
        );

        // cab
        paint.color = v.color;
        canvas.drawRRect(rr(Offset(c.dx, c.dy - h / 2 + cabH / 2), w, cabH, w * 0.18), paint);
        paint.color = glass;
        canvas.drawRRect(
          rr(Offset(c.dx, c.dy - h / 2 + cabH * 0.32), w * 0.78, cabH * 0.36, w * 0.1),
          paint,
        );
        break;

      case VehicleKind.bus:
        paint.color = v.color;
        canvas.drawRRect(body, paint);

        paint.color = Color.lerp(v.color, Colors.white, 0.35)!;
        canvas.drawRRect(rr(c.translate(0, h * 0.02), w * 0.8, h * 0.88, w * 0.1), paint);

        paint.color = const Color(0x55FFFFFF);
        canvas.drawRect(Rect.fromCenter(center: c, width: w * 0.1, height: h * 0.86), paint);

        paint.color = const Color(0xFFCFD8DC);
        canvas.drawRRect(rr(c.translate(0, -h * 0.18), w * 0.5, h * 0.1, 4), paint);
        canvas.drawRRect(rr(c.translate(0, h * 0.18), w * 0.5, h * 0.1, 4), paint);

        paint.color = glass;
        canvas.drawRRect(rr(c.translate(0, -h * 0.455), w * 0.82, h * 0.06, w * 0.08), paint);
        break;

      default:
        paint.color = v.color;
        canvas.drawRRect(body, paint);

        paint.color = const Color(0x24FFFFFF);
        canvas.drawRRect(rr(c.translate(-w * 0.24, 0), w * 0.14, h * 0.8, w * 0.07), paint);

        if (v.kind == VehicleKind.sports) {
          paint.color = Colors.white.withValues(alpha: 0.85);
          canvas.drawRect(Rect.fromCenter(center: c.translate(-w * 0.12, 0), width: w * 0.1, height: h * 0.96), paint);
          canvas.drawRect(Rect.fromCenter(center: c.translate(w * 0.12, 0), width: w * 0.1, height: h * 0.96), paint);
        }

        paint.color = glass;
        canvas.drawRRect(rr(c.translate(0, -h * 0.02), w * 0.78, h * 0.46, w * 0.16), paint);

        paint.color = Color.lerp(v.color, Colors.black, 0.25)!;
        canvas.drawRRect(rr(c.translate(0, h * 0.03), w * 0.74, h * 0.2, w * 0.1), paint);

        if (v.kind == VehicleKind.taxi) {
          paint.color = Colors.white;
          canvas.drawRRect(rr(c.translate(0, h * 0.03), w * 0.36, h * 0.08, 3), paint);
          paint.color = const Color(0xFF212121);
          canvas.drawRect(Rect.fromCenter(center: c.translate(0, h * 0.03), width: w * 0.2, height: h * 0.02), paint);
        }

        if (v.kind == VehicleKind.sports) {
          paint.color = const Color(0xFF111111);
          canvas.drawRect(Rect.fromCenter(center: c.translate(0, h * 0.44), width: w * 0.92, height: h * 0.05), paint);
        }
    }

    // tail lights (bottom, towards the bike) and head lights (top)
    paint.color = const Color(0xFFFF1744);

    final tl = math.max(h * 0.035, 3.0);

    for (final sd in const [-1.0, 1.0]) {
      canvas.drawRect(
        Rect.fromCenter(center: Offset(c.dx + sd * w * 0.3, c.dy + h / 2 - tl), width: w * 0.22, height: tl),
        paint,
      );
    }

    paint.color = const Color(0xFFFFF59D);

    for (final sd in const [-1.0, 1.0]) {
      canvas.drawCircle(Offset(c.dx + sd * w * 0.3, c.dy - h / 2 + 2.5), 2.2, paint);
    }
  }

  // ---------------------------------------------------------------
  // SHIELD, PARTICLES, NIGHT, FX
  // ---------------------------------------------------------------

  void _drawShield(Canvas canvas) {
    final c = Offset(s.bikeX, s.bikeTop + s.bikeH * 0.5);
    final r = s.bikeH * 0.72 * (1 + 0.04 * math.sin(s.clock * 8));

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          r,
          [const Color(0x0029B6F6), const Color(0x5529B6F6)],
          const [0.6, 1.0],
        ),
    );

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = const Color(0xFF81D4FA),
    );

    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.82),
      math.pi * 1.1,
      math.pi * 0.35,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.7),
    );
  }

  void _drawParticles(Canvas canvas) {
    final p = Paint();

    for (final pt in s.particles) {
      final t = (pt.life / pt.maxLife).clamp(0.0, 1.0).toDouble();
      final col = pt.color.withValues(alpha: (pt.color.a * t).clamp(0.0, 1.0));

      if (pt.glow) {
        p.blendMode = BlendMode.plus;
        p.color = col.withValues(alpha: col.a * 0.3);
        canvas.drawCircle(Offset(pt.x, pt.y), pt.size * 2.2, p);
      } else {
        p.blendMode = BlendMode.srcOver;
      }

      p.color = col;
      canvas.drawCircle(Offset(pt.x, pt.y), pt.size, p);
    }
  }

  void _drawNight(Canvas canvas, Size size) {
    if (s.night < 0.02) return;

    canvas.drawRect(
      Rect.fromLTWH(-30, -30, size.width + 60, size.height + 60),
      Paint()..color = const Color(0xFF050A24).withValues(alpha: 0.55 * s.night),
    );

    final plus = Paint()..blendMode = BlendMode.plus;

    // headlight cone
    final bx = s.bikeX;
    final top = s.bikeTop;
    const reach = 400.0;

    final cone = Path()
      ..moveTo(bx - s.bikeW * 0.18, top + s.bikeH * 0.05)
      ..lineTo(bx - s.laneW * 1.05, top - reach)
      ..lineTo(bx + s.laneW * 1.05, top - reach)
      ..lineTo(bx + s.bikeW * 0.18, top + s.bikeH * 0.05)
      ..close();

    plus.shader = ui.Gradient.linear(
      Offset(bx, top),
      Offset(bx, top - reach),
      [const Color(0xFFFFE9A8).withValues(alpha: 0.6 * s.night), const Color(0x00FFE9A8)],
    );
    canvas.drawPath(cone, plus);

    // tail light glow of the traffic
    for (final v in s.vehicles) {
      final h = s.carH * v.len;
      final w = s.carW * v.wf;
      final cx = s.laneCenter(v.lane);

      for (final sd in const [-1.0, 1.0]) {
        final pos = Offset(cx + sd * w * 0.3, v.y + h / 2);

        plus.shader = ui.Gradient.radial(
          pos,
          24,
          [const Color(0xFFFF1744).withValues(alpha: 0.75 * s.night), const Color(0x00FF1744)],
        );
        canvas.drawCircle(pos, 24, plus);
      }
    }

    // street lamps
    const spacing = 110.0;
    final k0 = ((s.worldDist - size.height - 120) / spacing).floor();
    final k1 = ((s.worldDist + 120) / spacing).ceil();

    for (var k = k0; k <= k1; k++) {
      if (k % 3 != 0) continue;

      final y0 = s.worldDist - k * spacing;

      for (final x in [s.roadLeft - 7.5, s.roadLeft + s.roadW + 7.5]) {
        plus.shader = ui.Gradient.radial(
          Offset(x, y0),
          70,
          [const Color(0xFFFFE082).withValues(alpha: 0.55 * s.night), const Color(0x00FFE082)],
        );
        canvas.drawCircle(Offset(x, y0), 70, plus);
      }
    }
  }

  void _drawSpeedLines(Canvas canvas, Size size) {
    if (s.speedFx < 0.15) return;

    final len = 30 + s.speedFx * 90;
    final p = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.18 * s.speedFx);

    for (var i = 0; i < 14; i++) {
      final x = s.roadLeft + _hash(i, 31) * s.roadW;
      final y = ((s.worldDist * 1.7 + _hash(i, 37) * size.height * 1.5) %
              (size.height + len)) -
          len;

      canvas.drawLine(Offset(x, y), Offset(x, y + len), p);
    }
  }

  void _drawFloats(Canvas canvas) {
    for (final f in s.floats) {
      final a = (f.life / 0.9).clamp(0.0, 1.0).toDouble();

      final tp = TextPainter(
        text: TextSpan(
          text: f.text,
          style: TextStyle(
            color: f.color.withValues(alpha: a),
            fontSize: 17,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: Colors.black.withValues(alpha: a * 0.7), blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(f.x - tp.width / 2, f.y - tp.height / 2));
    }
  }

  // A red 150cc-style sports bike (black tail, gold front fork, dual
  // head lights, big mirrors) with a rider tucked low over the tank.
  // The front of the bike points up. While changing lane the bike leans.
  void _drawBike(Canvas canvas) {
    final w = bikeW;
    final h = bikeH;
    final cx = bikeX;

    double y(double f) => bikeTop + h * f;

    final paint = Paint();

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Shadow on the road (does not lean)
    paint.color = Colors.black26;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx + 3, y(0.5) + 4),
        width: w * 0.95,
        height: h * 1.05,
      ),
      paint,
    );

    canvas.save();
    canvas.translate(cx, y(0.5));
    canvas.rotate(lean);
    canvas.translate(-cx, -y(0.5));

    // ---- Boost flame (behind the bike) ----
    if (boosting) {
      final flame = Path()
        ..moveTo(cx - w * 0.1, y(0.96))
        ..lineTo(cx, y(1.28))
        ..lineTo(cx + w * 0.1, y(0.96))
        ..close();

      paint.color = const Color(0xFFFF6D00);
      canvas.drawPath(flame, paint);

      final inner = Path()
        ..moveTo(cx - w * 0.05, y(0.96))
        ..lineTo(cx, y(1.15))
        ..lineTo(cx + w * 0.05, y(0.96))
        ..close();

      paint.color = const Color(0xFFFFEB3B);
      canvas.drawPath(inner, paint);
    }

    // ---- Wheels (front at the top, rear at the bottom) ----
    paint.color = const Color(0xFF1A1A1A);

    // Rear tyre (wide)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, y(0.88)),
          width: w * 0.36,
          height: h * 0.25,
        ),
        Radius.circular(w * 0.12),
      ),
      paint,
    );

    // Front tyre
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, y(0.11)),
          width: w * 0.24,
          height: h * 0.22,
        ),
        Radius.circular(w * 0.1),
      ),
      paint,
    );

    // Rims
    paint.color = const Color(0xFF616161);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(cx, y(0.88)),
        width: w * 0.1,
        height: h * 0.2,
      ),
      paint,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(cx, y(0.11)),
        width: w * 0.08,
        height: h * 0.17,
      ),
      paint,
    );

    // ---- Gold front fork ----
    line
      ..color = const Color(0xFFE0A526)
      ..strokeWidth = w * 0.055;

    canvas.drawLine(
      Offset(cx - w * 0.08, y(0.13)),
      Offset(cx - w * 0.1, y(0.31)),
      line,
    );
    canvas.drawLine(
      Offset(cx + w * 0.08, y(0.13)),
      Offset(cx + w * 0.1, y(0.31)),
      line,
    );

    // ---- Exhaust (right side) ----
    paint.color = const Color(0xFF263238);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx + w * 0.26, y(0.8)),
          width: w * 0.11,
          height: h * 0.26,
        ),
        Radius.circular(w * 0.05),
      ),
      paint,
    );

    paint.color = const Color(0xFFB0BEC5);
    canvas.drawCircle(Offset(cx + w * 0.26, y(0.93)), w * 0.05, paint);

    // ---- Black tail section with LED tail light ----
    final tail = Path()
      ..moveTo(cx - w * 0.17, y(0.7))
      ..quadraticBezierTo(cx - w * 0.2, y(0.85), cx - w * 0.07, y(0.97))
      ..lineTo(cx + w * 0.07, y(0.97))
      ..quadraticBezierTo(cx + w * 0.2, y(0.85), cx + w * 0.17, y(0.7))
      ..close();

    paint.color = const Color(0xFF1A1A1A);
    canvas.drawPath(tail, paint);

    paint.color = const Color(0xFFFF3D00);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, y(0.955)),
          width: w * 0.15,
          height: h * 0.03,
        ),
        Radius.circular(w * 0.02),
      ),
      paint,
    );

    // ---- Red fairing + tank ----
    final body = Path()
      ..moveTo(cx, y(0.03))
      ..quadraticBezierTo(cx + w * 0.22, y(0.08), cx + w * 0.27, y(0.3))
      ..quadraticBezierTo(cx + w * 0.34, y(0.5), cx + w * 0.2, y(0.74))
      ..lineTo(cx - w * 0.2, y(0.74))
      ..quadraticBezierTo(cx - w * 0.34, y(0.5), cx - w * 0.27, y(0.3))
      ..quadraticBezierTo(cx - w * 0.22, y(0.08), cx, y(0.03))
      ..close();

    paint.color = const Color(0xFFD32F2F);
    canvas.drawPath(body, paint);

    // Black side panels
    paint.color = const Color(0xFF1A1A1A);

    for (final s in const [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + s * w * 0.22, y(0.56)),
          width: w * 0.08,
          height: h * 0.2,
        ),
        paint,
      );
    }

    // Yellow accent lines on the fairing
    line
      ..color = const Color(0xFFFFEB3B)
      ..strokeWidth = w * 0.03;

    for (final s in const [-1.0, 1.0]) {
      canvas.drawLine(
        Offset(cx + s * w * 0.1, y(0.18)),
        Offset(cx + s * w * 0.22, y(0.27)),
        line,
      );
    }

    // Smoked wind screen
    paint.color = const Color(0xFF263238).withValues(alpha: 0.75);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, y(0.2)),
        width: w * 0.24,
        height: h * 0.1,
      ),
      paint,
    );

    // Dual head lights
    paint.color = const Color(0xFFFFF59D);

    for (final s in const [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + s * w * 0.07, y(0.065)),
          width: w * 0.07,
          height: h * 0.03,
        ),
        paint,
      );
    }

    // ---- Mirrors ----
    line
      ..color = const Color(0xFF111111)
      ..strokeWidth = w * 0.03;

    for (final s in const [-1.0, 1.0]) {
      canvas.drawLine(
        Offset(cx + s * w * 0.18, y(0.25)),
        Offset(cx + s * w * 0.4, y(0.2)),
        line,
      );
    }

    paint.color = const Color(0xFF111111);

    for (final s in const [-1.0, 1.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx + s * w * 0.45, y(0.19)),
            width: w * 0.13,
            height: h * 0.07,
          ),
          Radius.circular(w * 0.04),
        ),
        paint,
      );
    }

    // ---- Rider: legs gripping the tank, boots on silver foot pegs ----
    paint.color = const Color(0xFF212121);

    for (final s in const [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + s * w * 0.3, y(0.55)),
          width: w * 0.2,
          height: h * 0.26,
        ),
        paint,
      );
    }

    paint.color = const Color(0xFFB0BEC5);

    for (final s in const [-1.0, 1.0]) {
      canvas.drawCircle(Offset(cx + s * w * 0.33, y(0.76)), w * 0.045, paint);
    }

    paint.color = const Color(0xFF111111);

    for (final s in const [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + s * w * 0.34, y(0.74)),
          width: w * 0.15,
          height: h * 0.1,
        ),
        paint,
      );
    }

    // ---- Clip-on handlebar ----
    line
      ..color = const Color(0xFF111111)
      ..strokeWidth = w * 0.05;

    canvas.drawLine(
      Offset(cx - w * 0.4, y(0.34)),
      Offset(cx + w * 0.4, y(0.34)),
      line,
    );

    // ---- Rider: arms to the handlebar ----
    line
      ..color = const Color(0xFF2B2B2B)
      ..strokeWidth = w * 0.14;

    for (final s in const [-1.0, 1.0]) {
      canvas.drawLine(
        Offset(cx + s * w * 0.24, y(0.5)),
        Offset(cx + s * w * 0.38, y(0.35)),
        line,
      );
    }

    // Gloves
    paint.color = const Color(0xFFD32F2F);

    for (final s in const [-1.0, 1.0]) {
      canvas.drawCircle(Offset(cx + s * w * 0.4, y(0.34)), w * 0.07, paint);
    }

    // ---- Rider: racing jacket (black with red shoulders) ----
    paint.color = const Color(0xFF1B1B1B);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, y(0.57)),
        width: w * 0.62,
        height: h * 0.3,
      ),
      paint,
    );

    paint.color = const Color(0xFFD32F2F);

    for (final s in const [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + s * w * 0.24, y(0.5)),
          width: w * 0.16,
          height: h * 0.1,
        ),
        paint,
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, y(0.6)),
          width: w * 0.06,
          height: h * 0.2,
        ),
        Radius.circular(w * 0.03),
      ),
      paint,
    );

    // ---- Rider: white full-face helmet with red stripe and dark visor ----
    paint.color = const Color(0xFFF5F5F5);
    canvas.drawCircle(Offset(cx, y(0.47)), w * 0.2, paint);

    paint.color = const Color(0xFFD32F2F);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, y(0.49)),
          width: w * 0.07,
          height: h * 0.1,
        ),
        Radius.circular(w * 0.03),
      ),
      paint,
    );

    paint.color = const Color(0xFF263238);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, y(0.415)),
        width: w * 0.25,
        height: h * 0.055,
      ),
      paint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BikePainter oldDelegate) => true;
}
