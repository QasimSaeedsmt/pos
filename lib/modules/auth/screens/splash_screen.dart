import 'package:flutter/material.dart';
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
            FlutterLogo(size: AuthMeasurements.logoSize),
            const SizedBox(height: AuthMeasurements.spacingXLarge),
            const Text(
              'Multi-Tenant SaaS',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AuthMeasurements.spacingXLarge),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}