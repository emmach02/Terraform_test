# Registro de Errores - Terraform

## Error 1: `Incorrect attribute value type` en `egress` (`aws_security_group`)

- **Archivo:** `tp-2-devops-terraform/main.tf` (líneas 69–74)
- **Mensaje de error:**
  ```text
  Error: Incorrect attribute value type

    on main.tf line 69, in resource "aws_security_group" "web":
    69:     egress = {
    70:         from_port = 443
    71:         to_port = 443
    72:         protocol = "tcp"
    73:         cidr_block = ["0.0.0.0/0"] #Esto solo si queremos actualizar algo en la bastion
    74:     }

  Inappropriate value for attribute "egress": set of object required.
  ```
- **Causa:**
  1. Se escribió `egress = { ... }` con signo `=` (asignación de un único objeto), cuando lo correcto es declararlo como **bloque** `egress { ... }` sin `=`. *(Si se asigna con `=`, Terraform exige un conjunto de objetos `[{ ... }]` con todos los campos del esquema completo).*
  2. En la línea 73 se escribió `cidr_block` (singular), cuando en las reglas `ingress` y `egress` el atributo se llama **`cidr_blocks`** (plural, porque recibe una lista).
- **Solución:**
  ```hcl
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Esto solo si queremos actualizar algo en la bastion
  }
  ```

---

## Error 2: Referencia a otro Security Group dentro de `cidr_blocks` (`aws_security_group`)

- **Archivo:** `tp-2-devops-terraform/main.tf` (líneas 77–86)
- **Mensajes de error:**
  - Sin comillas (`cidr_blocks = [aws_security_group.bastion]`):
    ```text
    Error: Incorrect attribute value type

      on main.tf line 85, in resource "aws_security_group" "web":
      85:         cidr_blocks = [aws_security_group.bastion]
        ├────────────────
        │ aws_security_group.bastion is object with 13 attributes

    Inappropriate value for attribute "cidr_blocks": element 0: string required, but have object.
    ```
  - Con comillas (`cidr_blocks = ["aws_security_group.bastion"]`):
    ```text
    Error: "aws_security_group.bastion" is not a valid CIDR block: invalid CIDR address: aws_security_group.bastion

      with aws_security_group.web,
      on main.tf line 77, in resource "aws_security_group" "web":
      77: resource "aws_security_group" "web" {
    ```
- **Causa:**
  1. `cidr_blocks` solo acepta rangos de IP en formato CIDR (por ejemplo `["10.0.0.0/24"]`): sin comillas falla porque recibe un objeto completo en vez de un string, y con comillas falla porque el texto no es un CIDR válido.
  2. Para referenciar otro Security Group como origen o destino en una regla, se usa el atributo **`security_groups`** pasando el `.id` del grupo.
- **Solución:**
  ```hcl
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }
  ```

---

## Error 3: Protocolo `"ssh"` inválido en Security Group (`aws_security_group`)

- **Archivo:** `tp-2-devops-terraform/main.tf` (líneas 65 y 85)
- **Mensaje de error:**
  ```text
  Error: updating Security Group (sg-07dda0fc41da82713) ingress rules: authorizing Security Group (ingress) rules: operation error EC2: AuthorizeSecurityGroupIngress, https response error StatusCode: 400, RequestID: 15556ce1-6eef-4380-a7c1-b512c04e2e28, api error InvalidParameterValue: Invalid value 'ssh' for IP protocol. Unknown protocol.

    with aws_security_group.bastion,
    on main.tf line 57, in resource "aws_security_group" "bastion":
    57: resource "aws_security_group" "bastion" {
  ```
- **Causa:**
  AWS EC2 no acepta nombres de protocolos de aplicación como `"ssh"` o `"https"` en el campo `protocol` de un Security Group. Ahí va el protocolo de red/transporte (`"tcp"`, `"udp"`, `"icmp"`, o `"-1"` para todos).
- **Solución:**
  Reemplazar `protocol = "ssh"` por `protocol = "tcp"` (tanto en `aws_security_group.bastion` como en `aws_security_group.web`):
  ```hcl
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["<tu_ip_publica>/32"]
  }
  ```

- **Nota importante — Salida (`egress`) del Bastion por puerto 22:**
  En `aws_security_group.bastion`, si solo se define `egress` para el puerto `443`, el Bastion **no podrá iniciar conexiones SSH salientes** hacia la EC2 Web (en Terraform un SG sin `egress` explícito para ese puerto bloquea la salida). Hay que agregar una regla `egress` para el puerto `22` hacia la subnet o hacia `aws_security_group.web.id` (si se referencia otro SG bidireccionalmente, usar `aws_vpc_security_group_egress_rule` o el CIDR de la subnet para evitar referencia circular):
  ```hcl
  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.privada.cidr_block] # o aws_subnet.publica.cidr_block según dónde esté la Web
  }
  ```

---

## Error 4: Dependencia circular (`Error: Cycle`) entre Security Groups (`aws_security_group`)

- **Archivo:** `tp-2-devops-terraform/main.tf` (líneas 80 y 94)
- **Mensaje de error:**
  ```text
  Error: Cycle:
    aws_security_group.web
    aws_security_group.bastion
  ```
- **Causa:**
  `aws_security_group.bastion` referenciaba a `aws_security_group.web.id` en su `egress` (puerto 22) y, al mismo tiempo, `aws_security_group.web` referenciaba a `aws_security_group.bastion.id` en su `ingress` (puerto 22). Al usar bloques inline dentro de ambos recursos, Terraform no puede crear ninguno primero porque cada uno necesita el `.id` del otro.
- **Solución elegida (Opción 2 — usar el CIDR de la subred en el `egress` del Bastion):**
  En `aws_security_group.bastion`, reemplazar `security_groups = [aws_security_group.web.id]` por el CIDR de la subred donde esté la instancia Web (o `aws_vpc.nova.cidr_block` si aplica a toda la VPC), manteniendo restringido el `ingress` de `aws_security_group.web` a `security_groups = [aws_security_group.bastion.id]`:
  ```hcl
  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.privada.cidr_block] # o aws_subnet.publica.cidr_block según dónde esté la Web
  }
  ```
- **Alternativa (Opción 1 — para referencia futura):**
  Usar recursos separados `aws_vpc_security_group_ingress_rule` / `aws_vpc_security_group_egress_rule` para `bastion` (sacando las reglas inline de `aws_security_group.bastion`, ya que no se deben mezclar reglas inline con recursos separados en un mismo SG porque se pisan entre sí en los siguientes `apply`).

---

## Error 5: Referencias inválidas y falta de `ami` en `aws_instance` (`bastion` y `web`)

- **Archivo:** `tp-2-devops-terraform/main.tf` (líneas 245–255)
- **Causas:**
  1. **Prefijo `aws.` sobrante en Security Groups:** se escribió `aws.aws_security_group.bastion.id` y `aws.aws_security_group.web.id`. En Terraform, los recursos se referencian directo por `<tipo>.<nombre>.<atributo>`, sin anteponer el nombre del provider.
  2. **Error de tipeo en `subnet_id` de `web`:** se escribió `aws_subne.privada.id` en lugar de `aws_subnet.privada.id`.
  3. **Falta del argumento obligatorio `ami`:** toda `aws_instance` exige indicar la imagen del sistema operativo (`ami`).
- **Solución:**
  Corregir las referencias (`aws_security_group.*` y `aws_subnet.privada.id`) y agregar un `data "aws_ami"` para obtener el ID más reciente de Amazon Linux 2023 en la región:
  ```hcl
  data "aws_ami" "amazon_linux" {
    most_recent = true
    owners      = ["amazon"]

    filter {
      name   = "name"
      values = ["al2023-ami-2023.*-x86_64"]
    }
  }

  resource "aws_instance" "bastion" {
    ami                    = data.aws_ami.amazon_linux.id
    subnet_id              = aws_subnet.publica.id
    vpc_security_group_ids = [aws_security_group.bastion.id]
    instance_type          = "t3.micro"
  }
  ```

---

## Error 6: Permiso denegado (`AccessDeniedException`) en `acm:ImportCertificate` dentro del Sandbox

- **Archivo:** `tp-2-devops-terraform/main.tf` (recurso `aws_acm_certificate.alb`)
- **Mensaje de error:**
  ```text
  Error: importing ACM Certificate: operation error ACM: ImportCertificate, https response error StatusCode: 400, api error AccessDeniedException: User: arn:aws:sts::814831434422:assumed-role/voclabs/... is not authorized to perform: acm:ImportCertificate on resource: arn:aws:acm:us-east-1:814831434422:certificate/* because no identity-based policy allows the acm:ImportCertificate action
  ```
- **Causa:**
  El rol del sandbox de AWS Academy (`voclabs`) bloquea por políticas IAM la importación de certificados en **AWS Certificate Manager (ACM)** (`acm:ImportCertificate`), por lo que no se puede configurar un Listener HTTPS (`443`) en el ALB con un certificado autofirmado importado a ACM.
- **Solución:**
  Dejar el ALB escuchando por **HTTP (puerto `80`)** haciendo `forward` directo al Target Group `aws_lb_target_group.web`, y quitar el bloque de certificado (`tls_*` + `aws_acm_certificate`) junto con el listener `443`:
  ```hcl
  resource "aws_lb_listener" "http" {
    load_balancer_arn = aws_lb.nova.arn
    port              = 80
    protocol          = "HTTP"

    default_action {
      type             = "forward"
      target_group_arn = aws_lb_target_group.web.arn
    }
  }
  ```
