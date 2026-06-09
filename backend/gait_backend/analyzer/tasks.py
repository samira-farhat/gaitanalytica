import io
import os
import shutil
import pandas as pd
from django.core.mail import EmailMultiAlternatives
from django.conf import settings
import time
from google import genai
from google.genai import types
from .models import GaitSession, Notification, UserProfile, Consultant, GaitAnalysis
from django_q.tasks import async_task

# function for sending email to consultant
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
    <p><strong>Email Address:</strong> {raw_user.email}</p>
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

    Notification.objects.create(
        user=raw_user, 
        title="Request Sent", 
        message=f"Your request has been shared with {consultant.name}. They will reach out to you soon.", 
        notification_type='system'
    )



# function for ai interpretation
def run_ai_analysis_task(analysis_id):
    analysis = GaitAnalysis.objects.get(id=analysis_id)
    session = analysis.session
    client = genai.Client()

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

    raw_rom = float(analysis.kinematic_metrics.avg_rom) if getattr(analysis.kinematic_metrics, 'avg_rom', None) is not None else 0.0
    raw_sym = float(analysis.kinematic_metrics.knee_symmetry_diff) if getattr(analysis.kinematic_metrics, 'knee_symmetry_diff', None) is not None else 0.0
    raw_cad = float(analysis.temporal_metrics.cadence_bpm) if getattr(analysis.temporal_metrics, 'cadence_bpm', None) is not None else 0.0
    raw_cv  = float(analysis.temporal_metrics.stride_time_cv) if getattr(analysis.temporal_metrics, 'stride_time_cv', None) is not None else 0.0
    raw_eff = float(analysis.spatial_metrics.avg_step_length_norm) if getattr(analysis.spatial_metrics, 'avg_step_length_norm', None) is not None else 0.0

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


    uploaded_file_ref = None
    try:
        contents_list = []
        if session.video_path and os.path.exists(session.video_path.path):
            uploaded_file_ref = client.files.upload(file=session.video_path.path)
            while uploaded_file_ref.state.name == "PROCESSING":
                time.sleep(2)
                uploaded_file_ref = client.files.get(name=uploaded_file_ref.name)
            if uploaded_file_ref.state.name == "FAILED":
                raise Exception("Video processing failed.")
            contents_list.append(uploaded_file_ref)
        

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

        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=contents_list,
            config=types.GenerateContentConfig(temperature=0.1)
        )
        
        analysis.ai_interpretation = response.text.replace("**", "").replace("*", "").strip()
        analysis.save()

        if not Notification.objects.filter(
            user=analysis.session.user, 
            title="AI Analysis Ready", 
            target_id=analysis.session.id
        ).exists():
            Notification.objects.create(
                user=analysis.session.user, 
                title="AI Analysis Ready", 
                message="Your gait analysis interpretation is complete.", 
                notification_type='session', 
                target_screen='AiInterpretation', 
                target_id=analysis.session.id    
            )

    except Exception as e:

        Notification.objects.create(
            user=analysis.session.user, 
            title="Analysis Failed", 
            message="AI analysis could not be completed.", 
            notification_type='system'
        )

    finally:
        if uploaded_file_ref:
            try:
                client.files.delete(name=uploaded_file_ref.name)
            except:
                pass