package com.bookurtechnician.auth.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.security.SecureRandom;
import java.time.Duration;
import java.util.concurrent.TimeUnit;

@Service
@RequiredArgsConstructor
@Slf4j
public class OtpService {

    private final StringRedisTemplate redisTemplate;
    private final BrevoEmailService brevoEmailService;
    private final SecureRandom secureRandom = new SecureRandom();

    private static final Duration OTP_EXPIRY = Duration.ofMinutes(5);
    private static final Duration RESEND_COOLDOWN = Duration.ofSeconds(60);
    private static final int MAX_ATTEMPTS = 3;

    private String getOtpKey(String purpose, String email) {
        return "otp:" + purpose.toLowerCase() + ":" + email.toLowerCase().trim();
    }

    private String getCooldownKey(String purpose, String email) {
        return "otp:cooldown:" + purpose.toLowerCase() + ":" + email.toLowerCase().trim();
    }

    private String getAttemptsKey(String purpose, String email) {
        return "otp:attempts:" + purpose.toLowerCase() + ":" + email.toLowerCase().trim();
    }

    public void requestEmailOtp(String email, String name, String purpose) {
        String cooldownKey = getCooldownKey(purpose, email);
        if (Boolean.TRUE.equals(redisTemplate.hasKey(cooldownKey))) {
            Long ttl = redisTemplate.getExpire(cooldownKey, TimeUnit.SECONDS);
            throw new IllegalStateException("Please wait " + ttl + " seconds before requesting a new verification code.");
        }

        // Generate 6-digit cryptographic OTP
        int code = 100000 + secureRandom.nextInt(900000);
        String otpString = String.valueOf(code);

        String otpKey = getOtpKey(purpose, email);
        String attemptsKey = getAttemptsKey(purpose, email);

        // Store plain OTP in Redis with 5-minute TTL
        redisTemplate.opsForValue().set(otpKey, otpString, OTP_EXPIRY);
        redisTemplate.opsForValue().set(attemptsKey, "0", OTP_EXPIRY);
        redisTemplate.opsForValue().set(cooldownKey, "active", RESEND_COOLDOWN);

        // Send via Brevo Transactional Email
        brevoEmailService.sendOtpEmail(email, name, otpString);
        log.info("Dispatched {} OTP to {}", purpose, email);
    }

    public boolean verifyEmailOtp(String email, String purpose, String inputOtp) {
        String otpKey = getOtpKey(purpose, email);
        String attemptsKey = getAttemptsKey(purpose, email);

        String storedOtp = redisTemplate.opsForValue().get(otpKey);
        if (storedOtp == null) {
            log.warn("OTP verification failed for {}: Code expired or not found", email);
            return false;
        }

        // Check attempts limit
        Long currentAttempts = redisTemplate.opsForValue().increment(attemptsKey);
        if (currentAttempts != null && currentAttempts > MAX_ATTEMPTS) {
            redisTemplate.delete(otpKey);
            redisTemplate.delete(attemptsKey);
            log.warn("OTP verification locked for {}: Exceeded max verification attempts", email);
            throw new IllegalStateException("Maximum verification attempts exceeded. Please request a new code.");
        }

        // Validate cryptographic OTP stored in Redis
        boolean isMatch = storedOtp.equals(inputOtp.trim());

        if (isMatch) {
            // Delete OTP immediately upon success
            redisTemplate.delete(otpKey);
            redisTemplate.delete(attemptsKey);
            redisTemplate.delete(getCooldownKey(purpose, email));
            log.info("OTP verified successfully for {} [Purpose: {}]", email, purpose);
            return true;
        }

        return false;
    }
}
