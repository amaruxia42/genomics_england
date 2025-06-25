# genomics_england
Genomics England Platform AWS/Terraform/Python Test

A company allows their users to upload pictures to an S3 bucket. These pictures are always in the .jpg format.
The company wants these files to be stripped from any exif metadata before being shown on their website.
Pictures are uploaded to an S3 bucket A.
Create a system that retrieves .jpg files when they are uploaded to the S3 bucket A, removes any exif metadata,
and save them to another S3 bucket B. The path of the files should be the same in buckets A and B.

📸 EXIF Metadata Removal Pipeline using AWS Lambda & S3

📝 Solution Scope

This project implements a serverless solution to automatically strip EXIF metadata from .jpg images uploaded to an Amazon S3 bucket (Bucket A) and save the sanitized images to a secondary S3 bucket (Bucket B) with the same key path.

⸻

✅ Step 1: Remove Metadata (EXIF)

🎯 Objective

Ensure that any .jpg images uploaded to the S3 (Bucket A) has its EXIF metadata removed before being uploaded and made available on the company’s website, where it is accessed from another S3 (Bucket B).

⚙️ How It Works
	•	An Amazon S3 event trigger is configured on Bucket A to invoke a Lambda function when a .jpg file is uploaded.
	•	The Lambda function:
	1.	Retrieves the uploaded .jpg file from Bucket A.
	2.	Uses the exif Python module to check and remove any EXIF metadata found.
	3.	Once the EXIF metadata is removed it then writes the cleaned image to Bucket B, preserving the original key (file path).
	•	The file in Bucket B is now ready to upload to the website, free of any metadata information.

⸻

🔐 Step 2: IAM Access Control Least Privileges 

🧑‍💼 User Permissions

Two IAM users are created with least privilege access:
	•	User A:
	•	Needs Read/Write access to Bucket A
	•	Can upload new .jpg files and view/manage existing ones.
	•	User B:
	•	Read-only access to Bucket B
	•	Can safely view sanitized images served on the website.

⸻

📦 Tech Stack
	•	AWS S3 (storage) 
	•	AWS Lambda (image processing)
	•	IAM (access control)
	•	Terraform (infrastructure as code)
	•	Python with:
	•	exif
	•	reverse_geocoder (optional future use but outside the requirements stated for the task)
	•	pycountry (optional future use, but outside the requirements stated for the task)

⸻

📁 Folder Structure
