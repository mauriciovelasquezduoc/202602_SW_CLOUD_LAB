package duoc.cloud.solicitudes;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.LambdaLogger;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.SQSEvent;
import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.ObjectMapper;
import duoc.cloud.solicitudes.model.Alumno;
import duoc.cloud.solicitudes.model.EstadoSolicitud;
import duoc.cloud.solicitudes.model.Solicitud;
import duoc.cloud.solicitudes.model.TipoSolicitud;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;
import software.amazon.awssdk.services.dynamodb.model.PutItemRequest;
import software.amazon.awssdk.services.sns.SnsClient;
import software.amazon.awssdk.services.sns.model.PublishRequest;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

/**
 * Lambda de PROCESAMIENTO: consume mensajes de la cola SQS.
 * <p>
 * Por cada mensaje:
 * 1. Calcula el resultado segun el tipo de solicitud.
 * 2. Guarda la solicitud en DynamoDB con estado PROCESADA.
 * 3. Publica la notificacion en SNS para que el alumno reciba un correo.
 * <p>
 * Si algo falla, se relanza la excepcion: SQS reintenta la entrega
 * y, tras 3 intentos, mueve el mensaje a la DLQ.
 */
public class ProcesamientoHandler implements RequestHandler<SQSEvent, Void> {

    private static final ObjectMapper MAPPER = new ObjectMapper()
            .configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);

    private final DynamoDbClient dynamo;
    private final SnsClient sns;
    private final String tabla;
    private final String topico;

    public ProcesamientoHandler() {
        this.dynamo = DynamoDbClient.create();
        this.sns = SnsClient.create();
        this.tabla = System.getenv("TABLA_SOLICITUDES");
        this.topico = System.getenv("TOPICO_NOTIFICACIONES");
    }

    @Override
    public Void handleRequest(SQSEvent event, Context context) {
        LambdaLogger log = context.getLogger();

        for (SQSEvent.SQSMessage mensaje : event.getRecords()) {
            try {
                Solicitud solicitud = MAPPER.readValue(mensaje.getBody(), Solicitud.class);
                log.log("Procesando solicitud " + solicitud.getSolicitudId());

                // 1. Procesar segun el tipo de solicitud
                String resultado = ProcesadorSolicitudes.procesar(
                        TipoSolicitud.desde(solicitud.getTipo()));

                // 2. Persistir con el estado final
                solicitud.setEstado(EstadoSolicitud.PROCESADA.name());
                solicitud.setFechaProcesamiento(Instant.now().toString());
                solicitud.setResultado(resultado);
                guardar(solicitud);

                // 3. Notificar al alumno por correo
                notificar(solicitud, log);

            } catch (Exception e) {
                // Lanzamos la excepcion para que SQS reintente y, si corresponde, envie a la DLQ.
                // PutItem es idempotente (PK = solicitudId), por lo que un reintento
                // del mismo mensaje no genera registros duplicados.
                log.log("Error al procesar mensaje de la cola: " + e);
                throw new RuntimeException("Fallo el procesamiento de la solicitud", e);
            }
        }
        return null;
    }

    private void guardar(Solicitud s) {
        Map<String, AttributeValue> item = new HashMap<>();
        item.put("solicitudId", AttributeValue.builder().s(s.getSolicitudId()).build());
        item.put("tipo", AttributeValue.builder().s(s.getTipo()).build());
        item.put("descripcion", AttributeValue.builder().s(s.getDescripcion()).build());
        item.put("nombreAlumno", AttributeValue.builder().s(s.getAlumno().getNombre()).build());
        item.put("emailAlumno", AttributeValue.builder().s(s.getAlumno().getEmail()).build());
        item.put("estado", AttributeValue.builder().s(s.getEstado()).build());
        item.put("fechaCreacion", AttributeValue.builder().s(s.getFechaCreacion()).build());
        item.put("fechaProcesamiento", AttributeValue.builder().s(s.getFechaProcesamiento()).build());
        item.put("resultado", AttributeValue.builder().s(s.getResultado()).build());

        dynamo.putItem(PutItemRequest.builder()
                .tableName(tabla)
                .item(item)
                .build());
    }

    private void notificar(Solicitud s, LambdaLogger log) {
        String asunto = "Solicitud " + s.getSolicitudId().substring(0, 8) + " procesada";
        String cuerpo = "Hola " + s.getAlumno().getNombre() + ":\n\n"
                + "Tu solicitud de tipo " + s.getTipo() + " fue PROCESADA con éxito.\n\n"
                + "Resultado: " + s.getResultado() + "\n\n"
                + "Fecha de procesamiento: " + s.getFechaProcesamiento() + "\n\n"
                + "Atentamente,\nDirección de Asuntos Estudiantiles";

        sns.publish(PublishRequest.builder()
                .topicArn(topico)
                .subject(asunto)
                .message(cuerpo)
                .build());

        log.log("Notificación SNS enviada para la solicitud " + s.getSolicitudId());
    }
}
