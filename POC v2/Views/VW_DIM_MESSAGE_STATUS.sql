select 
    upper(dimension_key) as dim_status_key, 
    dimension_value as MESSAGE_STATUS 
from InsightsV2a.MDR_MESSAGE_STATUS 
