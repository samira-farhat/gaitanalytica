
from django.contrib import admin
from .models import (
    UserProfile,
    GaitSession,
    GaitAnalysis,
    KinematicMetric,
    SpatialMetric,
    TemporalMetric,
    UserGoal
)

admin.site.register(UserProfile)
admin.site.register(GaitSession)
admin.site.register(GaitAnalysis)
admin.site.register(KinematicMetric)
admin.site.register(SpatialMetric)
admin.site.register(TemporalMetric)
admin.site.register(UserGoal)