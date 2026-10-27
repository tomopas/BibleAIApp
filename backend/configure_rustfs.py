"""Create the public read-only RustFS bucket used for chapter audio."""

from __future__ import annotations

import json
import os

import boto3
from botocore.exceptions import ClientError
from dotenv import load_dotenv

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
load_dotenv(os.path.join(ROOT, "deploy", ".env"))

ENDPOINT = os.environ.get("AUDIO_S3_ENDPOINT", "http://127.0.0.1:9000")
BUCKET = os.environ.get("AUDIO_S3_BUCKET", "bible-audio")
REGION = os.environ.get("AUDIO_S3_REGION", "us-east-1")


def main() -> None:
    client = boto3.client(
        "s3",
        endpoint_url=ENDPOINT,
        region_name=REGION,
        aws_access_key_id=os.environ["AUDIO_S3_ACCESS_KEY"],
        aws_secret_access_key=os.environ["AUDIO_S3_SECRET_KEY"],
    )
    try:
        client.head_bucket(Bucket=BUCKET)
    except ClientError:
        client.create_bucket(Bucket=BUCKET)
    policy = {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "PublicReadAudio",
                "Effect": "Allow",
                "Principal": "*",
                "Action": ["s3:GetObject"],
                "Resource": [f"arn:aws:s3:::{BUCKET}/*"],
            }
        ],
    }
    client.put_bucket_policy(Bucket=BUCKET, Policy=json.dumps(policy))
    print(f"Configured public read-only bucket {BUCKET} at {ENDPOINT}")


if __name__ == "__main__":
    main()
