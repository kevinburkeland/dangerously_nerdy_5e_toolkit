import 'package:flutter/material.dart';
import '../models/srd_summons.dart';
import 'minion_tool_screen.dart';

class AnimateObjectsScreen extends StatelessWidget {
  const AnimateObjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MinionToolScreen(
      preset: AnimateObjectsSummon.preset,
      customTitle: 'Animate Objects Companion',
    );
  }
}

