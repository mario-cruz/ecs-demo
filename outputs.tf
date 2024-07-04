# ALB ECS outputs
output "load_balancer_ip" {
  value = aws_lb.alb.dns_name
}
