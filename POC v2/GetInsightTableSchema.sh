#Get the table schema for the Insights Database for deployement
bq show --format=prettyjson bandwidthstream:insightsV2.CORRELATED_MDR | jq '.schema.fields' >CORRELATED_MDR.json
bq show --format=prettyjson bandwidthstream:insightsV2.REALTIME_MDR_AGGREGATE | jq '.schema.fields' >REALTIME_MDR_AGGREGATE.json
bq show --format=prettyjson bandwidthstream:insightsV2.MDR_AMP_NAME | jq '.schema.fields' >MDR_AMP_NAME.json
bq show --format=prettyjson bandwidthstream:insightsV2.MDR_CUSTOMER | jq '.schema.fields' >MDR_CUSTOMER.json
bq show --format=prettyjson bandwidthstream:insightsV2.MDR_DLR_CODE | jq '.schema.fields' >MDR_DLR_CODE.json
bq show --format=prettyjson bandwidthstream:insightsV2.MDR_MESSAGE_DIRECTION | jq '.schema.fields' >MDR_MESSAGE_DIRECTION.json
bq show --format=prettyjson bandwidthstream:insightsV2.MDR_MESSAGE_STATUS | jq '.schema.fields' >MDR_MESSAGE_STATUS.json
bq show --format=prettyjson bandwidthstream:insightsV2.MDR_PRODUCT | jq '.schema.fields' >MDR_PRODUCT.json
bq show --format=prettyjson bandwidthstream:insightsV2.MDR_RECORD_TYPE | jq '.schema.fields' >MDR_RECORD_TYPE.json
