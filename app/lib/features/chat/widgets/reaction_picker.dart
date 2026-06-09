import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

const List<String> kDefaultReactions = ['👍', '❤️', '😂', '🎉', '😮', '😢'];

class ReactionPicker extends StatefulWidget {
  const ReactionPicker({
    super.key,
    required this.position,
    required this.onReactionSelected,
    this.reactions = kDefaultReactions,
  });

  final Offset position;
  final void Function(String reactionKey) onReactionSelected;
  final List<String> reactions;

  @override
  State<ReactionPicker> createState() => _ReactionPickerState();
}

class _ReactionPickerState extends State<ReactionPicker>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pickerWidth = widget.reactions.length * 44.0 + 16;
    final pickerHeight = 56.0;
    const padding = 8.0;

    double left = widget.position.dx - pickerWidth / 2;
    double top = widget.position.dy - pickerHeight - 20;

    if (left < padding) {
      left = padding;
    }
    if (left + pickerWidth > MediaQuery.of(context).size.width - padding) {
      left = MediaQuery.of(context).size.width - pickerWidth - padding;
    }
    if (top < padding) {
      top = widget.position.dy + 30;
    }

    return GestureDetector(
      onTap: () => _closePicker(),
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: _buildPickerContainer(pickerWidth, pickerHeight),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerContainer(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: widget.reactions.map((reaction) {
          return _buildReactionButton(reaction);
        }).toList(),
      ),
    );
  }

  Widget _buildReactionButton(String reaction) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _handleSelect(reaction),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Text(
            reaction,
            style: const TextStyle(fontSize: 22),
          ),
        ),
      ),
    );
  }

  void _handleSelect(String reaction) {
    widget.onReactionSelected(reaction);
    _closePicker();
  }

  void _closePicker() {
    _animationController.reverse().whenComplete(() {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }
}

Future<void> showReactionPicker({
  required BuildContext context,
  required Offset position,
  required void Function(String reactionKey) onReactionSelected,
  List<String> reactions = kDefaultReactions,
}) async {
  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 200),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return child;
    },
    pageBuilder: (context, animation, secondaryAnimation) {
      return ReactionPicker(
        position: position,
        onReactionSelected: onReactionSelected,
        reactions: reactions,
      );
    },
  );
}
