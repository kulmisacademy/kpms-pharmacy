import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Premium 6-digit OTP: distinct cells, active-cell focus ring, paste, haptics.
class KpmsOtpInput extends StatefulWidget {
  const KpmsOtpInput({
    super.key,
    required this.controller,
    this.enabled = true,
    this.autofocus = false,
    this.onCompleted,
    this.pasteLabel = 'Paste code',
  });

  final TextEditingController controller;
  final bool enabled;
  final bool autofocus;
  final ValueChanged<String>? onCompleted;
  final String pasteLabel;

  @override
  State<KpmsOtpInput> createState() => _KpmsOtpInputState();
}

class _KpmsOtpInputState extends State<KpmsOtpInput> with SingleTickerProviderStateMixin {
  late final FocusNode _focus;
  late final AnimationController _pulse;
  bool _completedFired = false;
  int _prevLen = 0;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
    _prevLen = widget.controller.text.length;
    widget.controller.addListener(_onText);
    _focus.addListener(() {
      if (mounted) setState(() {});
      if (_focus.hasFocus) {
        _pulse.repeat(reverse: true);
      } else {
        _pulse.stop();
        _pulse.reset();
      }
    });
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  void _onText() {
    final t = widget.controller.text.replaceAll(RegExp(r'\D'), '');
    if (t != widget.controller.text) {
      final clipped = t.length > 6 ? t.substring(0, 6) : t;
      widget.controller.value = TextEditingValue(
        text: clipped,
        selection: TextSelection.collapsed(offset: clipped.length),
      );
    }
    final len = widget.controller.text.length;
    if (len > _prevLen && len <= 6) {
      HapticFeedback.selectionClick();
    }
    _prevLen = len;
    if (mounted) setState(() {});
    if (len < 6) _completedFired = false;
    if (len == 6) {
      _pulse.stop();
      _pulse.reset();
    }
    if (len == 6 && !_completedFired) {
      _completedFired = true;
      HapticFeedback.mediumImpact();
      widget.onCompleted?.call(widget.controller.text);
    }
  }

  Future<void> _pasteFromClipboard() async {
    if (!widget.enabled) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = data?.text ?? '';
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 6) {
      HapticFeedback.lightImpact();
      return;
    }
    widget.controller.text = digits.substring(0, 6);
    widget.controller.selection = const TextSelection.collapsed(offset: 6);
    HapticFeedback.mediumImpact();
    if (mounted) _focus.requestFocus();
  }

  @override
  void didUpdateWidget(covariant KpmsOtpInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
      _prevLen = widget.controller.text.length;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    _focus.dispose();
    _pulse.dispose();
    super.dispose();
  }

  int get _activeIndex {
    if (!_focus.hasFocus) return -1;
    final len = widget.controller.text.length;
    if (len >= 6) return 5;
    return len;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final focused = _focus.hasFocus;
    final active = _activeIndex;

    return Semantics(
      label: 'One time passcode, 6 digits',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: () {
              if (!widget.enabled) return;
              _focus.requestFocus();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: focused ? scheme.primary.withValues(alpha: 0.85) : scheme.outlineVariant.withValues(alpha: 0.55),
                  width: focused ? 2 : 1,
                ),
                boxShadow: focused
                    ? [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.12),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: 0.03,
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focus,
                      enabled: widget.enabled,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      maxLength: 6,
                      autofocus: widget.autofocus,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      showCursor: true,
                      style: const TextStyle(fontSize: 1, height: 1.45),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        counterText: '',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 22),
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(6, (i) {
                          final ch = i < widget.controller.text.length ? widget.controller.text[i] : '';
                          final filled = ch.isNotEmpty;
                          final isActive = active == i;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: AnimatedScale(
                                scale: filled ? 1.0 : 0.94,
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOutCubic,
                                child: AnimatedBuilder(
                                  animation: _pulse,
                                  builder: (context, child) {
                                    final pulseW = isActive && focused ? 1.0 + _pulse.value * 0.35 : 0.0;
                                    return DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: scheme.surfaceContainerHighest.withValues(
                                          alpha: filled ? 0.58 : 0.32,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          width: isActive && focused ? 2 + pulseW : 1,
                                          color: isActive && focused
                                              ? (Color.lerp(
                                                        scheme.primary,
                                                        scheme.secondary,
                                                        (_pulse.value * 0.5).clamp(0.0, 1.0),
                                                      ) ??
                                                      scheme.primary)
                                              : filled
                                                  ? scheme.primary.withValues(alpha: 0.42)
                                                  : scheme.outlineVariant.withValues(alpha: 0.45),
                                        ),
                                      ),
                                      child: child,
                                    );
                                  },
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: Center(
                                      child: Text(
                                        ch,
                                        style: theme.textTheme.headlineSmall?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                          height: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.controller.text.isEmpty ? ' ' : '${widget.controller.text.length}/6',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: widget.enabled ? _pasteFromClipboard : null,
                icon: Icon(Icons.content_paste_go_rounded, size: 18, color: scheme.primary),
                label: Text(widget.pasteLabel),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
