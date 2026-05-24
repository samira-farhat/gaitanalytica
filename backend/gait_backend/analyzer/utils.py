import math

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
