import 'package:flutter/material.dart';

class PlatformChip extends StatefulWidget {
  final String name;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const PlatformChip({
    super.key,
    required this.name,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  State<PlatformChip> createState() => _PlatformChipState();
}

class _PlatformChipState extends State<PlatformChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scale = Tween<double>(begin: 1, end: 0.88).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTap() async {
    await _ctrl.forward();
    await _ctrl.reverse();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: ScaleTransition(
        scale: _scale,
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color == Colors.black
                    ? const Color(0xFF1A1A1A)
                    : widget.name == 'More'
                        ? const Color(0xFF1A1A35)
                        : widget.color,
                border: widget.name == 'More'
                    ? Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.4), width: 1.5, style: BorderStyle.solid)
                    : null,
                boxShadow: widget.name != 'More'
                    ? [
                        BoxShadow(
                          color: widget.color.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : null,
              ),
              child: Icon(
                widget.icon,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.name,
              style: const TextStyle(
                color: Color(0xFF888AAA),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
