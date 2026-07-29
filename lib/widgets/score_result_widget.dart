// lib/widgets/score_result_widget.dart
// แสดงผลคะแนน Pronunciation หลังฝึกพูด
// ใช้ใน PracticePage หลัง stopRecording + assessPronunciation

import 'package:flutter/material.dart';
import '../services/pronunciation_service.dart';
import '../theme/app_theme.dart';

class ScoreResultWidget extends StatelessWidget {
  final PronunciationResult result;
  final VoidCallback? onClose;
  final VoidCallback? onRetry;

  const ScoreResultWidget({
    super.key,
    required this.result,
    this.onClose,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 20, offset: const Offset(0, 4),
        )],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // ── Header ─────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: BoxDecoration(
            color: result.color.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(children: [
            // Big score circle
            SizedBox(
              width: 88, height: 88,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox(
                  width: 88, height: 88,
                  child: CircularProgressIndicator(
                    value: result.pronScore / 100,
                    strokeWidth: 8,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation(result.color),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${result.pronScore}%',
                    style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800,
                      color: result.color, fontFamily: 'NotoSans',
                    )),
                  const Text('Match', style: TextStyle(
                    fontSize: 10, color: AppColors.textHint, fontFamily: 'NotoSans',
                  )),
                ]),
              ]),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: result.color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Grade ${result.grade}',
                    style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: Colors.white, fontFamily: 'NotoSans',
                    )),
                ),
              ]),
              const SizedBox(height: 8),
              _ScoreBar(label: 'Accuracy',     score: result.accuracyScore,     color: const Color(0xFF4CAF50)),
              const SizedBox(height: 4),
              _ScoreBar(label: 'Fluency',      score: result.fluencyScore,       color: const Color(0xFF2196F3)),
              const SizedBox(height: 4),
              _ScoreBar(label: 'Completeness', score: result.completenessScore,  color: const Color(0xFF9C27B0)),
            ])),
          ]),
        ),

        // ── Recognized text ────────────────────────────────
        if (result.recognizedText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Recognized:', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: AppColors.textHint, fontFamily: 'NotoSans',
              )),
              const SizedBox(height: 4),
              Text(result.recognizedText, style: const TextStyle(
                fontSize: 13, color: AppColors.text,
                fontFamily: 'NotoSans', height: 1.5,
              )),
            ]),
          ),

        // ── Word-level scores ──────────────────────────────
        if (result.words.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Word-by-word:', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: AppColors.textHint, fontFamily: 'NotoSans',
              )),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: result.words.map((w) => _WordChip(word: w)).toList(),
              ),
            ]),
          ),

        // ── Buttons ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            if (onRetry != null)
              Expanded(child: OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Try Again'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              )),
            if (onRetry != null && onClose != null) const SizedBox(width: 10),
            if (onClose != null)
              Expanded(child: ElevatedButton.icon(
                onPressed: onClose,
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Done'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              )),
          ]),
        ),
      ]),
    );
  }
}

// ── Score bar mini ────────────────────────────────────────────
class _ScoreBar extends StatelessWidget {
  final String label;
  final int score;
  final Color color;
  const _ScoreBar({required this.label, required this.score, required this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
    SizedBox(width: 72, child: Text(label, style: const TextStyle(
      fontSize: 10, color: AppColors.textSub, fontFamily: 'NotoSans',
    ))),
    Expanded(child: ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: score / 100,
        backgroundColor: AppColors.border,
        valueColor: AlwaysStoppedAnimation(color),
        minHeight: 6,
      ),
    )),
    const SizedBox(width: 6),
    Text('$score', style: TextStyle(
      fontSize: 11, fontWeight: FontWeight.w700,
      color: color, fontFamily: 'NotoSans',
    )),
  ]);
}

// ── Word chip ─────────────────────────────────────────────────
class _WordChip extends StatelessWidget {
  final WordScore word;
  const _WordChip({required this.word});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: word.errorType == 'None'
        ? '${word.accuracyScore}%'
        : '${word.errorType} (${word.accuracyScore}%)',
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: word.wordColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: word.wordColor.withValues(alpha: 0.4)),
      ),
      child: Text(word.word, style: TextStyle(
        fontSize: 12, color: word.wordColor,
        fontWeight: word.hasError ? FontWeight.w700 : FontWeight.w400,
        fontFamily: 'NotoSans',
      )),
    ),
  );
}

// ── Show as bottom sheet ───────────────────────────────────────
void showScoreResultSheet(BuildContext context, PronunciationResult result, {VoidCallback? onRetry}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, ctrl) => SingleChildScrollView(
        controller: ctrl,
        child: ScoreResultWidget(
          result: result,
          onClose: () => Navigator.pop(context),
          onRetry: onRetry,
        ),
      ),
    ),
  );
}
