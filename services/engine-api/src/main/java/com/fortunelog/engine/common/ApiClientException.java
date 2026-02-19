package com.fortunelog.engine.common;

import org.springframework.http.HttpStatus;

public class ApiClientException extends RuntimeException {

    private final String code;
    private final HttpStatus status;

    public ApiClientException(String code, HttpStatus status, String message) {
        super(message);
        this.code = code;
        this.status = status;
    }

    public String code() {
        return code;
    }

    public HttpStatus status() {
        return status;
    }
}
