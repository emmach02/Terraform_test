#Salidas por consola post aplicar un terraform apply, detalles de intancias, IDs, entre otras cosas.
output "vpc_id" {
  value = local.vpc_nova_id
}

output "alb_dns_name" {
  description = "DNS público del Application Load Balancer (usar http://)"
  value       = aws_lb.nova.dns_name
}

output "bastion_public_ip" {
  description = "IP pública del Bastion para conectarse por SSH"
  value       = aws_instance.bastion.public_ip
}

output "web_private_ip" {
  description = "IP privada de la EC2 Web para saltar por SSH desde el Bastion"
  value       = aws_instance.web.private_ip
}

output "web_2_private_ip" {
  description = "IP privada de la segunda EC2 Web para saltar por SSH desde el Bastion"
  value       = aws_instance.web_2.private_ip
}
