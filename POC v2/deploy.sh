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

#create the dataset
bq --location=US mk -d --description "Insights POC Dataset" InsightsV2a

#build tables in data set
bq mk --table InsightsV2a.CORRELATED_MDR schema/CORRELATED_MDR.json
bq mk --table InsightsV2a.REALTIME_MDR_AGGREGATE schema/REALTIME_MDR_AGGREGATE.json
bq mk --table InsightsV2a.MDR_AMP_NAME schema/MDR_AMP_NAME.json
bq mk --table InsightsV2a.MDR_CUSTOMER schema/MDR_CUSTOMER.json
bq mk --table InsightsV2a.MDR_DLR_CODE schema/MDR_DLR_CODE.json
bq mk --table InsightsV2a.MDR_MESSAGE_DIRECTION schema/MDR_MESSAGE_DIRECTION.json
bq mk --table InsightsV2a.MDR_MESSAGE_STATUS schema/MDR_MESSAGE_STATUS.json
bq mk --table InsightsV2a.MDR_PRODUCT schema/MDR_PRODUCT.json
bq mk --table InsightsV2a.MDR_RECORD_TYPE schema/MDR_RECORD_TYPE.json
#Create views... 
#### Not Done


#insert data in the dimension tables
#### Not Done


#create incoming message queue in pub/sub with a subscription so we can look at messages
gcloud pubsub topics create IncomingV2
gcloud pubsub subscriptions create IncomingV2-Sub --topic=IncomingV2 



#command to create top customer test messages Streaming_Data_Generator
df_test_schema="gs://${storage_configname}/top_customer_stream_config_v2.json,topic=projects/${project_name}/topics/InboundV2"
echo "Fakes stream config: ${df_test_schema}"
gcloud beta dataflow flex-template run namtop_customer-v2-stream-fakes  --template-file-gcs-location gs://dataflow-templates-us-central1/latest/flex/Streaming_Data_Generator --region us-central1 --parameters schemaLocation=${df_test_schema},qps=270


#add the schema to the pub/subtopic in BQ's dataflow SQL editor
entrylocation=pubsub.topic.${project_name}.IncomingV2
echo "Data Catalog Schema Location: ${entrylocation}"

gcloud beta data-catalog entries update --lookup-entry="${entrylocation}" --schema-from-file=pubsub_schema_for_inputv2.json

#command to create BQ stream to Raw holding loacation
gcloud dataflow sql query 'SELECT * FROM pubsub.topic.$project_name.InboundV2' --job-name dfsql-incomingv2-bq-a --region us-central1 --bigquery-write-disposition write-append --bigquery-project $project_name --bigquery-dataset InsightsV2a --bigquery-table CORRELATED_MDR_LONG_TERM




