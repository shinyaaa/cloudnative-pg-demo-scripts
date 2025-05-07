#!/bin/bash

gcloud container clusters create cnds2025-03-node-failure \
  --project cnds2025-db-on-k8s \
  --zone us-central1-c \
  --machine-type e2-medium \
  --disk-size 50 \
  --num-nodes 1 \
  --no-enable-autoscaling \
  --no-enable-autorepair \
  --node-labels cnds2025.com/role=postgres

gcloud storage buckets create gs://cnds2025-03-node-failure \
  --project cnds2025-db-on-k8s

gcloud iam service-accounts create cnds2025-03-node-failure-sa \
  --project cnds2025-db-on-k8s

gcloud projects add-iam-policy-binding cnds2025-db-on-k8s \
  --member serviceAccount:cnds2025-03-node-failure-sa@cnds2025-db-on-k8s.iam.gserviceaccount.com \
  --role roles/storage.admin

gcloud iam service-accounts keys create key.json \
  --project cnds2025-db-on-k8s \
  --iam-account cnds2025-03-node-failure-sa@cnds2025-db-on-k8s.iam.gserviceaccount.com

gcloud container clusters get-credentials cnds2025-03-node-failure \
  --project=cnds2025-db-on-k8s \
  --zone=us-central1-c

kubectl create secret generic backup-creds --from-file=gcsCredentials=key.json
kubectl apply --server-side -f \
  https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.25/releases/cnpg-1.25.1.yaml

sleep 30
kubectl apply -f volume-snapshot-class.yaml
kubectl apply -f pgcluster-prod.yaml

sleep 10
kubectl wait cluster.postgresql.cnpg.io/pgcluster-prod \
  --for=jsonpath='{.status.phase}'="Cluster in healthy state" \
  --timeout=600s

kubectl apply -f pgcluster-prod-backup.yaml

gcloud container clusters resize cnds2025-03-node-failure \
  --node-pool default-pool \
  --num-nodes 4 \
  --zone us-central1-c \
  --project cnds2025-db-on-k8s \
  --quiet
