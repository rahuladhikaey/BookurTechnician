package com.bookurtechnician.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ServiceAvailabilityDto {
    private String serviceId;
    private String serviceName;
    private long availableTechnicianCount;
}
