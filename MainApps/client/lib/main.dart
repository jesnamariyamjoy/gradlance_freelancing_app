import 'package:client/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:client/services/notification_service.dart';
import 'package:client/providers/theme_provider.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  ); 
  runApp(const MainApp());
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
            debugShowCheckedModeBanner: false,
            title: 'Gradlance Client',
            themeMode: themeProvider.themeMode,

            // 🌞 LIGHT THEME
            theme: ThemeData(
              brightness: Brightness.light,
              useMaterial3: true,
              primaryColor: const Color(0xFF102030),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF20A0A0),
                primary: const Color(0xFF102030),
                secondary: const Color(0xFF20A0A0),
                brightness: Brightness.light,
              ),
              scaffoldBackgroundColor: const Color(0xFFF4F7F9),
              cardColor: Colors.white,
              appBarTheme: const AppBarTheme(
                elevation: 0,
                backgroundColor: Colors.white,
                centerTitle: true,
                titleTextStyle: TextStyle(color: Color(0xFF102030), fontSize: 18, fontWeight: FontWeight.bold),
                iconTheme: IconThemeData(color: Color(0xFF102030)),
              ),
            ),

            // 🌙 DARK THEME
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              useMaterial3: true,
              scaffoldBackgroundColor: const Color(0xFF0A0F14),
              primaryColor: const Color(0xFF20A0A0),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF20A0A0),
                primary: const Color(0xFF20A0A0),
                surface: const Color(0xFF102030),
                brightness: Brightness.dark,
              ),
              cardColor: const Color(0xFF102030),
              appBarTheme: const AppBarTheme(
                elevation: 0,
                backgroundColor: Color(0xFF102030),
                centerTitle: true,
                titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                iconTheme: IconThemeData(color: Colors.white),
              ),
              dividerColor: Colors.white10,
            ),
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
