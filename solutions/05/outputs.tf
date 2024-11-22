output "lb_endpoint" {
  value = "http://${aws_lb.lab-alb.dns_name}"
}
