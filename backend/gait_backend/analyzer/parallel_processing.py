import cv2
import mediapipe as mp
from .utils import calculate_angle, get_leg_length

# function to split frames into chunks and process each one
def process_frame_chunk(frames):

    # each process creates its own MediaPipe Pose object (because processes dont share objects safely)
    mp_pose = mp.solutions.pose
    pose = mp_pose.Pose()

    left_angles = []
    right_angles = []
    knee_symmetry_diffs = []
    step_lengths = []

    landmark_frames = 0

    for frame in frames:

        results = pose.process(
            cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        )

        if results.pose_landmarks:

            landmark_frames += 1

            lm = results.pose_landmarks.landmark

            l_hip = (lm[23].x, lm[23].y)
            l_knee = (lm[25].x, lm[25].y)
            l_ankle = (lm[27].x, lm[27].y)

            r_hip = (lm[24].x, lm[24].y)
            r_knee = (lm[26].x, lm[26].y)
            r_ankle = (lm[28].x, lm[28].y)

            ang_l = calculate_angle(
                l_hip,
                l_knee,
                l_ankle
            )

            ang_r = calculate_angle(
                r_hip,
                r_knee,
                r_ankle
            )

            left_angles.append(ang_l)
            right_angles.append(ang_r)

            knee_symmetry_diffs.append(
                abs(ang_l - ang_r)
            )

            step_dist = abs(
                l_ankle[0] - r_ankle[0]
            )

            leg_len = get_leg_length(
                l_hip,
                l_ankle
            )

            step_lengths.append(
                step_dist / leg_len
                if leg_len > 0 else 0
            )

    pose.close()

    return {
        "left_angles": left_angles,
        "right_angles": right_angles,
        "knee_symmetry_diffs": knee_symmetry_diffs,
        "step_lengths": step_lengths,
        "landmark_frames": landmark_frames
    }
