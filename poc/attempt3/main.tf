variable "aws_region" {
  description = "AWS region"
  default     = "ap-southeast-1"
}

variable "lambda_vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "apigw_vpc_cidr" {
  default = "10.1.0.0/16"
}


# Create Lambda VPC
resource "aws_vpc" "lambda_vpc" {
  cidr_block           = var.lambda_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "lambda-vpc"
  }
}

resource "aws_subnet" "lambda_subnet" {
  vpc_id            = aws_vpc.lambda_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"
  tags = {
    Name = "lambda-subnet"
  }
}

resource "aws_security_group" "lambda_sg" {
  name        = "lambda-sg"
  description = "Allow outbound traffic for Lambda"
  vpc_id      = aws_vpc.lambda_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Lambda IAM Role
resource "aws_iam_role" "lambda_role" {
  name = "lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Lambda Function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "lambda_function.py"
  output_path = "lambda_function.zip"
}

resource "aws_lambda_function" "example_lambda" {
  filename      = "lambda_function.zip"
  function_name = "example-lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.8"

  vpc_config {
    subnet_ids         = [aws_subnet.lambda_subnet.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}




# API Gateway
resource "aws_api_gateway_rest_api" "example_api" {
  name        = "example-api"
  description = "Example API Gateway"
}

# Root resource
resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.example_api.id
  parent_id   = aws_api_gateway_rest_api.example_api.root_resource_id
  path_part   = "{proxy+}" # Catches all paths (e.g., /any/path/here)
}

# # Method for root path
# resource "aws_api_gateway_method" "root_method" {
#   rest_api_id   = aws_api_gateway_rest_api.example_api.id
#   resource_id   = aws_api_gateway_rest_api.example_api.root_resource_id
#   http_method   = "ANY"  # Handles all HTTP methods
#   authorization = "NONE" # No auth required
# }

# Method for proxy paths ("/{proxy+}")
resource "aws_api_gateway_method" "proxy_method" {
  rest_api_id   = aws_api_gateway_rest_api.example_api.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

# Connects root method to Lambda
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.example_api.id
  resource_id = aws_api_gateway_method.proxy_method.resource_id
  http_method = aws_api_gateway_method.proxy_method.http_method
  integration_http_method = "POST"
  type        = "AWS_PROXY" # Lambda integration
  uri         = aws_lambda_function.example_lambda.invoke_arn
}

# # Connects proxy method to Lambda
# resource "aws_api_gateway_integration" "proxy_integration" {
#   rest_api_id = aws_api_gateway_rest_api.example_api.id
#   resource_id = aws_api_gateway_method.proxy_method.resource_id
#   http_method = aws_api_gateway_method.proxy_method.http_method
#   integration_http_method = "POST"
#   type        = "AWS_PROXY"
#   uri         = aws_lambda_function.example_lambda.invoke_arn
# }


# Deployment & Stage
resource "aws_api_gateway_deployment" "example_deployment" {
  depends_on = [
    aws_api_gateway_integration.lambda_integration,
  ]
  rest_api_id = aws_api_gateway_rest_api.example_api.id
  #   stage_name  = "dev"
}

# Creates stage environment
resource "aws_api_gateway_stage" "example" {
  deployment_id = aws_api_gateway_deployment.example_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.example_api.id
  stage_name    = "dev"
}


# Lambda Permission
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.example_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.example_api.execution_arn}/*/*"
}

output "api_invoke_url" {
  value = aws_api_gateway_stage.example.invoke_url
}



### SUMMARY

# 1. Rest API: You create an API called "MyAPI" with a base URL.
# 2. Resource: You add a /users path to your API.
# 3. Method: You set up a GET method on /users to fetch users.
# 4. Integration: You connect the GET /users method to a Lambda function that gets user data.
# 5. Deployment: You deploy the API so it’s live.
# 6. Stage: You deploy it to a "dev" stage, so the URL becomes https://<api-id>.execute-api.<region>.amazonaws.com/dev/users.