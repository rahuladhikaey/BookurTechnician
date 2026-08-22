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
import lombok.AllArgsConstructor;
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
                .orElseGet(() -> {
                    User user = userRepository.findById(principal.getId())
                            .orElseThrow(() -> new ResourceNotFoundException("User not found: " + principal.getId()));
                    CustomerProfile newProfile = CustomerProfile.builder()
                            .user(user)
                            .hasValidName(user.getFullName() != null && !user.getFullName().isBlank())
                            .hasVerifiedPhone(user.getPhone() != null && !user.getPhone().isBlank())
                            .hasVerifiedEmail(user.getEmail() != null && !user.getEmail().isBlank())
                            .build();
                    newProfile.recalculateScore();
                    return profileRepository.save(newProfile);
                });
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
        if (dto.getGender() != null) {
            profile.setGender(dto.getGender());
        }
        if (dto.getDateOfBirth() != null) {
            profile.setDateOfBirth(dto.getDateOfBirth());
        }
        if (dto.getAnniversaryDate() != null) {
            profile.setAnniversaryDate(dto.getAnniversaryDate());
        }
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

        validateCoordinates(dto.getLatitude(), dto.getLongitude());

        Point point = null;
        if (dto.getLatitude() != null && dto.getLongitude() != null) {
            point = geometryFactory.createPoint(new Coordinate(dto.getLongitude(), dto.getLatitude()));
        }

        String houseFlat = dto.getHouseFlat() != null && !dto.getHouseFlat().isBlank() ? dto.getHouseFlat() : dto.getAddressLine1();
        String street = dto.getStreet() != null && !dto.getStreet().isBlank() ? dto.getStreet() : dto.getAddressLine2();
        String area = dto.getArea() != null && !dto.getArea().isBlank() ? dto.getArea() : dto.getLocality();
        String label = dto.getAddressType() != null && !dto.getAddressType().isBlank() ? dto.getAddressType() : (dto.getLabel() != null ? dto.getLabel() : "HOME");

        CustomerAddress address = CustomerAddress.builder()
                .customer(user)
                .addressType(label.toUpperCase())
                .houseFlat(houseFlat != null ? houseFlat : "Premises")
                .street(street != null ? street : "Main Road")
                .area(area != null ? area : "Locality")
                .city(dto.getCity() != null ? dto.getCity() : "City")
                .state(dto.getState() != null ? dto.getState() : "State")
                .postalCode(dto.getPostalCode() != null ? dto.getPostalCode() : "000000")
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

    @PutMapping("/addresses/{id}")
    public ResponseEntity<ApiResponse<CustomerAddress>> updateAddress(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable UUID id,
            @RequestBody CreateAddressDto dto) {
        CustomerAddress address = addressRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Address not found with id: " + id));

        if (!address.getCustomer().getId().equals(principal.getId())) {
            throw new com.bookurtechnician.common.exception.BadRequestException("Unauthorized access to this address.");
        }

        validateCoordinates(dto.getLatitude(), dto.getLongitude());

        if (dto.getLatitude() != null && dto.getLongitude() != null) {
            Point point = geometryFactory.createPoint(new Coordinate(dto.getLongitude(), dto.getLatitude()));
            address.setCoordinates(point);
        }

        if (dto.getHouseFlat() != null || dto.getAddressLine1() != null) {
            address.setHouseFlat(dto.getHouseFlat() != null ? dto.getHouseFlat() : dto.getAddressLine1());
        }
        if (dto.getStreet() != null || dto.getAddressLine2() != null) {
            address.setStreet(dto.getStreet() != null ? dto.getStreet() : dto.getAddressLine2());
        }
        if (dto.getArea() != null || dto.getLocality() != null) {
            address.setArea(dto.getArea() != null ? dto.getArea() : dto.getLocality());
        }
        if (dto.getCity() != null) address.setCity(dto.getCity());
        if (dto.getState() != null) address.setState(dto.getState());
        if (dto.getPostalCode() != null) address.setPostalCode(dto.getPostalCode());
        if (dto.getLandmark() != null) address.setLandmark(dto.getLandmark());
        if (dto.getAddressType() != null) address.setAddressType(dto.getAddressType().toUpperCase());
        else if (dto.getLabel() != null) address.setAddressType(dto.getLabel().toUpperCase());
        address.setPrimary(dto.isPrimary());

        address = addressRepository.save(address);
        return ResponseEntity.ok(ApiResponse.success(address, "Address updated successfully"));
    }

    @DeleteMapping("/addresses/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteAddress(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable UUID id) {
        CustomerAddress address = addressRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Address not found with id: " + id));

        if (!address.getCustomer().getId().equals(principal.getId())) {
            throw new com.bookurtechnician.common.exception.BadRequestException("Unauthorized access to this address.");
        }

        addressRepository.delete(address);
        return ResponseEntity.ok(ApiResponse.success(null, "Address deleted successfully"));
    }

    private void validateCoordinates(Double latitude, Double longitude) {
        if (latitude != null) {
            if (latitude.isNaN() || latitude.isInfinite() || latitude < -90.0 || latitude > 90.0) {
                throw new com.bookurtechnician.common.exception.BadRequestException("Invalid latitude: must be between -90.0 and +90.0");
            }
        }
        if (longitude != null) {
            if (longitude.isNaN() || longitude.isInfinite() || longitude < -180.0 || longitude > 180.0) {
                throw new com.bookurtechnician.common.exception.BadRequestException("Invalid longitude: must be between -180.0 and +180.0");
            }
        }
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class UpdateProfileDto {
        private String fullName;
        private String gender;
        private java.time.LocalDate dateOfBirth;
        private java.time.LocalDate anniversaryDate;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class CreateAddressDto {
        private String houseFlat;
        private String street;
        private String area;
        private String city;
        private String state;
        private String postalCode;
        private String addressType;
        private String label;
        private String addressLine1;
        private String addressLine2;
        private String locality;
        private String landmark;
        private Double latitude;
        private Double longitude;
        private boolean primary;
    }
}
