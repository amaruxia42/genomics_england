import boto3
from exif import Image
import io
import os

s3 = boto3.client('s3')
DEST_BUCKET = os.environ['DEST_BUCKET']

def lambda_handler(event, context):

    for record in event['Records']:
        src_bucket = record['s3']['bucket']['name']
        obj_key = record['s3']['object']['key']

        if not obj_key.lower().endswith(('.jpg', '.jpeg')):
            print(f"Skipping non-JPG/JPEG file {obj_key}")
            continue

        obj = s3.get_object(Bucket=src_bucket, Key=obj_key)
        img_data = obj['Body'].read()

        try:
            image = Image(img_data)

            # Removes EXIF metadata
            if image.has_exif:
                image.delete_all()
            output = io.BytesIO(image.get_file())

        except Exception as e:
            print(f"Failed to strip EXIF from {obj_key}: {e}")
            continue

        # Upload to destination bucket
        s3.put_object(Bucket=DEST_BUCKET, Key=obj_key, Body=output.getvalue(), ContentType='image/jpeg')
        print(f"Cleaned file written to {DEST_BUCKET}/{obj_key}")