import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'providers/work_day_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home/home_screen.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()..load()),
        ChangeNotifierProvider(
            create: (_) => WorkDayProvider()..loadToday()),
      ],
      child: const FieldClockApp(),
    ),
  );
}

class FieldClockApp extends StatelessWidget {
  const FieldClockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          title: 'FieldClock',
          debugShowCheckedModeBanner: false,
          theme: themeProvider.theme.themeData,
          home: const HomeScreen(),
        );
      },
    );
  }
}