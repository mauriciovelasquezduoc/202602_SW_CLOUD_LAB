package duoc.cloud.solicitudes.validacion;

import duoc.cloud.solicitudes.model.Alumno;
import duoc.cloud.solicitudes.model.SolicitudRequest;
import duoc.cloud.solicitudes.model.TipoSolicitud;

import java.util.ArrayList;
import java.util.List;
import java.util.regex.Pattern;

/**
 * Reglas de validacion de una solicitud, aplicadas en la recepcion.
 * Si la lista devuelta esta vacia, la solicitud es valida y se encola.
 */
public final class ValidadorSolicitud {

    private static final Pattern EMAIL = Pattern.compile("^[\\w.+-]+@[\\w-]+(\\.[\\w-]+)+$");

    private ValidadorSolicitud() {
    }

    /**
     * @return lista de errores; vacia si la solicitud es valida.
     */
    public static List<String> validar(SolicitudRequest request) {
        List<String> errores = new ArrayList<>();

        if (request == null) {
            errores.add("El cuerpo de la solicitud es obligatorio.");
            return errores;
        }

        Alumno alumno = request.getAlumno();
        if (alumno == null) {
            errores.add("Los datos del alumno son obligatorios.");
        } else {
            if (alumno.getNombre() == null
                    || alumno.getNombre().trim().length() < 3
                    || alumno.getNombre().trim().length() > 100) {
                errores.add("El nombre del alumno es obligatorio (entre 3 y 100 caracteres).");
            }
            if (alumno.getEmail() == null || !EMAIL.matcher(alumno.getEmail().trim()).matches()) {
                errores.add("El email del alumno no es válido.");
            }
        }

        if (TipoSolicitud.desde(request.getTipo()) == null) {
            errores.add("El tipo debe ser uno de: CERTIFICADO, REVISION_NOTAS, SOPORTE_TECNICO, INFO_ACADEMICA.");
        }

        if (request.getDescripcion() == null
                || request.getDescripcion().trim().length() < 10
                || request.getDescripcion().trim().length() > 500) {
            errores.add("La descripción es obligatoria (entre 10 y 500 caracteres).");
        }

        return errores;
    }
}
