# 1. First, create a zip file of your layer content
data "archive_file" "lambda_layer_zip" {
  type        = "zip"
  source_dir  = "${path.module}/layer_content/python"  # Directory containing your layer code/files
  output_path = "${path.module}/lambda_layer.zip"
}

# 2. Upload the layer to S3 (optional, but recommended for larger layers)
# resource "aws_s3_object" "lambda_layer_s3" {
#   bucket = "your-s3-bucket-name"
#   key    = "lambda_layers/lambda_layer.zip"
#   source = data.archive_file.lambda_layer_zip.output_path
# }

# 3. Create the Lambda Layer
resource "aws_lambda_layer_version" "my_lambda_layer" {
  layer_name          = "atl-lambda-base-layer"
  filename            = data.archive_file.lambda_layer_zip.output_path
  compatible_runtimes = ["python3.12", "python3.13"]  # Specify your runtime
  description         = "Base python layer containing dependencies for ATLAS lambda functions"

  # Optional parameters
  # license_info       = "MIT"
  source_code_hash   = data.archive_file.lambda_layer_zip.output_base64sha256
}

# resource "aws_iam_role" "lambda_role" {
#   name = "lambda-execution-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Action = "sts:AssumeRole",
#       Effect = "Allow",
#       Principal = {
#         Service = "lambda.amazonaws.com"
#       }
#     }]
#   })
# }

# # 4. Example of attaching the layer to a Lambda function
# resource "aws_lambda_function" "example" {
#   filename      = "lambda_function.zip"
#   function_name = "example_lambda"
#   role          = aws_iam_role.lambda_role.arn
#   handler       = "lambda_function.lambda_handler"
#   runtime       = "python3.12"

#   # Attach the layer
#   layers = [aws_lambda_layer_version.my_lambda_layer.arn]
# }