package com.bookurtechnician.admin.dto;

import com.bookurtechnician.auth.entity.Role;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AdminBootstrapDto {

    @NotBlank(message = "Developer Access Key 1 is required")
    private String accessKey1;

    @NotBlank(message = "Developer Access Key 2 is required")
    private String accessKey2;

    @NotBlank(message = "Developer Bootstrap Password is required")
    private String bootstrapPassword;

    @NotBlank(message = "Admin email address is required")
    @Email(message = "Please provide a valid admin email address")
    private String email;

    @NotBlank(message = "Admin phone number is required")
    private String phone;

    private String fullName;

    private Role role; // ADMIN, SUPER_ADMIN, or FINANCE_ADMIN (defaults to SUPER_ADMIN)
}
