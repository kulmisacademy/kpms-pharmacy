import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'kpms_app_lock_controller.dart';

/// Wraps the app and overlays a PIN lock screen whenever the app lock is engaged.
/// Also re-locks after the app has been backgrounded past the relock window.
class KpmsAppLockGate extends ConsumerStatefulWidget {
  const KpmsAppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<KpmsAppLockGate> createState() => _KpmsAppLockGateState();
}

class _KpmsAppLockGateState extends ConsumerState<KpmsAppLockGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = ref.read(kpmsAppLockProvider.notifier);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      ctrl.onPaused();
    } else if (state == AppLifecycleState.resumed) {
      ctrl.onResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = ref.watch(kpmsAppLockProvider.select((s) => s.shouldBlock));
    return Stack(
      children: [
        widget.child,
        if (locked)
          const Positioned.fill(
            child: _AppLockScreen(),
          ),
      ],
    );
  }
}

class _AppLockScreen extends ConsumerStatefulWidget {
  const _AppLockScreen();

  @override
  ConsumerState<_AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<_AppLockScreen> {
  String _pin = '';
  bool _error = false;
  bool _busy = false;

  static const int _maxLen = 6;

  Future<void> _onDigit(String d) async {
    if (_busy || _pin.length >= _maxLen) return;
    setState(() {
      _pin += d;
      _error = false;
    });
    if (_pin.length >= 4) {
      // Allow up to 6, but attempt verify on each press from length 4 upward.
      await _tryUnlock();
    }
  }

  Future<void> _tryUnlock() async {
    setState(() => _busy = true);
    final ok = await ref.read(kpmsAppLockProvider.notifier).unlock(_pin);
    if (!mounted) return;
    if (ok) {
      HapticFeedback.lightImpact();
      return; // gate rebuilds and removes overlay
    }
    setState(() {
      _busy = false;
      if (_pin.length >= _maxLen) {
        _error = true;
        _pin = '';
      }
    });
    if (_error) HapticFeedback.heavyImpact();
  }

  void _backspace() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surface,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_rounded, size: 48, color: scheme.primary),
                  const SizedBox(height: 18),
                  Text(
                    l.appLockEnterTitle,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _error ? l.appLockWrong : l.appLockEnterSubtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _error ? scheme.error : scheme.onSurfaceVariant,
                      fontWeight: _error ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 26),
                  _PinDots(length: _pin.length, max: _maxLen, error: _error),
                  const SizedBox(height: 30),
                  _PinPad(onDigit: _onDigit, onBackspace: _backspace),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinDots extends StatelessWidget {
  const _PinDots({required this.length, required this.max, this.error = false});

  final int length;
  final int max;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(max, (i) {
        final filled = i < length;
        return Container(
          width: 14,
          height: 14,
          margin: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled
                ? (error ? scheme.error : scheme.primary)
                : scheme.onSurface.withValues(alpha: 0.14),
          ),
        );
      }),
    );
  }
}

class _PinPad extends StatelessWidget {
  const _PinPad({required this.onDigit, required this.onBackspace});

  final void Function(String) onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];
    return Column(
      children: [
        for (final row in rows)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final key in row) _PadKey(label: key, onDigit: onDigit, onBackspace: onBackspace),
            ],
          ),
      ],
    );
  }
}

class _PadKey extends StatelessWidget {
  const _PadKey({required this.label, required this.onDigit, required this.onBackspace});

  final String label;
  final void Function(String) onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (label.isEmpty) {
      return const SizedBox(width: 76, height: 76);
    }
    final isBackspace = label == '⌫';
    return SizedBox(
      width: 76,
      height: 76,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Material(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => isBackspace ? onBackspace() : onDigit(label),
            child: Center(
              child: isBackspace
                  ? Icon(Icons.backspace_outlined, color: theme.colorScheme.onSurface)
                  : Text(
                      label,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
