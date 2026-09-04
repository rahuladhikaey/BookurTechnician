package com.bookurtechnician.dto;

import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class OnlineStatusRequest {

    @NotNull(message = "isOnline status is required")
    private Boolean isOnline;

    private String availabilityStatus; // Optional override: AVAILABLE, BUSY
}
