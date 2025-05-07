#!/bin/bash

gcloud container clusters delete cnds2025-04-pitr \
  --project cnds2025-db-on-k8s \
  --zone us-central1-c \
  --quiet

gcloud storage rm --recursive gs://cnds2025-04-pitr

gcloud projects remove-iam-policy-binding cnds2025-db-on-k8s \
  --member serviceAccount:cnds2025-04-pitr-sa@cnds2025-db-on-k8s.iam.gserviceaccount.com \
  --role roles/storage.admin

gcloud iam service-accounts delete cnds2025-04-pitr-sa@cnds2025-db-on-k8s.iam.gserviceaccount.com \
  --quiet

rm -f key.json
