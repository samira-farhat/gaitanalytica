# GaitAnalytica

A smartphone-based markerless gait analysis system for rehabilitation monitoring and quantitative gait assessment.

GaitAnalytica is a Final Year Project developed at Phoenicia University that leverages Computer Vision and Artificial Intelligence to analyze human gait from a simple smartphone video. The system extracts clinically relevant gait metrics without requiring wearable sensors or specialized laboratory equipment, making gait monitoring more accessible for rehabilitation and long-term progress tracking.

---

# Project Overview

Traditional gait analysis systems rely on expensive marker-based motion capture equipment and controlled laboratory environments.

GaitAnalytica provides an alternative approach by using:

- Smartphone video recordings
- MediaPipe Pose Estimation
- OpenCV
- Computer Vision
- Biomechanical feature extraction
- AI-generated gait interpretation

The application allows users to upload walking videos, automatically extract gait measurements, monitor rehabilitation progress, communicate with consultants, and receive AI-assisted explanations of their gait results.

---

# Features

## User Authentication

- User registration
- Secure login
- Password reset
- JWT authentication
- OTP verification

---

## Gait Analysis

- Upload walking videos
- Automatic pose estimation using MediaPipe
- Skeleton video generation
- Automatic gait feature extraction

Extracted metrics include:

- Knee Range of Motion (ROM)
- Knee Symmetry
- Step Length
- Step Length Symmetry
- Walking Cadence
- Average Stride Time
- Stride Time Variability
- Step Efficiency

---

## Progress Tracking

- View previous gait sessions
- Compare historical analyses
- Monitor rehabilitation progress over time
- Interactive metric visualization

---

## Goal Management

Users can create rehabilitation goals for:

- Knee ROM
- Knee Symmetry
- Cadence
- Stride Consistency
- Step Efficiency

The system automatically checks whether goals have been achieved after each completed gait analysis.

---

## AI Interpretation

Each completed gait analysis is automatically interpreted using Google's Gemini API.

The AI generates:

- Metric-by-metric explanations
- Clinical interpretation
- Easy-to-understand summaries

---

## Consultant Module

Users can:

- Connect with rehabilitation consultants
- Share gait sessions
- Receive professional feedback

---

## Notifications

Automatic notifications are generated for:

- Completed analyses
- Goal achievements
- Consultant updates
- AI interpretation completion

---

# System Architecture

Frontend:
- Flutter

Backend:
- Django
- Django REST Framework

Computer Vision:
- MediaPipe
- OpenCV

Database:
- SQLite (Development)

Background Processing:
- Django-Q2

AI:
- Google Gemini API

---

# Technologies Used

## Frontend

- Flutter
- Dart

## Backend

- Python
- Django
- Django REST Framework

## Computer Vision

- MediaPipe
- OpenCV
- NumPy
- SciPy

## Database

- SQLite

## AI

- Google Gemini API

---

# Gait Processing Pipeline

1. User uploads a walking video.
2. Video is sent to the Django backend.
3. MediaPipe extracts body landmarks.
4. OpenCV processes each frame.
5. Biomechanical features are calculated.
6. Results are stored in the database.
7. AI generates an interpretation.
8. Results become available inside the mobile application.

---

# Running the Application

## Start the Django Server

```bash
python manage.py runserver
```

---

## Start the Background Task Queue

In a second terminal:

```bash
python manage.py qcluster
```

---

## Run the Flutter Application

```bash
flutter run
```

---

# Application Screenshots

## Authentication (Login + Registration + Forgot Password)



---

## Home Screen

(Add image here)

---

## Upload Video

(Add image here)

---

## Gait Analysis Results

(Add image here)

---

## Progress Tracking

(Add image here)

---

## Goal Management

(Add image here)

---

## AI Interpretation

(Add image here)

---

## Consultant Module

(Add image here)

---

# Biomechanical Metrics

The system extracts multiple clinically relevant gait parameters, including:

| Metric | Description |
|---------|-------------|
| Knee Range of Motion | Difference between maximum and minimum knee angle during walking |
| Knee Symmetry | Difference between left and right knee movement |
| Step Length | Normalized distance between both feet |
| Cadence | Number of steps per minute |
| Average Stride Time | Average time between consecutive strides |
| Stride Time Variability | Consistency of stride timing |
| Step Efficiency | Normalized walking efficiency |

---

# Validation

The extracted gait metrics are compared against biomechanical reference ranges reported in the literature.

Additionally, qualitative clinical consistency validation was performed using the University of Utah *Neurologic Exam Videos and Descriptions*, where the extracted metrics were verified against documented gait abnormalities.

---

# Future Improvements

- Clinical validation using real patient datasets
- 3D pose estimation
- Real-time gait analysis
- Cloud deployment
- Additional gait metrics
- Wearable sensor integration

---

# Author

**Samira Farhat**

Bachelor of Science in Computer Science

Phoenicia University

GitHub:
https://github.com/samira-farhat

---

# License

This project was developed as a Final Year Project for academic purposes at Phoenicia University.
