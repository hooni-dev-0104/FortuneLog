package com.fortunelog.engine.infra.config;

import com.fortunelog.engine.common.RequestIdFilter;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.env.Environment;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.UUID;

@Configuration
public class SecurityConfig {

    private static final Logger log = LoggerFactory.getLogger(SecurityConfig.class);

    @Bean
    public RequestIdFilter requestIdFilter() {
        return new RequestIdFilter();
    }

    @Bean
    public SecurityFilterChain securityFilterChain(
            HttpSecurity http,
            ObjectMapper objectMapper,
            RequestIdFilter requestIdFilter,
            Environment env
    ) throws Exception {
        boolean insecureJwt = Boolean.parseBoolean(env.getProperty("ENGINE_INSECURE_JWT", "false"));
        boolean authDebug = Boolean.parseBoolean(env.getProperty("ENGINE_AUTH_DEBUG", "false"));
        String jwtSecret = env.getProperty("SUPABASE_JWT_SECRET", "");
        boolean hasJwtSecret = jwtSecret != null && !jwtSecret.isBlank();

        // Always log the resolved values so local runs can confirm whether env is being loaded.
        log.info(
                "engine security flags: ENGINE_INSECURE_JWT={}, ENGINE_AUTH_DEBUG={}, SUPABASE_JWT_SECRET={}",
                insecureJwt,
                authDebug,
                hasJwtSecret ? "set" : "not set"
        );
        if (insecureJwt) {
            log.warn("ENGINE_INSECURE_JWT=true: JWT signature verification is DISABLED (local dev only).");
        }
        if (authDebug) {
            log.warn("ENGINE_AUTH_DEBUG=true: auth failure responses will include exception details (local dev only).");
        }
        if (hasJwtSecret) {
            log.info("Using SUPABASE_JWT_SECRET (HS256) for JWT verification.");
        } else if (!insecureJwt) {
            log.info("Using JWKS (spring.security.oauth2.resourceserver.jwt.jwk-set-uri) for JWT verification.");
        }

        http
                .csrf(csrf -> csrf.disable())
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .addFilterBefore(requestIdFilter, UsernamePasswordAuthenticationFilter.class)
                .exceptionHandling(ex -> ex
                        .authenticationEntryPoint((request, response, authException) -> {
                            String requestId = requestId(request);
                            log.warn("auth failed (requestId={}, path={}): {}", requestId, request.getRequestURI(), authException.toString());
                            String message = "authentication required";
                            if (authDebug) {
                                String detail = authException.getClass().getSimpleName();
                                if (authException.getMessage() != null && !authException.getMessage().isBlank()) {
                                    detail += ": " + authException.getMessage();
                                }
                                // Keep it short to avoid dumping huge traces into the client response.
                                if (detail.length() > 200) {
                                    detail = detail.substring(0, 200);
                                }
                                message = message + " (" + detail + ")";
                            }
                            writeAuthError(objectMapper, request, response, 401, "UNAUTHORIZED", message);
                        })
                        .accessDeniedHandler((request, response, accessDeniedException) ->
                                writeAuthError(objectMapper, request, response, 403, "FORBIDDEN", "access denied")
                        )
                )
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers("/actuator/health", "/engine/v1/health").permitAll()
                        .anyRequest().authenticated()
                )
                .oauth2ResourceServer(oauth2 -> {
                    if (insecureJwt) {
                        oauth2.jwt(jwt -> jwt.decoder(new InsecureJwtDecoder()));
                    } else if (hasJwtSecret) {
                        // Supabase projects may use HS256 (shared secret) instead of asymmetric keys (JWKS).
                        SecretKey key = new SecretKeySpec(jwtSecret.getBytes(StandardCharsets.UTF_8), "HmacSHA256");
                        JwtDecoder decoder = NimbusJwtDecoder.withSecretKey(key)
                                .macAlgorithm(MacAlgorithm.HS256)
                                .build();
                        oauth2.jwt(jwt -> jwt.decoder(decoder));
                    } else {
                        oauth2.jwt(Customizer.withDefaults());
                    }
                });

        return http.build();
    }

    private void writeAuthError(
            ObjectMapper objectMapper,
            HttpServletRequest request,
            HttpServletResponse response,
            int status,
            String code,
            String message
    ) {
        try {
            response.setStatus(status);
            response.setCharacterEncoding("UTF-8");
            response.setContentType("application/json");

            String requestId = requestId(request);
            response.setHeader("X-Request-Id", requestId);

            String body = objectMapper.writeValueAsString(Map.of(
                    "requestId", requestId,
                    "code", code,
                    "message", message
            ));
            response.getWriter().write(body);
        } catch (Exception ignored) {
            // If writing JSON fails, fall back to the default behavior (empty body is fine).
        }
    }

    private String requestId(HttpServletRequest request) {
        Object value = request.getAttribute(RequestIdFilter.REQUEST_ID_KEY);
        if (value == null) {
            return UUID.randomUUID().toString();
        }
        return value.toString();
    }
}
