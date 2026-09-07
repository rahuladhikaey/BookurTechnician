package com.bookurtechnician.dto;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonIgnoreProperties(ignoreUnknown = true)
public class TechnicianSkillsResponse {
    private String technicianId;
    private String technicianCode;
    private String fullName;
    private Double rating;
    private Integer totalRatingsCount;
    private Integer totalJobsCompleted;
    private List<TechnicianSkillDto> skills;
    private Integer totalSkillsCount;
    private Integer verifiedSkillsCount;
    private Integer pendingSkillsCount;
}
