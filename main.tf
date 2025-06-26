# === S3 BUCKETS ===

resource "aws_s3_bucket" "bucket_a" {
  bucket = "avengers-bucket-a"

  tags = {
    Name        = "exif-images-src"
    Environment = "with-metadata"
  }
}

resource "aws_s3_bucket" "bucket_b" {
  bucket = "avengers-bucket-b"

  tags = {
    Name        = "exif-images-dst"
    Environment = "without-metadata"
  }
}

# === IAM USERS & POLICIES ===

resource "aws_iam_user" "user_a" {
  name = "UserA"
}

resource "aws_iam_user" "user_b" {
  name = "UserB"
}

resource "aws_iam_policy" "user_a_policy" {
  name        = "UserA-RW-BucketA"
  description = "Allow User A read/write access to Bucket A"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      Resource = [
        aws_s3_bucket.bucket_a.arn,
        "${aws_s3_bucket.bucket_a.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_policy" "user_b_policy" {
  name        = "UserB-RO-BucketB"
  description = "Allow User B read-only access to Bucket B"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      Resource = [
        aws_s3_bucket.bucket_b.arn,
        "${aws_s3_bucket.bucket_b.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_user_policy_attachment" "attach_user_a" {
  user       = aws_iam_user.user_a.name
  policy_arn = aws_iam_policy.user_a_policy.arn
}

resource "aws_iam_user_policy_attachment" "attach_user_b" {
  user       = aws_iam_user.user_b.name
  policy_arn = aws_iam_policy.user_b_policy.arn
}

# === LAMBDA ROLE & POLICIES ===

resource "aws_iam_role" "lambda_exec" {
  name = "lambda_basic_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "lambda_s3_access" {
  name        = "LambdaS3Access"
  description = "Allow Lambda access to S3 buckets"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["s3:GetObject", "s3:ListBucket"],
        Resource = [
          aws_s3_bucket.bucket_a.arn,
          "${aws_s3_bucket.bucket_a.arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = ["s3:PutObject"],
        Resource = [
          "${aws_s3_bucket.bucket_b.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_exec_policy" {
  name        = "lambda_exec_policy"
  description = "Log lambda activity to CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Resource = [
          "${aws_s3_bucket.bucket_a.arn}",
          "${aws_s3_bucket.bucket_a.arn}/*",
          "${aws_s3_bucket.bucket_b.arn}",
          "${aws_s3_bucket.bucket_b.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_exec_attach_s3" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_s3_access.arn
}

resource "aws_iam_role_policy_attachment" "lambda_exec_attach_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_exec_policy.arn
}

# === LAMBDA FUNCTION ===

resource "aws_lambda_function" "remove_exif" {
  function_name    = "removeExifFromImages"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.13"
  timeout          = 30
  filename         = "lambda_exif_cleaner.zip"
  source_code_hash = filebase64sha256("lambda_exif_cleaner.zip")

  environment {
    variables = {
      DEST_BUCKET = aws_s3_bucket.bucket_b.bucket
    }
  }
}

# === ALLOW S3 TO INVOKE LAMBDA ===

resource "aws_lambda_permission" "allow_s3_invocation" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.remove_exif.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.bucket_a.arn
}

# === S3 EVENT NOTIFICATION TRIGGER ===

resource "aws_s3_bucket_notification" "bucket_a_trigger" {
  bucket = aws_s3_bucket.bucket_a.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.remove_exif.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".jpg"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.remove_exif.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".jpeg"
  }

  depends_on = [aws_lambda_permission.allow_s3_invocation]
}