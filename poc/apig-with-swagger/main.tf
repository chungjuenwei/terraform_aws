

# Create the Lambda function
resource "aws_lambda_function" "example_lambda" {
  function_name    = "example_lambda_function"
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  role             = aws_iam_role.lambda_exec.arn
  
}

# Zip the Lambda function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

# IAM role for Lambda
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Attach basic execution policy
resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# API Gateway
resource "aws_api_gateway_rest_api" "example_api" {
  name        = "example_api"
  description = "Example API Gateway"
  # body        = templatefile("swagger.yml", { lambda_arn = aws_lambda_function.example_lambda.invoke_arn })
  body        = file("swagger.yml") 
}

resource "aws_api_gateway_deployment" "example" {
  rest_api_id = aws_api_gateway_rest_api.example_api.id
  stage_name  = "prod"
}

# Lambda permission
resource "aws_lambda_permission" "apigw_cross_account" {
  statement_id  = "AllowCrossAccountAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = "example_lambda_function" # Hardcoded function name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.example_api.execution_arn}/*/*"

  # source_account = "API_GATEWAY_ACCOUNT_ID" # For Cross Account permissions
}

output "api_url" {
  value = "curl -X POST ${aws_api_gateway_deployment.example.invoke_url}/example"
}

output "lambda_arn" {
  value = aws_lambda_function.example_lambda.arn
}

output "value_used_for_swagger" {
  value = aws_lambda_function.example_lambda.invoke_arn
}

