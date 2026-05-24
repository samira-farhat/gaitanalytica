import 'package:flutter/material.dart';
import 'package:gait_analytica_flutter/screens/register_screen.dart';

// importing custom app colors
import '../core/theme/app_colors.dart';
import 'about_screen.dart';
import 'login_screen.dart';

// welcome screen widget
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // setting the background color of the whole screen
      backgroundColor: AppColors.pureWhite,

      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height,
            ),

            child: IntrinsicHeight(
              child: Padding(
                // horizontal padding
                padding: EdgeInsets.symmetric(horizontal: 24.0),

                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [

                    SizedBox(height: 50),

                    // logo image
                    Image.asset(
                      'assets/logo_clear_bk.png',
                      height: 220,
                    ),

                    SizedBox(height: 20),

                    // app description
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

                    SizedBox(height: 50),

                    // row for login and register buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [

                        // login button
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LoginScreen(),
                                ),
                              );
                            },

                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.skeletonBlue,
                              foregroundColor: AppColors.pureWhite,

                              padding: EdgeInsets.symmetric(vertical: 18),

                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(40),
                              ),

                              elevation: 4,
                            ),

                            child: Text(
                              'LOG IN',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),

                        SizedBox(width: 16),

                        // register button
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RegisterScreen(),
                                ),
                              );
                            },

                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.skeletonBlue,
                              foregroundColor: AppColors.pureWhite,

                              padding: EdgeInsets.symmetric(vertical: 18),

                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(40),
                              ),

                              elevation: 4,
                            ),

                            child: Text(
                              'REGISTER',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 28),

                    // learn more outlined button
                    SizedBox(
                      width: 240,

                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AboutScreen(),
                            ),
                          );
                        },

                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.skeletonBlue,

                          side: BorderSide(
                            color: AppColors.skeletonBlue,
                            width: 2,
                          ),

                          padding: EdgeInsets.symmetric(vertical: 18),

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(40),
                          ),
                        ),

                        child: Text(
                          'LEARN MORE',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 100),

                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}