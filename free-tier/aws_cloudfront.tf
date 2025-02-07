# Create an S3 bucket
resource "aws_s3_bucket" "website_bucket" {
  bucket = "my-cloudfront-website-bucket"  # Replace with a unique bucket name
}

# Upload index.html to the S3 bucket
resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.website_bucket.bucket
  key          = "index.html"
  content      = <<-EOT
    <!DOCTYPE html>
    <html>
      <head>
        <title>Hello CloudFront!</title>
        <link rel="stylesheet" href="style.css">
      </head>
      <body>
        <h1>Hello, CloudFront!</h1>
        <p>This page is served via CloudFront.</p>
        <script src="script.js"></script>
      </body>
    </html>
  EOT
  content_type = "text/html"
}

# Upload style.css
resource "aws_s3_object" "style_css" {
  bucket       = aws_s3_bucket.website_bucket.bucket
  key          = "style.css"
  content      = <<-EOT
    body {
      font-family: Arial, sans-serif;
      background-color: #f0f0f0;
    }
  EOT
  content_type = "text/css"
}

# Upload script.js
resource "aws_s3_object" "script_js" {
  bucket       = aws_s3_bucket.website_bucket.bucket
  key          = "script.js"
  content      = <<-EOT
    console.log("Hello from JavaScript!");
  EOT
  content_type = "application/javascript"
}

## Uploading a gif file to see if it works
resource "aws_s3_object" "gif_file" {
  bucket       = aws_s3_bucket.website_bucket.bucket
  key          = "image2.gif"  # Replace with your GIF file name
  source       = "cloudfront_media/dont-leave-meeee.gif"  # Path to your local file
  content_type = "image/gif"
}
## TODO: Animate the gif with me and yash leaving kw xdxd

# Create a CloudFront Origin Access Identity (OAI)
resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "OAI for S3 bucket ${aws_s3_bucket.website_bucket.bucket}"
}

# Update S3 bucket policy to allow CloudFront access
data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.website_bucket.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.oai.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.website_bucket.bucket
  policy = data.aws_iam_policy_document.s3_policy.json
}

# Create a CloudFront distribution
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.website_bucket.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.website_bucket.bucket}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.website_bucket.bucket}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# Output the CloudFront domain name
output "cloudfront_domain" {
  value = aws_cloudfront_distribution.s3_distribution.domain_name
}

output "cloudfront_gif_url" {
  value = "${aws_cloudfront_distribution.s3_distribution.domain_name}/${aws_s3_object.gif_file.key}"
}

