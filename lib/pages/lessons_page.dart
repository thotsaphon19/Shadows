// lib/pages/lessons_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class LessonsPage extends StatefulWidget {
  final String languageId;
  const LessonsPage({super.key, this.languageId = 'English'});
  @override State<LessonsPage> createState() => _LessonsPageState();
}

class _LessonsPageState extends State<LessonsPage> {
  int _wordCount = 50;
  bool _isPremium = false;
  bool _generating = false;
  final _textCtrl = TextEditingController();

  static const _cats = [
    {'icon':'☕','name':'Coffee Shop','color':Color(0xFFFF9800)},
    {'icon':'✈️','name':'Airport','color':Color(0xFF2196F3)},
    {'icon':'🛎️','name':'Hotel','color':Color(0xFF9C27B0)},
    {'icon':'🍴','name':'Restaurant','color':Color(0xFFF44336)},
    {'icon':'🛍️','name':'Shopping','color':Color(0xFFE91E63)},
    {'icon':'🙋','name':'Self Intro','color':Color(0xFF4CAF50)},
    {'icon':'💼','name':'Job Interview','color':Color(0xFF795548)},
    {'icon':'📊','name':'Business','color':Color(0xFF009688)},
    {'icon':'📞','name':'Phone Call','color':Color(0xFF4CAF50)},
    {'icon':'✉️','name':'Short Email','color':Color(0xFF3F51B5)},
    {'icon':'🚦','name':'Directions','color':Color(0xFFFF9800)},
    {'icon':'🚕','name':'Taxi Ride','color':Color(0xFFFFC107)},
    {'icon':'🚆','name':'Train & Bus','color':Color(0xFF2196F3)},
    {'icon':'🏥','name':'Hospital','color':Color(0xFFF44336)},
    {'icon':'💊','name':'Pharmacy','color':Color(0xFF00BCD4)},
    {'icon':'👫','name':'Making Friends','color':Color(0xFFE91E63)},
    {'icon':'👨‍👩‍👧','name':'Family Talk','color':Color(0xFFFF9800)},
    {'icon':'🎨','name':'Hobbies','color':Color(0xFF4CAF50)},
    {'icon':'📅','name':'Weekend Plans','color':Color(0xFF2196F3)},
    {'icon':'🚨','name':'Emergency','color':Color(0xFFF44336)},
  ];

  @override
  void initState() { super.initState(); _checkPremium(); }

  Future<void> _checkPremium() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (mounted) setState(() => _isPremium = doc.data()?['package'] == 'premium');
  }

  Future<void> _startCategory(String cat) async {
    setState(() => _generating = true);
    try {
      // Try to generate with OpenAI via Cloud Function
      final fn = FirebaseFunctions.instanceFor(region: 'asia-southeast1');
      final res = await fn.httpsCallable('generateLesson').call({
        'category': cat, 'wordCount': _wordCount, 'language': widget.languageId,
      });
      final text = res.data['text'] as String? ?? _defaultText(cat);
      if (!mounted) return;
      // Save as temp lesson
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
      final lessonRef = await FirebaseFirestore.instance.collection('lessons').add({
        'text': text, 'category': cat, 'wordCount': _wordCount,
        'language': widget.languageId, 'createdBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _goToPractice(lessonRef.id);
    } catch (_) {
      // Fallback: use default text
      final lessonId = 'demo_${cat.replaceAll(' ', '_').toLowerCase()}';
      _goToPractice(lessonId);
    }
    if (mounted) setState(() => _generating = false);
  }

  String _defaultText(String cat) =>
      'Hello everyone. My name is Daniel, and today I want to talk about my daily routine. '
      'I usually wake up at six o\'clock in the morning. The first thing I do is drink a glass '
      'of water because it helps me feel fresh and awake. After that, I brush my teeth and take a shower.';

  Future<void> _startCustom() async {
    if (_textCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอก text ก่อน'), backgroundColor: AppColors.error));
      return;
    }
    setState(() => _generating = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
      final lessonRef = await FirebaseFirestore.instance.collection('lessons').add({
        'text': _textCtrl.text.trim(), 'category': 'Custom',
        'wordCount': _wordCount, 'language': widget.languageId,
        'createdBy': uid, 'createdAt': FieldValue.serverTimestamp(),
      });
      _goToPractice(lessonRef.id);
    } catch (_) {
      _goToPractice('demo_custom');
    }
    if (mounted) setState(() => _generating = false);
  }

  void _goToPractice(String lessonId) {
    Navigator.pushNamed(context, '/tutors', arguments: {
      'lessonId': lessonId,
      'wordCount': _wordCount,
      'languageId': widget.languageId,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const ShadowsAppBar(showBack: true),
      body: SingleChildScrollView(child: Column(children: [
        _buildWordToggle(),
        _buildGrid(),
        _buildCreateSection(),
        const SizedBox(height: 20),
      ])),
      bottomNavigationBar: const ShadowsBottomNav(activeIndex: 1),
    );
  }

  Widget _buildWordToggle() => Padding(
    padding: const EdgeInsets.all(12),
    child: Row(children: [
      _WordOpt(count: 50, label: 'For Everyone',
        icon: '👤', isActive: _wordCount == 50,
        onTap: () => setState(() => _wordCount = 50)),
      const SizedBox(width: 10),
      _WordOpt(count: 100, label: _isPremium ? 'For Members' : 'Members Only',
        icon: _isPremium ? '👑' : '🔒', isActive: _wordCount == 100,
        onTap: () {
          if (!_isPremium) { Navigator.pushNamed(context, '/premium'); return; }
          setState(() => _wordCount = 100);
        }),
    ]),
  );

  Widget _buildGrid() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    child: GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5, childAspectRatio: 0.75,
        crossAxisSpacing: 8, mainAxisSpacing: 8,
      ),
      itemCount: _cats.length,
      itemBuilder: (_, i) {
        final c = _cats[i];
        return GestureDetector(
          onTap: _generating ? null : () => _startCategory(c['name'] as String),
          child: Column(children: [
            Container(width: 54, height: 54,
              decoration: BoxDecoration(
                color: c['color'] as Color,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 6, offset: const Offset(0, 2),
                )],
              ),
              child: Center(child: Text(c['icon'] as String,
                style: const TextStyle(fontSize: 26)))),
            const SizedBox(height: 4),
            Text(c['name'] as String,
              style: AppText.tiny, textAlign: TextAlign.center,
              maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        );
      },
    ),
  );

  Widget _buildCreateSection() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 12),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(children: [
      const Text('Create Lesson', style: TextStyle(
        fontSize: 17, fontWeight: FontWeight.w700,
        color: AppColors.text, fontFamily: 'NotoSans')),
      const SizedBox(height: 12),
      _buildWordToggle(),
      const SizedBox(height: 4),
      const Align(alignment: Alignment.centerLeft, child: Row(children: [
        Text('Text for creating a lesson', style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'NotoSans')),
        SizedBox(width: 4),
        Icon(Icons.info_outline, size: 14, color: AppColors.textHint),
      ])),
      const SizedBox(height: 6),
      TextField(controller: _textCtrl, maxLines: 4,
        decoration: const InputDecoration(
          hintText: 'Paste text from ChatGPT or type here',
          border: OutlineInputBorder(),
        )),
      const SizedBox(height: 4),
      const Row(children: [
        Icon(Icons.info_outline, size: 12, color: AppColors.textHint),
        SizedBox(width: 4),
        Text('Maximum 100 words', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
      ]),
      const SizedBox(height: 14),
      GreenButton(
        text: 'Start Practice',
        isLoading: _generating,
        onTap: _startCustom,
      ),
    ]),
  );
}

class _WordOpt extends StatelessWidget {
  final int count;
  final String label, icon;
  final bool isActive;
  final VoidCallback onTap;
  const _WordOpt({required this.count, required this.label,
    required this.icon, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.surface50 : AppColors.white,
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.border,
            width: isActive ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text('$count Words', style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700,
            color: isActive ? AppColors.primary : AppColors.text,
            fontFamily: 'NotoSans',
          )),
          Text(label, style: AppText.tiny),
        ]),
      ),
    ),
  );
}
