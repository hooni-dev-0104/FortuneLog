package com.fortunelog.engine.common;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import jakarta.servlet.http.HttpServletRequest;
import java.time.format.DateTimeParseException;
import java.util.Map;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@RestControllerAdvice
public class ApiExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(ApiExceptionHandler.class);

    @ExceptionHandler(MethodArgumentNotValidException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public Map<String, Object> handleValidationError(
            MethodArgumentNotValidException ex,
            HttpServletRequest request
    ) {
        return Map.of(
                "requestId", requestId(request),
                "code", "VALIDATION_ERROR",
                "message", "request validation failed"
        );
    }

    @ExceptionHandler({IllegalArgumentException.class, DateTimeParseException.class})
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public Map<String, Object> handleBadRequest(
            Exception ex,
            HttpServletRequest request
    ) {
        return Map.of(
                "requestId", requestId(request),
                "code", "BIRTH_INFO_INVALID",
                "message", ex.getMessage()
        );
    }

    @ExceptionHandler(Exception.class)
    @ResponseStatus(HttpStatus.INTERNAL_SERVER_ERROR)
    public Map<String, Object> handleUnexpected(
            Exception ex,
            HttpServletRequest request
    ) {
        log.error("unexpected error", ex);
        return Map.of(
                "requestId", requestId(request),
                "code", "INTERNAL_ERROR",
                "message", "unexpected server error"
        );
    }

    private String requestId(HttpServletRequest request) {
        Object value = request.getAttribute(RequestIdFilter.REQUEST_ID_KEY);
        if (value == null) {
            return UUID.randomUUID().toString();
        }
        return value.toString();
    }
}
