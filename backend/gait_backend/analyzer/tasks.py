import io
import os
import shutil
import pandas as pd
from django.core.mail import EmailMultiAlternatives
from django.conf import settings
from .models import GaitSession, Notification, UserProfile, Consultant

def send_consultation_email_task(user_id, consultant_id, survey_data, scope):
    user = UserProfile.objects.get(user_id=user_id)
    raw_user = user.user
    consultant = Consultant.objects.get(id=consultant_id)
    
    sessions = raw_user.gait_sessions.all().order_by('-session_date')
    if scope == 'latest':
        sessions = sessions[:1]

    data = []

    os.makedirs(settings.EXPORTS_ROOT, exist_ok=True)

    for i, s in enumerate(sessions, 1):

        # handle video export for public viewing
        public_url = "N/A"
        if s.video_path:
            file_name = f"session_{s.id}_{raw_user.id}.mp4"
            dest_path = os.path.join(settings.EXPORTS_ROOT, file_name)
            
            # copy to public folder if it doesn't exist yet
            if not os.path.exists(dest_path):
                shutil.copy2(s.video_path.path, dest_path)
            
            # use your local IP/Domain here. 
            base_url = "http://127.0.0.1:8000" 
            public_url = f"{base_url}{settings.EXPORTS_URL}{file_name}"

        analysis = getattr(s, 'analysis', None)
        data.append({
            'Session #': i,
            'Date': s.session_date.strftime('%Y-%m-%d'),
            'Knee Range of Motion': f"{analysis.kinematic_metrics.avg_rom:.5f}" if analysis else "N/A",
            'Knee Symmetry': f"{analysis.kinematic_metrics.knee_symmetry_diff:.5f}" if analysis else "N/A",
            'Step Efficiency': f"{analysis.spatial_metrics.avg_step_length_norm:.5f}" if analysis else "N/A",
            'Walking Cadence': f"{analysis.temporal_metrics.cadence_bpm:.5f}" if analysis else "N/A",
            'Stride Consistency': f"{analysis.temporal_metrics.stride_time_cv:.5f}" if analysis else "N/A",
            'Video URL': public_url
        })
    
    df = pd.DataFrame(data)
    excel_buffer = io.BytesIO()
    with pd.ExcelWriter(excel_buffer, engine='xlsxwriter') as writer:
        df.to_excel(writer, index=False, sheet_name='GaitData')
    excel_buffer.seek(0)

    html_content = f"""
    <h2>Consultation Request: {raw_user.first_name} {raw_user.last_name}</h2>
    <p><strong>Profile:</strong> Age {user.age}, {user.gender}, {user.height_cm}cm, {user.weight_kg}kg</p>
    <hr>
    <h3>Clinical Concern</h3>
    <p><strong>Primary:</strong> {survey_data.get('concern')}</p>
    <p><strong>Notes:</strong> {survey_data.get('notes')}</p>
    <hr>
    <p>Attached is the full gait analysis data for the requested session scope.</p>
    """

    msg = EmailMultiAlternatives(f"GaitAnalytica Consultation: {raw_user.first_name}", "Please view in HTML.", settings.EMAIL_HOST_USER, [consultant.email])
    msg.attach_alternative(html_content, "text/html")
    msg.attach(f"GaitData_{raw_user.username}.xlsx", excel_buffer.getvalue(), 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
    msg.send()

    Notification.objects.create(user=raw_user, title="Request Sent", message=f"Your data was sent to {consultant.name}.", notification_type='system')