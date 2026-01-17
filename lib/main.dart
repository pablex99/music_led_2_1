import 'package:flutter/material.dart';
import 'home_screen.dart';

void main() {
  runApp(const MusicLedApp());
}

class MusicLedApp extends StatelessWidget {
  const MusicLedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music-Led 2.1',
      theme: ThemeData(
        fontFamily: 'PressStart2P',
        scaffoldBackgroundColor: Colors.black,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF00FFFF)),
          bodyMedium: TextStyle(color: Color(0xFF00FFFF)),
          bodySmall: TextStyle(color: Color(0xFF00FFFF)),
          titleLarge: TextStyle(color: Color(0xFF00FFFF)),
          titleMedium: TextStyle(color: Color(0xFF00FFFF)),
          titleSmall: TextStyle(color: Color(0xFF00FFFF)),
          labelLarge: TextStyle(color: Color(0xFF00FFFF)),
          labelMedium: TextStyle(color: Color(0xFF00FFFF)),
          labelSmall: TextStyle(color: Color(0xFF00FFFF)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Color(0xFF00FFFF),
          titleTextStyle: TextStyle(
            color: Color(0xFF00FFFF),
            fontFamily: 'PressStart2P',
            fontSize: 16,
          ),
          iconTheme: IconThemeData(color: Color(0xFF00FFFF)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
              if (states.contains(MaterialState.pressed)) {
                return const Color(0xFF003B46);
              }
              return const Color(0xFF002B36);
            }),
            foregroundColor: MaterialStatePropertyAll(Color(0xFF00FFFF)),
            textStyle: MaterialStatePropertyAll(TextStyle(fontFamily: 'PressStart2P', fontSize: 10)),
            overlayColor: MaterialStatePropertyAll(Color(0x3300FFFF)),
            shape: MaterialStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8)))),
            side: MaterialStateProperty.resolveWith<BorderSide>((states) {
              return const BorderSide(color: Color(0xFF00FFFF), width: 2);
            }),
            elevation: MaterialStateProperty.resolveWith<double>((states) {
              if (states.contains(MaterialState.pressed) || states.contains(MaterialState.hovered)) {
                return 8;
              }
              return 4;
            }),
            minimumSize: MaterialStatePropertyAll(Size(80, 32)),
            padding: MaterialStatePropertyAll(EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
          ),
        ),
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
