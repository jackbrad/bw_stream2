select 
    upper(dimension_key) as dim_record_type_key, 
    dimension_value as RECORD_TYPE 
from InsightsV2a.MDR_RECORD_TYPE
