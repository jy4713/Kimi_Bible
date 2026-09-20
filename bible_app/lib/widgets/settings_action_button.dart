import 'package:flutter/material.dart';

import '../screens/settings/settings_screen.dart';

/// Small settings gear shown at the top-right corner of the main tab screens.
/// (Settings used to be a bottom-nav tab; it moved here to make room.)
class SettingsActionButton extends StatelessWidget {
  const SettingsActionButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.settings_outlined),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      ),
    );
  }
}
