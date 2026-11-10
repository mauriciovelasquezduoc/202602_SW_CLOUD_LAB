package duoc.cloud.solicitudes.model;

import com.fasterxml.jackson.annotation.JsonInclude;

/**
 * Solicitud completa: viaja como mensaje SQS (estado RECIBIDA)
 * y se persiste en DynamoDB (estado PROCESADA).
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public class Solicitud {

    private String solicitudId;
    private Alumno alumno;
    private String tipo;
    private String descripcion;
    private String estado;
    private String fechaCreacion;
    private String fechaProcesamiento;
    private String resultado;

    public String getSolicitudId() {
        return solicitudId;
    }

    public void setSolicitudId(String solicitudId) {
        this.solicitudId = solicitudId;
    }

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

    public String getEstado() {
        return estado;
    }

    public void setEstado(String estado) {
        this.estado = estado;
    }

    public String getFechaCreacion() {
        return fechaCreacion;
    }

    public void setFechaCreacion(String fechaCreacion) {
        this.fechaCreacion = fechaCreacion;
    }

    public String getFechaProcesamiento() {
        return fechaProcesamiento;
    }

    public void setFechaProcesamiento(String fechaProcesamiento) {
        this.fechaProcesamiento = fechaProcesamiento;
    }

    public String getResultado() {
        return resultado;
    }

    public void setResultado(String resultado) {
        this.resultado = resultado;
    }
}
