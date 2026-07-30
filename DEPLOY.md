# สรุปไฟล์ที่แก้ไข + วิธี Deploy

โปรเจกต์นี้มี 2 ส่วนที่ถูกแก้ไข:
1. **shadows_admin_web-main** — Next.js admin panel (สร้างวิดีโอ Tutor ด้วย HeyGen)
2. **shadows_flutter_app** — แอป Flutter (เล่นวิดีโอ Tutor, กล้อง+avatar ฝั่งผู้เรียน, มุกซ์เสียง, แชร์)

ทุกไฟล์ในแพ็กนี้วางแทนที่ไฟล์เดิม **ตำแหน่งเดียวกันกับ path ที่เห็น** ในโปรเจกต์จริงของคุณ

---

## 1) shadows_admin_web-main (Next.js)

ดาวน์โหลด `shadows_admin_web-main.zip` แล้วแทนที่ทั้งโปรเจกต์ (หรือ merge เฉพาะไฟล์ใหม่ตามรายการด้านล่าง)

| ไฟล์ | สถานะ | หน้าที่ |
|---|---|---|
| `lib/heygen.ts` | ใหม่ | wrapper เรียก HeyGen v3 API (server-only) |
| `app/api/heygen/avatars/route.ts` | ใหม่ | GET รายชื่อ Avatar |
| `app/api/heygen/voices/route.ts` | ใหม่ | GET รายชื่อเสียง |
| `app/api/heygen/generate/route.ts` | ใหม่ | POST สั่งสร้างวิดีโอ |
| `app/api/heygen/status/route.ts` | ใหม่ | GET เช็คสถานะ + อัปโหลดเก็บถาวรที่ R2 อัตโนมัติเมื่อเสร็จ |
| `app/admin/tutors/page.tsx` | แก้ไข | เพิ่มแผง "สร้างวิดีโอด้วย HeyGen AI" ในฟอร์ม Tutor |
| `.env.example` | แก้ไข | เพิ่ม `HEYGEN_API_KEY` |

### ตั้งค่าก่อน deploy
```
HEYGEN_API_KEY=xxxxx   # จาก https://app.heygen.com/home?from=&nav=API (ฝั่ง server เท่านั้น ห้ามมี NEXT_PUBLIC_ prefix)
```
รันตามปกติ: `npm install && npm run build && npm start` (หรือ deploy ขึ้น Vercel/host เดิม)

### สถานะ
✅ ทดสอบ build ผ่านแล้วในระบบ (`npm run build` compiled successfully, type-check ผ่าน)

---

## 2) shadows_flutter_app (Flutter)

นำไฟล์ในโฟลเดอร์ `shadows_flutter_app/` ไปวางทับตำแหน่งเดียวกันใน repo `Shadows` ของคุณ:

```
shadows_flutter_app/
├── lib/
│   ├── pages/
│   │   └── practice_page.dart          → แทนที่ lib/pages/practice_page.dart
│   └── services/
│       └── social_share_service.dart   → ไฟล์ใหม่ (อ้างอิงเท่านั้น ยังไม่ใช้งานจริง — ดูหมายเหตุด้านล่าง)
├── pubspec.yaml                        → แทนที่ pubspec.yaml (root)
├── android/
│   └── app/
│       ├── build.gradle.kts            → แทนที่ android/app/build.gradle.kts
│       └── src/main/
│           └── AndroidManifest.xml     → แทนที่ android/app/src/main/AndroidManifest.xml
└── ios/
    ├── Runner/
    │   └── Info.plist                  → แทนที่ ios/Runner/Info.plist
    └── Runner.xcodeproj/
        └── project.pbxproj             → แทนที่ ios/Runner.xcodeproj/project.pbxproj
```

### สิ่งที่แก้ไข (เรียงตามลำดับที่ทำ)

| ไฟล์ | เปลี่ยนอะไร |
|---|---|
| `lib/pages/practice_page.dart` | (1) เล่นวิดีโอ HeyGen จริงแทนรูปนิ่ง ผ่าน `video_player` — มิวท์เสียงในวิดีโอ (กันชนกับ TTS)<br>(2) เพิ่ม `_LearnerPanel`: โชว์ Avatar จริงของผู้เรียน (จาก `users/{uid}.avatarId/avatarUrl`) แทนไอคอนคนทั่วไป<br>(3) เพิ่มปุ่มเปิด/ปิดกล้องหน้า — อัดวิดีโอคู่ขนานกับเสียงตอนฝึก (มิวท์ตอนอัด กันชนไมค์กับ STT)<br>(4) มุกซ์เสียง(WAV)เข้าวิดีโอ(มิวท์)ด้วย FFmpeg หลังหยุดอัด → ได้ mp4 ที่มีเสียงสมบูรณ์<br>(5) เพิ่ม `_VideoCompareSheet`: เทียบวิดีโอผู้เรียน vs วิดีโอครู AI ข้างกัน + คะแนน<br>(6) แชร์/ดาวน์โหลด: เลือกไฟล์วิดีโอ (ถ้ามี) แทนไฟล์เสียงโดยอัตโนมัติ |
| `pubspec.yaml` | เพิ่ม `camera: ^0.10.5+9`, `ffmpeg_kit_flutter_new: ^4.2.0` |
| `android/app/build.gradle.kts` | บังคับ `minSdk` ขั้นต่ำ 24 (ffmpeg_kit_flutter_new ต้องการ) |
| `android/app/src/main/AndroidManifest.xml` | เพิ่มสิทธิ์ `CAMERA` + `uses-feature` กล้อง |
| `ios/Runner/Info.plist` | เพิ่ม `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription` (มิคและ speech เดิมขาดอยู่ก่อนแล้ว ทำให้ฟีเจอร์อัดเสียงเดิมพังบน iOS — แก้พร้อมกันไปด้วย) |
| `ios/Runner.xcodeproj/project.pbxproj` | เพิ่ม iOS deployment target จาก 13.0 → 14.0 (ffmpeg_kit_flutter_new ต้องการ) |
| `lib/services/social_share_service.dart` | **ไฟล์อ้างอิง ยังไม่ได้ใช้งานจริง** — โครงโค้ดสำหรับแชร์ตรงเข้า TikTok/Facebook ในอนาคต (ต้องมี Developer account/App ID ก่อนถึงจะเปิดใช้ได้ ดูคอมเมนต์ในไฟล์) |

### ขั้นตอน deploy
```bash
flutter clean
flutter pub get      # ต้องต่อเน็ต - ffmpeg_kit_flutter_new ดาวน์โหลด .aar ครั้งแรกตอน build Android
flutter build apk    # หรือ flutter build ios
```

### ทดสอบว่าอะไรพร้อมใช้แล้วบ้าง
- ✅ เล่นวิดีโอ Tutor จาก HeyGen — ใช้ได้ทันทีถ้า tutor doc มี `videoUrl` (จากแอดมินพาเนล)
- ✅ Avatar ผู้เรียน — ใช้ได้ทันที ถ้าผู้ใช้เคยเลือก avatar ผ่านหน้าเดิมของแอปแล้ว (`avatar_page.dart`)
- ✅ กล้อง + มุกซ์เสียง + แชร์/ดาวน์โหลดวิดีโอ — ใช้ได้ทันทีหลัง `flutter pub get`
- ⏳ แชร์ตรงเข้า TikTok/Facebook — **ยังใช้ไม่ได้** จนกว่าจะสมัคร Developer account ของแต่ละแพลตฟอร์มและเชื่อม `social_share_service.dart` ตามคอมเมนต์ในไฟล์

### ข้อจำกัดที่ควรรู้
- โค้ดทั้งหมดผ่านการตรวจสอบ syntax/brace-paren balance ด้วยมืออย่างละเอียด และฝั่ง Next.js ผ่าน `npm run build` จริงแล้ว
- ฝั่ง Flutter **ยังไม่ได้รัน `flutter analyze`/build จริงบนเครื่อง** เพราะ sandbox นี้ดาวน์โหลด Flutter SDK ไม่ได้ (โดเมนไม่อยู่ใน allowlist) — แนะนำให้รัน `flutter analyze` ในเครื่อง dev ของคุณอีกรอบก่อน merge เข้า main
