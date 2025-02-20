# Fetch current public IP dynamically
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/" # Fetches your public IP
}

# Trim the newline character from the response
locals {
  my_public_ip = "${chomp(data.http.my_ip.response_body)}/32"
}

output "_current_ip_address" {
  value = chomp(data.http.my_ip.response_body)
}
