package com.bookurtechnician;

import com.bookurtechnician.dto.TechnicianSkillDto;
import com.bookurtechnician.dto.TechnicianSkillsResponse;
import com.bookurtechnician.model.ServiceEntity;
import com.bookurtechnician.model.TechnicianProfile;
import com.bookurtechnician.model.TechnicianServiceEntity;
import com.bookurtechnician.repository.ServiceRepository;
import com.bookurtechnician.repository.TechnicianProfileRepository;
import com.bookurtechnician.repository.TechnicianServiceRepository;
import com.bookurtechnician.service.TechnicianSkillService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class TechnicianSkillServiceTest {

    @Mock
    private TechnicianProfileRepository technicianProfileRepository;

    @Mock
    private TechnicianServiceRepository technicianServiceRepository;

    @Mock
    private ServiceRepository serviceRepository;

    private TechnicianSkillService technicianSkillService;

    @BeforeEach
    void setUp() {
        technicianSkillService = new TechnicianSkillService(
                technicianProfileRepository,
                technicianServiceRepository,
                serviceRepository
        );
    }

    @Test
    @DisplayName("1. Saving skills maps services, saves to technician_services, and enables verification")
    void testSaveSkillsMapsServicesAndEnablesVerification() {
        String techId = "tech-test-01";
        TechnicianProfile profile = TechnicianProfile.builder()
                .technicianId(techId)
                .technicianCode("BT-TECH-01")
                .fullName("Rahul Adhikary")
                .kycStatus("PENDING")
                .isOnline(false)
                .build();

        when(technicianProfileRepository.findByTechnicianId(techId)).thenReturn(Optional.of(profile));
        when(serviceRepository.findAll()).thenReturn(List.of(
                ServiceEntity.builder().id("fan_rep").name("Fan repair").categoryId("cat_electrical").basePrice(BigDecimal.valueOf(149)).build(),
                ServiceEntity.builder().id("ac_rep").name("AC repair").categoryId("cat_ac").basePrice(BigDecimal.valueOf(499)).build()
        ));

        List<TechnicianSkillDto> skills = List.of(
                TechnicianSkillDto.builder().skillId("fan_rep").skillName("Fan repair").categoryId("cat_electrical").build(),
                TechnicianSkillDto.builder().skillId("ac_rep").skillName("AC repair").categoryId("cat_ac").build()
        );

        TechnicianSkillsResponse response = technicianSkillService.saveSkills(techId, skills);

        assertNotNull(response);
        assertEquals(2, response.getTotalSkillsCount());
        assertEquals("VERIFIED", profile.getKycStatus());
        verify(technicianServiceRepository).deleteByTechnicianId(techId);
        verify(technicianServiceRepository, times(2)).save(any(TechnicianServiceEntity.class));
        verify(technicianProfileRepository).save(profile);
    }

    @Test
    @DisplayName("2. Retrieve skills returns configured active service mappings")
    void testGetSkillsReturnsConfiguredServices() {
        String techId = "tech-test-02";
        TechnicianProfile profile = TechnicianProfile.builder()
                .technicianId(techId)
                .technicianCode("BT-TECH-02")
                .fullName("Amit Sharma")
                .kycStatus("VERIFIED")
                .build();

        when(technicianProfileRepository.findByTechnicianId(techId)).thenReturn(Optional.of(profile));
        when(technicianServiceRepository.findByTechnicianId(techId)).thenReturn(List.of(
                TechnicianServiceEntity.builder().id("ts_1").technicianId(techId).serviceId("fan_rep").active(true).build()
        ));
        when(serviceRepository.findAll()).thenReturn(List.of(
                ServiceEntity.builder().id("fan_rep").name("Fan repair").categoryId("cat_electrical").basePrice(BigDecimal.valueOf(149)).build()
        ));

        TechnicianSkillsResponse response = technicianSkillService.getSkills(techId);

        assertNotNull(response);
        assertEquals(1, response.getTotalSkillsCount());
        assertEquals("fan_rep", response.getSkills().get(0).getSkillId());
        assertEquals("Fan repair", response.getSkills().get(0).getSkillName());
    }

    @Test
    @DisplayName("3. Toggle skill flips active state")
    void testToggleSkillFlipsActiveState() {
        TechnicianServiceEntity entity = TechnicianServiceEntity.builder()
                .id("ts_toggle")
                .technicianId("tech-03")
                .serviceId("fan_rep")
                .active(true)
                .build();

        when(technicianServiceRepository.findById("ts_toggle")).thenReturn(Optional.of(entity));

        boolean toggled = technicianSkillService.toggleSkill("tech-03", "ts_toggle");

        assertTrue(toggled);
        assertFalse(entity.getActive());
        verify(technicianServiceRepository).save(entity);
    }
}
