select 
    upper(dimension_key) as dim_direction_key, 
    dimension_value as MESSAGE_DIRECTION 
from InsightsV2a.MDR_MESSAGE_DIRECTION
