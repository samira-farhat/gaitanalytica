from django.db import models
from django.contrib.auth.models import User
import random
from django.utils import timezone
from datetime import timedelta


# 1. USER PROFILE TABLE

class UserProfile(models.Model):

    GENDER_CHOICES = [
        ('Male', 'Male'),
        ('Female', 'Female'),
        ('Other', 'Other'),
    ]

    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name='profile'
    )

    middle_name = models.CharField(max_length=100, blank=True, null=True)

    age = models.IntegerField(blank=True, null=True)

    gender = models.CharField(
        max_length=10,
        choices=GENDER_CHOICES,
        blank=True,
        null=True
    )

    height_cm = models.FloatField(blank=True, null=True)

    weight_kg = models.FloatField(blank=True, null=True)

    profile_pic = models.ImageField(upload_to='profile_pics/', blank=True, null=True)

    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.first_name} {self.user.last_name}"



# 2. GAIT SESSION TABLE

class GaitSession(models.Model):

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='gait_sessions'
    )

    session_date = models.DateTimeField(auto_now_add=True)

    video_path = models.FileField(upload_to='uploads/')

    skeleton_video_path = models.FileField(
        upload_to='processed/',
        blank=True,
        null=True
    )

    thumbnail_path = models.ImageField(
        upload_to='thumbnails/',
        blank=True,
        null=True
    )

    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Session {self.id} - {self.user.username}"



# 3. GAIT ANALYSIS TABLE

class GaitAnalysis(models.Model):

    STATUS_CHOICES = [
        ('Pending', 'Pending'),
        ('Processing', 'Processing'),
        ('Detecting Pose', 'Detecting Pose'),
        ('Extracting Features', 'Extracting Features'),
        ('Completed', 'Completed'),
        ('Failed', 'Failed'),
        ('Failed - No landmarks detected', 'Failed - No landmarks detected'),
    ]

    session = models.OneToOneField(
        GaitSession,
        on_delete=models.CASCADE,
        related_name='analysis'
    )

    analysis_date = models.DateTimeField(auto_now_add=True)

    total_frames = models.IntegerField(default=0)

    landmark_frames = models.IntegerField(default=0)

    processing_status = models.CharField(
        max_length=50,
        choices=STATUS_CHOICES,
        default='Pending'
    )

    processing_time_sec = models.FloatField(default=0)

    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Analysis {self.id} for Session {self.session.id}"

# 4. KINEMATIC METRICS TABLE

class KinematicMetric(models.Model):

    analysis = models.OneToOneField(
        GaitAnalysis,
        on_delete=models.CASCADE,
        related_name='kinematic_metrics'
    )

    left_avg_angle = models.FloatField()

    right_avg_angle = models.FloatField()

    left_rom = models.FloatField()

    right_rom = models.FloatField()

    avg_rom = models.FloatField()

    knee_symmetry_diff = models.FloatField()

    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Kinematic Metrics for Analysis {self.analysis.id}"



# 5. SPATIAL METRICS TABLE

class SpatialMetric(models.Model):

    analysis = models.OneToOneField(
        GaitAnalysis,
        on_delete=models.CASCADE,
        related_name='spatial_metrics'
    )

    avg_step_length_norm = models.FloatField()

    max_step_length_norm = models.FloatField()

    step_length_symmetry = models.FloatField()

    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Spatial Metrics for Analysis {self.analysis.id}"



# 6. TEMPORAL METRICS TABLE

class TemporalMetric(models.Model):

    analysis = models.OneToOneField(
        GaitAnalysis,
        on_delete=models.CASCADE,
        related_name='temporal_metrics'
    )

    cadence_bpm = models.FloatField()

    avg_stride_time = models.FloatField()

    stride_time_variability_std = models.FloatField()

    stride_time_cv = models.FloatField()

    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Temporal Metrics for Analysis {self.analysis.id}"



# 7. USER GOALS TABLE

class UserGoal(models.Model):

    METRIC_CHOICES = [
        ('avg_rom', 'Knee ROM'),
        ('knee_symmetry_diff', 'Knee Symmetry'),
        ('avg_step_length_norm', 'Step Length'),
        ('cadence_bpm', 'Cadence'),
        ('stride_time_cv', 'Stride Variability'),
    ]

    GOAL_STATUS_CHOICES = [
        ('Active', 'Active'),
        ('Achieved', 'Achieved'),
        ('Cancelled', 'Cancelled'),
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='goals'
    )

    metric_name = models.CharField(
        max_length=50,
        choices=METRIC_CHOICES
    )

    target_value = models.FloatField()

    current_value_at_start = models.FloatField()

    status = models.CharField(
        max_length=20,
        choices=GOAL_STATUS_CHOICES,
        default='Active'
    )

    achieved_value = models.FloatField(
        null=True,
        blank=True
    )

    achieved_date = models.DateTimeField(
        blank=True,
        null=True
    )

    final_value = models.FloatField(
        null=True, 
        blank=True
    )

    start_date = models.DateTimeField(auto_now_add=True)

    end_date = models.DateField(
        blank=True,
        null=True
    )

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        # ensures only ONE active goal per user + metric
        constraints = [
            models.UniqueConstraint(
                fields=['user', 'metric_name'],
                condition=models.Q(status='Active'),
                name='unique_active_goal_per_metric'
            )
        ]

    def __str__(self):
        return f"{self.user.username} - {self.metric_name}"


class EmailVerification(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    otp_code = models.CharField(max_length=6)
    created_at = models.DateTimeField(auto_now_add=True)
    last_sent = models.DateTimeField(auto_now=True)

    def is_expired(self):
        # otp expires after 10 minutes
        return timezone.now() > self.created_at + timedelta(minutes=10)

    def can_resend(self):
        # resend allowed after 60 seconds
        return timezone.now() > self.last_sent + timedelta(seconds=60)
    


class Notification(models.Model):

    NOTIFICATION_TYPES = (
        ('goal', 'Goal Update'),
        ('session', 'Session Reminder'),
        ('achievement', 'Achievement Unlocked'),
        ('system', 'System Alert'),
    )

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='notifications')
    title = models.CharField(max_length=255)
    message = models.TextField()
    notification_type = models.CharField(max_length=20, choices=NOTIFICATION_TYPES, default='system')
    
    # Deep-linking: Where should the user go when they click?
    target_screen = models.CharField(max_length=100, blank=True, null=True) 
    target_id = models.CharField(max_length=100, blank=True, null=True)     
    
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']