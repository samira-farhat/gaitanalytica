import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      backgroundColor: AppColors.pureWhite,

      appBar: AppBar(
        backgroundColor: AppColors.pureWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
              Icons.arrow_back_ios_new,
              color: AppColors.onyxCharcoal,
              size: 20
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),


      body: SafeArea(

        child: SingleChildScrollView(

          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Center(
                child: Column(
                  children: [

                    // logo image
                    Image.asset(
                      'assets/skeleton_clear_bk.png',
                      height: 110,
                    ),

                    SizedBox(height: 5),

                    Text(
                      'What is GaitAnalytica?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onyxCharcoal,
                      ),
                    ),

                    SizedBox(height: 12),

                    Text(
                      'Video-based gait analysis for mobility monitoring and recovery tracking',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        color: AppColors.terrainGrey,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 40),

              // section 1: how it works
              Text(
                'How it Works',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onyxCharcoal,
                ),
              ),

              SizedBox(height: 20),

              // 1
              _buildInfoCard(
                icon: Icons.psychology_alt_rounded,
                title: 'AI-Powered Detection',
                description:
                'Uses MediaPipe technology to identify 33 body landmarks without physical sensors.',
              ),

              SizedBox(height: 16),

              // 2
              _buildInfoCard(
                icon: Icons.analytics_outlined,
                title: 'Quantitative Movement Analysis',
                description:
                'Extracts biomechanical gait features from video using pose estimation.',
              ),

              SizedBox(height: 16),

              // 3
              _buildInfoCard(
                icon: Icons.show_chart_rounded,
                title: 'Trend Tracking',
                description:
                'Visualizes your recovery journey from GBS or injury through daily sessions.',
              ),

              SizedBox(height: 40),

              // section 2: metrics
              Text(
                'Understanding Your Metrics',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onyxCharcoal,
                ),
              ),

              SizedBox(height: 24),

              // kinematics metric
              _buildMetricTile(
                title: 'Kinematics',
                description:
                'Tracks your Knee Range of Motion (ROM), and symmetry between left and right legs to monitor joint flexibility.',
              ),

              SizedBox(height: 20),

              // spatial metric
              _buildMetricTile(
                title: 'Spatial',
                description:
                'Measures step length and symmetry to ensure balanced walking.',
              ),

              SizedBox(height: 20),

              // temporal metric
              _buildMetricTile(
                title: 'Temporal',
                description:
                'Analyzes cadence and stride variability to assess stability and fall risk.',
              ),

              SizedBox(height: 40),

              // section 3: privacy
              Container(
                padding: EdgeInsets.all(18),

                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(18),
                ),

                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // shield icon
                    Icon(
                      Icons.shield_outlined,
                      color: AppColors.skeletonBlue,
                      size: 28,
                    ),

                    SizedBox(width: 14),

                    Expanded(
                      child: Text(
                        'Your data is handled securely. Videos are processed on a backend server, and access is restricted through authenticated endpoints.',
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.terrainGrey,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(

      // padding inside the card
      padding: EdgeInsets.all(20),

      decoration: BoxDecoration(

        color: AppColors.pureWhite,

        borderRadius: BorderRadius.circular(22),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Container(
            padding: EdgeInsets.all(12),

            decoration: BoxDecoration(
              color: AppColors.powderBlue.withOpacity(0.2),
              shape: BoxShape.circle,
            ),

            child: Icon(
              icon,
              color: AppColors.skeletonBlue,
              size: 28,
            ),
          ),

          SizedBox(width: 18),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // card title
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onyxCharcoal,
                  ),
                ),

                SizedBox(height: 8),

                // card description
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.terrainGrey,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String description,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // metric title
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.onyxCharcoal,
          ),
        ),

        SizedBox(height: 8),

        // metric description
        Text(
          description,
          style: TextStyle(
            fontSize: 15,
            color: AppColors.terrainGrey,
            height: 1.5,
          ),
        ),

        SizedBox(height: 12),

        // healthy vs pathological indicator
        Row(
          children: [

            // healthy section
            Expanded(
              flex: 7,
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.green.shade400,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),

            SizedBox(width: 6),

            // pathological section
            Expanded(
              flex: 3,
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.red.shade300,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),

        SizedBox(height: 6),

        // labels under indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [

            Text(
              'Healthy',
              style: TextStyle(
                color: Colors.green.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),

            Text(
              'Pathological',
              style: TextStyle(
                color: Colors.red.shade400,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}