# Ejemplo para levantar una EC2 de estilo web server
resource "aws_instance" "web" {
    ami = "test"
    instance_type = "t3.small"
}

output "instance.detail" {
    value = aws.instance.web.id
}