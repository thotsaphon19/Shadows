// ============================================================
// lib/pages/avatar_page.dart
// ============================================================
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class AvatarPage extends StatefulWidget {
  const AvatarPage({super.key});
  @override State<AvatarPage> createState() => _AvatarPageState();
}

class _AvatarPageState extends State<AvatarPage> {
  final _nameCtrl = TextEditingController();
  String _selectedId = '0';
  bool _isPremium = false, _saving = false;

  static const _avatars = [
    {'id':'0','emoji':'🌸🎧','isPremium':false},
    {'id':'1','emoji':'👑🎧','isPremium':true},
    {'id':'2','emoji':'🎾🎧','isPremium':true},
    {'id':'3','emoji':'🛹🎧','isPremium':true},
    {'id':'4','emoji':'🧣🎧','isPremium':true},
    {'id':'5','emoji':'📚🎧','isPremium':true},
    {'id':'6','emoji':'🎨🎧','isPremium':true},
    {'id':'7','emoji':'📸🎧','isPremium':true},
    {'id':'8','emoji':'🔬🎧','isPremium':true},
    {'id':'9','emoji':'💼🎧','isPremium':true},
    {'id':'10','emoji':'👨‍🍳🎧','isPremium':true},
    {'id':'11','emoji':'🎮🎧','isPremium':true},
    {'id':'12','emoji':'🎸🎧','isPremium':true},
    {'id':'13','emoji':'🚀🎧','isPremium':true},
    {'id':'14','emoji':'🎩🎧','isPremium':true},
  ];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data() ?? {};
    if (mounted) {
      setState(() {
      _nameCtrl.text = data['displayName'] as String? ?? '';
      _selectedId = data['avatarId'] as String? ?? '0';
      _isPremium = data['package'] == 'premium';
    });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'displayName': _nameCtrl.text.trim(),
        'avatarId': _selectedId,
      });
    }
    if (mounted) { setState(() => _saving = false); Navigator.pop(context); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const ShadowsAppBar(showBack: true),
      body: SingleChildScrollView(child: Column(children: [
        // Form card
        Container(margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Container(width: 80, height: 80,
              decoration: const BoxDecoration(color: AppColors.surface100, shape: BoxShape.circle),
              child: Center(child: Text(
                _avatars.firstWhere((a) => a['id'] == _selectedId,
                  orElse: () => _avatars.first)['emoji'] as String,
                style: const TextStyle(fontSize: 32)))),
            const SizedBox(height: 16),
            const Align(alignment: Alignment.centerLeft, child: Text('Display Name',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'NotoSans'))),
            const SizedBox(height: 6),
            TextField(controller: _nameCtrl, decoration: const InputDecoration(hintText: 'Display Name')),
            const SizedBox(height: 12),
            const Align(alignment: Alignment.centerLeft, child: Text('Age Group',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'NotoSans'))),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(initialValue: '18',
              decoration: const InputDecoration(),
              items: ['13','18','25','30','40','50+'].map((a) =>
                DropdownMenuItem(value: a, child: Text(a))).toList(),
              onChanged: (_) {}),
            const SizedBox(height: 12),
            const Align(alignment: Alignment.centerLeft, child: Text('Country',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'NotoSans'))),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(initialValue: 'Thailand',
              decoration: const InputDecoration(),
              items: ['Thailand','Japan','USA','UK','Korea','China'].map((c) =>
                DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (_) {}),
          ])),
        // Avatar grid
        Padding(padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Row(children: [
            const Text('Avatar', style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'NotoSans')),
            const Spacer(),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: AppColors.surface100, borderRadius: BorderRadius.circular(20)),
              child: const Text('Free', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: AppColors.primary, fontFamily: 'NotoSans'))),
          ])),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GridView.count(
            crossAxisCount: 5, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 6, mainAxisSpacing: 6,
            children: _avatars.map((av) {
              final isSelected = av['id'] == _selectedId;
              final locked = av['isPremium'] == true && !_isPremium;
              return GestureDetector(
                onTap: () {
                  if (locked) { Navigator.pushNamed(context, '/premium'); return; }
                  setState(() => _selectedId = av['id'] as String);
                },
                child: Stack(children: [
                  AnimatedContainer(duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                        width: isSelected ? 2 : 1),
                      borderRadius: BorderRadius.circular(8)),
                    child: Center(child: Text(av['emoji'] as String,
                      style: const TextStyle(fontSize: 22)))),
                  if (locked) Positioned(top: 2, right: 2, child: Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                    child: const Icon(Icons.lock, size: 9, color: AppColors.white))),
                  if (isSelected) Positioned(top: 2, right: 2, child: Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    child: const Icon(Icons.check, size: 10, color: AppColors.white))),
                ]),
              );
            }).toList(),
          )),
        const SizedBox(height: 16),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GreenButton(text: 'Save Profile', isLoading: _saving, onTap: _save)),
        const SizedBox(height: 20),
      ])),
    );
  }
}
