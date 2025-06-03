module "vpc" {
  source = "./modules/vpc"
  name           = var.name
  vpc_cidr_block = var.vpc_cidr_block
  
}

module "alb" {
  source      = "./modules/alb"
  vpc_id      = module.vpc.vpc_id
  subnets     = module.vpc.public_subnets
  security_groups = [module.sg_group.alb_security_group_id]
  tg_arns     = [module.target_group.arn]
}

module "target_group" {
  source      = "./modules/target_group"
  name        = "target-group"
  port        = 80
  vpc_id      = module.vpc.vpc_id
  path        = "/"
}



module "sg_group" {
  source     = "./modules/sg_group"
  vpc_id     = module.vpc.vpc_id
}



locals {
  user_data = <<-EOF
         #!/bin/bash
         sudo dnf update -y
         sudo dnf install -y docker git 
         sudo dnf install -y libxcrypt-compat
         sudo systemctl enable docker
         sudo systemctl start docker
         sudo usermod -aG docker ec2-user
         sleep 10
         # Install Docker Compose
         sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
         sudo chmod +x /usr/local/bin/docker-compose
         
         # Clone working DevLake repo with UI support
         cd /home/ec2-user
         git clone https://github.com/merico-dev/lake.git devlake-setup
         cd devlake-setup
         cp -arp devops/releases/lake-v0.21.0/docker-compose.yml ./
         
         
         # Set up .env file
         cp env.example .env
         echo "ENCRYPTION_SECRET=super-secret-123" >> .env
         
         # Run Docker Compose
         docker-compose up -d
    EOF
}




module "instance" {
  source          = "./modules/instance"
  tg_arn          = module.target_group.arn
  subnet_id       = module.vpc.public_subnets[0]
  vpc_security_group_ids = [module.sg_group.ec2_security_group_id]
  user_data       = local.user_data
  name            = "Docker-instance"
}


