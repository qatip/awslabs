### Ex1 Task1 start
data "aws_ami" "amazon-linux-2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-5.10-*-x86_64-ebs"]
  }
}

resource "aws_launch_template" "lab-launch-template1" {
  name = "lab-launch-template1"
  image_id = data.aws_ami.amazon-linux-2.id
  instance_type = "t3.micro"
  vpc_security_group_ids = [module.vpc.ec2instance-sg]
  user_data = filebase64("userdata.sh")

  depends_on = [module.vpc.lab-vpc, module.vpc.nat-gateway]
}
### Ex1 Task1 end

### Ex1 Task2 start
resource "aws_autoscaling_group" "lab-asg" {
  name = "lab-asg"
  min_size = 2
  max_size = 5
  desired_capacity = 2
  vpc_zone_identifier = [for subnet in module.vpc.private-subnets : subnet.id]

  launch_template {
    id = aws_launch_template.lab-launch-template1.id
    version = "$Latest"
  }

  tag {
    key = "Name"
    value = "Lab ASG member"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [load_balancers, target_group_arns]
  }

  depends_on = [aws_launch_template.lab-launch-template1]
}
### Ex1 Task2 end

### Ex2 Task1 start
resource "aws_lb" "lab-alb" { 
  name = "lab-alb"
  internal = false
  load_balancer_type = "application"
  security_groups = [module.vpc.loadbal-sg]
  subnets = [for subnet in module.vpc.public-subnets : subnet.id]
}
### Ex2 Task1 end

### Ex2 Task2 start
resource "aws_lb_listener" "alb-listener" {
  load_balancer_arn = aws_lb.lab-alb.arn
  port = "80"
  protocol = "HTTP"#

  default_action {
   type = "forward"
   target_group_arn = aws_lb_target_group.alb-targetgroup.arn
 }

  depends_on = [aws_lb_target_group.alb-targetgroup]

}

resource "aws_lb_target_group" "alb-targetgroup" { 
  name = "backend-target-group"
  port = 80
  protocol = "HTTP"
  vpc_id = module.vpc.vpc-id
}
### Ex2 Task2 end

### Ex3 start
resource "aws_autoscaling_attachment" "lab-asg-attachment" { 
  autoscaling_group_name = aws_autoscaling_group.lab-asg.id
  lb_target_group_arn   = aws_lb_target_group.alb-targetgroup.arn

}
### Ex3 end
