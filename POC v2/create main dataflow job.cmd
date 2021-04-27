gcloud dataflow sql query 'SELECT * FROM pubsub.topic.bandwidthstream.InboundV2' --job-name dfsql-incomingv2-bq-a --region us-central1 --bigquery-write-disposition write-empty --bigquery-project bandwidthstream --bigquery-dataset insightsV2 --bigquery-table CORRELATED_MDR_LONG_TERM