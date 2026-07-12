import 'package:flutter/material.dart';

/// Shown while workspace bootstrap is still loading an empty tenant.
class DashboardLoadingBody extends StatelessWidget {
  const DashboardLoadingBody({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading workspace…'),
          ],
        ),
      ),
    );
  }
}
