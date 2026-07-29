// lib/pages/lesson_content_page.dart
// ─────────────────────────────────────────────────────────────
// หน้าเลือกเนื้อหาบทเรียน 50 คำ (5 ตัวเลือก) ก่อนไปหน้า Practice
// Flow: Lessons → (กด category) → LessonContentPage → Practice
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class LessonContentPage extends StatefulWidget {
  final String category;
  final String categoryIcon;
  final String languageId;
  final String tutorId;
  final int wordCount;

  const LessonContentPage({
    super.key,
    required this.category,
    required this.categoryIcon,
    required this.languageId,
    required this.tutorId,
    this.wordCount = 50,
  });

  @override
  State<LessonContentPage> createState() => _LessonContentPageState();
}

class _LessonContentPageState extends State<LessonContentPage> {
  List<_LessonItem> _lessons = [];
  bool _loading = true;
  int? _selectedIndex;

  // ── Default texts ต่อ category (fallback เมื่อไม่มี internet) ──
  static final Map<String, List<String>> _defaultTexts = {
    'Coffee Shop': [
      'Hello! Welcome to our coffee shop. What would you like to order today? We have hot and cold drinks. Our best sellers are the caramel latte and the iced Americano. Would you like to try one of those?',
      'Good morning! Can I get your order please? We have a special promotion today. Buy two drinks and get a free muffin. What size would you like? Small, medium, or large? We also have soy milk if you prefer.',
      'Hi there! Are you ready to order? Our new seasonal drink is the matcha frappuccino with whipped cream. It is very popular this week. Would you like to add a pastry on the side?',
      'Welcome! We just opened for the day. Our fresh-brewed coffee is ready. We use beans from Ethiopia and Colombia. Would you prefer a light roast or a dark roast? Let me know your preference.',
      'Thank you for visiting us today. Our barista will prepare your drink in just a few minutes. Please find a seat and we will call your name when it is ready. Would you like a receipt?',
    ],
    'Airport': [
      'Good afternoon. May I see your passport and boarding pass please? Your flight is scheduled to depart at three fifteen from gate B twelve. Please proceed through security and be at the gate thirty minutes before departure.',
      'Welcome to the check-in counter. Are you checking any luggage today? The weight limit per bag is twenty three kilograms. Please place your bag on the scale. Do you have any fragile items inside?',
      'Attention all passengers. Flight TG four zero two to Tokyo is now boarding. Please have your boarding pass and identification ready. Business class passengers may board first through door number one.',
      'Excuse me, could you help me find the baggage claim area? I just arrived from Bangkok and I cannot find my suitcase. It is a large blue bag with a yellow tag. I have been waiting for twenty minutes.',
      'Hello, I would like to report a delayed flight. My connection was missed because of the weather. Can you help me rebook my ticket? I need to arrive in London by tomorrow morning for an important meeting.',
    ],
    'Self Intro': [
      'Hi everyone! My name is Daniel and I am from Thailand. I am twenty five years old and I work as a software engineer. In my free time I enjoy listening to music and learning new languages. Nice to meet you all.',
      'Hello! I am happy to introduce myself today. My name is Noi and I study at Chulalongkorn University. My major is business administration. I am very interested in international trade and hope to work abroad someday.',
      'Good morning everyone. Please let me introduce myself. I have been working in marketing for five years. I love creative campaigns and social media strategy. Outside of work I enjoy cooking and hiking on weekends.',
      'Nice to meet you all. I recently moved to this city from Chiang Mai. It has been an exciting experience. I am currently looking for new friends and hoping to improve my English skills through daily conversation.',
      'Hello my name is Tom. I am a high school student who loves science and technology. My dream is to become a doctor one day. I spend most of my weekends reading medical books and watching educational videos online.',
    ],
    'Restaurant': [
      'Good evening and welcome to our restaurant. My name is James and I will be your server tonight. Can I start you off with some drinks? We have a great selection of wines and cocktails available tonight.',
      'Are you ready to order? Our chef recommends the grilled salmon with roasted vegetables tonight. It comes with a side of mashed potatoes and a lemon butter sauce. Would you like to start with our soup of the day?',
      'Excuse me, I think there may be a mistake with my order. I asked for the pasta without mushrooms but I can see mushrooms in the dish. Could you please ask the kitchen to prepare a new one for me?',
      'This meal looks absolutely wonderful. Could I please have the recipe for this sauce? It tastes amazing with the chicken. Also could we see the dessert menu when you get a chance? We definitely want something sweet.',
      'Thank you so much for the wonderful dining experience tonight. Everything was delicious especially the chocolate cake. Could we please have the bill when you are ready? We would also like to leave a tip.',
    ],
    'Hotel': [
      'Hello and welcome to the Grand Hotel. I have a reservation under the name Johnson. I booked a deluxe room for three nights. Could I also request a room on a higher floor with a city view if possible?',
      'Good morning! I am calling from room three fifteen. The air conditioning in my room does not seem to be working properly. It keeps making a strange noise throughout the night. Could someone come and check it?',
      'Excuse me, could you tell me where the nearest gym and swimming pool are located? Also what time does the breakfast buffet start? I would like to go for a swim before eating in the morning.',
      'I would like to extend my stay by two more nights if possible. Is the same room available? Also could you arrange for laundry service? I have some shirts that need to be cleaned for my meeting tomorrow.',
      'Thank you for a wonderful stay. I really enjoyed the facilities and the staff was very helpful throughout my visit. Could you call me a taxi to the airport? My flight departs at noon so I need to leave by nine.',
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    setState(() => _loading = true);
    try {
      // โหลดจาก Firestore — ดึงตาม category + language
      final snap = await FirebaseFirestore.instance
          .collection('lessons')
          .where('category', isEqualTo: widget.category)
          .where('language', isEqualTo: widget.languageId)
          .limit(10)
          .get();

      if (snap.docs.isNotEmpty) {
        // มีบทเรียนใน Firestore
        setState(() {
          _lessons = snap.docs.map((d) => _LessonItem(
            id: d.id,
            text: d.data()['text'] as String? ?? '',
          )).toList();
          _loading = false;
        });
        return;
      }

      // ไม่มีใน Firestore → ลอง generate จาก OpenAI
      await _generateLessons();
    } catch (_) {
      // fallback → ใช้ default texts
      _useDefaultTexts();
    }
  }

  Future<void> _generateLessons() async {
    // ไม่มีบทเรียนใน Firestore → ใช้ default text fallback
    _useDefaultTexts();
  }

  void _useDefaultTexts() {
    final texts = _defaultTexts[widget.category] ??
        _defaultTexts['Self Intro']!;
    if (!mounted) return;
    setState(() {
      _lessons = List.generate(texts.length, (i) => _LessonItem(
        id: 'default_${widget.category}_$i',
        text: texts[i],
      ));
      _loading = false;
    });
  }

  void _startPractice(int index) {
    final lesson = _lessons[index];
    Navigator.pushNamed(context, '/practice', arguments: {
      'tutorId':    widget.tutorId.isEmpty ? 'demo_tutor' : widget.tutorId,
      'lessonId':   lesson.id,
      'lessonText': lesson.text,
      'languageId': widget.languageId,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: ShadowsAppBar(showBack: true),
      body: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(widget.categoryIcon,
                  style: const TextStyle(fontSize: 24))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.category, style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700,
                color: AppColors.text, fontFamily: 'NotoSans',
              )),
              Text('เลือก 1 บทเรียน ${widget.wordCount} คำ',
                style: const TextStyle(
                  fontSize: 12, color: AppColors.textHint, fontFamily: 'NotoSans',
                )),
            ])),
          ]),
        ),

        // List
        Expanded(child: _loading
            ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 12),
                const Text('กำลังเตรียมบทเรียน...',
                  style: TextStyle(fontSize: 13, color: AppColors.textHint, fontFamily: 'NotoSans')),
              ])
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                itemCount: _lessons.length,
                itemBuilder: (_, i) => _LessonCard(
                  lesson: _lessons[i],
                  index: i,
                  isSelected: _selectedIndex == i,
                  onTap: () {
                    setState(() => _selectedIndex = i);
                    Future.delayed(const Duration(milliseconds: 200), () {
                      _startPractice(i);
                    });
                  },
                ),
              )),
      ]),
      bottomNavigationBar: const ShadowsBottomNav(activeIndex: 1),
    );
  }
}

// ── Lesson Item model ─────────────────────────────────────────
class _LessonItem {
  final String id;
  final String text;
  const _LessonItem({required this.id, required this.text});

  // ตัดแสดงเฉพาะ 2 บรรทัดแรก
  String get preview {
    final words = text.split(' ');
    if (words.length <= 20) return text;
    return '${words.take(20).join(' ')}...';
  }
}

// ── Lesson Card ───────────────────────────────────────────────
class _LessonCard extends StatelessWidget {
  final _LessonItem lesson;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;

  const _LessonCard({
    required this.lesson,
    required this.index,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surface50 : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6, offset: const Offset(0, 2),
          )],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // เลขที่
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surface100,
                shape: BoxShape.circle,
              ),
              child: Center(child: Text('${index + 1}',
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: isSelected ? AppColors.white : AppColors.primaryMid,
                  fontFamily: 'NotoSans',
                ))),
            ),
            const SizedBox(width: 12),
            // เนื้อหา
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(lesson.preview,
                style: const TextStyle(
                  fontSize: 13, color: AppColors.text,
                  height: 1.6, fontFamily: 'NotoSans',
                  fontStyle: FontStyle.italic,
                )),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.play_circle_outline,
                    size: 14, color: AppColors.primaryMid),
                const SizedBox(width: 4),
                const Text('เริ่มฝึก',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: AppColors.primaryMid, fontFamily: 'NotoSans',
                  )),
                const Spacer(flex: 1),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('เลือกแล้ว ✓',
                      style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: AppColors.white, fontFamily: 'NotoSans',
                      )),
                  ),
              ]),
            ])),
          ]),
        ),
      ),
    );
  }
}
