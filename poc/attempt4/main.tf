# Zip the Python scripts
data "archive_file" "lambda_dev_zip" {
  type        = "zip"
  source_file = "lambda_dev.py"
  output_path = "lambda_dev.zip"
}

data "archive_file" "lambda_prod_zip" {
  type        = "zip"
  source_file = "lambda_prod.py"
  output_path = "lambda_prod.zip"
}

# IAM role for Lambda execution
resource "aws_iam_role" "lambda_role" {
  name = "lambda_execution_role"
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

# Lambda function for dev
resource "aws_lambda_function" "lambda_dev" {
  function_name = "example_lambda_dev"
  handler       = "lambda_dev.lambda_handler"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_role.arn
  filename      = data.archive_file.lambda_dev_zip.output_path
}

# Lambda function for prod
resource "aws_lambda_function" "lambda_prod" {
  function_name = "example_lambda_prod"
  handler       = "lambda_prod.lambda_handler"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_role.arn
  filename      = data.archive_file.lambda_prod_zip.output_path
}

# API Gateway Rest API
resource "aws_api_gateway_rest_api" "example_api" {
  name = "MyExampleAPI"
}

# API Gateway resource (/hello)
resource "aws_api_gateway_resource" "hello_resource" {
  rest_api_id = aws_api_gateway_rest_api.example_api.id
  parent_id   = aws_api_gateway_rest_api.example_api.root_resource_id
  path_part   = "hello"
}

# API Gateway method (GET /hello)
resource "aws_api_gateway_method" "get_hello_method" {
  rest_api_id   = aws_api_gateway_rest_api.example_api.id
  resource_id   = aws_api_gateway_resource.hello_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

# API Gateway integration with stage variable for Lambda ARN
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.example_api.id
  resource_id             = aws_api_gateway_resource.hello_resource.id
  http_method             = aws_api_gateway_method.get_hello_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
#   uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/$${stageVariables.lambdaArn}/invocations"
  uri                     = aws_lambda_function.lambda_dev.invoke_arn
}

# Permissions for API Gateway to invoke Lambdas
resource "aws_lambda_permission" "apigw_dev" {
  statement_id  = "AllowAPIGatewayInvokeDev"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_dev.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.example_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_prod" {
  statement_id  = "AllowAPIGatewayInvokeProd"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_prod.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.example_api.execution_arn}/*/*"
}

# API Gateway deployment
resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.example_api.id
  depends_on  = [aws_api_gateway_integration.lambda_integration]
}

# API Gateway stages with stage variables
resource "aws_api_gateway_stage" "dev_stage" {
  rest_api_id   = aws_api_gateway_rest_api.example_api.id
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  stage_name    = "dev"
  variables = {
    "lambdaArn" = aws_lambda_function.lambda_dev.arn
  }
}

resource "aws_api_gateway_stage" "prod_stage" {
  rest_api_id   = aws_api_gateway_rest_api.example_api.id
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  stage_name    = "prod"
  variables = {
    "lambdaArn" = aws_lambda_function.lambda_prod.arn
  }
}

# Variable for AWS region
variable "region" {
  default = "ap-southeast-1" # Change to your preferred region
}

output "api_invoke_url" {
  value = aws_api_gateway_stage.dev_stage.invoke_url
}
