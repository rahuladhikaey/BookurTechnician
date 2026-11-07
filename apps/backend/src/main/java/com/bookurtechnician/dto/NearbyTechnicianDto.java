package com.bookurtechnician.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class NearbyTechnicianDto {

    private String technicianId;
    private String technicianCode;
    private String fullName;
    private String phone;
    private String category;
    private String profileImageUrl;
    private Integer experienceYears;
    private Double rating;
    private Integer totalRatingsCount;
    private Integer totalJobsCompleted;
    private Double currentLatitude;
    private Double currentLongitude;
    private Double distanceKm;
    private Double distanceMeters;
    private Integer estimatedArrivalMinutes;
    private Boolean isOnline;
    private String availabilityStatus;
}
