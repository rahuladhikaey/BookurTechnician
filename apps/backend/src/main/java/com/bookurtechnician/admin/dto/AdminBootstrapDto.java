package com.bookurtechnician.admin.dto;

import com.bookurtechnician.auth.entity.Role;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

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

    private Role role;

    public AdminBootstrapDto() {}

    public String getAccessKey1() { return accessKey1; }
    public void setAccessKey1(String accessKey1) { this.accessKey1 = accessKey1; }
    public String getAccessKey2() { return accessKey2; }
    public void setAccessKey2(String accessKey2) { this.accessKey2 = accessKey2; }
    public String getBootstrapPassword() { return bootstrapPassword; }
    public void setBootstrapPassword(String bootstrapPassword) { this.bootstrapPassword = bootstrapPassword; }
    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
    public String getPhone() { return phone; }
    public void setPhone(String phone) { this.phone = phone; }
    public String getFullName() { return fullName; }
    public void setFullName(String fullName) { this.fullName = fullName; }
    public Role getRole() { return role; }
    public void setRole(Role role) { this.role = role; }
}
