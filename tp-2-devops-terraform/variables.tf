#Podemos crear variables que sirvan para parametrizar todo el código.

# Siempre se define la estructura como:
# variable "nombre" {
#   description = "texto" //Opcional creo
#   type = "categoria" //String, numeric, boolean, etc
#   default = "valor" //Valor que se asigna por defecto si no se parametriza como entrada
#}

#Se puede utilizar en archivos para valores repetidos
# locals {
#   variable = "nombre"
#}

variable "az" {
  description = "Zona de disponibilidad"
  type        = string
  default     = "us-east-1a"
}

variable "az_2" {
  description = "Segunda zona de disponibilidad (requerida por el ALB)"
  type        = string
  default     = "us-east-1b"
}


