// lib/services/social_share_service.dart
//
// ═══════════════════════════════════════════════════════════════
// ตัวอย่างโค้ดสำหรับ "แชร์ตรง" เข้าแพลตฟอร์ม (ไม่ผ่าน system share sheet)
// ═══════════════════════════════════════════════════════════════
// ⚠️ ไฟล์นี้เป็น "ตัวอย่างเผื่อไว้" — ยังไม่ได้เชื่อมเข้ากับ practice_page.dart จริง
// เพราะต้องมี Developer account + App ID/Client Key ของแต่ละแพลตฟอร์มก่อน
// ถึงจะทดสอบ/ใช้งานได้จริง (ไม่งั้น build จะพังเพราะ config ไม่ครบ)
//
// เมื่อสมัคร account เสร็จแล้ว ทำตามนี้:
//
// 1) เพิ่ม dependency ใน pubspec.yaml:
//      appinio_social_share_plus: ^latest
//
// 2) TikTok (iOS) ต้องเพิ่ม TikTok OpenSDK ผ่าน Swift Package Manager ใน Xcode เอง
//    (Add Packages... → https://github.com/tiktok/tiktok-opensdk-ios)
//    แล้วใส่ TikTokClientKey ใน ios/Runner/Info.plist:
//      <key>TikTokClientKey</key>
//      <string>YOUR_TIKTOK_CLIENT_KEY</string>
//      <key>LSApplicationQueriesSchemes</key>
//      <array>
//        <string>tiktokopensdk</string>
//        <string>tiktoksharesdk</string>
//        <string>snssdk1180</string>
//        <string>snssdk1233</string>
//      </array>
//
// 3) Facebook ต้องใส่ App ID ใน:
//    - android/app/src/main/res/values/strings.xml → facebook_app_id
//    - ios/Runner/Info.plist → FacebookAppID, FacebookClientToken, FacebookDisplayName
//
// 4) LINE: LINE **ไม่มี** public API ให้แชร์ไฟล์วิดีโอ/รูปตรงจากแอปอื่นแบบ TikTok/Facebook
//    (flutter_line_sdk มีแค่ LINE Login เท่านั้น) — สำหรับ LINE, system share sheet
//    ที่ใช้อยู่แล้วตอนนี้ (Share.shareXFiles ใน practice_page.dart) คือวิธีที่ถูกต้อง
//    และเป็นวิธีเดียวที่ทำได้แล้ว ไม่ต้องแก้อะไรเพิ่ม
//
// ═══════════════════════════════════════════════════════════════

// import 'package:appinio_social_share_plus/appinio_social_share_plus.dart';

class SocialShareService {
  // TODO: ใส่ App ID จริงหลังสมัคร Facebook for Developers
  static const String facebookAppId = 'YOUR_FACEBOOK_APP_ID';

  // TikTok ไม่ต้องใช้ client key ตอนเรียก share (ใส่ไว้ที่ Info.plist/Manifest แทน)
  // แต่เก็บ constant ไว้เผื่ออ้างอิง/debug
  static const String tiktokClientKey = 'YOUR_TIKTOK_CLIENT_KEY';

  // static final _social = AppinioSocialShare();

  /// แชร์วิดีโอตรงเข้า TikTok (เปิดแอป TikTok พร้อมวิดีโอ ให้ผู้ใช้กด "โพสต์" เอง)
  /// หมายเหตุ: TikTok Share Kit ไม่ให้แอปภายนอกโพสต์อัตโนมัติแบบไม่ผ่านผู้ใช้ยืนยัน
  /// (นี่เป็นข้อกำหนดของ TikTok เอง เพื่อป้องกันสแปม)
  static Future<bool> shareVideoToTikTok(String videoPath) async {
    // TODO: เปิดใช้เมื่อเพิ่ม dependency + setup TikTok OpenSDK แล้ว
    // try {
    //   final result = await _social.shareToTiktokPost([videoPath]);
    //   return result == true;
    // } catch (e) {
    //   return false;
    // }
    throw UnimplementedError(
      'ยังไม่ได้ตั้งค่า TikTok Client Key — ดูขั้นตอนที่คอมเมนต์ด้านบนของไฟล์นี้',
    );
  }

  /// แชร์วิดีโอตรงเข้า Facebook (เปิด Facebook share dialog พร้อมวิดีโอ)
  static Future<bool> shareVideoToFacebook(String videoPath) async {
    // TODO: เปิดใช้เมื่อเพิ่ม dependency + setup Facebook App ID แล้ว
    // try {
    //   final result = await _social.shareToFacebook(videoPath);
    //   return result == true;
    // } catch (e) {
    //   return false;
    // }
    throw UnimplementedError(
      'ยังไม่ได้ตั้งค่า Facebook App ID — ดูขั้นตอนที่คอมเมนต์ด้านบนของไฟล์นี้',
    );
  }

  /// ตรวจสอบว่าตั้งค่าแพลตฟอร์มไหนพร้อมใช้งานแล้วบ้าง (ยังไม่พร้อมสักอัน จนกว่าจะใส่ค่าจริง)
  static bool get isFacebookReady => facebookAppId != 'YOUR_FACEBOOK_APP_ID';
  static bool get isTikTokReady   => tiktokClientKey != 'YOUR_TIKTOK_CLIENT_KEY';
}

// ═══════════════════════════════════════════════════════════════
// ตัวอย่างการเรียกใช้ใน practice_page.dart (ในอนาคต เมื่อพร้อมแล้ว)
// ═══════════════════════════════════════════════════════════════
//
// แก้ _buildShareRow() ปุ่ม TikTok ให้เรียกตรงแทน (แทนที่จะเรียก _shareRecording ทั่วไป):
//
//   _ShareIcon(brand: _ShareBrand.tiktok, label: 'TikTok/Reels',
//     onTap: () async {
//       final completed = _recordings.where((r) => r.isCompleted).toList();
//       if (completed.isEmpty || completed.last.videoLocalPath == null) {
//         _showSnack('ต้องมีวิดีโอก่อนถึงจะแชร่ตรงเข้า TikTok ได้');
//         return;
//       }
//       if (!SocialShareService.isTikTokReady) {
//         // ยังไม่ได้ตั้งค่า → fallback ไปใช้ system share sheet แบบเดิม
//         _shareRecording(completed.last);
//         return;
//       }
//       final ok = await SocialShareService.shareVideoToTikTok(completed.last.videoLocalPath!);
//       if (!ok) _showSnack('แชร่เข้า TikTok ไม่สำเร็จ', isError: true);
//     }),
//
// รูปแบบเดียวกันนี้ใช้กับปุ่ม Facebook ได้เลย — ส่วนปุ่ม YouTube และ LINE
// แนะนำให้ยังคงเรียก _shareRecording() (system share sheet) แบบเดิมต่อไป
// เพราะ YouTube ต้องทำ resumable upload ผ่าน OAuth (ไม่ใช่ "แชร์" แบบนี้)
// และ LINE ไม่มี public API ให้แชร์ไฟล์ตรงตามที่อธิบายไว้ด้านบน
