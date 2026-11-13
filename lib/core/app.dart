import 'package:flutter/material.dart';

import 'router/app_router.dart';

class TontineApp extends StatelessWidget {
  const TontineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Tontine',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF176B58)),
        useMaterial3: true,
      ),
      routerConfig: appRouter,
    );
  }
}