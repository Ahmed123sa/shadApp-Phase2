import 'package:flutter/material.dart';
import '../../am/workspace/reports_tab.dart';
import '../../../core/theme.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, fontFamily: 'PlayfairDisplay', color: ShadColors.gold)),
      ),
      body: const ReportsTab(),
    );
  }
}
