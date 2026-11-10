package duoc.cloud.solicitudes;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.LambdaLogger;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyRequestEvent;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyResponseEvent;
import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.ObjectMapper;
import duoc.cloud.solicitudes.model.Alumno;
import duoc.cloud.solicitudes.model.EstadoSolicitud;
import duoc.cloud.solicitudes.model.Solicitud;
import duoc.cloud.solicitudes.model.SolicitudRequest;
import duoc.cloud.solicitudes.model.TipoSolicitud;
import duoc.cloud.solicitudes.validacion.ValidadorSolicitud;
import software.amazon.awssdk.services.sqs.SqsClient;
import software.amazon.awssdk.services.sqs.model.SendMessageRequest;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Lambda de RECEPCION (POST /solicitudes).
 * <p>
 * Responsabilidades:
 * 1. Validar el cuerpo de la solicitud (si es invalido responde 400 y no encola).
 * 2. Generar el solicitudId y armar la Solicitud con estado RECIBIDA.
 * 3. Enviarla a la cola SQS para el procesamiento asincrono.
 * 4. Responder 202 Accepted inmediatamente (no espera el procesamiento).
 */
public class RecepcionHandler implements RequestHandler<APIGatewayProxyRequestEvent, APIGatewayProxyResponseEvent> {

    private static final ObjectMapper MAPPER = new ObjectMapper()
            .configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);

    private final SqsClient sqs;
    private final String colaUrl;

    public RecepcionHandler() {
        this.sqs = SqsClient.create();
        this.colaUrl = System.getenv("COLA_SOLICITUDES_URL");
    }

    @Override
    public APIGatewayProxyResponseEvent handleRequest(APIGatewayProxyRequestEvent event, Context context) {
        LambdaLogger log = context.getLogger();
        try {
            // 1. Parsear el cuerpo JSON
            SolicitudRequest request = null;
            if (event.getBody() != null && !event.getBody().isBlank()) {
                request = MAPPER.readValue(event.getBody(), SolicitudRequest.class);
            }

            // 2. Validar: los errores se devuelven al alumno con detalle
            List<String> errores = ValidadorSolicitud.validar(request);
            if (!errores.isEmpty()) {
                log.log("Solicitud invalida: " + errores);
                return respuesta(400, MAPPER.writeValueAsString(Map.of("errores", errores)));
            }

            // 3. Armar la solicitud completa con su identificador unico
            Solicitud solicitud = new Solicitud();
            solicitud.setSolicitudId(UUID.randomUUID().toString());

            Alumno alumno = new Alumno();
            alumno.setNombre(request.getAlumno().getNombre().trim());
            alumno.setEmail(request.getAlumno().getEmail().trim());
            solicitud.setAlumno(alumno);

            solicitud.setTipo(TipoSolicitud.desde(request.getTipo()).name());
            solicitud.setDescripcion(request.getDescripcion().trim());
            solicitud.setEstado(EstadoSolicitud.RECIBIDA.name());
            solicitud.setFechaCreacion(Instant.now().toString());

            // 4. Encolar para el procesamiento asincrono
            sqs.sendMessage(SendMessageRequest.builder()
                    .queueUrl(colaUrl)
                    .messageBody(MAPPER.writeValueAsString(solicitud))
                    .build());

            log.log("Solicitud " + solicitud.getSolicitudId() + " encolada en SQS");

            // 5. Responder 202: aceptada, todavia no procesada
            String body = MAPPER.writeValueAsString(Map.of(
                    "solicitudId", solicitud.getSolicitudId(),
                    "estado", solicitud.getEstado(),
                    "mensaje", "Su solicitud fue recibida y será procesada en breve. "
                            + "Recibirá un correo cuando esté lista."));
            return respuesta(202, body);

        } catch (Exception e) {
            log.log("Error inesperado en recepcion: " + e);
            try {
                return respuesta(500, MAPPER.writeValueAsString(
                        Map.of("error", "Error interno al recibir la solicitud.")));
            } catch (Exception ignored) {
                return respuesta(500, "{\"error\":\"Error interno al recibir la solicitud.\"}");
            }
        }
    }

    private APIGatewayProxyResponseEvent respuesta(int statusCode, String body) {
        return new APIGatewayProxyResponseEvent()
                .withStatusCode(statusCode)
                .withHeaders(Map.of("Content-Type", "application/json"))
                .withBody(body);
    }
}
