import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:meu_app_android/core/database/app_database.dart';
import 'package:meu_app_android/core/routes/app_router.dart';
import 'package:meu_app_android/core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = await AppDatabase.instance.database;
  final u = await db.rawQuery('SELECT COUNT(*) AS n FROM unidades');
  final c = await db.rawQuery('SELECT COUNT(*) AS n FROM categorias');
  debugPrint('Unidades cadastradas: ${u.first['n']}');
  debugPrint('Categorias cadastradas: ${c.first['n']}');

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Estoque UAN',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: appRouter,
    );
  }
}
