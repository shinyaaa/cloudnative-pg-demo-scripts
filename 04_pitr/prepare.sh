#!/bin/bash

gcloud container clusters create cnds2025-04-pitr \
  --project cnds2025-db-on-k8s \
  --zone us-central1-c \
  --machine-type e2-medium \
  --disk-size 50 \
  --num-nodes 3 \
  --node-labels cnds2025.com/role=postgres

gcloud storage buckets create gs://cnds2025-04-pitr \
  --project cnds2025-db-on-k8s

gcloud iam service-accounts create cnds2025-04-pitr-sa \
  --project cnds2025-db-on-k8s

gcloud projects add-iam-policy-binding cnds2025-db-on-k8s \
  --member serviceAccount:cnds2025-04-pitr-sa@cnds2025-db-on-k8s.iam.gserviceaccount.com \
  --role roles/storage.admin

gcloud iam service-accounts keys create key.json \
  --project cnds2025-db-on-k8s \
  --iam-account cnds2025-04-pitr-sa@cnds2025-db-on-k8s.iam.gserviceaccount.com

gcloud container clusters get-credentials cnds2025-04-pitr \
  --project=cnds2025-db-on-k8s \
  --zone=us-central1-c

kubectl create secret generic backup-creds --from-file=gcsCredentials=key.json
kubectl apply --server-side -f \
  https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.25/releases/cnpg-1.25.1.yaml

sleep 10
kubectl apply -f volume-snapshot-class.yaml
kubectl apply -f pgcluster-prod.yaml

sleep 10
kubectl wait cluster.postgresql.cnpg.io/pgcluster-prod \
  --for=jsonpath='{.status.phase}'="Cluster in healthy state" \
  --timeout=600s

kubectl exec -i pgcluster-prod-1 -- psql -c "CREATE TABLE orders (order_id SERIAL PRIMARY KEY, customer_id INTEGER NOT NULL, order_date TIMESTAMP WITH TIME ZONE, total_amount NUMERIC(10, 2) NOT NULL, status VARCHAR(50) NOT NULL)"
kubectl exec -i pgcluster-prod-1 -- psql -c "INSERT INTO orders (customer_id, order_date, total_amount, status) VALUES (101, '2025-04-21 10:30:00+09:00', 150.75, 'shipped'), (102, '2025-04-22 14:15:00+09:00', 89.99, 'delivered'), (103, '2025-04-23 09:00:00+09:00', 250.00, 'pending'), (101, '2025-04-24 11:45:10+09:00', 75.50, 'delivered'), (104, '2025-04-25 16:20:30+09:00', 120.00, 'processing'), (102, '2025-04-26 08:05:00+09:00', 45.30, 'shipped'), (105, '2025-04-27 19:00:00+09:00', 500.80, 'pending'), (103, '2025-04-28 12:00:00+09:00', 99.95, 'delivered'), (101, '2025-04-29 15:30:45+09:00', 15.00, 'shipped'), (104, '2025-04-30 10:00:00+09:00', 310.40, 'processing')"
kubectl exec -i pgcluster-prod-1 -- psql -c "SELECT * FROM orders"

kubectl apply -f pgcluster-prod-backup.yaml
