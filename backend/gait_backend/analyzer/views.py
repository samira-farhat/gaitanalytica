import uuid

import cv2 
import mediapipe as mp
import numpy as np
import math
from scipy.signal import find_peaks
from django.core.files.storage import default_storage
from django.core.files.base import ContentFile
from rest_framework.decorators import api_view, permission_classes, action
from rest_framework.response import Response
from rest_framework_simplejwt.views import TokenObtainPairView
import time
from django.contrib.auth.models import User
from .models import (
    GaitSession,
    GaitAnalysis,
    KinematicMetric,
    SpatialMetric,
    TemporalMetric,
    UserGoal,
    UserProfile,
    EmailVerification,
    Notification
)
from rest_framework.permissions import IsAuthenticated
from .serializers import (
    GaitSessionSerializer, 
    GaitAnalysisSerializer,
    KinematicMetricSerializer, 
    SpatialMetricSerializer, 
    TemporalMetricSerializer, 
    UserProfileSerializer, 
    UserGoalSerializer,
    CustomTokenObtainPairSerializer,
    NotificationSerializer
)
from datetime import date, datetime
from django.utils import timezone
from datetime import timedelta
import threading
import random
from django.core.mail import send_mail
from django.conf import settings

from rest_framework import viewsets, status

import os
os.environ["DJANGO_ALLOW_ASYNC_UNSAFE"] = "true"

from google import genai
from google.genai import types

# HELPER FUNCTIONS (Math parts)

# function that calculates the angle at vertex b for points a, b, and c
def calculate_angle(a, b, c):
    ba = (a[0]-b[0], a[1]-b[1])
    bc = (c[0]-b[0], c[1]-b[1])

    dot_prod = ba[0]*bc[0] + ba[1]*bc[1]

    mag_ba = math.sqrt(ba[0]**2 + ba[1]**2)
    mag_bc = math.sqrt(bc[0]**2 + bc[1]**2)

    cosine_val = max(-1.0, min(1.0, dot_prod / (mag_ba * mag_bc)))

    return math.degrees(math.acos(cosine_val))


# function that calculates the Euclidean distance between hip and ankle
def get_leg_length(hip, ankle):
    
    return math.sqrt((hip[0] - ankle[0])**2 + (hip[1] - ankle[1])**2)


# function that calculates the normalized symmetry difference between two values
def calculate_symmetry_index(v1, v2):
    
    denom = (v1 + v2) / 2
    return abs(v1 - v2) / denom if denom != 0 else 0


# function to check if the users goal was achieved
def check_goal_achievement(user, analysis):

    # get all active goals for this user
    active_goals= UserGoal.objects.filter(
        user=user,
        status="Active"
    )

    km = getattr(analysis, "kinematic_metrics", None)
    sm = getattr(analysis, "spatial_metrics", None)
    tm = getattr(analysis, "temporal_metrics", None)

    if not km and not sm and not tm:
        return

    for goal in active_goals:

        current_value= None
        achieved= False

        # KINEMATIC
        if goal.metric_name == "avg_rom":

            if not km:
                continue

            current_value = km.avg_rom
            # since higher is better
            achieved = current_value >= goal.target_value


        elif goal.metric_name == "knee_symmetry_diff":
            if not km:
                continue

            current_value = km.knee_symmetry_diff

            # lower is better
            achieved = current_value <= goal.target_value


        # SPATIAL
        elif goal.metric_name == "avg_step_length_norm":
            if not sm:
                continue

            current_value = sm.avg_step_length_norm

            # higher is better
            achieved = current_value >= goal.target_value


        # TEMPORAL
        elif goal.metric_name == "cadence_bpm":

            if not tm:
                continue
             
            current_value = tm.cadence_bpm

            # higher is better
            achieved = current_value >= goal.target_value


        elif goal.metric_name == "stride_time_cv":

            if not tm:
                continue
             
            current_value = tm.stride_time_cv

            # lower is better
            achieved = current_value <= goal.target_value


        else:
            continue


        # if goal is achieved
        if achieved:
            goal.final_value = current_value
            goal.achieved_value = current_value
            goal.status = "Achieved"
            goal.achieved_date = timezone.now()
            goal.end_date = analysis.session.session_date.date()
            goal.achieved_session = analysis.session

            goal.save()



            Notification.objects.create(
                user=user,
                target_id=goal.id,
                notification_type='achievement',
                title="Goal Achieved! ",
                message=f"Amazing! You reached your {goal.get_metric_name_display()} target.",
                target_screen='GoalDetail'
            )



# function to smooth the angles to ensure jumpy frames dont ruin anything
def smooth_list(data, window_size=3):
    if len(data) < window_size: return data
    return np.convolve(data, np.ones(window_size)/window_size, mode='valid').tolist()


def safe_mean(arr):
    return float(np.mean(arr)) if len(arr) > 0 else None


def get_latest_metric_value(user, metric_name):
    session = GaitSession.objects.filter(user=user).order_by('-session_date').first()

    if not session:
        return None

    try:
        analysis = GaitAnalysis.objects.get(session=session)
    except GaitAnalysis.DoesNotExist:
        return None

    mapping = {
        "avg_rom": analysis.kinematic_metrics.avg_rom,
        "knee_symmetry_diff": analysis.kinematic_metrics.knee_symmetry_diff,
        "avg_step_length_norm": analysis.spatial_metrics.avg_step_length_norm,
        "cadence_bpm": analysis.temporal_metrics.cadence_bpm,
        "stride_time_cv": analysis.temporal_metrics.stride_time_cv,
    }

    return mapping.get(metric_name)


# function to re-check goal achievement after session deletion
def recalculate_user_goals(user):

    goals = UserGoal.objects.filter(user=user, status="Active")

    for goal in goals:
        latest_value = get_latest_metric_value(user, goal.metric_name)

        goal.current_value_at_start = latest_value
        goal.save(update_fields=["current_value_at_start"])


def handle_goal_after_session_delete(user, deleted_session):
    goals = UserGoal.objects.filter(user=user)

    for goal in goals:

        # CASE 1: this session was the one that achieved the goal
        if goal.achieved_session_id == deleted_session.id:
            goal.status = "Cancelled"
            goal.invalid_reason = "session_deleted"

            goal.final_value = goal.achieved_value  
            goal.save()

            Notification.objects.create(
                user=user,
                target_id=goal.id,
                notification_type='goal',
                title="Goal Invalidated",
                message=f"Your {goal.get_metric_name_display()} goal was invalidated because the session used to achieve it was deleted.",
                target_screen="GoalDetail"
            )

        # CASE 2: ACTIVE goals → just recompute latest value (safe)
        elif goal.status == "Active":
            latest_value = get_latest_metric_value(user, goal.metric_name)

            goal.current_value_at_start = latest_value
            goal.save(update_fields=["current_value_at_start"])


# to process the uploaded video
def process_analysis(session_id):

    pose = None
    cap = None
   
    try:
        session= GaitSession.objects.get(id=session_id)
        analysis= GaitAnalysis.objects.get(session=session)

        analysis.processing_status = "Detecting Pose"
        analysis.save()

        full_path = default_storage.path(session.video_path.name)

        cap = cv2.VideoCapture(full_path)

        fourcc = cv2.VideoWriter_fourcc(*'avc1')

        output_filename = f"{uuid.uuid4()}_skeleton.mp4"
        from django.conf import settings

        output_path = os.path.join(settings.MEDIA_ROOT, "processed", output_filename)
        os.makedirs(os.path.dirname(output_path), exist_ok=True)

        fps = cap.get(cv2.CAP_PROP_FPS)
        if not fps or fps == 0:
            fps = 30

        frame_width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        frame_height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))

        out = cv2.VideoWriter(output_path, fourcc, fps, (frame_width, frame_height))

        if not out.isOpened():
            raise Exception("VideoWriter failed to open output file")

        mp_pose = mp.solutions.pose
        pose = mp_pose.Pose()

        start_time= time.time()

        total_pose_time = 0
   
        # lists for data collections
        frame_count = 0
        landmark_frames = 0
        left_angles= []
        right_angles = []
        knee_symmetry_diffs = []
        step_lengths = []

        # processing loop (to gather data)
        while True:

            ret, frame = cap.read()
            if not ret: break
            frame_count += 1

            if frame_count == 30:
                analysis.processing_status = "Extracting Features"
                analysis.save()

            pose_start = time.time()

            results = pose.process(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
       
            pose_time = time.time() - pose_start
            total_pose_time += pose_time

            if results.pose_landmarks:
                landmark_frames += 1

                # draw skeleton on frame
                mp.solutions.drawing_utils.draw_landmarks(
                    frame,
                    results.pose_landmarks,
                    mp_pose.POSE_CONNECTIONS
                )

                lm = results.pose_landmarks.landmark

                # extract Coordinates
                l_hip, l_knee, l_ankle = (lm[23].x, lm[23].y), (lm[25].x, lm[25].y), (lm[27].x, lm[27].y)
                r_hip, r_knee, r_ankle = (lm[24].x, lm[24].y), (lm[26].x, lm[26].y), (lm[28].x, lm[28].y)

                # record angles (Kinematics)
                ang_l = calculate_angle(l_hip, l_knee, l_ankle)
                ang_r = calculate_angle(r_hip, r_knee, r_ankle)
                left_angles.append(ang_l)
                right_angles.append(ang_r)
                knee_symmetry_diffs.append(abs(ang_l - ang_r))

                # record normalized step length (Spatial)
                step_dist = abs(l_ankle[0] - r_ankle[0])
                leg_len = get_leg_length(l_hip, l_ankle)
                step_lengths.append(step_dist / leg_len if leg_len > 0 else 0)

            out.write(frame)


        if landmark_frames == 0:
            analysis.processing_status = "Failed - No landmarks detected"
            analysis.save()

            return

        # FEATURE EXTRACTION
   
        # JOINT KINEMATIC FEATURES

        # 1. Knee Angles (Averages)
        avg_left = safe_mean(left_angles) or 0
        avg_right = safe_mean(right_angles) or 0
   
        # 2. Step/Knee Symmetry (Frame-by-frame average)
        avg_knee_symmetry = safe_mean(knee_symmetry_diffs) or 0
   
        # smoothed angles
        smoothed_left = smooth_list(left_angles)
        smoothed_right = smooth_list(right_angles)


        # 3. Knee Range of Motion (ROM)
        l_rom = max(smoothed_left) - min(smoothed_left) if smoothed_left else 0
        r_rom = max(smoothed_right) - min(smoothed_right) if smoothed_right else 0
        avg_rom = (l_rom + r_rom) / 2


        # PEAK DETECTION (For Spatial/Temporal)
        peaks, _ = find_peaks(step_lengths, height=0.25, distance=int(fps * 0.4), prominence=0.1)
        step_indices = peaks.tolist()
        peak_values = [step_lengths[i] for i in step_indices]


        # SPATIAL FEATURES

        # 4. Step Length
        avg_step_len = safe_mean(step_lengths) or 0
        max_step_len = max(step_lengths) if step_lengths else 0

        # 5. Step Length Symmetry (Comparing consecutive peaks)
        step_len_sym_list = [calculate_symmetry_index(peak_values[i], peak_values[i+1]) for i in range(len(peak_values)-1)]
        step_length_symmetry = np.mean(step_len_sym_list) if len(step_len_sym_list) > 0 else 0

        # TEMPORAL FEATURES

        # 6. Cadence
        total_time = frame_count / fps
        cadence = (len(step_indices) / total_time) * 60 if total_time > 0 else 0

        # 7. Stride Time
        stride_times = [(step_indices[i] - step_indices[i-1]) / fps for i in range(1, len(step_indices))]
       
        # filter outliers (noise reduction)
        if len(stride_times) > 3:
            q1= np.percentile(stride_times, 25)
            q3= np.percentile(stride_times, 75)
            iqr= q3 - q1

            lower_bound= q1 - (1.5 * iqr)
            upper_bound= q3 + (1.5 * iqr)

            # keep only the actual real strides
            filtered_stride_times= [t for t in stride_times if lower_bound <=t <= upper_bound]

            # using the data (if we still have any) after filtering
            if len(filtered_stride_times) >= 2:
                stride_times= filtered_stride_times


        avg_stride_time = np.mean(stride_times) if stride_times else 0

        # 8. Stride Time Variability (CV)
        stride_std = np.std(stride_times) if stride_times else 0

        # calculate cv as decimal
        stride_cv = stride_std / avg_stride_time if avg_stride_time > 0.0001 else 0

        end_time= time.time()

        processing_time= end_time - start_time

        print("****************************************************")
        print(f"processing time = {processing_time:.3f} seconds")
        print("total frames =", frame_count)
        print("****************************************************")

        # save analysis to db

        analysis.total_frames = frame_count
        analysis.landmark_frames = landmark_frames
        analysis.processing_time_sec = processing_time

        analysis.processing_status = "Completed"
        analysis.save()

        session.skeleton_video_path = f"processed/{output_filename}"
        session.save()

        # save kinematic metrics
        KinematicMetric.objects.create(
            analysis=analysis,
            left_avg_angle=avg_left,
            right_avg_angle=avg_right,
            left_rom=l_rom,
            right_rom=r_rom,
            avg_rom=avg_rom,
            knee_symmetry_diff=avg_knee_symmetry
        )

        # save spatial metrics
        SpatialMetric.objects.create(
            analysis=analysis,
            avg_step_length_norm=avg_step_len,
            max_step_length_norm=max_step_len,
            step_length_symmetry=step_length_symmetry
        )

        # save temporal metrics
        TemporalMetric.objects.create(
            analysis=analysis,
            cadence_bpm=cadence,
            avg_stride_time=avg_stride_time,
            stride_time_variability_std=stride_std,
            stride_time_cv=stride_cv
        )

        # check goals
        check_goal_achievement(session.user, analysis)
        Notification.objects.get_or_create(
            user=session.user,
            target_id=str(session.id),
            notification_type='session',
            defaults={
                "title": "Analysis Complete",
                "message": "Your gait analysis is ready to view.",
                "target_screen": "SessionDetail"
            }
        )

    except Exception as e:

        if 'analysis' in locals():
            analysis.processing_status = "Failed"
            analysis.save()

        print(e)

    finally:
        if pose is not None:
            pose.close()
        if cap is not None:
            cap.release()
        if 'out' in locals():
            out.release()




# fucntion that takes an input video and generates a skeleton overlay video.
def generate_skeleton_video(input_path, output_path):

    mp_pose = mp.solutions.pose
    mp_drawing = mp.solutions.drawing_utils

    cap = cv2.VideoCapture(input_path)

    if not cap.isOpened():
        raise Exception(f"Cannot open video: {input_path}")

    # Get video properties
    fps = int(cap.get(cv2.CAP_PROP_FPS))
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))

    # Ensure output directory exists
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    # Define video writer (MP4)
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(output_path, fourcc, fps, (width, height))

    pose = mp_pose.Pose()

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

        results = pose.process(rgb)

        if results.pose_landmarks:
            mp_drawing.draw_landmarks(
                frame,
                results.pose_landmarks,
                mp_pose.POSE_CONNECTIONS
            )

        out.write(frame)

    cap.release()
    out.release()




# MAIN API ENDPOINT
# API 1 - to analyze video

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def analyze_video(request):

    # video setup
    if 'video' not in request.FILES:
        return Response({"error": "No video uploaded"}, status=400)

    video_file = request.FILES['video']

    path = default_storage.save('uploads/' + video_file.name, ContentFile(video_file.read()))
   
    session= GaitSession.objects.create(
        user=request.user,
        video_path=path
    )

    analysis= GaitAnalysis.objects.create(
        session=session,
        processing_status="Processing"
    )

    thread = threading.Thread(
        target=process_analysis,
        args=(session.id,)
    )

    thread.start()

    return Response({
        "session_id": session.id,
        "analysis_id": analysis.id,
        "status": "processing"
    }, status=202)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def analysis_status(request, session_id):

    try:
        session = GaitSession.objects.get(
            id=session_id,
            user=request.user
        )

        analysis = GaitAnalysis.objects.get(session=session)

    except GaitSession.DoesNotExist:
        return Response({"error": "Session not found"}, status=404)

    except GaitAnalysis.DoesNotExist:
        return Response({"error": "Analysis not found"}, status=404)

    return Response({
        "session_id": session.id,
        "status": analysis.processing_status
    })



# API 2 - authentication

@api_view(['POST'])
# to create a new user account
def register_user(request):

    # extract data 
    first_name = request.data.get('first_name')
    last_name = request.data.get('last_name')
    middle_name = request.data.get('middle_name')

    age = request.data.get('age')
    gender = request.data.get('gender')
    height_cm = request.data.get('height_cm')
    weight_kg = request.data.get('weight_kg')

    username= request.data.get('username')
    email = request.data.get('email')
    password = request.data.get('password')

    if not username or not password:
        return Response(
            {"error": "Username and password required"}, 
            status=400
        )
    
    # to check if user already exists
    if User.objects.filter(username=username).exists():
        return Response(
            {"error": "Username already exists"},
            status=400
        )
    
    # check if email already exists
    if User.objects.filter(email=email).exists():
        return Response(
            {"error": "Email already exists"},
            status=400
        )
    
    # create django user 
    user= User.objects.create_user(
        username=username,
        email=email,
        password=password, 
        first_name=first_name,
        last_name=last_name,
        is_active=False
    )

    # create user profile
    UserProfile.objects.create(
        user=user,
        middle_name=middle_name,
        age=age,
        gender=gender,
        height_cm=height_cm,
        weight_kg=weight_kg
    )

    # delete old OTP if exists (important for resend safety)
    EmailVerification.objects.filter(user=user).delete()

    # OTP logic
    otp_code = str(random.randint(100000, 999999))
    EmailVerification.objects.create(user=user, otp_code=otp_code)
    
    # send email to the user
    subject= "Verify your GaitAnalytica Account"
    message = f"Hello {first_name}, \n\nYour verification code is: {otp_code}\n\nThis code expires in 10 minutes."

    try:
        send_mail(subject, message, settings.EMAIL_HOST_USER, [email])
    except Exception as e:
        print(f"Email error: {e}")


    return Response({
        "message": "User created. Please check your email for the OTP.",
        "email":email
    }, status=201)


@api_view(['POST'])
# to verify otp
def verify_otp(request):
    email = request.data.get('email')
    otp_entered = request.data.get('otp')
    purpose = request.data.get('purpose') # add this

    try:
        user = User.objects.get(email=email)
        verification = EmailVerification.objects.get(user=user)

        if verification.is_expired():
            return Response({"error": "OTP expired"}, status=400)

        if verification.otp_code != otp_entered:
            return Response({"error": "Invalid OTP code"}, status=400)

        # only activate the user if they are registering
        if purpose != "password_reset":
            user.is_active = True
            user.save()
            verification.delete() # delete only on registration
            return Response({"message": "Account verified successfully!"}, status=200)
        else:
            # for password reset, we keep the OTP so the next screen can use it
            return Response({"message": "Code verified, proceed to reset password"}, status=200)

    except (User.DoesNotExist, EmailVerification.DoesNotExist):
        return Response({"error": "Verification record not found"}, status=404)

@api_view(['POST'])
# to resend otp
def resend_otp(request):
    email = request.data.get('email')

    try:
        user = User.objects.get(email=email)

        if user.is_active:
            return Response({"error": "User already verified"}, status=400)

        verification = EmailVerification.objects.get(user=user)

        # cooldown check
        if not verification.can_resend():
            return Response(
                {"error": "Please wait before requesting another OTP"},
                status=429
            )

        # generate new otp
        otp_code = str(random.randint(100000, 999999))

        # update instead of delete (cleaner)
        verification.otp_code = otp_code
        verification.created_at = timezone.now()
        verification.save()

        subject = "Your new OTP code"
        message = f"Your new verification code is: {otp_code}"

        send_mail(subject, message, settings.EMAIL_HOST_USER, [email])

        return Response({"message": "OTP resent successfully"}, status=200)

    except User.DoesNotExist:
        return Response({"error": "User not found"}, status=404)

    except EmailVerification.DoesNotExist:
        return Response({"error": "No OTP found. Please register again."}, status=404)


class CustomTokenObtainPairView(TokenObtainPairView):
    serializer_class = CustomTokenObtainPairSerializer


@api_view(['POST'])
# to request a password reset otp
def request_password_reset(request):
    email = request.data.get('email')

    try:
        user = User.objects.get(email=email)

        # to check if they are active
        if not user.is_active:
            return Response({"error": "this account is not verified. please register first."}, status=400)
        
        # generate otp (6 digits)
        otp_code = str(random.randint(100000, 999999))
        
        # update or create the verification record
        EmailVerification.objects.update_or_create(
            user=user, 
            defaults={'otp_code': otp_code, 'created_at': timezone.now()}
        )

        # send the email
        subject = "Reset your GaitAnalytica Password"
        message = f"Hello {user.first_name},\n\nYour code to reset your password is: {otp_code}\n\nIf you did not request this, please ignore this email."
        
        send_mail(subject, message, settings.EMAIL_HOST_USER, [email])

        return Response({"message": "reset code sent to your email"}, status=200)

    except User.DoesNotExist:
        # 5. Explicit error so Flutter knows to stay on the screen
        return Response({"error": "no account found with this email address"}, status=404)

@api_view(['POST'])
def reset_password_confirm(request):
    email = request.data.get('email')
    otp_entered = request.data.get('otp')
    new_password = request.data.get('new_password')

    # print these to your terminal to see what flutter is actually sending
    print(f"DEBUG: Email received: '{email}'")
    print(f"DEBUG: OTP received: '{otp_entered}'")

    try:
        user = User.objects.get(email=email)
        verification = EmailVerification.objects.get(user=user)

        if verification.otp_code == otp_entered and not verification.is_expired():
            
            # update password
            user.set_password(new_password)
            user.save()

            verification.delete()

            return Response({"message": "password reset successful"}, status=200)
        else:
            return Response({"error": "invalid or expired code"}, status=400)

    # change the status codes to 400 so the terminal stops saying "URL Not Found"
    except User.DoesNotExist:
        return Response({"error": "debug: user not found"}, status=400)
    except EmailVerification.DoesNotExist:
        return Response({"error": "debug: verification record not found"}, status=400)

# API 3 - to get sessions / history

@api_view(['GET'])
@permission_classes([IsAuthenticated])
# to return gait sessions for the logged-in user 
def get_sessions(request): 

    # get ordering option
    order= request.query_params.get('order', 'newest')
    
    sessions= GaitSession.objects.filter(user=request.user)

    if order == 'oldest':
        sessions= sessions.order_by('session_date')
    else:
        # default -> newest first
        sessions= sessions.order_by('-session_date')

    serializer= GaitSessionSerializer(sessions, many=True)

    return Response(serializer.data)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
# to return full session details / analysis / metrics of one session
def get_session_details(request, session_id):

    try:
        # get the session only if it belongs to a alogged-in user
        session= GaitSession.objects.get(id=session_id, user=request.user)

        # get related objects
        analysis= GaitAnalysis.objects.get(session=session)
        kinematic= KinematicMetric.objects.get(analysis=analysis)
        spatial= SpatialMetric.objects.get(analysis=analysis)
        temporal= TemporalMetric.objects.get(analysis=analysis)

    except GaitSession.DoesNotExist:
        return Response({"error": "Session not found"}, status=404)
    
    return Response({
        "session": GaitSessionSerializer(session).data,
        "analysis": GaitAnalysisSerializer(analysis).data,
        "kinematics": KinematicMetricSerializer(kinematic).data,
        "spatial": SpatialMetricSerializer(spatial).data,
        "temporal": TemporalMetricSerializer(temporal).data,
    })


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
# to remove a session that is not correct
def discard_session(request, session_id):
    try:
        session = GaitSession.objects.get(id=session_id, user=request.user)

        handle_goal_after_session_delete(request.user, session)

        session.delete()

        return Response({"message": "Session discarded"}, status=200)

    except GaitSession.DoesNotExist:
        return Response({"error": "Not found"}, status=404)


# API 4 - profile

# so django doesnt break if profile doesnt exist
def get_or_create_profile(user):
    profile, created= UserProfile.objects.get_or_create(user=user)

    return profile


@api_view(['GET'])
@permission_classes([IsAuthenticated])
# to get user profile / data
def get_profile(request):

    # get or create profile for this user
    profile, created= UserProfile.objects.get_or_create(user=request.user)

    serializer= UserProfileSerializer(profile)

    return Response(serializer.data)



@api_view(['PUT', 'PATCH'])
@permission_classes([IsAuthenticated])
# to update profile
def update_profile(request):

    # get or create profile
    profile, created= UserProfile.objects.get_or_create(user=request.user)

    if request.data.get("remove_profile_pic"):
        if profile.profile_pic:
            profile.profile_pic.delete(save=False)
        profile.profile_pic = None

    # update with incoming data
    serializer= UserProfileSerializer(profile, data=request.data, partial=True)

    if serializer.is_valid():
        serializer.save()

        return Response(serializer.data)
    
    return Response(serializer.errors, status=400)



# API 5 - recovery goal


@api_view(['POST'])
@permission_classes([IsAuthenticated])
# to create a recovery goal
def create_goal(request):

    # get data from frontend 
    metric_name= request.data.get('metric_name')
    target_value = request.data.get('target_value')
    end_date = request.data.get('end_date')

    # get the latest session for logged-in user
    latest_session = GaitSession.objects.filter(
        user=request.user
    ).order_by('-session_date').first()

    # to make sure the user has at least one analysis
    if not latest_session:
        return Response(
            {"error": "No sessions found. Record a session first."},
            status=400
        )
    
    if target_value is None:
        return Response(
            {"error": "Target value is required"},
            status=400
    )

    target_value= float(target_value)
    
    # get analysis
    try:
        analysis = GaitAnalysis.objects.get(session=latest_session)

    except GaitAnalysis.DoesNotExist:
        return Response(
            {"error": "No analysis found for latest session"},
            status=400
    )

    # determine where metric exists
    current_value= None

    # KINEMATIC metrics
    if metric_name == "avg_rom":
        current_value= analysis.kinematic_metrics.avg_rom

    elif metric_name == "knee_symmetry_diff":
        current_value = analysis.kinematic_metrics.knee_symmetry_diff

    # SPATIAL metrics
    elif metric_name == "avg_step_length_norm":
        current_value = analysis.spatial_metrics.avg_step_length_norm

    # TEMPORAL metrics
    elif metric_name == "cadence_bpm":
        current_value = analysis.temporal_metrics.cadence_bpm

    elif metric_name == "stride_time_cv":
        current_value = analysis.temporal_metrics.stride_time_cv

    else:
        return Response(
            {"error": "Invalid metric name"},
            status=400
        )
    
    # check if the same active goal already exists
    existing_goal = UserGoal.objects.filter(
        user=request.user,
        metric_name=metric_name,
        status="Active"
    ).first()

    if existing_goal:
        return Response({
            "message": "Goal already exists",
            "goal": {
                "id": existing_goal.id,
                "metric_name": existing_goal.metric_name,
                "target_value": existing_goal.target_value,
                "status": existing_goal.status
            }
        }, status=200)

    # create goal
    goal= UserGoal.objects.create(
        user=request.user, 
        metric_name=metric_name, 
        target_value=target_value,
        current_value_at_start=current_value,
        end_date=end_date
    )

    return Response({
        "message": "Goal created successfully",

        "goal": {
            "id": goal.id,
            "metric_name": goal.metric_name,
            "starting_value": goal.current_value_at_start,
            "target_value": goal.target_value,
            "status": goal.status
        }
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])

# to return all recovery goals for the logged-in user
def get_goals(request):

    # optional filters
    status_filter = request.query_params.get('status')
    order = request.query_params.get('order', 'newest')

    # get user goals
    goals = UserGoal.objects.filter(user=request.user)

    # filter by status
    if status_filter:
        goals = goals.filter(status=status_filter)

    # ordering
    if order == 'oldest':
        goals = goals.order_by('start_date')
    else:
        goals = goals.order_by('-start_date')

    response_data = []

    # latest session
    latest_session = GaitSession.objects.filter(
        user=request.user
    ).order_by('-session_date').first()

    analysis = None

    if latest_session:
        try:
            analysis = GaitAnalysis.objects.get(session=latest_session)
        except GaitAnalysis.DoesNotExist:
            pass

    for goal in goals:

        latest_value = None

        if analysis:

            if goal.metric_name == "avg_rom":
                latest_value = analysis.kinematic_metrics.avg_rom
                higher_is_better = True

            elif goal.metric_name == "knee_symmetry_diff":
                latest_value = analysis.kinematic_metrics.knee_symmetry_diff
                higher_is_better = False

            elif goal.metric_name == "avg_step_length_norm":
                latest_value = analysis.spatial_metrics.avg_step_length_norm
                higher_is_better = True

            elif goal.metric_name == "cadence_bpm":
                latest_value = analysis.temporal_metrics.cadence_bpm
                higher_is_better = True

            elif goal.metric_name == "stride_time_cv":
                latest_value = analysis.temporal_metrics.stride_time_cv
                higher_is_better = False


        response_data.append({

            "id": goal.id,

            "user": {
                "id": request.user.id,
                "username": request.user.username
            },

            "metric_name": goal.metric_name,

            "target_value": goal.target_value,

            # original value when goal started
            "starting_value": goal.current_value_at_start,

            # newest session value
            "latest_value": latest_value,

            "status": goal.status,

            "achieved_value": goal.achieved_value,
            
            "achieved_date": goal.achieved_date,

            "final_value": goal.final_value,

            "invalid_reason": goal.invalid_reason,

            "start_date": goal.start_date,

            "end_date": goal.end_date,

            "created_at": goal.created_at
        })

    return Response(response_data)



@api_view(['GET'])
@permission_classes([IsAuthenticated])
# to return details of one specific goal
def get_goal_details(request, goal_id):

    try:
        goal = UserGoal.objects.get(
            id=goal_id,
            user=request.user
        )

        achieved_session_deleted = (
            goal.invalid_reason == "session_deleted"
        )

    except UserGoal.DoesNotExist:
        return Response(
            {"error": "Goal not found"},
            status=404
        )

    # get latest session
    latest_session = GaitSession.objects.filter(
        user=request.user
    ).order_by('-session_date').first()

    latest_value = None

    if latest_session:

        try:
            analysis = GaitAnalysis.objects.get(session=latest_session)

            # extract latest metric value
            if goal.metric_name == "avg_rom":
                latest_value = analysis.kinematic_metrics.avg_rom
                higher_is_better = True

            elif goal.metric_name == "knee_symmetry_diff":
                latest_value = analysis.kinematic_metrics.knee_symmetry_diff
                higher_is_better = False

            elif goal.metric_name == "avg_step_length_norm":
                latest_value = analysis.spatial_metrics.avg_step_length_norm
                higher_is_better = True

            elif goal.metric_name == "cadence_bpm":
                latest_value = analysis.temporal_metrics.cadence_bpm
                higher_is_better = True

            elif goal.metric_name == "stride_time_cv":
                latest_value = analysis.temporal_metrics.stride_time_cv
                higher_is_better = False


        except GaitAnalysis.DoesNotExist:
            pass

    return Response({

        "id": goal.id,

        "user": {
            "id": request.user.id,
            "username": request.user.username
        },

        "metric_name": goal.metric_name,

        "starting_value": goal.current_value_at_start,

        "target_value": goal.target_value,

        "current_value": latest_value,

        "final_value": goal.final_value,

        "achieved_session_deleted": achieved_session_deleted,

        "invalid_reason": goal.invalid_reason,

        "status": goal.status,

        "achieved_value": goal.achieved_value,
        
        "achieved_date": goal.achieved_date,

        "start_date": goal.start_date,

        "end_date": goal.end_date,

        "created_at": goal.created_at
    })


@api_view(['PUT', 'PATCH'])
# to update a specific goal
@permission_classes([IsAuthenticated])
def update_goal(request, goal_id):

    try:
        # get goal only if it belongs to logged-in user
        goal = UserGoal.objects.get(
            id=goal_id,
            user=request.user
        )

    except UserGoal.DoesNotExist:

        return Response(
            {"error": "Goal not found"},
            status=404
        )

    # block update if goal already achieved
    if goal.status == "Achieved":

        return Response(
            {"error": "Cannot update an achieved goal"},
            status=400
        )

    # block update if goal cancelled
    if goal.status == "Cancelled":

        return Response(
            {"error": "Cannot update a cancelled goal"},
            status=400
        )

    # get incoming fields
    target_value = request.data.get('target_value')
    end_date = request.data.get('end_date')

    # update target value if provided
    if target_value is not None:

        try:
            target_value = float(target_value)

        except ValueError:

            return Response(
                {"error": "Invalid target value"},
                status=400
            )

        # validation per metric
        if goal.metric_name == "avg_rom":

            if target_value < 10 or target_value > 180:

                return Response(
                    {"error": "ROM target must be between 10 and 180"},
                    status=400
                )

        elif goal.metric_name == "knee_symmetry_diff":

            if target_value < 0 or target_value > 50:

                return Response(
                    {"error": "Symmetry target must be between 0 and 50"},
                    status=400
                )

        elif goal.metric_name == "avg_step_length_norm":

            if target_value < 0 or target_value > 2:

                return Response(
                    {"error": "Step length target must be between 0 and 2"},
                    status=400
                )

        elif goal.metric_name == "cadence_bpm":

            if target_value < 10 or target_value > 250:

                return Response(
                    {"error": "Cadence target must be between 10 and 250"},
                    status=400
                )

        elif goal.metric_name == "stride_time_cv":

            if target_value < 0 or target_value > 1:

                return Response(
                    {"error": "Stride consistency target must be between 0 and 1"},
                    status=400
                )

        goal.target_value = target_value

    # update end date if provided
    if end_date is not None:

        try:
            parsed_date = datetime.strptime(end_date, "%Y-%m-%d").date()

        except ValueError:

            return Response(
                {"error": "Invalid date format"},
                status=400
            )

        # prevent past dates
        if parsed_date < timezone.now().date():

            return Response(
                {"error": "End date cannot be in the past"},
                status=400
            )

        goal.end_date = parsed_date

    # save updates
    goal.save()

    # recheck goal achievement after update
    latest_session = GaitSession.objects.filter(
        user=request.user
    ).order_by('-session_date').first()

    if latest_session:

        try:
            analysis = GaitAnalysis.objects.get(session=latest_session)

            check_goal_achievement(request.user, analysis)

        except GaitAnalysis.DoesNotExist:
            pass

    # get latest metric value
    latest_value = None

    if latest_session:

        try:
            analysis = GaitAnalysis.objects.get(session=latest_session)

            if goal.metric_name == "avg_rom":
                latest_value = analysis.kinematic_metrics.avg_rom

            elif goal.metric_name == "knee_symmetry_diff":
                latest_value = analysis.kinematic_metrics.knee_symmetry_diff

            elif goal.metric_name == "avg_step_length_norm":
                latest_value = analysis.spatial_metrics.avg_step_length_norm

            elif goal.metric_name == "cadence_bpm":
                latest_value = analysis.temporal_metrics.cadence_bpm

            elif goal.metric_name == "stride_time_cv":
                latest_value = analysis.temporal_metrics.stride_time_cv

        except GaitAnalysis.DoesNotExist:
            pass

    return Response({

        "message": "Goal updated successfully",

        "goal": {

            "id": goal.id,

            "user": {
                "id": request.user.id,
                "username": request.user.username
            },

            "metric_name": goal.metric_name,

            "target_value": goal.target_value,

            # original value at goal creation
            "starting_value": goal.current_value_at_start,

            # latest tracked value
            "latest_value": latest_value,

            "status": goal.status,

            "achieved_value": goal.achieved_value,
            
            "achieved_date": goal.achieved_date,

            "start_date": goal.start_date,

            "end_date": goal.end_date,

            "created_at": goal.created_at
        }
    })




@api_view(['PATCH'])
@permission_classes([IsAuthenticated])
# cancel a goal
def cancel_goal(request, goal_id):

    try:
        goal= UserGoal.objects.get(id=goal_id, user=request.user)

    except UserGoal.DoesNotExist:
        return Response(
            {"error": "Goal not found"},
            status=404
        )
    
    if goal.status == "Achieved":
         return Response(
            {"error": "Cannot cancel an achieved goal"},
            status=400
        )

    # get latest session
    latest_session = GaitSession.objects.filter(
        user=request.user
    ).order_by('-session_date').first()

    latest_value = None

    if latest_session:

        try:
            analysis = GaitAnalysis.objects.get(session=latest_session)

            if goal.metric_name == "avg_rom":
                latest_value = analysis.kinematic_metrics.avg_rom

            elif goal.metric_name == "knee_symmetry_diff":
                latest_value = analysis.kinematic_metrics.knee_symmetry_diff

            elif goal.metric_name == "avg_step_length_norm":
                latest_value = analysis.spatial_metrics.avg_step_length_norm

            elif goal.metric_name == "cadence_bpm":
                latest_value = analysis.temporal_metrics.cadence_bpm

            elif goal.metric_name == "stride_time_cv":
                latest_value = analysis.temporal_metrics.stride_time_cv

        except GaitAnalysis.DoesNotExist:
            pass

    goal.status = "Cancelled"
    goal.final_value = latest_value
    goal.end_date = timezone.now().date()
    goal.save()

    return Response({

        "message": "Goal cancelled successfully",

        "goal": {

            "id": goal.id,

            "user": {
                "id": request.user.id,
                "username": request.user.username
            },

            "metric_name": goal.metric_name,

            "target_value": goal.target_value,

            # value when goal started
            "starting_value": goal.current_value_at_start,

            # latest tracked value
            "latest_value": latest_value,

            "status": goal.status,

            "final_value": goal.final_value,
            
            "achieved_date": goal.achieved_date,

            "start_date": goal.start_date,

            "end_date": goal.end_date,

            "created_at": goal.created_at
        }
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
# to get progress of a single goal (for graph part in frontend)
def goal_progress(request, goal_id):

    try: 
        goal= UserGoal.objects.get(id=goal_id, user= request.user)

    except UserGoal.DoesNotExist:
        return Response(
            {"error": "Goal not found"},
            status=404
        )
    
    # get all session for that user (in order)
    sessions= GaitSession.objects.filter(user=request.user).order_by('session_date')

    progress_data= [] # to save the session data for that metric value

    for session in sessions:
        try:
            analysis = GaitAnalysis.objects.get(session=session)

            value= None

            # match metric type
            if goal.metric_name == "avg_rom":
                value = analysis.kinematic_metrics.avg_rom

            elif goal.metric_name == "knee_symmetry_diff":
                value = analysis.kinematic_metrics.knee_symmetry_diff

            elif goal.metric_name == "avg_step_length_norm":
                value = analysis.spatial_metrics.avg_step_length_norm

            elif goal.metric_name == "cadence_bpm":
                value = analysis.temporal_metrics.cadence_bpm

            elif goal.metric_name == "stride_time_cv":
                value = analysis.temporal_metrics.stride_time_cv

            else:
                continue

            progress_data.append({
                "session_id": session.id,
                "date": session.session_date,
                "value": value

            })

        except GaitAnalysis.DoesNotExist:
            continue

    return Response({
        "goal": {
            "id": goal.id,
            "metric": goal.metric_name,
            "target": goal.target_value,
            "status": goal.status
        },
        "progress": progress_data
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
# to get goal completion
def goal_completion(request, goal_id):
    try:
        goal= UserGoal.objects.get(id=goal_id, user=request.user)

    except UserGoal.DoesNotExist:
        return  Response(
            {"error": "Goal not found"}, 
            status=404
        )
    
    # get latest session
    latest_session= GaitSession.objects.filter(user=request.user).order_by('-session_date').first()

    if not latest_session:
        return Response(
            {"error": "No sessions found"}, 
            status=400
        )
    
    try:
        analysis= GaitAnalysis.objects.get(session=latest_session)

    except GaitAnalysis.DoesNotExist:
        return Response(
            {"error": "No analysis found"}, 
            status=400
        )
    
    current_value= None

    # metrics 
    if goal.metric_name == "avg_rom":
        current_value = analysis.kinematic_metrics.avg_rom
        higher_is_better = True

    elif goal.metric_name == "knee_symmetry_diff":
        current_value = analysis.kinematic_metrics.knee_symmetry_diff
        higher_is_better = False

    elif goal.metric_name == "avg_step_length_norm":
        current_value = analysis.spatial_metrics.avg_step_length_norm
        higher_is_better = True

    elif goal.metric_name == "cadence_bpm":
        current_value = analysis.temporal_metrics.cadence_bpm
        higher_is_better = True

    elif goal.metric_name == "stride_time_cv":
        current_value = analysis.temporal_metrics.stride_time_cv
        higher_is_better = False

    else:
        return Response({"error": "Invalid metric"}, status=400)
    
    # calculation for progress
    target= goal.target_value

    if higher_is_better:
        progress = (current_value / target) * 100 if target > 0 else 0
    else:
        progress = (target / current_value) * 100 if current_value > 0 else 0

    # clamp between 0 and 100 
    progress= max(0, min(progress, 100))

    return Response({
        "goal_id": goal.id,
        "metric": goal.metric_name,
        "current_value": current_value,
        "target_value": target,
        "progress_percent": round(progress, 2),
        "status": goal.status
    })


# API 6 - trends (for graphs)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def goal_trend(request, goal_id):

    try:
        goal = UserGoal.objects.get(id=goal_id, user=request.user)

    except UserGoal.DoesNotExist:
        return Response({"error": "Goal not found"}, status=404)

    if goal.status == "Cancelled" and goal.invalid_reason == "session_deleted":
        return Response({
            "goal_id": goal.id,
            "metric": goal.metric_name,
            "trend": "invalid",
            "message": "This goal was invalidated because the session that achieved it was deleted.",
            "data_points": []
        }, status=200)

    metric_map = {
        "avg_rom": ("kinematic_metrics", "avg_rom", True),
        "knee_symmetry_diff": ("kinematic_metrics", "knee_symmetry_diff", False),
        "avg_step_length_norm": ("spatial_metrics", "avg_step_length_norm", True),
        "cadence_bpm": ("temporal_metrics", "cadence_bpm", True),
        "stride_time_cv": ("temporal_metrics", "stride_time_cv", False),
    }

    if goal.metric_name not in metric_map:
        return Response({"error": "Invalid metric"}, status=400)

    section, field, higher_is_better = metric_map[goal.metric_name]

    # get sessions in order
    sessions = GaitSession.objects.filter(
        user=request.user,
        session_date__gte=goal.start_date
    ).order_by('session_date')


    if goal.status in ["Achieved", "Cancelled"]:
        cutoff_date = goal.achieved_date or goal.end_date
        sessions = sessions.filter(session_date__lte=cutoff_date)


    session_ids = sessions.values_list('id', flat=True)
    analyses = GaitAnalysis.objects.filter(session_id__in=session_ids)

    analysis_map = {a.session_id: a for a in analyses}

    # to build data points
    data_points = []

    # loop sessions and extract metric values
    for session in sessions:

        analysis = analysis_map.get(session.id)
        if not analysis:
            continue

        metrics_obj = getattr(analysis, section, None)
        if not metrics_obj:
            continue

        value = getattr(metrics_obj, field, None)
        if value is None:
            continue

        data_points.append({
            "session_id": session.id,
            "date": session.session_date,
            "value": float(value)
        })

    if not data_points:
        return Response(
            {"error": "No data available for this goal yet"},
            status=400
        )

    # first and last values
    start_value = float(goal.current_value_at_start or 0.0)
   
    end_value = data_points[-1]["value"]

    start_value = float(start_value)
    end_value = float(end_value)

    change = end_value - start_value

    # determine trend direction
    if higher_is_better:
        if change > 0:
            trend = "improving"
        elif change < 0:
            trend = "worsening"
        else:
            trend = "stable"
    else:
        # inverse logic
        if change < 0:
            trend = "improving"
        elif change > 0:
            trend = "worsening"
        else:
            trend = "stable"

    return Response({
        "goal_id": goal.id,
        "metric": goal.metric_name,
        "trend": trend,
        "start_value": start_value,
        "latest_value": end_value,
        "change": round(change, 4),
        "data_points": data_points
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def metric_trend(request, metric_name):

    metric_map = {
        "avg_rom": ("kinematic_metrics", "avg_rom", True),
        "knee_symmetry_diff": ("kinematic_metrics", "knee_symmetry_diff", False),
        "avg_step_length_norm": ("spatial_metrics", "avg_step_length_norm", True),
        "cadence_bpm": ("temporal_metrics", "cadence_bpm", True),
        "stride_time_cv": ("temporal_metrics", "stride_time_cv", False),
    }

    if metric_name not in metric_map:
        return Response(
            {"error": "Invalid metric"},
            status=400
        )

    section, field, higher_is_better = metric_map[metric_name]

    sessions = GaitSession.objects.filter(
        user=request.user
    ).order_by('session_date')

    target_session_id = request.query_params.get('session_id')
    if target_session_id:
        target_session_id = target_session_id.rstrip('/')
        try:
            target_session = GaitSession.objects.get(id=target_session_id, user=request.user)
            # filter out any session recorded after the target session's timestamp
            sessions = sessions.filter(session_date__lte=target_session.session_date)
        except GaitSession.DoesNotExist:
            return Response({"error": "Target session context not found"}, status=404)

    data_points = []

    for session in sessions:

        try:
            analysis = GaitAnalysis.objects.get(session=session)

            metrics_obj = getattr(analysis, section)

            value = getattr(metrics_obj, field)

            data_points.append({
                "session_id": session.id,
                "date": session.session_date,
                "value": float(value)
            })

        except (
            GaitAnalysis.DoesNotExist,
            KinematicMetric.DoesNotExist,
            SpatialMetric.DoesNotExist,
            TemporalMetric.DoesNotExist
        ):
            continue

    if not data_points:
        return Response(
            {"error": "No data available"},
            status=400
        )

    first_value = data_points[0]["value"]
    latest_value = data_points[-1]["value"]

    change = latest_value - first_value

    if higher_is_better:

        if change > 0:
            trend = "improving"
        elif change < 0:
            trend = "worsening"
        else:
            trend = "stable"

    else:

        if change < 0:
            trend = "improving"
        elif change > 0:
            trend = "worsening"
        else:
            trend = "stable"

    return Response({

        "metric_name": metric_name,

        "first_value": round(first_value, 4),

        "current_value": round(latest_value, 4),

        "change": round(change, 4),

        "trend": trend,

        "total_sessions": len(data_points),

        "data_points": data_points

    })



# API 7 - notifications


class NotificationViewSet(viewsets.ModelViewSet):
    serializer_class = NotificationSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        self.generate_notifications(self.request.user)
        return Notification.objects.filter(user=self.request.user).order_by('-created_at')

    def generate_notifications(self, user):
        today = date.today()

        expired_goals = UserGoal.objects.filter(
            user=user,
            end_date__lte=today,
            status='Active'
        )

        for goal in expired_goals:
            Notification.objects.get_or_create(
                user=user,
                target_id=str(goal.id),
                notification_type='goal',
                title="Goal Deadline Reached!",
                defaults={
                    'message': f"Today is the deadline for your {goal.get_metric_name_display()} goal. Tap to review.",
                    'target_screen': 'GoalDetail',
                    'is_read': False
                }
            )

        last_session = GaitSession.objects.filter(user=user).order_by('-session_date').first()

        if last_session:
            days_since = (today - last_session.session_date.date()).days
            if days_since >= 3:
                Notification.objects.get_or_create(
                    user=user,
                    notification_type='system',
                    title="Consistency is Key!",
                    message="It's been 3 days since your last gait analysis. Ready for a scan?",
                    defaults={
                        'target_screen': 'ScanInstructions',
                        'is_read': False
                    }
                )

    # Endpoint: mark all as read
    @action(detail=False, methods=['post'], url_path='mark-all-read')
    def mark_all_as_read(self, request):
        self.generate_notifications(request.user)
        queryset = self.get_queryset().filter(is_read=False)
        count = queryset.count()
        queryset.update(is_read=True)
        return Response({
            'message': f'{count} notifications marked as read.',
            'unread_count': 0
        }, status=status.HTTP_200_OK)

    # Endpoint: mark a specific notification as read
    @action(detail=True, methods=['post'], url_path='mark-read')
    def mark_as_read(self, request, pk=None):
        self.generate_notifications(request.user)
        try:
            notification = self.get_object()
            notification.is_read = True
            notification.save()
            return Response({'status': 'notification marked as read'}, status=status.HTTP_200_OK)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_404_NOT_FOUND)
        


# API 8 - ai interpretation 

# to initialize the Gemini Client (i put GEMINI_API_KEY is my environment variables)
client = genai.Client()

@api_view(['GET'])
@permission_classes([IsAuthenticated])
# uses Gemini API to interpret the current session's metrics and video
def interpret_current_session_with_ai(request):
    
    target_session_id = request.query_params.get('session_id')
    
    # 1. fetch the target session and corresponding Analysis data
    if target_session_id:
        target_session_id = target_session_id.rstrip('/')
        try:
            session = GaitSession.objects.get(id=target_session_id, user=request.user)
        except GaitSession.DoesNotExist:
            return Response({"error": "Specified session not found"}, status=404)
    else:
        session = GaitSession.objects.filter(user=request.user).order_by('-session_date').first()
        if not session:
            return Response({"error": "No gait sessions found for this user"}, status=404)

    try:
        analysis = GaitAnalysis.objects.get(session=session)
    except GaitAnalysis.DoesNotExist:
        return Response({"error": "Analysis data not found for this session"}, status=404)

    if analysis.ai_interpretation and analysis.ai_interpretation.strip():
        return Response({
            "session_id": session.id,
            "recorded_date": session.session_date,
            "ai_interpretation": analysis.ai_interpretation
        })

    # 2. extracts the raw numerical values safely from your sub-tables
    raw_rom = float(analysis.kinematic_metrics.avg_rom) if getattr(analysis.kinematic_metrics, 'avg_rom', None) is not None else 0.0
    raw_sym = float(analysis.kinematic_metrics.knee_symmetry_diff) if getattr(analysis.kinematic_metrics, 'knee_symmetry_diff', None) is not None else 0.0
    raw_cad = float(analysis.temporal_metrics.cadence_bpm) if getattr(analysis.temporal_metrics, 'cadence_bpm', None) is not None else 0.0
    raw_cv  = float(analysis.temporal_metrics.stride_time_cv) if getattr(analysis.temporal_metrics, 'stride_time_cv', None) is not None else 0.0
    raw_eff = float(analysis.spatial_metrics.avg_step_length_norm) if getattr(analysis.spatial_metrics, 'avg_step_length_norm', None) is not None else 0.0

    # 3. threshold evaluation logic
    def evaluate_status(val, key):
            if val <= 0.0: return "INVALID"
            v = round(val, 3)
            
            if key == 'rom':
                if v >= 45.0: return "HEALTHY"
                if v >= 35.0: return "NORMAL"
                return "NEEDS WORK"
                
            elif key == 'sym':
                if v <= 7.0: return "HEALTHY"
                if v <= 12.0: return "NORMAL"
                return "NEEDS WORK"
                
            elif key == 'cad':
                if v >= 80.0 and v <= 130.0: return "HEALTHY"
                if v >= 70.0: return "NORMAL"
                return "NEEDS WORK"
                
            elif key == 'cv':
                pct = v * 100
                if pct <= 7.0: return "HEALTHY"
                if pct <= 10.0: return "NORMAL"
                return "NEEDS WORK"
                
            elif key == 'eff':
                if v >= 0.28: return "HEALTHY"
                if v >= 0.20: return "NORMAL"
                return "NEEDS WORK"
                
            return "UNKNOWN"
    

    # 4. matching frontend screen names, ordering, and parsed values
    ordered_metrics_context = [
        {
            "ui_name": "Knee Range of Motion",
            "value": f"{round(raw_rom, 1)} degrees",
            "status": evaluate_status(raw_rom, 'rom')
        },
        {
            "ui_name": "Knee Symmetry",
            "value": f"{round(raw_sym, 1)} degrees",
            "status": evaluate_status(raw_sym, 'sym')
        },
        {
            "ui_name": "Walking Cadence",
            "value": f"{round(raw_cad, 1)} steps/min",
            "status": evaluate_status(raw_cad, 'cad')
        },
        {
            "ui_name": "Stride Consistency",
            "value": f"{round(raw_cv * 100, 1)} %",
            "status": evaluate_status(raw_cv, 'cv')
        },
        {
            "ui_name": "Step Efficiency",
            "value": f"{round(raw_eff, 2)} stature ratio",
            "status": evaluate_status(raw_eff, 'eff')
        }
    ]

    # 5. to send video to Gemini as well
    video_file_system_path = None
    uploaded_file_ref = None
    
    if session.video_path:
        video_file_system_path = session.video_path.path

    try:
        contents_list = []
        
        # if the file exists locally, upload it temporarily to the GenAI Files API
        if video_file_system_path and os.path.exists(video_file_system_path):
            uploaded_file_ref = client.files.upload(file=video_file_system_path)

            while uploaded_file_ref.state.name == "PROCESSING":
                time.sleep(2)  # wait 2 seconds before checking again
                uploaded_file_ref = client.files.get(name=uploaded_file_ref.name)
            
            if uploaded_file_ref.state.name == "FAILED":
                raise Exception("Google video processing file optimization failed.")
            
            contents_list.append(uploaded_file_ref)
        
        # building the structured analytical prompt 
        prompt_text = f"""
        You are a concise, professional biomechanics analysis assistant.
        Analyze the following gait session metrics and correlate them with the movement execution patterns in the video:
        {ordered_metrics_context}

        CRITICAL OUTPUT FORMATTING INSTRUCTIONS:
        CRITICAL OUTPUT FORMATTING INSTRUCTIONS:
        1. You MUST generate exactly FIVE distinct, separate paragraphs—one paragraph for each metric item.
        2. Separate each paragraph with TWO newline characters (\\n\\n) to ensure they render as distinct blocks.
        3. Keep the text in the EXACT sequence order as provided in the metric list above.
        4. Do NOT use any markdown characters like asterisks (**), hashtags (#), bullet points, dashes, or numbered lists.
        5. Do NOT include any introductory statements (e.g., "Here is your report..."), summary remarks, or complimentary chat feedback.
        6. Do NOT include any recommendations, actionable steps, or exercise suggestions at the end. 
        7. Address the user directly using the UI Names provided. Use the Status value provided to ensure your text tone aligns perfectly with whether they are Healthy, Caution, or Needs Work.
        """

        contents_list.append(prompt_text)

        # 5. execute call via Gemini Multimodal framework
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=contents_list,
            config=types.GenerateContentConfig(
                temperature=0.1, 
            )
        )
        
        ai_interpretation = response.text.replace("**", "").replace("*", "").strip()

        # 6. add the interpretation directly into your GaitAnalysis record
        analysis.ai_interpretation = ai_interpretation
        analysis.save()

    except Exception as e:
        return Response({"error": f"Failed during AI processing sequence: {str(e)}"}, status=500)
    
    finally:
        # clean up the file from remote Google servers after evaluation is complete
        if uploaded_file_ref:
            try:
                client.files.delete(name=uploaded_file_ref.name)
            except Exception:
                pass 

    return Response({
        "session_id": session.id,
        "recorded_date": session.session_date,
        "ai_interpretation": ai_interpretation
    })