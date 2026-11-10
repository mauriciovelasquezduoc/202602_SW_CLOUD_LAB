package duoc.cloud.solicitudes.validacion;

import duoc.cloud.solicitudes.model.Alumno;
import duoc.cloud.solicitudes.model.SolicitudRequest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class ValidadorSolicitudTest {

    private SolicitudRequest solicitudValida() {
        Alumno alumno = new Alumno();
        alumno.setNombre("María Pérez Soto");
        alumno.setEmail("maria.perez@duocuc.cl");

        SolicitudRequest request = new SolicitudRequest();
        request.setAlumno(alumno);
        request.setTipo("CERTIFICADO");
        request.setDescripcion("Necesito certificado de notas para postular a una beca");
        return request;
    }

    @Test
    @DisplayName("Una solicitud con datos correctos no genera errores")
    void solicitudValidaNoGeneraErrores() {
        List<String> errores = ValidadorSolicitud.validar(solicitudValida());
        assertTrue(errores.isEmpty(), "No debería haber errores: " + errores);
    }

    @Test
    @DisplayName("Un tipo no soportado genera error de validación")
    void tipoInvalidoGeneraError() {
        SolicitudRequest request = solicitudValida();
        request.setTipo("PRESTAMO_LIBROS");

        List<String> errores = ValidadorSolicitud.validar(request);
        assertTrue(errores.stream().anyMatch(e -> e.contains("tipo")));
    }

    @Test
    @DisplayName("Un email mal formado genera error de validación")
    void emailInvalidoGeneraError() {
        SolicitudRequest request = solicitudValida();
        request.getAlumno().setEmail("correo-sin-arroba");

        List<String> errores = ValidadorSolicitud.validar(request);
        assertTrue(errores.stream().anyMatch(e -> e.contains("email")));
    }

    @Test
    @DisplayName("Una descripción demasiado corta genera error de validación")
    void descripcionCortaGeneraError() {
        SolicitudRequest request = solicitudValida();
        request.setDescripcion("muy corta");

        List<String> errores = ValidadorSolicitud.validar(request);
        assertTrue(errores.stream().anyMatch(e -> e.contains("descripción")));
    }

    @Test
    @DisplayName("Un cuerpo nulo genera error y nunca pasa la validación")
    void cuerpoNuloGeneraError() {
        List<String> errores = ValidadorSolicitud.validar(null);
        assertFalse(errores.isEmpty());
    }
}
