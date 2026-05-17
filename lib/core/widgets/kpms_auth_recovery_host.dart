import 'package:flutter/material.dart';

import '../supabase/kpms_supabase_auth_recovery.dart';
import '../supabase/supabase_bootstrap.dart';

/// App lifecycle bridge: silent session validation on resume (debounced + rate-limited).
class KpmsAuthRecoveryHost extends StatefulWidget {
  const KpmsAuthRecoveryHost({super.key, required this.child});

  final Widget child;

  @override
  State<KpmsAuthRecoveryHost> createState() => _KpmsAuthRecoveryHostState();
}

class _KpmsAuthRecoveryHostState extends State<KpmsAuthRecoveryHost> with WidgetsBindingObserver {
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
    if (state == AppLifecycleState.resumed && SupabaseBootstrap.isConfigured) {
      KpmsSupabaseAuthRecovery.refreshSessionAfterResume();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
