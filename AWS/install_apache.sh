#!/bin/bash

#Update Package Index and Install Apache
yum update -y
yum install -y httpd

#Enable Apache services
systemctl start httpd
systemctl enable httpd


#Custom Text for Web Page
sudo tee /var/www/html/index.html <<END
<html>
<head>
  <title> My EC2 Server </title>
</head>
<body>
  <p> Let's Level Up in Tech!
</body>
</html>
END
