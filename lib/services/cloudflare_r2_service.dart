// lib/services/cloudflare_r2_service.dart
// อ่าน URL รูปภาพจาก Firestore (ที่เก็บ R2 URLs)
// Flutter ไม่ต้อง upload โดยตรง — Admin Web จัดการให้
// Flutter แค่อ่าน URL จาก Firestore แล้วแสดงรูปด้วย CachedNetworkImage

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class R2Service {
  static final Map<String,String> _avatarUrls = {};
  static Map<String,String> _imageUrls  = {};
  static bool _loaded = false;

  // ── โหลด URLs จาก Firestore ──────────────────────────────
  static Future<void> init() async {
    if (_loaded) return;
    try {
      // โหลด avatar URLs
      final avatarSnap = await FirebaseFirestore.instance
          .collection('avatars').get();
      for (final d in avatarSnap.docs) {
        final url = d.data()['url'] as String?;
        if (url != null && url.isNotEmpty) _avatarUrls[d.id] = url;
        // เก็บ version จาก updatedAt
        final ts = d.data()['updatedAt'];
        if (ts != null) _avatarVersion = ts.toString();
      }
      // โหลด app image URLs
      final imgSnap = await FirebaseFirestore.instance
          .collection('appConfig').doc('images').get();
      if (imgSnap.exists) {
        _imageUrls = Map<String,String>.from(
          (imgSnap.data() ?? {}).map((k,v) => MapEntry(k, v.toString()))
        );
      }
      _loaded = true;
      debugPrint('R2: ${_avatarUrls.length} avatars, ${_imageUrls.length} images loaded');
    } catch (e) {
      debugPrint('R2 init error: $e');
      _loaded = true;
    }
  }

  static Future<void> reload() async {
    _loaded = false; _avatarUrls.clear(); _imageUrls.clear();
    await init();
  }

  // ── Avatar ─────────────────────────────────────────────────
  static String _avatarVersion = '';

  static String? avatarUrl(String avatarId) {
    final id = avatarId.startsWith('avatar_') ? avatarId
        : 'avatar_${avatarId.padLeft(2,'0')}';
    final url = _avatarUrls[id];
    if (url == null || url.isEmpty) return null;
    // cache-busting เมื่อรูปเปลี่ยน
    if (_avatarVersion.isNotEmpty && !url.contains('?v=')) {
      return '$url?v=$_avatarVersion';
    }
    return url;
  }

  static List<String?> get allAvatarUrls =>
      List.generate(25, (i) => _avatarUrls['avatar_${i.toString().padLeft(2,'0')}']);

  // ── App Images ─────────────────────────────────────────────
  static String? imageUrl(String key) => _imageUrls[key];
  // ล้าง cache และโหลดใหม่
  static Future<void> clearCache() async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    await reload();
  }


  // Image keys
  static const mascotMain       = 'mascot_main';
  static const mascotPremium    = 'mascot_premium';
  static const mascotHalf       = 'mascot_half';
  static const logoIcon         = 'logo_icon';
  static const homeBannerBg     = 'home_banner_bg';
  static const leaderboardBanner= 'leaderboard_banner';
  static const profileBg        = 'profile_bg';
  static const profileBalloon   = 'profile_balloon';
  static const splashBg         = 'splash_bg';
}

// ── R2Image Widget ─────────────────────────────────────────
// ใช้แทน Image.asset ทุกที่ที่ต้องการรูปจาก R2
class R2Image extends StatelessWidget {
  final String imageKey;
  final double? width;
  final double? height;
  final BoxFit  fit;
  final Widget? placeholder;

  const R2Image({
    super.key,
    required this.imageKey,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    final url = R2Service.imageUrl(imageKey);
    if (url == null || url.isEmpty) {
      return placeholder ?? SizedBox(
        width: width, height: height,
        child: const Center(
          child: Icon(Icons.image_outlined, color: Color(0xFFCCCCCC), size: 32)),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      width: width, height: height, fit: fit,
      placeholder: (_,__) => SizedBox(
        width: width, height: height,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2E7D32)))),
      errorWidget: (_,__,___) => placeholder ?? SizedBox(
        width: width, height: height,
        child: const Center(
          child: Icon(Icons.broken_image_outlined, color: Color(0xFFCCCCCC), size: 32))),
    );
  }
}

// ── R2Avatar Widget ────────────────────────────────────────
class R2Avatar extends StatelessWidget {
  final String? avatarId;
  final double  size;
  final String  fallbackLetter;

  const R2Avatar({
    super.key,
    this.avatarId,
    this.size = 40,
    this.fallbackLetter = 'U',
  });

  @override
  Widget build(BuildContext context) {
    final url = avatarId != null ? R2Service.avatarUrl(avatarId!) : null;
    return Container(
      width: size, height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle, color: Color(0xFFE8F5E9)),
      clipBehavior: Clip.antiAlias,
      child: url != null
          ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover,
              errorWidget: (_,__,___) => _fallback())
          : _fallback(),
    );
  }

  Widget _fallback() => Center(
    child: Text(fallbackLetter.toUpperCase(),
      style: TextStyle(
        fontSize: size * 0.4,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF2E7D32),
        fontFamily: 'NotoSans',
      )));

}