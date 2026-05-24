import cv2
import mediapipe as mp

# initializing MediaPipe
mp_pose = mp.solutions.pose
mp_drawing = mp.solutions.drawing_utils

# to load the test video
video_path = "test_videos/v1_90.mp4"  
cap = cv2.VideoCapture(video_path)

pose = mp_pose.Pose()

while True:
    ret, frame = cap.read()
    if not ret:
        break

    # convert to RGB
    rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

    # process the frame
    results = pose.process(rgb)

    if results.pose_landmarks:
        # draw skeleton + landmarks
        mp_drawing.draw_landmarks(
            frame,
            results.pose_landmarks,
            mp_pose.POSE_CONNECTIONS
        )

    # show frame
    cv2.imshow("Pose Detection", frame)

    # press Q to exit
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()