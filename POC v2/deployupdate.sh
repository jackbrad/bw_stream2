#!/bin/sh

project_name=$(gcloud config get-value project)

#create cloud storage bucket
storage_configname="${project_name}_config"
echo "Storage config: $storage_configname"

#upload the test_harnes config
gsutil cp main_stream_config_v2.json gs://$storage_configname
gsutil cp top_customers_stream_config_v2.json gs://$storage_configname

gcloud dataflow jobs cancel stream-fakes-top-customers
gcloud dataflow jobs cancel stream-fakes-main-customers

#command to create top customer test messages Streaming_Data_Generator
df_test_schema="gs://${storage_configname}/top_customers_stream_config_v2.json,topic=projects/${project_name}/topics/IncomingV2"
echo "Fakes top customers stream config: ${df_test_schema}"
gcloud beta dataflow flex-template run stream-fakes-top-customers2 \
--template-file-gcs-location gs://dataflow-templates-us-central1/latest/flex/Streaming_Data_Generator \
--region us-central1 \
--parameters schemaLocation=${df_test_schema},qps=270

#command to create main customer test messages Streaming_Data_Generator
df_test_schema="gs://${storage_configname}/main_stream_config_v2.json,topic=projects/${project_name}/topics/IncomingV2"
echo "Fakes main customers stream config: ${df_test_schema}"
gcloud beta dataflow flex-template run stream-fakes-main-customers2 \
--template-file-gcs-location gs://dataflow-templates-us-central1/latest/flex/Streaming_Data_Generator \
--region us-central1 \
--parameters schemaLocation=${df_test_schema},qps=30

#add the schema to the pub/subtopic in BQ's dataflow SQL editor
gcloud beta data-catalog entries update \
 --lookup-entry="pubsub.topic.${project_name}.IncomingV2" \
 --schema-from-file=pubsub_schema_for_inputv2.json 
