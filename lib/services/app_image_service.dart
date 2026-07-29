// lib/services/app_image_service.dart
// โหลด URL รูปภาพจาก Firestore appConfig/images
// Flutter app ใช้รูปเหล่านี้แสดงในทุกหน้าแทน placeholder

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AppImageService {
  static Map<String, String> _urls = {};
  static bool   _loaded  = false;
  static String _version = '';

  // ── โหลด URLs จาก Firestore ──────────────────────────────
  static Future<void> init() async {
    if (_loaded && _urls.isNotEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('appConfig').doc('images').get();
      if (snap.exists && snap.data() != null) {
        _urls = Map<String, String>.from(
          snap.data()!.map((k, v) => MapEntry(k, v.toString()))
        );
        debugPrint('AppImages loaded: ${_urls.length} images');
      } else {
        debugPrint('AppImages: appConfig/images not found in Firestore');
        debugPrint('Please upload images in Admin Web → App Images');
      }
      _loaded = true;
    } catch (e) {
      debugPrint('AppImages error: $e');
      // อย่า mark loaded ถ้า error — จะ retry ครั้งถัดไป
      if (e.toString().contains('permission-denied')) {
        debugPrint('Firestore permission denied — check rules');
      }
      _loaded = false;
    }
  }

  // ── reload เมื่อ admin อัปเดตรูป ─────────────────────────
  static Future<void> reload() async {
    _loaded = false;
    await init();
  }

  // ── ดึง URL ──────────────────────────────────────────────
  // คืน URL พร้อม cache-busting param ถ้ามี version
  static String? getUrl(String key) {
    final url = _urls[key];
    if (url == null || url.isEmpty) return null;
    // เพิ่ม ?v=timestamp เพื่อบังคับ reload เมื่อรูปเปลี่ยน
    if (_version.isNotEmpty && !url.contains('?v=')) {
      return '$url?v=$_version';
    }
    return url;
  }

  // ล้าง cache รูปภาพทั้งหมด (เรียกหลัง Admin อัปโหลดรูปใหม่)
  static Future<void> clearImageCache() async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    _loaded = false;
    await reload();
  }

  // ── Keys ทั้งหมด ──────────────────────────────────────────
  static const mascotMain      = 'mascot_main';
  static const mascotPremium   = 'mascot_premium';
  static const mascotHalf      = 'mascot_half';
  static const logoIcon        = 'logo_icon';
  static const homeBannerBg    = 'home_banner_bg';
  static const leaderboardBanner = 'leaderboard_banner';
  static const profileBg       = 'profile_bg';
  static const profileBalloon  = 'profile_balloon';
  static const splashBg        = 'splash_bg';
}

// ── AppImage Widget ──────────────────────────────────────────
// ใช้แทน Image.asset ทุกที่ที่ต้องการรูปจาก Admin
class AppImage extends StatelessWidget {
  final String imageKey;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;

  const AppImage({
    super.key,
    required this.imageKey,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    final url = AppImageService.getUrl(imageKey);

    if (url == null || url.isEmpty) {
      return placeholder ?? SizedBox(
        width: width, height: height,
        child: const Center(
          child: Icon(Icons.image_outlined, color: Color(0xFFCCCCCC), size: 32),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      placeholder: (_, __) => SizedBox(
        width: width, height: height,
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2, color: Color(0xFF2E7D32),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => placeholder ?? SizedBox(
        width: width, height: height,
        child: const Center(
          child: Icon(Icons.broken_image_outlined, color: Color(0xFFCCCCCC), size: 32),
        ),
      ),
    );
  }
}
