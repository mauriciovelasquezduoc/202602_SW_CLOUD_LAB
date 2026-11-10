package duoc.cloud.solicitudes.model;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

/**
 * Cuerpo esperado en el POST /solicitudes.
 * Se ignora cualquier propiedad extra que envie el cliente.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public class SolicitudRequest {

    private Alumno alumno;
    private String tipo;
    private String descripcion;

    public Alumno getAlumno() {
        return alumno;
    }

    public void setAlumno(Alumno alumno) {
        this.alumno = alumno;
    }

    public String getTipo() {
        return tipo;
    }

    public void setTipo(String tipo) {
        this.tipo = tipo;
    }

    public String getDescripcion() {
        return descripcion;
    }

    public void setDescripcion(String descripcion) {
        this.descripcion = descripcion;
    }
}
