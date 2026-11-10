package duoc.cloud.solicitudes.model;

/**
 * Tipos de solicitud que atiende la institucion.
 * Si se agrega uno nuevo, actualizar ValidadorSolicitud y ProcesadorSolicitudes.
 */
public enum TipoSolicitud {
    CERTIFICADO,
    REVISION_NOTAS,
    SOPORTE_TECNICO,
    INFO_ACADEMICA;

    /**
     * Convierte un String (mayusculas o minusculas) a TipoSolicitud.
     * Devuelve null si el valor no corresponde a ningun tipo valido.
     */
    public static TipoSolicitud desde(String valor) {
        if (valor == null || valor.isBlank()) {
            return null;
        }
        try {
            return TipoSolicitud.valueOf(valor.trim().toUpperCase());
        } catch (IllegalArgumentException e) {
            return null;
        }
    }
}
