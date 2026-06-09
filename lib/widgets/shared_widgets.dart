// lib/widgets/shared_widgets.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ─── Shadows Logo ─────────────────────────────────────────────
class ShadowsLogo extends StatelessWidget {
  final double size;
  const ShadowsLogo({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: size, height: size,
        decoration: const BoxDecoration(color: AppColors.surface50, shape: BoxShape.circle),
        child: Center(child: Text('S', style: TextStyle(
          fontSize: size * 0.5, fontWeight: FontWeight.w900,
          color: AppColors.primary, fontFamily: 'NotoSans',
        ))),
      ),
      const SizedBox(width: 8),
      Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Shadows', style: TextStyle(
          fontSize: size * 0.47, fontWeight: FontWeight.w700,
          color: AppColors.primary, fontFamily: 'NotoSans',
        )),
        Text('by yannawut', style: TextStyle(
          fontSize: size * 0.27, color: AppColors.textHint, fontFamily: 'NotoSans',
        )),
      ]),
    ]);
  }
}

// ─── App Bar ──────────────────────────────────────────────────
class ShadowsAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool showBack;
  final VoidCallback? onBack;
  final VoidCallback? onProfile;
  final String language;
  final List<Widget>? actions;

  const ShadowsAppBar({
    super.key,
    this.showBack = false,
    this.onBack,
    this.onProfile,
    this.language = 'English',
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      child: SafeArea(bottom: false, child: SizedBox(
        height: 60,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            if (showBack) ...[
              GestureDetector(
                onTap: onBack ?? () => Navigator.pop(context),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                    color: AppColors.white,
                  ),
                  child: const Icon(Icons.chevron_left, size: 22, color: AppColors.text),
                ),
              ),
              const SizedBox(width: 10),
            ],
            const ShadowsLogo(),
            const Spacer(),
            // Language button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(20),
                color: AppColors.white,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.language, size: 15, color: AppColors.textSub),
                const SizedBox(width: 4),
                Text(language, style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: AppColors.text, fontFamily: 'NotoSans',
                )),
                const SizedBox(width: 2),
                const Icon(Icons.keyboard_arrow_down, size: 14, color: AppColors.text),
              ]),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onProfile ?? () => Navigator.pushNamed(context, '/profile'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(20),
                  color: AppColors.white,
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.person_outline, size: 16, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text('Member', style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: AppColors.primary, fontFamily: 'NotoSans',
                  )),
                ]),
              ),
            ),
            if (actions != null) ...actions!,
          ]),
        ),
      )),
    );
  }
}

// ─── Bottom Navigation ────────────────────────────────────────
class ShadowsBottomNav extends StatelessWidget {
  final int activeIndex;
  final VoidCallback? onHome;
  final VoidCallback? onRecent;
  final VoidCallback? onProfile;

  const ShadowsBottomNav({
    super.key,
    this.activeIndex = 0,
    this.onHome,
    this.onRecent,
    this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(child: SizedBox(
        height: 60,
        child: Row(children: [
          _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home,
            label: 'Home', isActive: activeIndex == 0,
            onTap: onHome ?? () => Navigator.pushReplacementNamed(context, '/home')),
          _NavItem(icon: Icons.access_time_outlined, activeIcon: Icons.access_time,
            label: 'Recent', isActive: activeIndex == 1,
            onTap: onRecent ?? () => Navigator.pushNamed(context, '/lessons')),
          _NavItem(icon: Icons.person_outline, activeIcon: Icons.person,
            label: 'Profile', isActive: activeIndex == 2,
            onTap: onProfile ?? () => Navigator.pushNamed(context, '/profile')),
        ]),
      )),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _NavItem({
    required this.icon, required this.activeIcon,
    required this.label, this.isActive = false, this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(isActive ? activeIcon : icon, size: 24,
          color: isActive ? AppColors.primary : AppColors.textHint),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(
          fontSize: 11, fontFamily: 'NotoSans',
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
          color: isActive ? AppColors.primary : AppColors.textHint,
        )),
      ]),
    ),
  );
}

// ─── Green Button ─────────────────────────────────────────────
class GreenButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool isLoading;
  final double height;
  final double? width;
  final IconData? icon;

  const GreenButton({
    super.key, required this.text,
    this.onTap, this.isLoading = false,
    this.height = 52, this.width, this.icon,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width ?? double.infinity,
    height: height,
    child: ElevatedButton(
      onPressed: isLoading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: isLoading
          ? const SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2.5))
          : Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Icon(icon, size: 18, color: AppColors.white), const SizedBox(width: 8)],
              Text(text, style: AppText.btn),
            ]),
    ),
  );
}

// ─── Waveform Painter ─────────────────────────────────────────
class WaveformPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final Color accentColor;
  final double animValue;

  const WaveformPainter({
    required this.data,
    required this.color,
    required this.accentColor,
    required this.animValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barW = size.width / data.length - 1.5;
    final cy = size.height / 2;
    for (int i = 0; i < data.length; i++) {
      final frac = i / data.length;
      final raw = data[i] * size.height * 0.88;
      final h = raw * (0.65 + 0.35 * math.sin((frac + animValue) * math.pi * 2));
      final x = i * (size.width / data.length) + barW / 2;
      final barColor = Color.lerp(color, accentColor, frac)!;
      canvas.drawLine(
        Offset(x, cy - h.clamp(1.0, size.height * 0.95) / 2),
        Offset(x, cy + h.clamp(1.0, size.height * 0.95) / 2),
        Paint()
          ..color = barColor.withValues(alpha: 0.88)
          ..strokeWidth = barW
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter old) =>
      old.animValue != animValue || old.data != data;
}

// ─── Score Circle ─────────────────────────────────────────────
class ScoreCircle extends StatelessWidget {
  final int score;
  final double size;

  const ScoreCircle({super.key, required this.score, this.size = 80});

  Color get _color {
    if (score >= 80) return AppColors.scoreGreen;
    if (score >= 60) return const Color(0xFFFF9800);
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size, height: size,
    child: Stack(alignment: Alignment.center, children: [
      SizedBox(width: size, height: size, child: CircularProgressIndicator(
        value: score / 100, strokeWidth: 7,
        backgroundColor: AppColors.border,
        valueColor: AlwaysStoppedAnimation(_color),
        strokeCap: StrokeCap.round,
      )),
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text('$score%', style: TextStyle(
          fontSize: size * 0.21, fontWeight: FontWeight.w800,
          color: _color, fontFamily: 'NotoSans',
        )),
        Text('Match', style: TextStyle(
          fontSize: size * 0.12, color: AppColors.textHint, fontFamily: 'NotoSans',
        )),
      ]),
    ]),
  );
}

// ─── Section Header ───────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionText;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key, required this.title,
    this.subtitle, this.actionText, this.onAction,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(title, style: AppText.h3),
        const Spacer(),
        if (actionText != null)
          GestureDetector(
            onTap: onAction,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(actionText!, style: const TextStyle(
                fontSize: 13, color: AppColors.primaryMid, fontFamily: 'NotoSans',
              )),
              const Icon(Icons.chevron_right, size: 16, color: AppColors.primaryMid),
            ]),
          ),
      ]),
      if (subtitle != null) Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(subtitle!, style: AppText.tiny),
      ),
    ]),
  );
}

// ─── Premium Lock Badge ───────────────────────────────────────
class LockBadge extends StatelessWidget {
  final VoidCallback? onTap;
  const LockBadge({super.key, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 28, height: 28,
      decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
      child: const Icon(Icons.lock, size: 14, color: AppColors.white),
    ),
  );
}

// ─── Stat Box ─────────────────────────────────────────────────
class StatBox extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const StatBox({super.key, required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(icon, size: 17, color: AppColors.primaryMid),
        const SizedBox(width: 5),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: AppColors.text, fontFamily: 'NotoSans',
            ), overflow: TextOverflow.ellipsis),
            Text(label, style: AppText.tiny),
          ],
        )),
      ]),
    ),
  );
}

// ─── Language Card ────────────────────────────────────────────
class LanguageCard extends StatelessWidget {
  final String flag, name, totalHours, weeklyInfo, learners;
  final VoidCallback? onTap;

  const LanguageCard({
    super.key, required this.flag, required this.name,
    required this.totalHours, required this.weeklyInfo,
    required this.learners, this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Text(flag, style: const TextStyle(fontSize: 32)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600,
            color: AppColors.text, fontFamily: 'NotoSans',
          )),
          const Text('Practice time', style: TextStyle(
            fontSize: 11, color: AppColors.textHint, fontFamily: 'NotoSans',
          )),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(totalHours, style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700,
            color: AppColors.text, fontFamily: 'NotoSans',
          )),
          Text(weeklyInfo, style: AppText.tiny),
        ]),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.surface50,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.group, size: 13, color: AppColors.primaryMid),
            const SizedBox(width: 3),
            Text(learners, style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: AppColors.primaryMid, fontFamily: 'NotoSans',
            )),
          ]),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right, size: 16, color: AppColors.textHint),
      ]),
    ),
  );
}
