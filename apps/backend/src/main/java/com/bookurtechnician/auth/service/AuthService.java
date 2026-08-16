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
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
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
    private final org.springframework.data.redis.core.StringRedisTemplate redisTemplate;

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

        boolean isValid = otpService.verifyEmailOtp(email, purpose, otp);
        if (!isValid) {
            log.warn("Invalid/expired OTP verification attempt for email: {}", email);
            throw new BadRequestException("Invalid or expired verification code. Please check your inbox and try again.");
        }

        // Find or create user
        User user = userRepository.findByEmail(email)
                .orElseGet(() -> createNewUser(dto));

        // If user already existed, ensure role compatibility if requested role is TECHNICIAN
        if (dto.getRole() != null && user.getRole() != dto.getRole()) {
            user.setRole(dto.getRole());
        }

        // Update name/phone if provided
        if (dto.getFullName() != null && !dto.getFullName().isBlank()) {
            user.setFullName(dto.getFullName().trim());
        }
        if (dto.getPhone() != null && !dto.getPhone().isBlank()) {
            user.setPhone(dto.getPhone().trim());
        }
        user.setEmailVerified(true);
        final User savedUser = userRepository.save(user);

        // Update profile status
        int completionScore = 100;
        if (savedUser.getRole() == Role.CUSTOMER) {
            CustomerProfile profile = customerProfileRepository.findByUser(savedUser)
                    .orElseGet(() -> {
                        CustomerProfile newProfile = CustomerProfile.builder()
                                .user(savedUser)
                                .hasValidName(savedUser.getFullName() != null && !savedUser.getFullName().isBlank())
                                .hasVerifiedPhone(true)
                                .hasVerifiedEmail(true)
                                .build();
                        newProfile.recalculateScore();
                        return customerProfileRepository.save(newProfile);
                    });

            profile.setHasVerifiedEmail(true);
            if (savedUser.getFullName() != null && !savedUser.getFullName().isBlank()) {
                profile.setHasValidName(true);
            }
            profile.recalculateScore();
            customerProfileRepository.save(profile);
            completionScore = profile.getProfileCompletionPercentage();
        } else if (savedUser.getRole() == Role.TECHNICIAN) {
            technicianProfileRepository.findByUser(savedUser).orElseGet(() -> {
                String techCode = "BT-TECH-" + String.format("%06d", (userRepository.countByRole(Role.TECHNICIAN) + 1));
                TechnicianProfile techProfile = TechnicianProfile.builder()
                        .user(savedUser)
                        .technicianCode(techCode)
                        .kycStatus("VERIFIED")
                        .rating(new BigDecimal("5.0"))
                        .upiId("technician@upi")
                        .upiVerified(true)
                        .build();
                techProfile = technicianProfileRepository.save(techProfile);

                if (technicianWalletRepository.findByTechnician(techProfile).isEmpty()) {
                    TechnicianWallet wallet = TechnicianWallet.builder()
                            .technician(techProfile)
                            .availableBalance(BigDecimal.ZERO)
                            .totalWithdrawn(BigDecimal.ZERO)
                            .build();
                    technicianWalletRepository.save(wallet);
                }
                return techProfile;
            });
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

    private User createNewUser(AuthDtos.VerifyOtpDto dto) {
        String phone = dto.getPhone() != null && !dto.getPhone().isBlank()
                ? dto.getPhone().trim()
                : "9" + String.format("%09d", Math.abs((dto.getEmail().hashCode() % 1000000000L)));

        String fullName = dto.getFullName() != null && !dto.getFullName().isBlank()
                ? dto.getFullName().trim()
                : (dto.getRole() == Role.TECHNICIAN ? "Technician Partner" : "Customer");

        User user = User.builder()
                .email(dto.getEmail().toLowerCase().trim())
                .phone(phone)
                .fullName(fullName)
                .role(dto.getRole() != null ? dto.getRole() : Role.CUSTOMER)
                .emailVerified(true)
                .phoneVerified(true)
                .build();

        user = userRepository.save(user);

        if (user.getRole() == Role.CUSTOMER) {
            CustomerProfile profile = CustomerProfile.builder()
                    .user(user)
                    .hasValidName(!fullName.isBlank())
                    .hasVerifiedPhone(true)
                    .hasVerifiedEmail(true)
                    .build();
            profile.recalculateScore();
            customerProfileRepository.save(profile);
        } else if (user.getRole() == Role.TECHNICIAN) {
            String techCode = "BT-TECH-" + String.format("%06d", (userRepository.countByRole(Role.TECHNICIAN) + 1));
            TechnicianProfile techProfile = TechnicianProfile.builder()
                    .user(user)
                    .technicianCode(techCode)
                    .kycStatus("VERIFIED")
                    .rating(new BigDecimal("5.0"))
                    .upiId("technician@upi")
                    .upiVerified(true)
                    .build();
            techProfile = technicianProfileRepository.save(techProfile);

            // Initialize Wallet
            TechnicianWallet wallet = TechnicianWallet.builder()
                    .technician(techProfile)
                    .availableBalance(BigDecimal.ZERO)
                    .totalWithdrawn(BigDecimal.ZERO)
                    .build();
            technicianWalletRepository.save(wallet);
        }

        return user;
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
