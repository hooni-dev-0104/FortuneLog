package com.fortunelog.engine.infra.config;

import com.nimbusds.jwt.SignedJWT;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtException;

import java.time.Instant;
import java.util.Date;
import java.util.Map;

/**
 * Dev-only JWT decoder that parses claims without verifying signature.
 * Use only for local development when JWKS fetch/validation is blocking.
 */
public class InsecureJwtDecoder implements JwtDecoder {

    @Override
    public Jwt decode(String token) throws JwtException {
        try {
            SignedJWT jwt = SignedJWT.parse(token);
            Map<String, Object> headers = jwt.getHeader().toJSONObject();
            Map<String, Object> claims = jwt.getJWTClaimsSet().getClaims();

            Instant issuedAt = toInstant(jwt.getJWTClaimsSet().getIssueTime());
            Instant expiresAt = toInstant(jwt.getJWTClaimsSet().getExpirationTime());

            // Minimal sanity checks to reduce foot-guns.
            if (expiresAt != null && expiresAt.isBefore(Instant.now())) {
                throw new JwtException("token expired");
            }

            Jwt.Builder builder = Jwt.withTokenValue(token).headers(h -> h.putAll(headers)).claims(c -> c.putAll(claims));
            if (issuedAt != null) builder.issuedAt(issuedAt);
            if (expiresAt != null) builder.expiresAt(expiresAt);
            return builder.build();
        } catch (JwtException e) {
            throw e;
        } catch (Exception e) {
            throw new JwtException("failed to parse jwt", e);
        }
    }

    private static Instant toInstant(Date d) {
        return d == null ? null : d.toInstant();
    }
}

