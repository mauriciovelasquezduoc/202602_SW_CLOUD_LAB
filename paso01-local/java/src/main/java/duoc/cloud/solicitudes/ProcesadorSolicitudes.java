package duoc.cloud.solicitudes;

import duoc.cloud.solicitudes.model.TipoSolicitud;

/**
 * Logica de negocio del procesamiento: define el resultado
 * que se le entrega al alumno segun el tipo de solicitud.
 */
public final class ProcesadorSolicitudes {

    private ProcesadorSolicitudes() {
    }

    public static String procesar(TipoSolicitud tipo) {
        if (tipo == null) {
            throw new IllegalArgumentException("Tipo de solicitud no reconocido.");
        }
        return switch (tipo) {
            case CERTIFICADO ->
                    "Su certificado fue emitido y estará disponible para retiro en 3 días hábiles.";
            case REVISION_NOTAS ->
                    "Su solicitud de revisión fue derivada al docente de la asignatura. Plazo de respuesta: 5 días hábiles.";
            case SOPORTE_TECNICO ->
                    "Se generó un ticket de soporte. El equipo técnico lo contactará a la brevedad.";
            case INFO_ACADEMICA ->
                    "La información académica solicitada fue enviada a su correo electrónico.";
        };
    }
}
