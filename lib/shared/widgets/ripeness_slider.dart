import 'package:flutter/material.dart';

const _ripenessColors = [
  Color(0xFF8BC34A), // 0 Necopt
  Color(0xFF4CAF50), // 1 Aproape copt
  Color(0xFF2ECC71), // 2 Copt
  Color(0xFFF39C12), // 3 Copt bine
  Color(0xFFE74C3C), // 4 Foarte copt
];

const _ripenessLabels = [
  'Necopt',
  'Aproape\ncopt',
  'Copt',
  'Copt\nbine',
  'Foarte\ncopt',
];

class RipenessSlider extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const RipenessSlider({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color = _ripenessColors[value.clamp(0, 4)];
    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color,
            inactiveTrackColor: color.withValues(alpha: 0.25),
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.18),
            trackHeight: 6,
            thumbShape:
                const RoundSliderThumbShape(enabledThumbRadius: 11),
          ),
          child: Slider(
            min: 0,
            max: 4,
            divisions: 4,
            value: value.toDouble(),
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(5, (i) {
            final c = _ripenessColors[i];
            final isSelected = i == value;
            return SizedBox(
              width: 58,
              child: Column(
                children: [
                  if (i == 2)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: c.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Ideal',
                        style: TextStyle(
                          fontSize: 8,
                          color: c,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 14),
                  const SizedBox(height: 2),
                  Text(
                    _ripenessLabels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      height: 1.3,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? c : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }
}

Color ripenessColor(double currentRipeness) {
  final clamped = currentRipeness.clamp(0.0, 4.0);
  final index = clamped.floor().clamp(0, 3);
  final t = clamped - index;
  return Color.lerp(
    _ripenessColors[index],
    _ripenessColors[index + 1],
    t,
  )!;
}
