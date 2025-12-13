#!/bin/bash

minecraft_dir=../minecraft
interval=3600

export AWS_REQUEST_CHECKSUM_CALCULATION=when_required
export AWS_RESPONSE_CHECKSUM_VALIDATION=when_required

aws s3 sync $minecraft_dir s3://$S3_BUCKET_NAME/$S3_BUCKET_PATH/ --delete

echo waiting...
sleep $interval
