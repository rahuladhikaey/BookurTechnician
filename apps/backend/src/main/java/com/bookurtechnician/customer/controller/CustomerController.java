package com.bookurtechnician.customer.controller;

import com.bookurtechnician.auth.entity.User;
import com.bookurtechnician.auth.repository.UserRepository;
import com.bookurtechnician.auth.security.UserPrincipal;
import com.bookurtechnician.common.exception.ResourceNotFoundException;
import com.bookurtechnician.common.response.ApiResponse;
import com.bookurtechnician.customer.entity.CustomerAddress;
import com.bookurtechnician.customer.entity.CustomerProfile;
import com.bookurtechnician.customer.repository.CustomerAddressRepository;
import com.bookurtechnician.customer.repository.CustomerProfileRepository;
import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.RequiredArgsConstructor;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/customer")
@RequiredArgsConstructor
public class CustomerController {

    private final CustomerProfileRepository profileRepository;
    private final CustomerAddressRepository addressRepository;
    private final UserRepository userRepository;
    private final GeometryFactory geometryFactory = new GeometryFactory(new PrecisionModel(), 4326);

    @GetMapping("/profile")
    public ResponseEntity<ApiResponse<CustomerProfile>> getProfile(@AuthenticationPrincipal UserPrincipal principal) {
        CustomerProfile profile = profileRepository.findByUserId(principal.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Customer profile not found"));
        return ResponseEntity.ok(ApiResponse.success(profile));
    }

    @PutMapping("/profile")
    public ResponseEntity<ApiResponse<CustomerProfile>> updateProfile(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestBody UpdateProfileDto dto) {
        User user = userRepository.findById(principal.getId())
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        if (dto.getFullName() != null && !dto.getFullName().isBlank()) {
            user.setFullName(dto.getFullName().trim());
            userRepository.save(user);
        }

        CustomerProfile profile = profileRepository.findByUser(user)
                .orElseGet(() -> CustomerProfile.builder().user(user).build());

        if (user.getFullName() != null && !user.getFullName().isBlank()) {
            profile.setHasValidName(true);
        }
        profile.setGender(dto.getGender());
        profile.setDateOfBirth(dto.getDateOfBirth());
        profile.recalculateScore();

        profile = profileRepository.save(profile);
        return ResponseEntity.ok(ApiResponse.success(profile, "Profile updated successfully"));
    }

    @GetMapping("/addresses")
    public ResponseEntity<ApiResponse<List<CustomerAddress>>> getAddresses(@AuthenticationPrincipal UserPrincipal principal) {
        List<CustomerAddress> addresses = addressRepository.findByCustomerIdOrderByCreatedAtDesc(principal.getId());
        return ResponseEntity.ok(ApiResponse.success(addresses));
    }

    @PostMapping("/addresses")
    public ResponseEntity<ApiResponse<CustomerAddress>> addAddress(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestBody CreateAddressDto dto) {
        User user = userRepository.findById(principal.getId())
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        Point point = null;
        if (dto.getLatitude() != null && dto.getLongitude() != null) {
            point = geometryFactory.createPoint(new Coordinate(dto.getLongitude(), dto.getLatitude()));
        }

        CustomerAddress address = CustomerAddress.builder()
                .customer(user)
                .addressType(dto.getAddressType() != null ? dto.getAddressType() : "HOME")
                .houseFlat(dto.getHouseFlat())
                .street(dto.getStreet())
                .area(dto.getArea())
                .city(dto.getCity())
                .state(dto.getState())
                .postalCode(dto.getPostalCode())
                .landmark(dto.getLandmark())
                .coordinates(point)
                .primary(dto.isPrimary())
                .build();

        address = addressRepository.save(address);

        // Update profile has_service_address flag
        CustomerProfile profile = profileRepository.findByUser(user).orElse(null);
        if (profile != null) {
            profile.setHasServiceAddress(true);
            profile.recalculateScore();
            profileRepository.save(profile);
        }

        return ResponseEntity.ok(ApiResponse.success(address, "Address saved successfully"));
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class UpdateProfileDto {
        private String fullName;
        private String gender;
        private java.time.LocalDate dateOfBirth;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class CreateAddressDto {
        @NotBlank
        private String houseFlat;
        @NotBlank
        private String street;
        @NotBlank
        private String area;
        @NotBlank
        private String city;
        @NotBlank
        private String state;
        @NotBlank
        private String postalCode;
        private String addressType;
        private String landmark;
        private Double latitude;
        private Double longitude;
        private boolean primary;
    }
}
