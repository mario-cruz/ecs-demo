environment  = "prod"
aws_profile  = "app_deployment_prod"
network_cidr = "10.32.0.0/24"
additional-tags = {
  "application" : "xray-poc",
  "env" : "production"
}
