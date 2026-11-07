package com.bookurtechnician.config;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import javax.crypto.SecretKey;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.Collections;
import java.util.List;

@Component
@Slf4j
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    @Value("${jwt.secret:super_secret_jwt_key_bookurtechnician_2026_secure}")
    private String jwtSecret;

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        String authHeader = request.getHeader("Authorization");

        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            String token = authHeader.substring(7).trim();
            try {
                // Ensure key has sufficient length for HMAC-SHA
                byte[] keyBytes = jwtSecret.getBytes(StandardCharsets.UTF_8);
                if (keyBytes.length < 32) {
                    byte[] padded = new byte[32];
                    System.arraycopy(keyBytes, 0, padded, 0, Math.min(keyBytes.length, 32));
                    keyBytes = padded;
                }
                SecretKey key = Keys.hmacShaKeyFor(keyBytes);

                Claims claims = Jwts.parser()
                        .verifyWith(key)
                        .build()
                        .parseSignedClaims(token)
                        .getPayload();

                String userId = claims.getSubject();
                if (userId == null || userId.isEmpty()) {
                    userId = claims.get("id", String.class);
                }

                String role = claims.get("role", String.class);
                if (role == null) {
                    role = "USER";
                }

                if (userId != null) {
                    List<SimpleGrantedAuthority> authorities = Collections.singletonList(
                            new SimpleGrantedAuthority("ROLE_" + role.toUpperCase())
                    );
                    UsernamePasswordAuthenticationToken authentication =
                            new UsernamePasswordAuthenticationToken(userId, null, authorities);
                    SecurityContextHolder.getContext().setAuthentication(authentication);
                }
            } catch (Exception e) {
                log.debug("JWT parsing/validation exception: {}", e.getMessage());
            }
        }

        filterChain.doFilter(request, response);
    }
}
