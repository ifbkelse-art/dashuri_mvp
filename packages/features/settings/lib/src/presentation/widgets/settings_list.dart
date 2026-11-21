import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:flutter/material.dart';

/// Scrollable, width-capped settings body.
class SettingsList extends StatelessWidget {
  const SettingsList({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.only(bottom: DashuriTokens.space8),
    children: [
      ResponsiveCenter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ],
  );
}
