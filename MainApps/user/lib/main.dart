import 'package:flutter/material.dart';
import 'package:user/screens/splash_screen.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:user/providers/theme_provider.dart';
import 'package:user/services/notification_service.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  runApp(MainApp());
}

final supabase = Supabase.instance.client;

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => NotificationService()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: "Gradlance - User",
            debugShowCheckedModeBanner: false,

            // 🔥 Theme Control
            themeMode: themeProvider.themeMode,

            // 🌞 Light Theme (Gradlance Light)
            theme: ThemeData(
              brightness: Brightness.light,
              scaffoldBackgroundColor: const Color(
                0xFFF4F7F9,
              ), // brandLightGrey
              primaryColor: const Color(0xFF20A0A0), // brandTeal
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF102030), // brandNavy
                primary: const Color(0xFF20A0A0), // brandTeal
                surface: Colors.white,
                brightness: Brightness.light,
              ),
              cardColor: Colors.white,
              dividerColor: Colors.grey.shade200,
            ),

            // 🌙 Dark Theme (Gradlance Dark)
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(
                0xFF0A0F14,
              ), // Deep Navy background
              primaryColor: const Color(0xFF20A0A0), // brandTeal
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF20A0A0), // brandTeal
                primary: const Color(0xFF20A0A0),
                surface: const Color(
                  0xFF102030,
                ), // brandNavy as card/surface color
                brightness: Brightness.dark,
              ),
              cardColor: const Color(0xFF102030), // brandNavy
              dividerColor: Colors.white10,
            ),
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
