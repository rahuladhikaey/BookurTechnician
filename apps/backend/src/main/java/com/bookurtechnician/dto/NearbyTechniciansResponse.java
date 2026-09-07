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
public class NearbyTechniciansResponse {

    private String serviceId;
    private String serviceName;
    private String categoryId;
    private Double latitude;
    private Double longitude;
    private Double radiusKm;
    private Integer totalOnlineTechnicians;
    private OffsetDateTime updatedAt;
    private List<NearbyTechnicianDto> technicians;
}
