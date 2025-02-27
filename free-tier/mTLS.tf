# # Certificate Authority
# resource "tls_private_key" "ca" {
#   algorithm = "RSA"
#   rsa_bits  = 4096
# }

# resource "tls_self_signed_cert" "ca" {
#   private_key_pem = tls_private_key.ca.private_key_pem

#   subject {
#     common_name  = "Mealie mTLS CA"
#     organization = "Mealie"
#   }

#   validity_period_hours = 8760 # 1 year
#   is_ca_certificate     = true

#   allowed_uses = [
#     "cert_signing",
#     "key_encipherment",
#     "digital_signature",
#   ]
# }

# # Server Certificate
# resource "tls_private_key" "server" {
#   algorithm = "RSA"
#   rsa_bits  = 4096
# }

# resource "tls_cert_request" "server" {
#   private_key_pem = tls_private_key.server.private_key_pem

#   subject {
#     common_name  = "mealie.example.com"
#     organization = "Mealie"
#   }

#   dns_names = ["mealie.example.com"]
# }

# resource "tls_locally_signed_cert" "server" {
#   cert_request_pem   = tls_cert_request.server.cert_request_pem
#   ca_private_key_pem = tls_private_key.ca.private_key_pem
#   ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

#   validity_period_hours = 720 # 30 days

#   allowed_uses = [
#     "key_encipherment",
#     "digital_signature",
#     "server_auth",
#   ]
# }

# # Client Certificate (for testing)
# resource "tls_private_key" "client" {
#   algorithm = "RSA"
#   rsa_bits  = 4096
# }

# resource "tls_cert_request" "client" {
#   private_key_pem = tls_private_key.client.private_key_pem

#   subject {
#     common_name  = "client"
#     organization = "Mealie"
#   }
# }

# resource "tls_locally_signed_cert" "client" {
#   cert_request_pem   = tls_cert_request.client.cert_request_pem
#   ca_private_key_pem = tls_private_key.ca.private_key_pem
#   ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

#   validity_period_hours = 720

#   allowed_uses = [
#     "key_encipherment",
#     "digital_signature",
#     "client_auth",
#   ]
# }

# # Save certificates to files
# resource "local_sensitive_file" "ca_crt" {
#   content  = tls_self_signed_cert.ca.cert_pem
#   filename = "${path.module}/mTLS/certs/ca.crt"
# }

# resource "local_sensitive_file" "server_crt" {
#   content  = tls_locally_signed_cert.server.cert_pem
#   filename = "${path.module}/mTLS/certs/server.crt"
# }

# resource "local_sensitive_file" "server_key" {
#   content  = tls_private_key.server.private_key_pem
#   filename = "${path.module}/mTLS/certs/server.key"
# }

# resource "local_sensitive_file" "client_crt" {
#   content  = tls_locally_signed_cert.client.cert_pem
#   filename = "${path.module}/mTLS/certs/client.crt"
# }

# resource "local_sensitive_file" "client_key" {
#   content  = tls_private_key.client.private_key_pem
#   filename = "${path.module}/mTLS/certs/client.key"
# }

# # Nginx configuration
# resource "local_file" "nginx_conf" {
#   content = templatefile("${path.module}/mTLS/templates/nginx.conf.tftpl", {
#     server_name = "mealie.example.com"
#   })
#   filename = "${path.module}/mTLS/nginx.conf"
# }

# # Docker Compose file
# resource "local_file" "docker_compose" {
#   content = templatefile("${path.module}/mTLS/templates/docker-compose.yml.tftpl", {
#     mealie_image = "ghcr.io/mealie-recipes/mealie:v2.6.0"
#   })
#   filename = "${path.module}/mTLS/docker-compose.yml"
# }
