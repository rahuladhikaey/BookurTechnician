package com.bookurtechnician.auth.controller;

import com.bookurtechnician.auth.dto.AuthDtos;
import com.bookurtechnician.auth.service.AuthService;
import com.bookurtechnician.common.response.ApiResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    @PostMapping("/request-otp")
    public ResponseEntity<ApiResponse<Void>> requestOtp(@Valid @RequestBody AuthDtos.RequestOtpDto dto) {
        authService.requestOtp(dto);
        return ResponseEntity.ok(ApiResponse.success(null, "Verification code sent to " + dto.getEmail()));
    }

    @PostMapping("/verify-otp")
    public ResponseEntity<ApiResponse<AuthDtos.AuthResponseDto>> verifyOtp(@Valid @RequestBody AuthDtos.VerifyOtpDto dto) {
        AuthDtos.AuthResponseDto response = authService.verifyOtpAndLogin(dto);
        return ResponseEntity.ok(ApiResponse.success(response, "Authentication successful"));
    }

    @PostMapping("/refresh-token")
    public ResponseEntity<ApiResponse<AuthDtos.AuthResponseDto>> refreshToken(@Valid @RequestBody AuthDtos.RefreshTokenDto dto) {
        AuthDtos.AuthResponseDto response = authService.refreshToken(dto);
        return ResponseEntity.ok(ApiResponse.success(response, "Token refreshed successfully"));
    }

    @PostMapping("/admin/direct-access")
    public ResponseEntity<ApiResponse<AuthDtos.AuthResponseDto>> adminDirectAccess(@Valid @RequestBody AuthDtos.AdminDirectAccessDto dto) {
        AuthDtos.AuthResponseDto response = authService.adminDirectAccess(dto);
        return ResponseEntity.ok(ApiResponse.success(response, "Admin access authorized successfully"));
    }

    @PostMapping("/logout")
    public ResponseEntity<ApiResponse<Void>> logout(@RequestBody(required = false) AuthDtos.LogoutDto dto) {
        authService.logout(dto);
        return ResponseEntity.ok(ApiResponse.success(null, "Logged out successfully"));
    }
}
