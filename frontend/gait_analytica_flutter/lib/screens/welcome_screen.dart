import 'package:flutter/material.dart';
import 'package:gait_analytica_flutter/screens/register_screen.dart';
import '../core/theme/app_colors.dart';
import 'about_screen.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pureWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top,
            ),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 50),
                    Image.asset(
                      'assets/logo_clear_bk.png',
                      height: 220,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Your pathway to precise gait analysis,\nreal-time monitoring, and movement optimization.\nReclaim your mobility.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        height: 1.4,
                        color: AppColors.onyxCharcoal,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 50),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                            style: _buttonStyle(),
                            child: const Text('LOG IN', style: _buttonTextStyle),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                            style: _buttonStyle(),
                            child: const Text('REGISTER', style: _buttonTextStyle),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: 240,
                      child: OutlinedButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen())),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.skeletonBlue,
                          side: BorderSide(color: AppColors.skeletonBlue, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                        ),
                        child: const Text('LEARN MORE', style: _buttonTextStyle),
                      ),
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helpers to keep build method clean
  ButtonStyle _buttonStyle() => ElevatedButton.styleFrom(
    backgroundColor: AppColors.skeletonBlue,
    foregroundColor: AppColors.pureWhite,
    padding: const EdgeInsets.symmetric(vertical: 18),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
    elevation: 4,
  );

  static const TextStyle _buttonTextStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    letterSpacing: 1,
  );
}