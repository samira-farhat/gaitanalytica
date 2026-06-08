from django.contrib import admin
from .models import (
    UserProfile,
    Consultant,
    GaitSession,
    GaitAnalysis,
    KinematicMetric,
    SpatialMetric,
    TemporalMetric,
    UserGoal,
    EmailVerification,
    Notification
)

# Registering models
admin.site.register(UserProfile)
admin.site.register(GaitSession)
admin.site.register(GaitAnalysis)
admin.site.register(KinematicMetric)
admin.site.register(SpatialMetric)
admin.site.register(TemporalMetric)
admin.site.register(UserGoal)
admin.site.register(EmailVerification)
admin.site.register(Notification)


@admin.register(Consultant)
class ConsultantAdmin(admin.ModelAdmin):
    list_display = ('name', 'specialization', 'email')
    search_fields = ('name', 'specialization')