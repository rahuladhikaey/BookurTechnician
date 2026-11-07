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
public class TechnicianSkillDto {
    private String id;
    private String skillId;
    private String skillName;
    private String categoryId;
    private String categoryName;
    private Integer experienceYears;
    private String verificationStatus;
    private Boolean enabled;
}
