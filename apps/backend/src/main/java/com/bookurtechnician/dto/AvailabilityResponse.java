package com.bookurtechnician.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.OffsetDateTime;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AvailabilityResponse {
    private Double latitude;
    private Double longitude;
    private Double radiusKm;
    private OffsetDateTime updatedAt;
    private List<ServiceAvailabilityDto> services;
}
