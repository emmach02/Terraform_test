# Terraform Test — Prácticas de Infraestructura como Código (AWS)

Repositorio de aprendizaje y práctica de **Terraform** sobre **AWS** (`us-east-1`), con entorno inicial de pruebas y el proyecto **FintechNova**.

---

## Estructura del repositorio

| Carpeta / Archivo | Descripción | Enlace |
| --- | --- | --- |
| **`tp-2-devops-terraform/`** | Infraestructura principal: VPC multi-AZ, subredes públicas y privadas, Bastion Host, Application Load Balancer (ALB) y dos instancias EC2 Web sirviendo *Fintech Nova*. | [Ver documentación del TP2](./tp-2-devops-terraform/documents/README.md) |
| **Diagrama de arquitectura** | Gráfico Mermaid, esquema ASCII y tabla de Security Groups de `tp-2-devops-terraform`. | [Ver arquitectura](./tp-2-devops-terraform/documents/arquitecture.md) |
| **`web-server-test/`** | Pruebas iniciales de Terraform con definición básica de provider AWS y recurso `aws_instance`. | [Ver carpeta](./web-server-test/) |
| **`Anotaciones.md`** | Cuaderno de apuntes sobre bloques HCL, variables, gestión de secretos y comandos de Terraform. | [Ver anotaciones](./Anotaciones.md) |
| **`ERRORES.md`** | Registro de errores encontrados durante las pruebas (`validate`, `apply`, `Cycle`, permisos de sandbox) y sus soluciones. | [Ver errores](./ERRORES.md) |

---

## Acceso rápido al proyecto TP2 (`tp-2-devops-terraform`)

- **Documentación y capturas:** [`tp-2-devops-terraform/documents/README.md`](./tp-2-devops-terraform/documents/README.md)
- **Diagrama de red y seguridad:** [`tp-2-devops-terraform/documents/arquitecture.md`](./tp-2-devops-terraform/documents/arquitecture.md)
- **Archivos Terraform:** [`main.tf`](./tp-2-devops-terraform/main.tf) · [`terraform.tf`](./tp-2-devops-terraform/terraform.tf) · [`variables.tf`](./tp-2-devops-terraform/variables.tf) · [`output.tf`](./tp-2-devops-terraform/output.tf) · [`index.html`](./tp-2-devops-terraform/index.html)
