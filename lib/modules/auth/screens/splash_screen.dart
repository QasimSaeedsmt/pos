import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/auth_measurements.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo.png',
              width: AuthMeasurements.logoSize,
              height: AuthMeasurements.logoSize,
              fit: BoxFit.contain, // keeps the aspect ratio
            )
,            const SizedBox(height: AuthMeasurements.spacingXLarge),
            RichText(
              text: TextSpan(
                style: GoogleFonts.poppins(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
                children: [
                  TextSpan(text: 'Point ', style: TextStyle(color: Color(0xFF0A1F44))),
                  TextSpan(text: 'of ', style: TextStyle(color: Color(0xFF00D1B2))),
                  TextSpan(text: 'Sale', style: TextStyle(color: Color(0xFF007B50))),
                ],
              ),
            )
,
            const SizedBox(height: AuthMeasurements.spacingXLarge),
            CircularProgressIndicator(
              strokeWidth: 6,
              color: Color(0xFF00D1B2),
              backgroundColor: Color(0xFF0A1F44), // Navy Blue track
            ),
          ],
        ),
      ),
    );
  }
}