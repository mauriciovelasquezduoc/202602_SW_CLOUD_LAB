# Sistema de Gestión de Solicitudes en AWS (Serverless)

Sistema que recibe solicitudes de alumnos (certificados, revisión de notas, soporte técnico,
información académica) y las procesa de forma **asíncrona** con arquitectura serverless:

```
POST /solicitudes → API Gateway → Lambda Recepción → SQS → Lambda Procesamiento
                                                              ├→ DynamoDB (guarda + estado)
                                                              └→ SNS (correo al alumno)
```

La documentación completa (arquitectura, decisiones de diseño, contrato de API, modelo de
datos) está en `../documento-diseno.md`.

## Estructura del proyecto

```
solicitudes-serverless/
├── template.yaml                  Infraestructura (AWS SAM): API, Lambdas, SQS, DLQ, DynamoDB, SNS
├── pom.xml                        Dependencias Maven (Java 21, AWS SDK v2, Jackson)
└── src/
    ├── main/java/duoc/cloud/solicitudes/
    │   ├── RecepcionHandler.java      Lambda 1: valida, encola en SQS, responde 202
    │   ├── ProcesamientoHandler.java  Lambda 2: consume SQS, guarda en DynamoDB, notifica SNS
    │   ├── ProcesadorSolicitudes.java Lógica de negocio: resultado según tipo
    │   ├── model/                     Solicitud, SolicitudRequest, Alumno, tipos y estados
    │   └── validacion/ValidadorSolicitud.java
    └── test/java/.../ValidadorSolicitudTest.java   Pruebas unitarias de la validación
```

## Prerrequisitos

- Java 21 (JDK) y Maven 3.9+
- AWS SAM CLI (`sam --version`) — [guía de instalación](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html)
- AWS CLI configurado (`aws configure`) con una cuenta con permisos sobre Lambda, API Gateway, SQS, SNS, DynamoDB, IAM y CloudFormation

> ⚠️ **Importante:** Java usa `:` como separador de classpath en macOS/Linux. Si el proyecto
> queda en una carpeta cuyo nombre contenga `:` (por ejemplo `JAVA: DISENO .../2020602_JAVACLOUD`),
> `mvn test` y `sam build` fallan con errores tipo `package ... does not exist` o
> `ClassNotFoundException: ForkedBooter`. Copia el proyecto a una ruta sin dos puntos
> (ej. `~/duoc/javacloud/solicitudes-serverless`) antes de compilar o desplegar.

## Despliegue en AWS Academy (Learner Lab)

> Este proyecto está adaptado al Learner Lab: **no crea ningún recurso IAM**.
> Todas las Lambdas usan el rol `LabRole` pre-existente del lab
> (`arn:aws:iam::<cuenta>:role/LabRole`), definido en `Globals.Function.Role` del template.
> Ojo: `labInstanceProfile` es el perfil de instancia **EC2/Cloud9** del lab, no sirve
> como rol de ejecución de Lambda — para eso es `LabRole`.

### Opción A — Desde Cloud9 del lab (recomendada)

Las credenciales llegan solas vía `labInstanceProfile` (no hay que configurar nada):

```bash
# Si falta JDK 21 en Cloud9 (Amazon Linux 2023):
sudo yum install -y java-21-amazon-corretto-devel
java -version   # debe mostrar 21

# SAM CLI suele venir preinstalado; si no:
brew install aws-sam-cli   # solo en Mac; en Cloud9 usar el instalador de SAM
```

### Opción B — Desde tu Mac con credenciales temporales

En la página del lab: **AWS Details → Show AWS CLI credentials** y cópialas:

```bash
export AWS_ACCESS_KEY_ID=ASIA...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...
# ⚠️ Expiran al terminar la sesión del lab (~4 h): re-exportar si caducan
```

### Desplegar (en cualquiera de las dos opciones)

```bash
# 1. Compilar (corre también las pruebas unitarias)
sam build

# 2. Desplegar — la región DEBE ser us-east-1 o us-west-2 (única permitidas por el lab)
sam deploy --guided
#   - Stack Name: solicitudes-serverless
#   - AWS Region: us-east-1
#   - EmailNotificaciones: tu correo (o el del "alumno" de la demo)
#   - Al preguntar por cambios IAM: el template no crea nada de IAM,
#     confirma con "y" normalmente.
```

3. **Importante:** revisa tu correo y confirma la suscripción SNS
   ("AWS Notification - Subscription Confirmation"), o no llegarán las notificaciones.

4. Copia la `ApiUrl` de la salida (o ejecuta `aws cloudformation describe-stacks`
   y revisa los Outputs).

### Presupuesto del lab (¡importante!)

El Learner Lab tiene presupuesto limitado (~USD 50-100). Al terminar tu sesión de trabajo:

```bash
sam delete   # elimina toda la pila: API, Lambdas, colas, tabla y tópico
```

Recréalo en la siguiente sesión con un solo comando (los datos de prueba no se conservan,
pero el despliegue toma ~3 minutos).

## Pruebas

### Pruebas unitarias

```bash
mvn test
```

### Prueba de punta a punta con curl (o Postman)

**Solicitud válida** — responde `202` con `solicitudId` y estado `RECIBIDA`:

```bash
curl -X POST "https://XXXX.execute-api.us-east-1.amazonaws.com/prod/solicitudes" \
  -H "Content-Type: application/json" \
  -d '{
        "alumno": { "nombre": "María Pérez Soto", "email": "maria.perez@duocuc.cl" },
        "tipo": "CERTIFICADO",
        "descripcion": "Necesito certificado de notas para postular a una beca"
      }'
```

Ejemplos para los otros tipos — solo cambia `tipo` y `descripcion`:

| `tipo` | `descripcion` de ejemplo |
|---|---|
| `REVISION_NOTAS` | "Solicito revisión de la nota final de Programación Avanzada, sección 2" |
| `SOPORTE_TECNICO` | "No puedo acceder a mi correo institucional desde ayer en la tarde" |
| `INFO_ACADEMICA` | "Deseo saber las fechas de inscripción de asignaturas para el próximo semestre" |

**Solicitud inválida** — responde `400` con el detalle y no entra al sistema:

```bash
curl -X POST "https://XXXX.execute-api.us-east-1.amazonaws.com/prod/solicitudes" \
  -H "Content-Type: application/json" \
  -d '{ "alumno": { "nombre": "Ana", "email": "no-valido" }, "tipo": "PRESTAMO_LIBROS", "descripcion": "corta" }'
```

### Qué verificar en la consola AWS (demo)

| Dónde | Qué se espera ver |
|---|---|
| Correo | Un email con asunto "Solicitud ... procesada" y el resultado según el tipo |
| DynamoDB → tabla `*-solicitudes` | Un ítem con `estado: PROCESADA`, `resultado` y ambas fechas |
| SQS → `*-solicitudes-pendientes` | `Approximate Number Of Messages Not Visible` baja a 0 al procesarse |
| SQS → `*-solicitudes-dlq` | Siempre vacía (si tiene mensajes, algo falló en el procesamiento) |
| CloudWatch → grupos `/aws/lambda/*-recepcion` y `*-procesamiento` | Logs de cada ejecución |

## Limpieza (evitar costos)

```bash
sam delete
```

Elimina la pila completa: API Gateway, Lambdas, colas SQS, tabla DynamoDB y tópico SNS.

## Solución de problemas

| Síntoma | Dónde revisar |
|---|---|
| `package ... does not exist` o `ClassNotFoundException: ForkedBooter` al compilar | La ruta del proyecto contiene `:` → muévelo a una ruta sin dos puntos (ver advertencia arriba) |
| `not authorized to perform: iam:CreateRole` (o similar) | Algo reintrodujo creación de IAM: el template debe seguir usando `Role: ...role/LabRole` en `Globals.Function` y sin bloques `Policies` |
| `The security token included in the request is expired` | Credenciales temporales del lab expiradas → re-exportarlas (Opción B) o reiniciar el lab |
| Despliegue falla en otra región | El Learner Lab solo permite `us-east-1` y `us-west-2` |
| El `POST` devuelve 500 | Logs de la Lambda de recepción en CloudWatch (¿está `COLA_SOLICITUDES_URL`?) |
| No llega el correo | 1) ¿Confirmaste la suscripción SNS? 2) Revisa spam 3) Logs de la Lambda de procesamiento |
| El ítem no aparece en DynamoDB | Logs de la Lambda de procesamiento; revisa si el mensaje quedó en la DLQ |
| Mensajes en la DLQ | La Lambda de procesamiento falló 3 veces: revisa sus logs en CloudWatch |
