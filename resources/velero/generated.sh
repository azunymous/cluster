#!/usr/bin/env bash
BUCKET_NAME=$1
velero install --provider gcp --plugins velero/velero-plugin-for-gcp:v1.0.1 --bucket $BUCKET_NAME --secret-file service-account.json --use-restic --dry-run -o yaml  > velero.yml
