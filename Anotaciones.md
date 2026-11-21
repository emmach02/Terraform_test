# Cuaderno de anotaciones - Terraform

Anotaciones sobre los bloques, parámetros y comandos utilizados en `web-server-test/`.

---

## 1. Configuración y Providers (`web-server-test/terraform.tf`)

- **`terraform { ... }`**: Bloque principal de configuración del proyecto. Define ajustes generales de Terraform (como los proveedores requeridos).
- **`required_providers { ... }`**: Indica qué proveedores externos necesita el proyecto para poder interactuar con plataformas como AWS, GCP, Azure, etc.
- **`aws = { ... }`**: Nombre local con el que vamos a identificar al proveedor dentro de nuestros archivos `.tf`.
  - **`source = "hashicorp/aws"`**: Ruta del proveedor en el Terraform Registry (`organización/proveedor`). En este caso descarga el provider oficial de AWS.
  - **`version = "5.87.0"`**: Fija la versión exacta del proveedor a utilizar para que el comportamiento sea siempre el mismo al inicializar el proyecto.

---

## 2. Recursos y Salidas (`web-server-test/main.tf`)

- **`# ...`**: Comentario de una línea. Terraform lo ignora al ejecutar.
- **`resource "aws_instance" "web" { ... }`**: Declara un recurso de infraestructura que Terraform va a crear y gestionar.
  - **`"aws_instance"`**: Tipo de recurso del provider de AWS (una máquina virtual EC2).
  - **`"web"`**: Nombre interno dentro de Terraform para referenciar este recurso en otros bloques (no es el nombre visible en AWS).
  - **`ami = "test"`**: Identificador de la imagen del sistema operativo (Amazon Machine Image) que usará la instancia. *(Actualmente tiene `"test"` como valor de prueba).*
  - **`instance_type = "t3.small"`**: Tipo/tamaño de instancia EC2 (define cuánta CPU y RAM tendrá).
- **`output "instance.detail" { ... }`**: Imprime información útil en consola luego de ejecutar `terraform apply` (por ejemplo, IDs o IPs generadas).
  - **`"instance.detail"`**: Nombre con el que aparece la salida en la terminal.
  - **`value = ...`**: Valor que se quiere mostrar. *(Nota: actualmente dice `aws.instance.web.id`; para referenciar el recurso `"aws_instance" "web"` va con guion bajo: `aws_instance.web.id`).*
  - **`"Tags"`**: suele utilizatse para hacer referencia a un/unos recurso/s que tengan el mismo tag. Ejemplo: `aws_instance.web.id` donde el tag es `web` y su repectivo `id`. 

---

## 3. Comandos básicos de Terraform (consola)

- **`terraform init`**: Inicializa la carpeta del proyecto y descarga los providers configurados en `required_providers`. Se corre al empezar o al agregar un provider nuevo.
- **`terraform validate`**: Revisa que la sintaxis de los archivos `.tf` y las referencias entre bloques estén bien escritas.
- **`terraform plan`**: Simula la ejecución y muestra qué recursos se van a crear, modificar o eliminar, sin aplicar cambios reales. Ejecuta una comparación con lo que dice el archivo `terraform.tfstate` y con lo que ya existe en AWS.
- **`terraform apply`**: Aplica los cambios y crea/actualiza la infraestructura real (pide confirmación escribiendo `yes`).
- **`terraform destroy`**: Elimina toda la infraestructura creada y registrada en el estado actual.
- **`terraform state list`**: Lista todos los recursos que Terraform tiene actualmente registrados y gestionados en el archivo de estado (`terraform.tfstate`). Sirve para ver rápidamente qué recursos existen en el state (por ejemplo, `aws_vpc.nova`, `aws_subnet.publica`).
  - **`terraform state show <recurso>`**: Muestra en detalle todos los atributos y valores guardados en el `terraform.tfstate` de un recurso específico (por ejemplo, `terraform state show aws_vpc.nova`).

---

## 4. Gestión de secretos en Terraform

- **Credenciales de AWS:** nunca hardcodear `access_key` ni `secret_key` en `provider "aws"`. Se pasan por variables de entorno (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`) o con un perfil local (`aws configure` en `~/.aws/credentials`).
- **`sensitive = true` en `variable`:** oculta el valor en la salida de consola (`plan`, `apply`, `output`), mostrando `(sensitive value)`:
  ```hcl
  variable "db_password" {
    type      = string
    sensitive = true
  }
  ```
- **Cómo cargar secretos sin subirlos a Git:**
  - **Variables de entorno con prefijo `TF_VAR_`:** por ejemplo en PowerShell `$env:TF_VAR_db_password = "..."`.
  - **Archivos `.tfvars` ignorados en `.gitignore`:** por ejemplo `terraform.tfvars` (se carga solo) o un archivo dedicado pasado con `-var-file="archivo.tfvars"`.
  - **Sin `default`:** si la variable no tiene valor por defecto ni se pasa por fuera, Terraform la pide por teclado al ejecutar `plan`/`apply`.
- **Cuidado con `terraform.tfstate`:** `sensitive = true` **no cifra** el archivo de estado; cualquier secreto usado en un recurso queda en texto plano dentro del `.tfstate`.
  - Nunca subir `*.tfstate`, `*.tfstate.*` ni `*.tfvars` con secretos al repositorio (agregarlos al `.gitignore`).
  - En producción/equipo se usa un **backend remoto cifrado** (por ejemplo S3 con cifrado y permisos IAM restringidos).
  - En versiones recientes (1.10/1.11+) existen variables/recursos `ephemeral` y atributos write-only (`*_wo`) para evitar que el secreto quede guardado en el state.
- **En AWS real (buenas prácticas):**
  - Usar **AWS Secrets Manager** o **SSM Parameter Store (`SecureString`)** para que el secreto viva en AWS (consumido por `data` o directamente desde la EC2 mediante un **IAM Role**).
  - Para acceso SSH (Bastion / EC2), subir solo la **clave pública** (`.pub`) en `aws_key_pair` y nunca guardar la clave privada en el proyecto (o usar **AWS SSM Session Manager** para conectarse sin abrir el puerto 22).
