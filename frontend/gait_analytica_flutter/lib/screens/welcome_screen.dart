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
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: 50),

                    Image.asset(
                      'assets/logo_clear_bk.png',
                      height: 220,
                    ),

                    SizedBox(height: 40),

                    Column(
                      children: [
                        Text(
                          'Every step counts. Track your progress',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            height: 1.2,
                            color: AppColors.midnightNavy,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        SizedBox(height: 16),

                        Text(
                          'Get real-time AI feedback on your gait to improve your posture, balance, and movement',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 60),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoginScreen())),
                            style: _buttonStyle(),
                            child: Text('LOG IN', style: _buttonTextStyle),
                          ),
                        ),

                        SizedBox(width: 16),

                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RegisterScreen())),
                            style: _buttonStyle(),
                            child: Text('REGISTER', style: _buttonTextStyle),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 28),

                    SizedBox(
                      width: 240,
                      child: OutlinedButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AboutScreen())),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.midnightNavy,
                          side: BorderSide(color: AppColors.midnightNavy, width: 2),
                          padding: EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                        ),
                        child: Text('LEARN MORE', style: _buttonTextStyle),
                      ),
                    ),

                    SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  ButtonStyle _buttonStyle() => ElevatedButton.styleFrom(
    backgroundColor: AppColors.skeletonBlue,
    foregroundColor: AppColors.pureWhite,
    padding: EdgeInsets.symmetric(vertical: 18),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
    elevation: 4,
  );

  static const TextStyle _buttonTextStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    letterSpacing: 1,
  );
}