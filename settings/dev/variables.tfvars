aws_profile  = "app_deployment_dev"
network_cidr = "10.32.0.0/24"
app_count    = 1
additional-tags = {
  "application" : "ecs-demo",
  "env" : "development"
}
