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

    public void requestOtp(AuthDtos.RequestOtpDto dto) {
        otpService.requestEmailOtp(dto.getEmail(), dto.getName(), dto.getPurpose());
    }

    @Transactional
    public AuthDtos.AuthResponseDto verifyOtpAndLogin(AuthDtos.VerifyOtpDto dto) {
        boolean isValid = otpService.verifyEmailOtp(dto.getEmail(), dto.getPurpose() != null ? dto.getPurpose() : "LOGIN", dto.getOtp());
        if (!isValid) {
            throw new BadRequestException("Invalid or expired verification code. Please try again.");
        }

        // Find or create user
        User user = userRepository.findByEmail(dto.getEmail().toLowerCase().trim())
                .orElseGet(() -> createNewUser(dto));

        // Update name/phone if provided
        if (dto.getFullName() != null && !dto.getFullName().isBlank()) {
            user.setFullName(dto.getFullName().trim());
        }
        if (dto.getPhone() != null && !dto.getPhone().isBlank()) {
            user.setPhone(dto.getPhone().trim());
        }
        user.setEmailVerified(true);
        user = userRepository.save(user);

        // Update profile status
        int completionScore = 100;
        if (user.getRole() == Role.CUSTOMER) {
            CustomerProfile profile = customerProfileRepository.findByUser(user)
                    .orElseGet(() -> {
                        CustomerProfile newProfile = CustomerProfile.builder()
                                .user(user)
                                .hasValidName(user.getFullName() != null && !user.getFullName().isBlank())
                                .hasVerifiedPhone(true)
                                .hasVerifiedEmail(true)
                                .build();
                        newProfile.recalculateScore();
                        return customerProfileRepository.save(newProfile);
                    });

            profile.setHasVerifiedEmail(true);
            if (user.getFullName() != null && !user.getFullName().isBlank()) {
                profile.setHasValidName(true);
            }
            profile.recalculateScore();
            customerProfileRepository.save(profile);
            completionScore = profile.getProfileCompletionPercentage();
        }

        // Generate JWT Access and Refresh tokens
        String accessToken = jwtTokenProvider.generateAccessToken(user.getId(), user.getEmail(), user.getRole().name());
        String refreshToken = jwtTokenProvider.generateRefreshToken(user.getId());

        return AuthDtos.AuthResponseDto.builder()
                .accessToken(accessToken)
                .refreshToken(refreshToken)
                .tokenType("Bearer")
                .user(AuthDtos.UserSummaryDto.builder()
                        .id(user.getId())
                        .email(user.getEmail())
                        .phone(user.getPhone())
                        .fullName(user.getFullName())
                        .role(user.getRole())
                        .profileCompleted(completionScore == 100)
                        .profileCompletionPercentage(completionScore)
                        .build())
                .build();
    }

    private User createNewUser(AuthDtos.VerifyOtpDto dto) {
        String phone = dto.getPhone() != null && !dto.getPhone().isBlank()
                ? dto.getPhone().trim()
                : "+91" + (System.currentTimeMillis() % 10000000000L);

        User user = User.builder()
                .email(dto.getEmail().toLowerCase().trim())
                .phone(phone)
                .fullName(dto.getFullName() != null ? dto.getFullName().trim() : "Valued Customer")
                .role(dto.getRole() != null ? dto.getRole() : Role.CUSTOMER)
                .emailVerified(true)
                .phoneVerified(true)
                .build();

        user = userRepository.save(user);

        if (user.getRole() == Role.CUSTOMER) {
            CustomerProfile profile = CustomerProfile.builder()
                    .user(user)
                    .hasValidName(user.getFullName() != null && !user.getFullName().isBlank())
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
                    .kycStatus("PENDING")
                    .rating(new BigDecimal("5.0"))
                    .upiId("technician@upi")
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
                    .map(CustomerProfile::getProfileCompletionPercentage)
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
}
