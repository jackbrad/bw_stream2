#command to create main test message Streaming_Data_Generator
gcloud beta dataflow flex-template run test-v2-stream-fakes --template-file-gcs-location gs://dataflow-templates-us-central1/latest/flex/Streaming_Data_Generator --region us-central1 --parameters schemaLocation=gs://streamer-config/test_stream_config_v2.json,topic=projects/bandwidthstream/topics/TestInboundV2,qps=1