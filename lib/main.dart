import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

import 'screens/home_screen.dart';
import 'providers/app_provider.dart';
import 'services/ai_service.dart';
import 'i18n/translations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化日志系统
  await AILogger.init();
  AILogger.log('APP', '应用启动');

  // 初始化 sqflite_ffi (Windows/Linux desktop support)
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // 初始化数据库
  final appProvider = AppProvider();
  await appProvider.initDatabase();
  await appProvider.loadLanguage(); // 加载语言设置

  // 初始化翻译系统
  await Translations().init(defaultLanguage: appProvider.language);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appProvider),
        ChangeNotifierProvider.value(value: Translations()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // 在第一帧渲染后打印窗口就绪日志
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AILogger.log('APP', '=== 窗口已就绪 ===');
      print('[APP] === 窗口已就绪 ===');
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI家庭教师',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'NotoSansSC',
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}