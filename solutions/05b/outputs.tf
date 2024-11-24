output "lb_endpoint" {
value = "http://${aws_lb.lab_alb.dns_name}"
}
