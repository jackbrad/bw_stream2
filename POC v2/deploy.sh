#!/bin/sh

project_name=$(gcloud config get-value project)

#enable the APIs we need. 
gcloud services enable bigquery.googleapis.com
gcloud services enable storage.googleapis.com
gcloud services enable pubsub.googleapis.com
gcloud services enable dataflow.googleapis.com

#install uuidgen for cloud storage bucket name
sudo apt install uuid-runtime

#create cloud storage bucket
storage_configname=$(uuidgen)
gsutil mb gs://$storage_configname

#upload the test_harnes config
gsutil cp main_stream_config_v2.json gs://$storage_configname
gsutil cp top_customers_stream_config_v2.json gs://$storage_configname

#create the dataset
bq --location=US mk -d --description "Insights POC Dataset" InsightsV2a

#build tables in data set
bq mk --table InsightsV2a.CORRELATED_MDR CORRELATED_MDR.json
bq mk --table InsightsV2a.REALTIME_MDR_AGGREGATE REALTIME_MDR_AGGREGATE.json
bq mk --table InsightsV2a.MDR_AMP_NAME MDR_AMP_NAME.json
bq mk --table InsightsV2a.MDR_CUSTOMER MDR_CUSTOMER.json
bq mk --table InsightsV2a.MDR_DLR_CODE MDR_DLR_CODE.json
bq mk --table InsightsV2a.MDR_MESSAGE_DIRECTION MDR_MESSAGE_DIRECTION.json
bq mk --table InsightsV2a.MDR_MESSAGE_STATUS MDR_MESSAGE_STATUS.json
bq mk --table InsightsV2a.MDR_PRODUCT MDR_PRODUCT.json
bq mk --table InsightsV2a.MDR_RECORD_TYPE MDR_RECORD_TYPE.json

#create incoming message queue in pub/sub
gcloud pubsub topics create IncomingV2
gcloud pubsub subscriptions create IncomingV2-Sub --topic=IncomingV2 

#command to create top customer test messages Streaming_Data_Generator
gcloud beta dataflow flex-template run top_customer-v2-stream-fakes --template-file-gcs-location gs://dataflow-templates-us-central1/latest/flex/Streaming_Data_Generator --region us-central1 --parameters schemaLocation=gs://$storage_configname/top_customer_stream_config_v2.json,topic=projects/$project_name/topics/InboundV2,qps=270
#command to create main test messages Streaming_Data_Generator
gcloud beta dataflow flex-template run main-v2-stream-fakes --template-file-gcs-location gs://dataflow-templates-us-central1/latest/flex/Streaming_Data_Generator --region us-central1 --parameters schemaLocation=gs://$storage_configname/main_stream_config_v2.json,topic=projects/$project_name/topics/InboundV2,qps=30

#command to create BQ stream to Raw holding loacation
gcloud dataflow sql query 'SELECT * FROM pubsub.topic.$project_name.InboundV2' --job-name dfsql-incomingv2-bq-a --region us-central1 --bigquery-write-disposition write-append --bigquery-project $project_name --bigquery-dataset InsightsV2a --bigquery-table CORRELATED_MDR_LONG_TERM