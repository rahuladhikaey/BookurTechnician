package com.bookurtechnician.auth.service;

import com.bookurtechnician.auth.dto.AuthDtos;
import com.bookurtechnician.auth.entity.Role;
import com.bookurtechnician.auth.entity.User;
import com.bookurtechnician.auth.repository.UserRepository;
import com.bookurtechnician.auth.security.JwtTokenProvider;
import com.bookurtechnician.common.exception.BadRequestException;
import com.bookurtechnician.common.exception.UnauthorizedException;
import com.bookurtechnician.customer.entity.CustomerProfile;
import com.bookurtechnician.customer.repository.CustomerProfileRepository;
import com.bookurtechnician.technician.entity.TechnicianProfile;
import com.bookurtechnician.technician.repository.TechnicianProfileRepository;
import com.bookurtechnician.wallet.entity.TechnicianWallet;
import com.bookurtechnician.wallet.repository.TechnicianWalletRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.Optional;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class AuthService {

    private final UserRepository userRepository;
    private final CustomerProfileRepository customerProfileRepository;
    private final TechnicianProfileRepository technicianProfileRepository;
    private final TechnicianWalletRepository technicianWalletRepository;
    private final OtpService otpService;
    private final JwtTokenProvider jwtTokenProvider;
    private final StringRedisTemplate redisTemplate;

    public void requestOtp(AuthDtos.RequestOtpDto dto) {
        String purpose = dto.getPurpose() != null && !dto.getPurpose().isBlank()
                ? dto.getPurpose().trim().toUpperCase()
                : "LOGIN";
        String email = dto.getEmail().trim().toLowerCase();
        otpService.requestEmailOtp(email, dto.getName(), purpose);
    }

    @Transactional
    public AuthDtos.AuthResponseDto verifyOtpAndLogin(AuthDtos.VerifyOtpDto dto) {
        String purpose = dto.getPurpose() != null && !dto.getPurpose().isBlank()
                ? dto.getPurpose().trim().toUpperCase()
                : "LOGIN";
        String email = dto.getEmail().trim().toLowerCase();
        String otp = dto.getOtp() != null ? dto.getOtp().trim() : "";
        String normalizedPhone = normalizePhone(dto.getPhone());

        boolean isValid = otpService.verifyEmailOtp(email, purpose, otp);
        if (!isValid) {
            log.warn("Invalid/expired OTP verification attempt for email: {}", email);
            throw new BadRequestException("Invalid or expired verification code. Please check your inbox and try again.");
        }

        // 1. Check existing user by email first
        // 2. If not found by email, check existing user by normalized phone
        // 3. If genuinely new, create exactly one user row
        User user = userRepository.findByEmail(email)
                .or(() -> (normalizedPhone != null && !normalizedPhone.isBlank())
                        ? userRepository.findByPhone(normalizedPhone)
                        : Optional.empty())
                .orElseGet(() -> createNewUser(dto, normalizedPhone, email));

        // Update user fields safely
        if (user.getEmail() == null || user.getEmail().isBlank()) {
            user.setEmail(email);
        }
        if (normalizedPhone != null && !normalizedPhone.isBlank() && (user.getPhone() == null || user.getPhone().isBlank())) {
            user.setPhone(normalizedPhone);
        }
        if (dto.getRole() != null && user.getRole() != dto.getRole()) {
            user.setRole(dto.getRole());
        }
        if (dto.getFullName() != null && !dto.getFullName().isBlank()) {
            user.setFullName(dto.getFullName().trim());
        }
        user.setEmailVerified(true);
        user.setPhoneVerified(true);
        user.setActive(true);

        User savedUser;
        try {
            savedUser = userRepository.save(user);
        } catch (DataIntegrityViolationException ex) {
            // Concurrent insert race condition safety fallback
            log.warn("Concurrent user record resolution for phone {} / email {}", normalizedPhone, email);
            savedUser = userRepository.findByEmail(email)
                    .or(() -> (normalizedPhone != null) ? userRepository.findByPhone(normalizedPhone) : Optional.empty())
                    .orElse(user);
        }

        // Update profile status idempotently
        int completionScore = 100;
        if (savedUser.getRole() == Role.CUSTOMER) {
            final User customerUser = savedUser;
            CustomerProfile profile = customerProfileRepository.findByUser(customerUser)
                    .orElseGet(() -> {
                        CustomerProfile newProfile = CustomerProfile.builder()
                                .user(customerUser)
                                .hasValidName(customerUser.getFullName() != null && !customerUser.getFullName().isBlank())
                                .hasVerifiedPhone(true)
                                .hasVerifiedEmail(true)
                                .build();
                        newProfile.recalculateScore();
                        return customerProfileRepository.save(newProfile);
                    });

            profile.setHasVerifiedEmail(true);
            profile.setHasVerifiedPhone(true);
            if (savedUser.getFullName() != null && !savedUser.getFullName().isBlank()) {
                profile.setHasValidName(true);
            }
            profile.recalculateScore();
            customerProfileRepository.save(profile);
            completionScore = profile.getProfileCompletionPercentage();
        } else if (savedUser.getRole() == Role.TECHNICIAN) {
            final User techUser = savedUser;
            TechnicianProfile techProfile = technicianProfileRepository.findByUser(techUser)
                    .orElseGet(() -> {
                        String techCode = "BT-TECH-" + String.format("%06d", (userRepository.countByRole(Role.TECHNICIAN) + 1));
                        TechnicianProfile newTechProfile = TechnicianProfile.builder()
                                .user(techUser)
                                .technicianCode(techCode)
                                .kycStatus("VERIFIED")
                                .rating(new BigDecimal("5.0"))
                                .upiId("technician@upi")
                                .upiVerified(true)
                                .build();
                        return technicianProfileRepository.save(newTechProfile);
                    });

            if (technicianWalletRepository.findByTechnician(techProfile).isEmpty()) {
                TechnicianWallet wallet = TechnicianWallet.builder()
                        .technician(techProfile)
                        .availableBalance(BigDecimal.ZERO)
                        .totalWithdrawn(BigDecimal.ZERO)
                        .build();
                technicianWalletRepository.save(wallet);
            }
        }

        // Generate JWT Access and Refresh tokens
        String accessToken = jwtTokenProvider.generateAccessToken(savedUser.getId(), savedUser.getEmail(), savedUser.getRole().name());
        String refreshToken = jwtTokenProvider.generateRefreshToken(savedUser.getId());

        log.info("Authentication successful for {} with role {}", savedUser.getEmail(), savedUser.getRole());

        return AuthDtos.AuthResponseDto.builder()
                .accessToken(accessToken)
                .refreshToken(refreshToken)
                .tokenType("Bearer")
                .user(AuthDtos.UserSummaryDto.builder()
                        .id(savedUser.getId())
                        .email(savedUser.getEmail())
                        .phone(savedUser.getPhone())
                        .fullName(savedUser.getFullName())
                        .role(savedUser.getRole())
                        .profileCompleted(completionScore == 100)
                        .profileCompletionPercentage(completionScore)
                        .build())
                .build();
    }

    private User createNewUser(AuthDtos.VerifyOtpDto dto, String normalizedPhone, String email) {
        String phone = (normalizedPhone != null && !normalizedPhone.isBlank())
                ? normalizedPhone
                : "9" + String.format("%09d", Math.abs((email.hashCode() % 1000000000L)));

        // Idempotency check: if user with this phone exists, return it
        Optional<User> existing = userRepository.findByPhone(phone);
        if (existing.isPresent()) {
            return existing.get();
        }

        String fullName = dto.getFullName() != null && !dto.getFullName().isBlank()
                ? dto.getFullName().trim()
                : (dto.getRole() == Role.TECHNICIAN ? "Technician Partner" : "Customer");

        User user = User.builder()
                .email(email)
                .phone(phone)
                .fullName(fullName)
                .role(dto.getRole() != null ? dto.getRole() : Role.CUSTOMER)
                .emailVerified(true)
                .phoneVerified(true)
                .active(true)
                .build();

        try {
            return userRepository.save(user);
        } catch (DataIntegrityViolationException ex) {
            // In case of race condition
            return userRepository.findByPhone(phone)
                    .or(() -> userRepository.findByEmail(email))
                    .orElseThrow(() -> ex);
        }
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

    public AuthDtos.AuthResponseDto refreshToken(AuthDtos.RefreshTokenDto dto) {
        if (!jwtTokenProvider.validateToken(dto.getRefreshToken())) {
            throw new UnauthorizedException("Invalid or expired refresh token. Please sign in again.");
        }

        UUID userId = jwtTokenProvider.getUserIdFromToken(dto.getRefreshToken());
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new UnauthorizedException("User session not found"));

        String newAccessToken = jwtTokenProvider.generateAccessToken(user.getId(), user.getEmail(), user.getRole().name());
        String newRefreshToken = jwtTokenProvider.generateRefreshToken(user.getId());

        int score = 100;
        if (user.getRole() == Role.CUSTOMER) {
            score = customerProfileRepository.findByUser(user)
                    .map(profile -> profile.getProfileCompletionPercentage())
                    .orElse(100);
        }

        return AuthDtos.AuthResponseDto.builder()
                .accessToken(newAccessToken)
                .refreshToken(newRefreshToken)
                .tokenType("Bearer")
                .user(AuthDtos.UserSummaryDto.builder()
                        .id(user.getId())
                        .email(user.getEmail())
                        .phone(user.getPhone())
                        .fullName(user.getFullName())
                        .role(user.getRole())
                        .profileCompleted(score == 100)
                        .profileCompletionPercentage(score)
                        .build())
                .build();
    }

    public void logout(AuthDtos.LogoutDto dto) {
        if (dto != null && dto.getRefreshToken() != null && !dto.getRefreshToken().isBlank()) {
            try {
                // Invalidate refresh token by storing in Redis blacklist
                redisTemplate.opsForValue().set("token:blacklist:" + dto.getRefreshToken(), "revoked", java.time.Duration.ofDays(30));
                log.info("Token session invalidated successfully.");
            } catch (Exception ex) {
                log.warn("Redis token blacklist warning: {}", ex.getMessage());
            }
        }
    }
}
