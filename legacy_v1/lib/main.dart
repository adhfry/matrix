import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/api/dio_client.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/connectivity_banner.dart';
import 'features/splash/presentation/pages/splash_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Indonesian locale for date formatting
  await initializeDateFormatting('id_ID', null);
  
  // Initialize Dio Client
  DioClient().init();
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
  runApp(
    const ProviderScope(
      child: MatrixApp(),
    ),
  );
}

class MatrixApp extends StatelessWidget {
  const MatrixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MATRIX Mobile',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const ConnectivityBanner(
        child: SplashPage(),
      ),
    );
  }
}
