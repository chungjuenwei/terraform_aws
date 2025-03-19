
# VPC for Lambda (VPC A)
resource "aws_vpc" "lambda_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "lambda-vpc"
  }
}

resource "aws_subnet" "lambda_subnet" {
  vpc_id            = aws_vpc.lambda_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-southeast-1a" # Adjust AZ as needed
  tags = {
    Name = "lambda-subnet"
  }
}

resource "aws_security_group" "lambda_sg" {
  vpc_id = aws_vpc.lambda_vpc.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "lambda-sg"
  }
}

# VPC for API Gateway (VPC B)
resource "aws_vpc" "api_vpc" {
  cidr_block = "10.1.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "api-vpc"
  }
}

resource "aws_subnet" "api_subnet" {
  vpc_id            = aws_vpc.api_vpc.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "ap-southeast-1a" # Adjust AZ as needed
  tags = {
    Name = "api-subnet"
  }
}

# VPC Endpoint for API Gateway in VPC B
resource "aws_vpc_endpoint" "api_endpoint" {
  vpc_id             = aws_vpc.api_vpc.id
  service_name       = "com.amazonaws.ap-southeast-1.execute-api"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = [aws_subnet.api_subnet.id]
  security_group_ids = [aws_security_group.api_sg.id]
  private_dns_enabled = true
}

resource "aws_security_group" "api_sg" {
  vpc_id = aws_vpc.api_vpc.id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.1.0.0/16"] # Allow traffic within VPC B
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "api-sg"
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda_execution_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Zips the Python code
data "archive_file" "hello_lambda" {
  type        = "zip"
  source_file  = "${path.module}/lambda_functions/hello_lambda.py"  # Directory containing your Python code
  output_path = "${path.module}/lambda_functions/hello_lambda.zip"
}

# Lambda Function in VPC A
resource "aws_lambda_function" "my_lambda" {
  filename         = "${path.module}/lambda_functions/hello_lambda.zip" # You’ll create this below
  function_name    = "myLambdaFunction"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  vpc_config {
    subnet_ids         = [aws_subnet.lambda_subnet.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
}

# API Gateway REST API in VPC B
resource "aws_api_gateway_rest_api" "my_api" {
  name = "MyAPI"
  endpoint_configuration {
    types            = ["PRIVATE"]
    vpc_endpoint_ids = [aws_vpc_endpoint.api_endpoint.id]
  }
}

resource "aws_api_gateway_resource" "root" {
  rest_api_id = aws_api_gateway_rest_api.my_api.id
  parent_id   = aws_api_gateway_rest_api.my_api.root_resource_id
  path_part   = "test"
}

resource "aws_api_gateway_method" "get_method" {
  rest_api_id   = aws_api_gateway_rest_api.my_api.id
  resource_id   = aws_api_gateway_resource.root.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.my_api.id
  resource_id             = aws_api_gateway_resource.root.id
  http_method             = aws_api_gateway_method.get_method.http_method
  integration_http_method = "POST" # Lambda integration uses POST
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:ap-southeast-1:lambda:path/2015-03-31/functions/${aws_lambda_function.my_lambda.arn}/invocations"
}


# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.my_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.my_api.execution_arn}/*/*"
}


# Deploy the API
resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.my_api.id
#   stage_name  = "prod"
  depends_on  = [aws_api_gateway_integration.lambda_integration]
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.my_api.id
  stage_name    = "prod"
}

# Output the API invoke URL
output "api_invoke_url" {
  value = "${aws_api_gateway_deployment.api_deployment.invoke_url}/test"
}

# ## Error message before i said screw it
# │ Error: creating API Gateway Deployment: operation error API Gateway: CreateDeployment, 
#   https response error StatusCode: 400, RequestID: 89b91b65-9937-40ab-91f7-69f43f299575, 
#   BadRequestException: Private REST API doesn't have a resource policy attached to it
# │ 
# │   with aws_api_gateway_deployment.api_deployment,
# │   on 2-vpc-apig-lambda.tf line 164, in resource "aws_api_gateway_deployment" "api_deployment":
# │  164: resource "aws_api_gateway_deployment" "api_deployment" {
# │ 
# ╵