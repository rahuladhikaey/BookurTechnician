package com.bookurtechnician.auth.dto;

import com.bookurtechnician.auth.entity.Role;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;

import java.util.UUID;

public class AuthDtos {

    public static class RequestOtpDto {
        @NotBlank(message = "Email is required")
        @Email(message = "Please provide a valid email address")
        private String email;
        private String name;
        private String phone;
        @NotBlank(message = "Purpose is required (e.g. LOGIN, SIGNUP, VERIFY)")
        private String purpose;

        public RequestOtpDto() {}
        public RequestOtpDto(String email, String name, String phone, String purpose) {
            this.email = email;
            this.name = name;
            this.phone = phone;
            this.purpose = purpose;
        }

        public String getEmail() { return email; }
        public void setEmail(String email) { this.email = email; }
        public String getName() { return name; }
        public void setName(String name) { this.name = name; }
        public String getPhone() { return phone; }
        public void setPhone(String phone) { this.phone = phone; }
        public String getPurpose() { return purpose; }
        public void setPurpose(String purpose) { this.purpose = purpose; }
    }

    public static class VerifyOtpDto {
        @NotBlank(message = "Email is required")
        @Email(message = "Please provide a valid email address")
        private String email;

        @NotBlank(message = "6-digit OTP code is required")
        @Pattern(regexp = "^[0-9]{6}$", message = "OTP must be exactly 6 digits")
        private String otp;

        @NotNull(message = "Role is required")
        private Role role;

        private String fullName;
        private String phone;
        private String purpose;

        public VerifyOtpDto() {}
        public VerifyOtpDto(String email, String otp, Role role, String fullName, String phone, String purpose) {
            this.email = email;
            this.otp = otp;
            this.role = role;
            this.fullName = fullName;
            this.phone = phone;
            this.purpose = purpose;
        }

        public String getEmail() { return email; }
        public void setEmail(String email) { this.email = email; }
        public String getOtp() { return otp; }
        public void setOtp(String otp) { this.otp = otp; }
        public Role getRole() { return role; }
        public void setRole(Role role) { this.role = role; }
        public String getFullName() { return fullName; }
        public void setFullName(String fullName) { this.fullName = fullName; }
        public String getPhone() { return phone; }
        public void setPhone(String phone) { this.phone = phone; }
        public String getPurpose() { return purpose; }
        public void setPurpose(String purpose) { this.purpose = purpose; }
    }

    public static class AuthResponseDto {
        private String accessToken;
        private String refreshToken;
        private String tokenType = "Bearer";
        private UserSummaryDto user;

        public AuthResponseDto() {}
        public AuthResponseDto(String accessToken, String refreshToken, String tokenType, UserSummaryDto user) {
            this.accessToken = accessToken;
            this.refreshToken = refreshToken;
            this.tokenType = tokenType != null ? tokenType : "Bearer";
            this.user = user;
        }

        public static Builder builder() { return new Builder(); }

        public static class Builder {
            private String accessToken;
            private String refreshToken;
            private String tokenType = "Bearer";
            private UserSummaryDto user;

            public Builder accessToken(String accessToken) { this.accessToken = accessToken; return this; }
            public Builder refreshToken(String refreshToken) { this.refreshToken = refreshToken; return this; }
            public Builder tokenType(String tokenType) { this.tokenType = tokenType; return this; }
            public Builder user(UserSummaryDto user) { this.user = user; return this; }
            public AuthResponseDto build() { return new AuthResponseDto(accessToken, refreshToken, tokenType, user); }
        }

        public String getAccessToken() { return accessToken; }
        public void setAccessToken(String accessToken) { this.accessToken = accessToken; }
        public String getRefreshToken() { return refreshToken; }
        public void setRefreshToken(String refreshToken) { this.refreshToken = refreshToken; }
        public String getTokenType() { return tokenType; }
        public void setTokenType(String tokenType) { this.tokenType = tokenType; }
        public UserSummaryDto getUser() { return user; }
        public void setUser(UserSummaryDto user) { this.user = user; }
    }

    public static class UserSummaryDto {
        private UUID id;
        private String email;
        private String phone;
        private String fullName;
        private Role role;
        private boolean profileCompleted;
        private int profileCompletionPercentage;

        public UserSummaryDto() {}
        public UserSummaryDto(UUID id, String email, String phone, String fullName, Role role, boolean profileCompleted, int profileCompletionPercentage) {
            this.id = id;
            this.email = email;
            this.phone = phone;
            this.fullName = fullName;
            this.role = role;
            this.profileCompleted = profileCompleted;
            this.profileCompletionPercentage = profileCompletionPercentage;
        }

        public static Builder builder() { return new Builder(); }

        public static class Builder {
            private UUID id;
            private String email;
            private String phone;
            private String fullName;
            private Role role;
            private boolean profileCompleted;
            private int profileCompletionPercentage;

            public Builder id(UUID id) { this.id = id; return this; }
            public Builder email(String email) { this.email = email; return this; }
            public Builder phone(String phone) { this.phone = phone; return this; }
            public Builder fullName(String fullName) { this.fullName = fullName; return this; }
            public Builder role(Role role) { this.role = role; return this; }
            public Builder profileCompleted(boolean profileCompleted) { this.profileCompleted = profileCompleted; return this; }
            public Builder profileCompletionPercentage(int profileCompletionPercentage) { this.profileCompletionPercentage = profileCompletionPercentage; return this; }
            public UserSummaryDto build() { return new UserSummaryDto(id, email, phone, fullName, role, profileCompleted, profileCompletionPercentage); }
        }

        public UUID getId() { return id; }
        public void setId(UUID id) { this.id = id; }
        public String getEmail() { return email; }
        public void setEmail(String email) { this.email = email; }
        public String getPhone() { return phone; }
        public void setPhone(String phone) { this.phone = phone; }
        public String getFullName() { return fullName; }
        public void setFullName(String fullName) { this.fullName = fullName; }
        public Role getRole() { return role; }
        public void setRole(Role role) { this.role = role; }
        public boolean isProfileCompleted() { return profileCompleted; }
        public void setProfileCompleted(boolean profileCompleted) { this.profileCompleted = profileCompleted; }
        public int getProfileCompletionPercentage() { return profileCompletionPercentage; }
        public void setProfileCompletionPercentage(int profileCompletionPercentage) { this.profileCompletionPercentage = profileCompletionPercentage; }
    }

    public static class RefreshTokenDto {
        @NotBlank(message = "Refresh token is required")
        private String refreshToken;

        public RefreshTokenDto() {}
        public RefreshTokenDto(String refreshToken) { this.refreshToken = refreshToken; }
        public String getRefreshToken() { return refreshToken; }
        public void setRefreshToken(String refreshToken) { this.refreshToken = refreshToken; }
    }

    public static class LogoutDto {
        private String refreshToken;

        public LogoutDto() {}
        public LogoutDto(String refreshToken) { this.refreshToken = refreshToken; }
        public String getRefreshToken() { return refreshToken; }
        public void setRefreshToken(String refreshToken) { this.refreshToken = refreshToken; }
    }

    public static class AdminDirectAccessDto {
        @NotBlank(message = "Admin email address is required")
        @Email(message = "Please provide a valid admin email address")
        private String email;

        @NotBlank(message = "Access Key 1 is required")
        private String accessKey1;

        @NotBlank(message = "Access Key 2 is required")
        private String accessKey2;

        public AdminDirectAccessDto() {}
        public AdminDirectAccessDto(String email, String accessKey1, String accessKey2) {
            this.email = email;
            this.accessKey1 = accessKey1;
            this.accessKey2 = accessKey2;
        }

        public String getEmail() { return email; }
        public void setEmail(String email) { this.email = email; }
        public String getAccessKey1() { return accessKey1; }
        public void setAccessKey1(String accessKey1) { this.accessKey1 = accessKey1; }
        public String getAccessKey2() { return accessKey2; }
        public void setAccessKey2(String accessKey2) { this.accessKey2 = accessKey2; }
    }
}