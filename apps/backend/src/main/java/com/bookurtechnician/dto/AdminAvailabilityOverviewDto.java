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
public class AdminAvailabilityOverviewDto {
    private long totalOnlineTechnicians;
    private long totalAvailableTechnicians;
    private long totalBusyTechnicians;
    private long staleLocationTechnicians;
    private double radiusKm;
    private OffsetDateTime updatedAt;
    private List<ServiceAvailabilityDto> serviceAvailability;
}
