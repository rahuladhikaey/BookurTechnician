package com.bookurtechnician.admin.controller;

import com.bookurtechnician.admin.dto.AdminBootstrapDto;
import com.bookurtechnician.audit.entity.AuditLog;
import com.bookurtechnician.audit.repository.AuditLogRepository;
import com.bookurtechnician.auth.entity.Role;
import com.bookurtechnician.auth.entity.User;
import com.bookurtechnician.auth.repository.UserRepository;
import com.bookurtechnician.common.exception.BadRequestException;
import com.bookurtechnician.common.exception.UnauthorizedException;
import com.bookurtechnician.common.response.ApiResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Duration;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

@RestController
@RequestMapping("/api/v1/internal/admin")
public class AdminBootstrapController {

    private static final Logger log = LoggerFactory.getLogger(AdminBootstrapController.class);

    private final UserRepository userRepository;
    private final AuditLogRepository auditLogRepository;
    private final StringRedisTemplate redisTemplate;

    public AdminBootstrapController(UserRepository userRepository,
                                    AuditLogRepository auditLogRepository,
                                    StringRedisTemplate redisTemplate) {
        this.userRepository = userRepository;
        this.auditLogRepository = auditLogRepository;
        this.redisTemplate = redisTemplate;
    }

    @Value("${app.security.admin.access-key-1:}")
    private String serverAccessKey1;

    @Value("${app.security.admin.access-key-2:}")
    private String serverAccessKey2;

    @Value("${app.security.admin.bootstrap-password:}")
    private String serverBootstrapPassword;

    private static final int MAX_FAILED_ATTEMPTS = 5;
    private static final Duration LOCKOUT_DURATION = Duration.ofHours(1);

    @PostMapping("/bootstrap")
    @Transactional
    public ResponseEntity<ApiResponse<Map<String, Object>>> bootstrapAdmin(
            @Valid @RequestBody AdminBootstrapDto dto,
            HttpServletRequest request) {

        String clientIp = extractClientIp(request);
        String rateLimitKey = "ratelimit:bootstrap:" + clientIp;

        // 1. Rate-limiting check
        String failedAttemptsStr = redisTemplate.opsForValue().get(rateLimitKey);
        int failedAttempts = failedAttemptsStr != null ? Integer.parseInt(failedAttemptsStr) : 0;
        if (failedAttempts >= MAX_FAILED_ATTEMPTS) {
            log.warn("Blocked bootstrap attempt from IP {} due to excessive failed attempts", clientIp);
            return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS)
                    .body(ApiResponse.error("Too many failed bootstrap attempts. Endpoint locked. Please try again later."));
        }

        // 2. Validate server-side environment secrets configuration
        if (isUnconfigured(serverAccessKey1) || isUnconfigured(serverAccessKey2) || isUnconfigured(serverBootstrapPassword)) {
            log.error("Developer admin bootstrap rejected: Server secrets are not configured in environment.");
            recordFailedAttempt(rateLimitKey);
            throw new UnauthorizedException("Unauthorized");
        }

        // 3. Constant-time validation of developer credentials
        boolean key1Valid = constantTimeEquals(dto.getAccessKey1(), serverAccessKey1);
        boolean key2Valid = constantTimeEquals(dto.getAccessKey2(), serverAccessKey2);
        boolean passwordValid = constantTimeEquals(dto.getBootstrapPassword(), serverBootstrapPassword);

        if (!key1Valid || !key2Valid || !passwordValid) {
            log.warn("Failed developer admin bootstrap attempt from IP: {}", clientIp);
            recordFailedAttempt(rateLimitKey);
            throw new UnauthorizedException("Unauthorized");
        }

        // Reset rate limit on success
        redisTemplate.delete(rateLimitKey);

        // 4. Validate requested role
        Role adminRole = dto.getRole() != null ? dto.getRole() : Role.SUPER_ADMIN;
        if (adminRole != Role.ADMIN && adminRole != Role.SUPER_ADMIN && adminRole != Role.FINANCE_ADMIN) {
            throw new BadRequestException("Invalid admin role specified. Must be ADMIN, SUPER_ADMIN, or FINANCE_ADMIN.");
        }

        String targetEmail = dto.getEmail().trim().toLowerCase();
        String targetPhone = normalizePhone(dto.getPhone());
        String fullName = (dto.getFullName() != null && !dto.getFullName().isBlank())
                ? dto.getFullName().trim()
                : "System Administrator";

        // 5. Upsert Admin User
        User user = userRepository.findByEmail(targetEmail)
                .or(() -> (targetPhone != null) ? userRepository.findByPhone(targetPhone) : Optional.empty())
                .orElseGet(() -> User.builder()
                        .email(targetEmail)
                        .phone(targetPhone != null ? targetPhone : "9" + String.format("%09d", Math.abs(targetEmail.hashCode() % 1000000000L)))
                        .build());

        user.setEmail(targetEmail);
        if (targetPhone != null) {
            user.setPhone(targetPhone);
        }
        user.setFullName(fullName);
        user.setRole(adminRole);
        user.setEmailVerified(true);
        user.setPhoneVerified(true);
        user.setActive(true);

        User savedAdmin = userRepository.save(user);

        // 6. Secure Audit Logging (Never log secrets!)
        AuditLog auditLog = AuditLog.builder()
                .actorId(null)
                .actorEmail("DEVELOPER_BOOTSTRAP")
                .action("ADMIN_PROVISIONED")
                .entityType("USER")
                .entityId(savedAdmin.getId().toString())
                .clientIp(clientIp)
                .changesJson("{\"email\":\"" + savedAdmin.getEmail() + "\",\"role\":\"" + savedAdmin.getRole().name() + "\",\"fullName\":\"" + savedAdmin.getFullName() + "\"}")
                .build();
        auditLogRepository.save(auditLog);

        log.info("Developer successfully provisioned Admin user {} with role {} from IP {}", savedAdmin.getEmail(), savedAdmin.getRole(), clientIp);

        Map<String, Object> result = new HashMap<>();
        result.put("id", savedAdmin.getId());
        result.put("email", savedAdmin.getEmail());
        result.put("phone", savedAdmin.getPhone());
        result.put("fullName", savedAdmin.getFullName());
        result.put("role", savedAdmin.getRole().name());
        result.put("status", "PROVISIONED");

        return ResponseEntity.ok(ApiResponse.success(result, "Administrator account successfully provisioned by developer"));
    }

    private boolean isUnconfigured(String secret) {
        return secret == null || secret.isBlank() || secret.trim().length() < 8;
    }

    private boolean constantTimeEquals(String a, String b) {
        if (a == null || b == null) {
            return false;
        }
        byte[] aBytes = a.getBytes(StandardCharsets.UTF_8);
        byte[] bBytes = b.getBytes(StandardCharsets.UTF_8);
        return MessageDigest.isEqual(aBytes, bBytes);
    }

    private void recordFailedAttempt(String rateLimitKey) {
        Long attempts = redisTemplate.opsForValue().increment(rateLimitKey);
        if (attempts != null && attempts == 1) {
            redisTemplate.expire(rateLimitKey, LOCKOUT_DURATION);
        }
    }

    private String extractClientIp(HttpServletRequest request) {
        String xForwardedFor = request.getHeader("X-Forwarded-For");
        if (xForwardedFor != null && !xForwardedFor.isBlank()) {
            return xForwardedFor.split(",")[0].trim();
        }
        return request.getRemoteAddr();
    }

    private String normalizePhone(String rawPhone) {
        if (rawPhone == null || rawPhone.isBlank()) {
            return null;
        }
        String digits = rawPhone.replaceAll("[^0-9]", "");
        if (digits.length() == 12 && digits.startsWith("91")) {
            digits = digits.substring(2);
        }
        if (digits.length() == 11 && digits.startsWith("0")) {
            digits = digits.substring(1);
        }
        return digits.isBlank() ? null : digits;
    }
}
