// lib/pages/tutor_selection_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class TutorSelectionPage extends StatefulWidget {
  final String lessonId, languageId, category;
  final int wordCount;
  const TutorSelectionPage({
    super.key,
    this.lessonId = '', this.languageId = 'English',
    this.category = '', this.wordCount = 50,
  });
  @override State<TutorSelectionPage> createState() => _TutorSelectionPageState();
}

class _TutorSelectionPageState extends State<TutorSelectionPage> {
  List<Map<String, dynamic>> _tutors = [];
  bool _loading = true, _isPremium = false;
  final _player = AudioPlayer();
  String? _playingId;

  // Demo tutors (ใช้เมื่อ Firestore ว่าง)
  final _demoTutors = [
    {'id':'yui','name':'Yui','language':'Japanese','gender':'หญิง',
     'voiceDesc':'เสียงใส ชัดเจน','isPremium':false,'flag':'🇯🇵'},
    {'id':'aiko','name':'Aiko','language':'Japanese','gender':'หญิง',
     'voiceDesc':'เสียงนุ่ม ฟังสบาย','isPremium':true,'flag':'🇯🇵'},
    {'id':'hana','name':'Hana','language':'Japanese','gender':'หญิง',
     'voiceDesc':'เสียงสุภาพ มั่นใจ','isPremium':true,'flag':'🇯🇵'},
    {'id':'sakura','name':'Sakura','language':'Japanese','gender':'หญิง',
     'voiceDesc':'เสียงสดใส เป็นธรรมชาติ','isPremium':true,'flag':'🇯🇵'},
    {'id':'haru','name':'Haru','language':'Japanese','gender':'ชาย',
     'voiceDesc':'เสียงอบอุ่น เป็นมิตร','isPremium':false,'flag':'🇯🇵'},
    {'id':'ren','name':'Ren','language':'Japanese','gender':'ชาย',
     'voiceDesc':'เสียงชัด หนักแน่น','isPremium':true,'flag':'🇯🇵'},
    {'id':'kaito','name':'Kaito','language':'Japanese','gender':'ชาย',
     'voiceDesc':'เสียงสุภาพ มีอาชีพ','isPremium':true,'flag':'🇯🇵'},
    {'id':'daichi','name':'Daichi','language':'Japanese','gender':'ชาย',
     'voiceDesc':'เสียงนุ่มลึก มั่นคง','isPremium':true,'flag':'🇯🇵'},
  ];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final u = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      _isPremium = u.data()?['package'] == 'premium';
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('tutors')
          .where('language', isEqualTo: widget.languageId)
          .get();
      if (!mounted) return;
      setState(() {
        _tutors = snap.docs.isEmpty ? _demoTutors
            : snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _tutors = _demoTutors; _loading = false; });
    }
  }

  Future<void> _tryVoice(Map<String, dynamic> t) async {
    final url = t['audioSampleUrl'] as String?;
    if (url == null) { _snack('ไม่พบตัวอย่างเสียง'); return; }
    if (_playingId == t['id']) {
      await _player.stop(); setState(() => _playingId = null); return;
    }
    await _player.play(UrlSource(url));
    setState(() => _playingId = t['id'] as String?);
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingId = null);
    });
  }

  void _select(Map<String, dynamic> t) {
    final locked = t['isPremium'] == true && !_isPremium;
    if (locked) { Navigator.pushNamed(context, '/premium'); return; }
    Navigator.pushNamed(context, '/practice', arguments: {
      'tutorId': t['id'],
      'lessonId': widget.lessonId.isEmpty ? 'demo_lesson' : widget.lessonId,
      'languageId': widget.languageId,
    });
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(m), backgroundColor: AppColors.primary));

  @override
  void dispose() { _player.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const ShadowsAppBar(showBack: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('เลือกครู AI', style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800,
                    color: AppColors.text, fontFamily: 'NotoSans')),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text('เลือกครูที่คุณต้องการฝึกด้วย',
                    style: TextStyle(fontSize: 13, color: AppColors.textHint, fontFamily: 'NotoSans')),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, childAspectRatio: 0.65,
                      crossAxisSpacing: 10, mainAxisSpacing: 10,
                    ),
                    itemCount: _tutors.length,
                    itemBuilder: (_, i) => _TutorCard(
                      tutor: _tutors[i],
                      isPremium: _isPremium,
                      isPlaying: _playingId == _tutors[i]['id'],
                      onTryVoice: () => _tryVoice(_tutors[i]),
                      onSelect: () => _select(_tutors[i]),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            )),
      bottomNavigationBar: const ShadowsBottomNav(activeIndex: 1),
    );
  }
}

class _TutorCard extends StatelessWidget {
  final Map<String, dynamic> tutor;
  final bool isPremium, isPlaying;
  final VoidCallback onTryVoice, onSelect;
  const _TutorCard({
    required this.tutor, required this.isPremium,
    required this.isPlaying, required this.onTryVoice,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final locked = tutor['isPremium'] == true && !isPremium;
    final isFree = tutor['isPremium'] != true;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        // Photo
        Stack(children: [
          Container(
            height: 130, width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5E9),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: tutor['photoUrl'] != null
                ? ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                    child: Image.network(tutor['photoUrl'], fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.person, size: 60, color: AppColors.primaryLight))))
                : const Center(child: Icon(Icons.person, size: 60, color: AppColors.primaryLight)),
          ),
          if (isFree)
            Positioned(top: 8, left: 8, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surface50, borderRadius: BorderRadius.circular(20)),
              child: const Text('ใช้ฟรี', style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: AppColors.primary, fontFamily: 'NotoSans')),
            )),
          if (locked)
            const Positioned(top: 8, right: 8, child: LockBadge()),
        ]),
        // Info
        Padding(padding: const EdgeInsets.fromLTRB(10, 8, 10, 0), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tutor['name'] as String? ?? '',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
              color: AppColors.text, fontFamily: 'NotoSans')),
          const SizedBox(height: 2),
          Row(children: [
            Text(tutor['flag'] as String? ?? '🌐', style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text('${tutor['language']} | ${tutor['gender']}',
              style: const TextStyle(fontSize: 11, color: AppColors.textHint, fontFamily: 'NotoSans')),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.volume_up, size: 12, color: AppColors.primary),
            const SizedBox(width: 3),
            Expanded(child: Text(tutor['voiceDesc'] as String? ?? '',
              style: const TextStyle(fontSize: 11, color: AppColors.primary, fontFamily: 'NotoSans'),
              overflow: TextOverflow.ellipsis)),
          ]),
        ])),
        // Buttons
        Padding(padding: const EdgeInsets.fromLTRB(8, 8, 8, 8), child: Column(children: [
          SizedBox(width: double.infinity, height: 32, child: OutlinedButton.icon(
            onPressed: onTryVoice,
            icon: Icon(isPlaying ? Icons.pause : Icons.headphones, size: 13, color: AppColors.primary),
            label: Text(isPlaying ? 'หยุดฟัง' : 'ทดลองฟังเสียง',
              style: const TextStyle(fontSize: 11, color: AppColors.primary, fontFamily: 'NotoSans')),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.surface200, width: 1.5),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          )),
          const SizedBox(height: 5),
          SizedBox(width: double.infinity, height: 32, child: ElevatedButton(
            onPressed: onSelect,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('เลือกครูนี้',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: AppColors.white, fontFamily: 'NotoSans')),
          )),
        ])),
      ]),
    );
  }
}
