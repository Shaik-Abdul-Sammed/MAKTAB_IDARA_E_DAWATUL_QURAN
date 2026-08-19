import 'package:flutter/material.dart';
import 'package:maktab_app/config/app_colors.dart';

/// Maktab logo widget.
/// Shows `assets/images/ic_launcher.png` inside a teal/gold glowing ring.
/// Supports an optional shimmer-pulse animation when [animate] = true.
class MaktabLogo extends StatefulWidget {
  final double size;
  final bool showGlow;
  /// When true, a subtle pulse ring animates around the logo.
  final bool animate;

  const MaktabLogo({
    super.key,
    this.size = 40.0,
    this.showGlow = true,
    this.animate = false,
  });

  @override
  State<MaktabLogo> createState() => _MaktabLogoState();
}

class _MaktabLogoState extends State<MaktabLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    if (widget.animate) {
      _pulseCtrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(MaktabLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat(reverse: true);
    } else if (!widget.animate && _pulseCtrl.isAnimating) {
      _pulseCtrl.stop();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;

    Widget logo = Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: widget.showGlow
            ? [
                BoxShadow(
                  color: AppColors.goldAccent.withValues(alpha: 0.40),
                  blurRadius: s * 0.30,
                  spreadRadius: s * 0.06,
                ),
                BoxShadow(
                  color: AppColors.primaryTeal.withValues(alpha: 0.25),
                  blurRadius: s * 0.18,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
        border: Border.all(
          color: AppColors.goldAccent,
          width: s * 0.045,
        ),
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/ic_launcher.png',
          width: s,
          height: s,
          fit: BoxFit.cover,
          // Graceful fallback if asset is missing
          errorBuilder: (_, _, _) => _fallbackIcon(s),
        ),
      ),
    );

    if (!widget.animate) return logo;

    // Animated pulse ring wraps the base logo
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer pulse ring
            Transform.scale(
              scale: _pulseAnim.value,
              child: Container(
                width: s * 1.28,
                height: s * 1.28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.goldAccent
                        .withValues(alpha: 0.30 * (1 - (_pulseAnim.value - 0.85) / 0.23)),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            child!,
          ],
        );
      },
      child: logo,
    );
  }

  Widget _fallbackIcon(double s) {
    return Container(
      width: s,
      height: s,
      color: AppColors.primaryTeal,
      child: Center(
        child: Icon(
          Icons.menu_book_rounded,
          size: s * 0.55,
          color: AppColors.goldAccent,
        ),
      ),
    );
  }
}

class AppIconsGlow {
  static const Color goldGlow = Color(0x66FFD700);
}
