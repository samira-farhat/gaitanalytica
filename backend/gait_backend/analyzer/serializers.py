from rest_framework import serializers
from django.contrib.auth.models import User
from .models import (
    UserProfile,
    GaitSession,
    GaitAnalysis,
    KinematicMetric,
    SpatialMetric,
    TemporalMetric,
    UserGoal, 
    Notification
)

from django.contrib.auth.models import User
from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from rest_framework.exceptions import AuthenticationFailed


# 1. USER SERIALIZER
# mini version
class UserMiniSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'username']

# full version
class UserSerializer(serializers.ModelSerializer):

    class Meta:
        model = User

        fields = [
            'id',
            'username',
            'first_name',
            'last_name',
            'email'
        ]

# 2. USER PROFILE
class UserProfileSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)

    class Meta:
        model = UserProfile
        fields = [
            'id',
            'user',
            'middle_name',
            'age',
            'gender',
            'height_cm',
            'weight_kg',
            'profile_pic',
            'created_at'
        ]


# 3. GAIT SESSION
class GaitSessionSerializer(serializers.ModelSerializer):

    user = UserMiniSerializer(read_only=True)

    class Meta:
        model = GaitSession
        fields = [
            'id',
            'user',
            'session_date',
            'video_path',
            'skeleton_video_path',
            'thumbnail_path',
            'created_at'
        ]


# 4. GAIT ANALYSIS
class GaitAnalysisSerializer(serializers.ModelSerializer):
    class Meta:
        model = GaitAnalysis
        fields = [
            'id',
            'session',
            'analysis_date',
            'total_frames',
            'landmark_frames',
            'processing_status',
            'processing_time_sec',
            'created_at'
        ]


# 5. KINEMATIC METRICS
class KinematicMetricSerializer(serializers.ModelSerializer):
    class Meta:
        model = KinematicMetric
        fields = [
            'id',
            'analysis',
            'left_avg_angle',
            'right_avg_angle',
            'left_rom',
            'right_rom',
            'avg_rom',
            'knee_symmetry_diff',
            'created_at'
        ]


# 6. SPATIAL METRICS
class SpatialMetricSerializer(serializers.ModelSerializer):
    class Meta:
        model = SpatialMetric
        fields = [
            'id',
            'analysis',
            'avg_step_length_norm',
            'max_step_length_norm',
            'step_length_symmetry',
            'created_at'
        ]


# 7. TEMPORAL METRICS
class TemporalMetricSerializer(serializers.ModelSerializer):
    class Meta:
        model = TemporalMetric
        fields = [
            'id',
            'analysis',
            'cadence_bpm',
            'avg_stride_time',
            'stride_time_variability_std',
            'stride_time_cv',
            'created_at'
        ]


# 8. USER GOALS 
class UserGoalSerializer(serializers.ModelSerializer):

    user = UserMiniSerializer(read_only=True)

    class Meta:
        model = UserGoal
        fields = [
            'id',
            'user',
            'metric_name',
            'target_value',
            'current_value_at_start',
            'status',
            'start_date',
            'end_date',
            'created_at'
        ]


# for the unverified account logic
class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):

    def validate(self, attrs):

        username = attrs.get("username")

        try:
            user = User.objects.get(username=username)

            # account exists but not verified
            if not user.is_active:
                raise AuthenticationFailed({
                    "error": "Account not verified",
                    "email": user.email,
                }) 
                
        except User.DoesNotExist:
            pass

        # continue normal jwt login
        return super().validate(attrs)
    

class NotificationSerializer(serializers.ModelSerializer):
   
    notification_type_display = serializers.CharField(source='get_notification_type_display', read_only=True)

    class Meta:
        model = Notification
        fields = [
            'id', 'title', 'message', 'notification_type', 
            'notification_type_display', 'target_screen', 
            'target_id', 'is_read', 'created_at'
        ]