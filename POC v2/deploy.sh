#!/bin/sh

project_name=$(gcloud config get-value project)

#enable the APIs we need. 
gcloud services enable bigquery.googleapis.com
gcloud services enable storage.googleapis.com
gcloud services enable pubsub.googleapis.com
gcloud services enable dataflow.googleapis.com
gcloud services enable datacatalog.googleapis.com

#create cloud storage bucket
storage_configname="${project_name}_config"
echo "Storage config: $storage_configname"
gsutil mb gs://$storage_configname

#upload the test_harnes config
gsutil cp main_stream_config_v2.json gs://$storage_configname
gsutil cp top_customers_stream_config_v2.json gs://$storage_configname
gsutil cp -r Data gs://$storage_configname

#create the dataset
bq --location=US mk -d --description "Insights POC Dataset" InsightsV2a

#build tables in data set
bq mk --table InsightsV2a.CORRELATED_MDR schema/CORRELATED_MDR.json
bq mk --table InsightsV2a.REALTIME_MDR_AGGREGATE schema/REALTIME_MDR_AGGREGATE.json

bq mk --table InsightsV2a.MDR_AMP_NAME schema/Dimension.json
bq mk --table InsightsV2a.MDR_CUSTOMER schema/Dimension.json
bq mk --table InsightsV2a.MDR_DLR_CODE schema/Dimension.json
bq mk --table InsightsV2a.MDR_MESSAGE_DIRECTION schema/Dimension.json
bq mk --table InsightsV2a.MDR_MESSAGE_STATUS schema/Dimension.json
bq mk --table InsightsV2a.MDR_PRODUCT schema/Dimension.json
bq mk --table InsightsV2a.MDR_RECORD_TYPE schema/Dimension.json

#Create views... 
bq mk --use_legacy_sql=false --iew "`cat Views/REALTIME_MDR_AGGREGATE.sql`" InsightsV2a.REALTIME_MDR_AGGREGATE
bq mk --use_legacy_sql=false --view "`cat Views/VW_DIM_AMP_NAME.sql`" InsightsV2a.VW_DIM_AMP_NAME
bq mk --use_legacy_sql=false --view "`cat Views/VW_DIM_CUSTOMER.sql`" InsightsV2a.VW_DIM_CUSTOMER
bq mk --use_legacy_sql=false --view "`cat Views/VW_DIM_DLR_CODE.sql`" InsightsV2a.VW_DIM_DLR_CODE
bq mk --use_legacy_sql=false --view "`cat Views/VW_DIM_MDR_PRODUCT.sql`" InsightsV2a.VW_DIM_MDR_PRODUCT
bq mk --use_legacy_sql=false --view "`cat Views/VW_DIM_MESSAGE_DIRECTION.sql`" InsightsV2a.VW_DIM_MESSAGE_DIRECTION
bq mk --use_legacy_sql=false --view "`cat Views/VW_DIM_RECORD_TYPE.sql`" InsightsV2a.VW_DIM_RECORD_TYPE


#insert data in the dimension tables
bq load --source_format=CSV InsightsV2a.MDR_AMP_NAME gs://$storage_configname/Data/MDR_AMP_NAME.csv 
bq load --source_format=CSV InsightsV2a.MDR_CUSTOMER gs://$storage_configname/Data/MDR_CUSTOMER.csv 
bq load --source_format=CSV InsightsV2a.MDR_DLR_CODE gs://$storage_configname/Data/MDR_DLR_CODE.csv 
bq load --source_format=CSV InsightsV2a.MDR_MESSAGE_DIRECTION gs://$storage_configname/Data/MDR_RECORD_TYPE..csv 
bq load --source_format=CSV InsightsV2a.MDR_MESSAGE_STATUS gs://$storage_configname/Data/MDR_RECORD_TYPE.csv 
bq load --source_format=CSV InsightsV2a.MDR_PRODUCT gs://$storage_configname/Data/MDR_PRODUCT.csv 
bq load --source_format=CSV InsightsV2a.MDR_RECORD_TYPE gs://$storage_configname/Data/MDR_RECORD_TYPE.csv 


#create incoming message queue in pub/sub with a subscription so we can look at messages
gcloud pubsub topics create IncomingV2
gcloud pubsub subscriptions create IncomingV2-Sub --topic=IncomingV2 



#command to create top customer test messages Streaming_Data_Generator
df_test_schema="gs://${storage_configname}/top_customers_stream_config_v2.json,topic=projects/${project_name}/topics/IncomingV2"
echo "Fakes top customers stream config: ${df_test_schema}"
gcloud beta dataflow flex-template run stream-fakes-top-customers \
--template-file-gcs-location gs://dataflow-templates-us-central1/latest/flex/Streaming_Data_Generator \
--region us-central1 \
--parameters schemaLocation=${df_test_schema},qps=270

#command to create main customer test messages Streaming_Data_Generator
df_test_schema="gs://${storage_configname}/main_stream_config_v2.json,topic=projects/${project_name}/topics/IncomingV2"
echo "Fakes main customers stream config: ${df_test_schema}"
gcloud beta dataflow flex-template run stream-fakes-main-customers \
--template-file-gcs-location gs://dataflow-templates-us-central1/latest/flex/Streaming_Data_Generator \
--region us-central1 \
--parameters schemaLocation=${df_test_schema},qps=30

#add the schema to the pub/subtopic in BQ's dataflow SQL editor
gcloud beta data-catalog entries update \
 --lookup-entry="pubsub.topic.${project_name}.IncomingV2" \
 --schema-from-file=pubsub_schema_for_inputv2.json 

#command to create BQ stream to Raw holding loacation for incoming messages
gcloud dataflow sql query "SELECT * FROM pubsub.topic.${project_name}.IncomingV2" --job-name dfsql-incomingv2-bq-a --region us-central1 --bigquery-write-disposition write-append --bigquery-project $project_name --bigquery-dataset InsightsV2a --bigquery-table CORRELATED_MDR

#setup Aggregate Query Stream
AggregateQuery="SELECT 
    CUSTOMER_ID,
    MESSAGE_STATUS,	
    RECORD_TYPE,
    DLR_CODE,
    PRODUCT,
    MESSAGE_DIRECTION,
    COUNT(MDR_ID) as MESSAGE_COUNT,
    MESSAGE_DATE,	
    EXTRACT(HOUR FROM event_timestamp) as MESSAGE_HOUR,	
    EXTRACT(MINUTE FROM event_timestamp) as MESSAGE_MINUTE,	
    MAX(event_timestamp) as MESSAGE_DATE_HR_MIN,	
    CALLING_NUMBER,
    AMP_NAME,
    PROVIDER_NAME,	
    CALLED_NUMBER_COUNTRY,	
    MAX(event_timestamp) as SOURCE_INSERT_TIMESTAMP,	
    MAX(event_timestamp) as INSERT_TIMESTAMP,
    MAX(event_timestamp) as UPDATE_TIMESTAMP,	
    CUSTOMER_NAME,
    CALLED_NUMBER_STATE,	
    BILLABLE
FROM pubsub.topic.${project_name}.IncomingV2
Group By 
    TUMBLE(event_timestamp, 'INTERVAL 1 MINUTE'),
    CUSTOMER_ID,
    MESSAGE_STATUS,	
    RECORD_TYPE,
    DLR_CODE,
    PRODUCT,
    MESSAGE_DIRECTION,	
    EXTRACT(HOUR FROM event_timestamp),	
    EXTRACT(MINUTE FROM event_timestamp),	
    EXTRACT(HOUR FROM event_timestamp),	
    CALLING_NUMBER,
    AMP_NAME,
    PROVIDER_NAME,	
    CALLED_NUMBER_COUNTRY,
    CUSTOMER_NAME,	
    CALLED_NUMBER_STATE,	
    BILLABLE, 
    MESSAGE_DATE"

   gcloud dataflow sql query "${AggregateQuery}" --job-name='dfsql-aggregates' --region us-central1 --bigquery-write-disposition write-empty --bigquery-project ${project_name} --bigquery-dataset InsightsV2a --bigquery-table REALTIME_MDR_AGGREGATE


