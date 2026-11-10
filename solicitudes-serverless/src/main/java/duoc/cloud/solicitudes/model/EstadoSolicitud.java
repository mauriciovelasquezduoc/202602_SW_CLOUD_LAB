package duoc.cloud.solicitudes.model;

/**
 * Estados posibles de una solicitud a lo largo del ciclo de vida.
 */
public enum EstadoSolicitud {
    /** El mensaje fue aceptado y esta en la cola SQS pendiente de procesamiento. */
    RECIBIDA,
    /** La Lambda de procesamiento la completo: persistida en DynamoDB y notificada por SNS. */
    PROCESADA,
    /** La institucion rechazo la solicitud (uso futuro: validaciones de negocio). */
    RECHAZADA
}
