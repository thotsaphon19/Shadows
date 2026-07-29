// lib/pages/avatar_page.dart
// ดึง Avatar รูปจริงจาก Firestore (URL อยู่ใน R2)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class AvatarPage extends StatefulWidget {
  const AvatarPage({super.key});
  @override State<AvatarPage> createState() => _AvatarPageState();
}

class _AvatarPageState extends State<AvatarPage> {
  final _nameCtrl = TextEditingController();
  String  _selectedId  = 'avatar_00';
  String? _selectedUrl;
  bool    _isPremium   = false;
  bool    _saving      = false;
  bool    _loading     = true;

  // รูป Avatar จาก Firestore
  List<Map<String, dynamic>> _avatars = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    // โหลด Avatar list จาก Firestore
    final avatarSnap = await FirebaseFirestore.instance
        .collection('avatars')
        .orderBy('index')
        .get();

    final avatars = avatarSnap.docs.map((d) => {
      'id':        d.id,
      'url':       d.data()['url'] as String? ?? '',
      'label':     d.data()['label'] as String? ?? '',
      'isPremium': d.data()['isPremium'] as bool? ?? false,
      'index':     (d.data()['index'] as num?)?.toInt() ?? 0,
    }).toList();

    // โหลดข้อมูล user
    Map<String, dynamic> userData = {};
    if (uid != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(uid).get();
      userData = doc.data() ?? {};
    }

    if (mounted) {
      setState(() {
        _avatars    = avatars.isNotEmpty ? avatars : _fallbackAvatars();
        _nameCtrl.text = userData['displayName'] as String?
            ?? userData['nickname'] as String? ?? '';
        _selectedId  = userData['avatarId'] as String? ?? 'avatar_00';
        _isPremium   = userData['package'] == 'premium';
        _loading     = false;

        // หา URL ของ avatar ที่เลือกอยู่
        final found = _avatars.where((a) => a['id'] == _selectedId).toList();
        _selectedUrl = found.isNotEmpty ? found.first['url'] as String? : null;
      });
    }
  }

  // Fallback ถ้ายังไม่มีรูปใน Firestore
  List<Map<String, dynamic>> _fallbackAvatars() => List.generate(25, (i) => {
    'id':        'avatar_${i.toString().padLeft(2,'0')}',
    'url':       '',
    'label':     'Avatar ${i.toString().padLeft(2,'0')}',
    'isPremium': i > 0,
    'index':     i,
  });

  Future<void> _save() async {
    setState(() => _saving = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'displayName': _nameCtrl.text.trim(),
        'avatarId':    _selectedId,
        'avatarUrl':   _selectedUrl ?? '',
        'updatedAt':   FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกแล้ว ✓'),
          backgroundColor: AppColors.primary));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const ShadowsAppBar(showBack: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(child: Column(children: [

        // ── Preview Avatar ──────────────────────────────────
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            // รูป Avatar ที่เลือก
            Container(width: 80, height: 80,
              decoration: const BoxDecoration(
                color: AppColors.surface100, shape: BoxShape.circle),
              clipBehavior: Clip.antiAlias,
              child: _selectedUrl != null && _selectedUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: _selectedUrl!,
              cacheKey: _selectedUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_,__) => const Center(
                        child: CircularProgressIndicator(strokeWidth: 2,
                          color: AppColors.primary)),
                      errorWidget: (_,__,___) => const Icon(
                        Icons.person, size: 44, color: AppColors.primaryLight))
                  : const Icon(Icons.person, size: 44, color: AppColors.primaryLight)),
            const SizedBox(height: 16),

            // Display Name
            const Align(alignment: Alignment.centerLeft,
              child: Text('Display Name', style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'NotoSans'))),
            const SizedBox(height: 6),
            TextField(controller: _nameCtrl,
              decoration: const InputDecoration(
                hintText: 'ชื่อที่ต้องการแสดง',
                border: OutlineInputBorder())),
          ])),

        // ── Avatar Grid ────────────────────────────────────
        Padding(padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Row(children: [
            const Text('เลือก Avatar', style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'NotoSans')),
            const Spacer(),
            Text('${_avatars.length} รูป',
              style: AppText.tiny),
          ])),

        // ถ้าไม่มีรูปใน R2 ให้แสดงคำแนะนำ
        if (_avatars.every((a) => (a['url'] as String).isEmpty))
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFB300))),
            child: const Row(children: [
              Icon(Icons.info_outline, color: Color(0xFFFF8F00), size: 18),
              SizedBox(width: 8),
              Expanded(child: Text(
                'ยังไม่มีรูป Avatar — อัปโหลดได้ที่ Admin Web → Avatars',
                style: TextStyle(fontSize: 12, fontFamily: 'NotoSans',
                  color: Color(0xFF5D4037)))),
            ])),

        Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GridView.count(
            crossAxisCount: 5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            children: _avatars.map((av) {
              final id         = av['id'] as String;
              final url        = av['url'] as String;
              final isPrem     = av['isPremium'] as bool;
              final isSelected = id == _selectedId;
              final locked     = isPrem && !_isPremium;

              return GestureDetector(
                onTap: () {
                  if (locked) {
                    Navigator.pushNamed(context, '/premium');
                    return;
                  }
                  setState(() {
                    _selectedId  = id;
                    _selectedUrl = url.isNotEmpty ? url : null;
                  });
                },
                child: Stack(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.surface50
                          : AppColors.white,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                        width: isSelected ? 2 : 1),
                      borderRadius: BorderRadius.circular(8)),
                    clipBehavior: Clip.antiAlias,
                    child: url.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: url,
              cacheKey: url,
                            fit: BoxFit.cover,
                            placeholder: (_,__) => const Center(
                              child: SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: AppColors.primary))),
                            errorWidget: (_,__,___) => _avatarPlaceholder(av))
                        : _avatarPlaceholder(av)),

                  // Lock badge
                  if (locked) Positioned(top: 2, right: 2,
                    child: Container(width: 16, height: 16,
                      decoration: const BoxDecoration(
                        color: AppColors.gold, shape: BoxShape.circle),
                      child: const Icon(Icons.lock, size: 9,
                        color: AppColors.white))),

                  // Selected badge
                  if (isSelected) Positioned(top: 2, right: 2,
                    child: Container(width: 16, height: 16,
                      decoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.check, size: 10,
                        color: AppColors.white))),
                ]),
              );
            }).toList(),
          )),

        const SizedBox(height: 16),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GreenButton(
            text: 'บันทึก',
            isLoading: _saving,
            onTap: _save)),
        const SizedBox(height: 20),
      ])),
    );
  }

  Widget _avatarPlaceholder(Map<String, dynamic> av) {
    final index = av['index'] as int;
    const emojis = ['🌸','👑','🎾','🛹','🧣','📚','🎨','📸','🔬','💼',
                    '👨‍🍳','🎮','🎸','🚀','🎩','✈️','🎩','👨‍🚀','🔍','🛹',
                    '👗','☕','🚴','📷','✈️'];
    return Center(child: Text(
      index < emojis.length ? emojis[index] : '😊',
      style: const TextStyle(fontSize: 22)));
  }
}
