#----------------- REDES -------------------------------------

locals {
  vpc_nova_id = aws_vpc.nova.id
}

# La idea es crear una VPC, una subnet, un security group y una instancia EC2
resource "aws_vpc" "nova" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true # Hace que la VPC reciba un host público automático
  tags                 = { Name = "nova-vpc" }
}

#Una vez creada la VPC definimos las subredes ----------------------------
resource "aws_subnet" "publica" {
  #Para llamar variables locales usamos local.[nombre]
  vpc_id     = local.vpc_nova_id
  cidr_block = "10.0.0.0/24"
  #Por ejemplo si queremos llamar a la variable de recién usamos var.[nombre]
  availability_zone       = var.az
  map_public_ip_on_launch = true
  tags                    = { Name = "nova-publica" }
}

#Segunda subred pública en otra AZ (obligatoria para el Application Load Balancer)
resource "aws_subnet" "publica_2" {
  vpc_id                  = local.vpc_nova_id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = var.az_2
  map_public_ip_on_launch = true
  tags                    = { Name = "nova-publica-2" }
}

resource "aws_subnet" "privada" {
  vpc_id            = local.vpc_nova_id
  cidr_block        = "10.0.1.0/24"
  availability_zone = var.az
  //map_public_ip_on_launch = true "Esto se comenta porque no queremos tenga ip publica"
  tags = { Name = "nova-privada" }
}

resource "aws_subnet" "privada_2" {
  vpc_id            = local.vpc_nova_id
  cidr_block        = "10.0.3.0/24"
  availability_zone = var.az_2
  tags              = { Name = "nova-privada-2" }
}

resource "aws_internet_gateway" "nova" {
  vpc_id = local.vpc_nova_id
  tags   = { Name = "fintech-nova-igw" }
}

#Faltaría la tabla de enrutamiento para la vpc
resource "aws_route_table" "publica" {
  vpc_id = local.vpc_nova_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.nova.id
  }
  tags = { Name = "nova-rt-publica" }
}

#Toda tabla de enrutamiento debe asociarse a las subnets públicas, por si solo no se da cuenta
resource "aws_route_table_association" "publica" {
  subnet_id      = aws_subnet.publica.id
  route_table_id = aws_route_table.publica.id
}

resource "aws_route_table_association" "publica_2" {
  subnet_id      = aws_subnet.publica_2.id
  route_table_id = aws_route_table.publica.id
}

#----------------- Seguridad -------------------------------------

#En orden, lo siguiente sería configurar las security groups
resource "aws_security_group" "bastion" {
  name   = "sg_bastion"
  vpc_id = local.vpc_nova_id

  #Reglas inbound, anifamos un ingress por cada regla que agreguemos.
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["190.227.139.185/32"] #Indicar la IP desde la cual se podría hacer uso del 22
  }
  #Reglas outbound, siempre agregar. Por si solo no entiende.
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #Esto solo si queremos actualizar algo en la bastion
  }

  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.privada.cidr_block, aws_subnet.privada_2.cidr_block] #Opción 2: evita dependencia circular con sg_web
  }
}

resource "aws_security_group" "alb" {
  name   = "sg_alb"
  vpc_id = local.vpc_nova_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #El ALB reenvía tráfico HTTP (puerto 80) hacia las EC2 Web en ambas subnets privadas
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.privada.cidr_block, aws_subnet.privada_2.cidr_block]
  }
}

resource "aws_security_group" "web" {
  name   = "sg_web"
  vpc_id = local.vpc_nova_id

  #Inbound
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  #Solo acepta tráfico web desde el ALB (no directo desde internet)
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  #Outbound
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #Nota: en subnet privada requiere NAT Gateway para salir a internet
  }
}

#----------------- Application Load Balancer (ALB) ---------------

resource "aws_lb" "nova" {
  name               = "nova-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.publica.id, aws_subnet.publica_2.id]

  tags = { Name = "nova-alb" }
}

resource "aws_lb_target_group" "web" {
  name     = "nova-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = local.vpc_nova_id

  health_check {
    path     = "/"
    protocol = "HTTP"
    matcher  = "200-399"
  }

  tags = { Name = "nova-web-tg" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.nova.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

#----------------- Cómputo (EC2s) y Conexión al ALB ---------------

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux.id
  subnet_id              = aws_subnet.publica.id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  instance_type          = "t3.micro"
  key_name               = "vockey" # Asocia la Key Pair del sandbox para poder conectarse por SSH

  tags = { Name = "nova-bastion" }
}

locals {
  web_user_data = <<-EOF
    #!/bin/bash
    mkdir -p /var/www/html
    echo "${filebase64("${path.module}/index.html")}" | base64 -d > /var/www/html/index.html

    cat <<'SERVICE' > /etc/systemd/system/web-test.service
    [Unit]
    Description=Servidor HTTP de prueba (Python)
    After=network.target

    [Service]
    ExecStart=/usr/bin/python3 -m http.server 80 --directory /var/www/html
    Restart=always

    [Install]
    WantedBy=multi-user.target
    SERVICE

    systemctl daemon-reload
    systemctl enable --now web-test.service
  EOF
}

resource "aws_instance" "web" {
  ami                         = data.aws_ami.amazon_linux.id
  subnet_id                   = aws_subnet.privada.id
  vpc_security_group_ids      = [aws_security_group.web.id]
  instance_type               = "t3.micro"
  key_name                    = "vockey" # Asocia la Key Pair del sandbox para poder entrar por SSH desde el Bastion
  user_data_replace_on_change = true
  user_data                   = local.web_user_data

  tags = { Name = "nova-web" }
}

resource "aws_instance" "web_2" {
  ami                         = data.aws_ami.amazon_linux.id
  subnet_id                   = aws_subnet.privada_2.id
  vpc_security_group_ids      = [aws_security_group.web.id]
  instance_type               = "t3.micro"
  key_name                    = "vockey" # Asocia la Key Pair del sandbox para poder entrar por SSH desde el Bastion
  user_data_replace_on_change = true
  user_data                   = local.web_user_data

  tags = { Name = "nova-web-2" }
}

#Enganche del balanceador de carga para las instancias EC2 Web
resource "aws_lb_target_group_attachment" "ALB" {
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "ALB_2" {
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web_2.id
  port             = 80
}