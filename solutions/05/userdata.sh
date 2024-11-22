#!/bin/bash
sudo yum update -y
sudo yum install -y httpd.x86_64
sudo systemctl start httpd.service
sudo systemctl enable httpd.service
sudo chmod -R 777 /var/www/html
sudo echo “Your message here $(hostname -f)” > /var/www/html/index.html
sudo systemctl restart httpd.service
