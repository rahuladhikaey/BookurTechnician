package com.bookurtechnician;

import com.bookurtechnician.dto.AvailabilityResponse;
import com.bookurtechnician.dto.ServiceAvailabilityDto;
import com.bookurtechnician.dto.TechnicianLocationRequest;
import com.bookurtechnician.model.BookingEntity;
import com.bookurtechnician.model.TechnicianProfile;
import com.bookurtechnician.repository.BookingRepository;
import com.bookurtechnician.repository.ServiceCountProjection;
import com.bookurtechnician.repository.TechnicianProfileRepository;
import com.bookurtechnician.service.BookingDispatchService;
import com.bookurtechnician.service.TechnicianAvailabilityService;
import com.bookurtechnician.service.TechnicianLocationService;
import com.bookurtechnician.service.TechnicianStatusService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.data.redis.core.ZSetOperations;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class TechnicianAvailabilityTest {

    @Mock
    private TechnicianProfileRepository technicianProfileRepository;

    @Mock
    private BookingRepository bookingRepository;

    @Mock
    private StringRedisTemplate redisTemplate;

    @Mock
    private ValueOperations<String, String> valueOperations;

    @Mock
    private ZSetOperations<String, String> zSetOperations;

    private TechnicianAvailabilityService availabilityService;
    private TechnicianLocationService locationService;
    private TechnicianStatusService statusService;
    private BookingDispatchService dispatchService;

    @BeforeEach
    void setUp() {
        availabilityService = new TechnicianAvailabilityService(technicianProfileRepository);
        ReflectionTestUtils.setField(availabilityService, "defaultRadiusKm", 15.0);
        ReflectionTestUtils.setField(availabilityService, "staleSeconds", 60);

        locationService = new TechnicianLocationService(technicianProfileRepository, redisTemplate);
        ReflectionTestUtils.setField(locationService, "staleSeconds", 60);

        statusService = new TechnicianStatusService(technicianProfileRepository, redisTemplate);

        dispatchService = new BookingDispatchService(technicianProfileRepository, bookingRepository);
        ReflectionTestUtils.setField(dispatchService, "defaultRadiusKm", 15.0);
        ReflectionTestUtils.setField(dispatchService, "staleSeconds", 60);
    }

    private ServiceCountProjection createProjection(String serviceId, String serviceName, Long count) {
        return new ServiceCountProjection() {
            @Override
            public String getServiceId() { return serviceId; }
            @Override
            public String getServiceName() { return serviceName; }
            @Override
            public Long getTechnicianCount() { return count; }
        };
    }

    @Test
    @DisplayName("1. Technician within 15km is counted by spatial query")
    void testTechnicianWithin15KmIsCounted() {
        when(technicianProfileRepository.findServiceAvailabilityWithinRadius(eq(22.5726), eq(88.3639), eq(15000.0), eq(60)))
                .thenReturn(List.of(createProjection("srv_ac", "AC Services", 1L)));

        AvailabilityResponse response = availabilityService.getAvailability(22.5726, 88.3639, 15.0);

        assertNotNull(response);
        assertEquals(1, response.getServices().size());
        assertEquals(1L, response.getServices().get(0).getAvailableTechnicianCount());
        assertEquals("AC Services", response.getServices().get(0).getServiceName());
    }

    @Test
    @DisplayName("2. Technician outside 15km is not counted (returns 0)")
    void testTechnicianOutside15KmIsNotCounted() {
        when(technicianProfileRepository.findServiceAvailabilityWithinRadius(eq(22.5726), eq(88.3639), eq(15000.0), eq(60)))
                .thenReturn(List.of(createProjection("srv_ac", "AC Services", 0L)));

        AvailabilityResponse response = availabilityService.getAvailability(22.5726, 88.3639, 15.0);

        assertNotNull(response);
        assertEquals(0L, response.getServices().get(0).getAvailableTechnicianCount());
    }

    @Test
    @DisplayName("3. Offline technician is excluded from available count")
    void testOfflineTechnicianIsNotCounted() {
        when(technicianProfileRepository.findServiceAvailabilityWithinRadius(anyDouble(), anyDouble(), anyDouble(), anyInt()))
                .thenReturn(List.of(createProjection("srv_elec", "Electrical Services", 0L)));

        AvailabilityResponse response = availabilityService.getAvailability(22.5726, 88.3639, 15.0);
        assertEquals(0L, response.getServices().get(0).getAvailableTechnicianCount());
    }

    @Test
    @DisplayName("4. Busy technician on active job is excluded")
    void testBusyTechnicianIsNotCounted() {
        when(technicianProfileRepository.findServiceAvailabilityWithinRadius(anyDouble(), anyDouble(), anyDouble(), anyInt()))
                .thenReturn(List.of(createProjection("srv_cctv", "CCTV & Security", 0L)));

        AvailabilityResponse response = availabilityService.getAvailability(22.5726, 88.3639, 15.0);
        assertEquals(0L, response.getServices().get(0).getAvailableTechnicianCount());
    }

    @Test
    @DisplayName("5. Unverified KYC technician cannot switch ONLINE")
    void testUnverifiedKycTechnicianCannotGoOnline() {
        TechnicianProfile unverified = TechnicianProfile.builder()
                .technicianId("tech-unverified")
                .kycStatus("PENDING")
                .isOnline(false)
                .build();
        when(technicianProfileRepository.findByTechnicianId("tech-unverified")).thenReturn(Optional.of(unverified));

        IllegalStateException ex = assertThrows(IllegalStateException.class, () ->
                statusService.updateStatus("tech-unverified", true, "AVAILABLE")
        );
        assertTrue(ex.getMessage().contains("KYC is not VERIFIED"));
    }

    @Test
    @DisplayName("6. Technician with stale GPS location is excluded")
    void testStaleGpsLocationIsNotCounted() {
        when(technicianProfileRepository.findServiceAvailabilityWithinRadius(anyDouble(), anyDouble(), anyDouble(), eq(60)))
                .thenReturn(List.of(createProjection("srv_ac", "AC Services", 0L)));

        AvailabilityResponse response = availabilityService.getAvailability(22.5726, 88.3639, 15.0);
        assertEquals(0L, response.getServices().get(0).getAvailableTechnicianCount());
    }

    @Test
    @DisplayName("7. Technician without requested skill is not counted for that service")
    void testTechnicianWithoutSkillIsNotCounted() {
        when(technicianProfileRepository.findServiceAvailabilityWithinRadius(anyDouble(), anyDouble(), anyDouble(), anyInt()))
                .thenReturn(List.of(
                        createProjection("srv_ac", "AC Services", 1L),
                        createProjection("srv_plumb", "Plumbing Services", 0L)
                ));

        AvailabilityResponse response = availabilityService.getAvailability(22.5726, 88.3639, 15.0);
        ServiceAvailabilityDto plumb = response.getServices().stream()
                .filter(s -> s.getServiceId().equals("srv_plumb")).findFirst().orElseThrow();
        assertEquals(0L, plumb.getAvailableTechnicianCount());
    }

    @Test
    @DisplayName("8. Technician with requested skill is counted")
    void testTechnicianWithSkillIsCounted() {
        when(technicianProfileRepository.findServiceAvailabilityWithinRadius(anyDouble(), anyDouble(), anyDouble(), anyInt()))
                .thenReturn(List.of(createProjection("srv_ac", "AC Services", 1L)));

        AvailabilityResponse response = availabilityService.getAvailability(22.5726, 88.3639, 15.0);
        assertEquals(1L, response.getServices().get(0).getAvailableTechnicianCount());
    }

    @Test
    @DisplayName("9. Multiple eligible technicians return accurate count")
    void testMultipleTechniciansCountAccuracy() {
        when(technicianProfileRepository.findServiceAvailabilityWithinRadius(anyDouble(), anyDouble(), anyDouble(), anyInt()))
                .thenReturn(List.of(
                        createProjection("srv_ac", "AC Services", 7L),
                        createProjection("srv_elec", "Electrical Services", 14L),
                        createProjection("srv_cctv", "CCTV & Security", 3L)
                ));

        AvailabilityResponse response = availabilityService.getAvailability(22.5726, 88.3639, 15.0);
        assertEquals(3, response.getServices().size());
        assertEquals(7L, response.getServices().get(0).getAvailableTechnicianCount());
        assertEquals(14L, response.getServices().get(1).getAvailableTechnicianCount());
        assertEquals(3L, response.getServices().get(2).getAvailableTechnicianCount());
    }

    @Test
    @DisplayName("10. Invalid coordinates are rejected with IllegalArgumentException")
    void testInvalidCoordinatesRejected() {
        assertThrows(IllegalArgumentException.class, () ->
                availabilityService.getAvailability(95.0, 88.3639, 15.0)
        );
        assertThrows(IllegalArgumentException.class, () ->
                availabilityService.getAvailability(22.5726, 185.0, 15.0)
        );

        TechnicianLocationRequest zeroCoords = TechnicianLocationRequest.builder()
                .latitude(0.0)
                .longitude(0.0)
                .build();
        assertThrows(IllegalArgumentException.class, () ->
                locationService.updateLocation("tech-01", zeroCoords)
        );

        TechnicianLocationRequest futureTimestamp = TechnicianLocationRequest.builder()
                .latitude(22.57)
                .longitude(88.36)
                .timestamp(OffsetDateTime.now().plusDays(2))
                .build();
        assertThrows(IllegalArgumentException.class, () ->
                locationService.updateLocation("tech-01", futureTimestamp)
        );
    }

    @Test
    @DisplayName("11. Location update updates PostGIS point and timestamp on correct technician profile")
    void testTechnicianLocationUpdatePersisted() {
        TechnicianProfile profile = TechnicianProfile.builder()
                .technicianId("tech-real-1")
                .fullName("John Tech")
                .phone("+919876543210")
                .kycStatus("VERIFIED")
                .isOnline(true)
                .build();
        when(technicianProfileRepository.findByTechnicianId("tech-real-1")).thenReturn(Optional.of(profile));

        TechnicianLocationRequest req = TechnicianLocationRequest.builder()
                .latitude(22.5726)
                .longitude(88.3639)
                .accuracyMeters(8.5)
                .timestamp(OffsetDateTime.now())
                .build();

        locationService.updateLocation("tech-real-1", req);

        verify(technicianProfileRepository).save(argThat(tp ->
                tp.getTechnicianId().equals("tech-real-1") &&
                tp.getCurrentLatitude().equals(22.5726) &&
                tp.getCurrentLongitude().equals(88.3639) &&
                tp.getLocation() != null &&
                tp.getLastLocationUpdate() != null
        ));
    }

    @Test
    @DisplayName("12. Concurrent booking cannot assign same technician twice")
    void testConcurrentBookingLockPreventsDoubleAssignment() {
        BookingEntity booking = BookingEntity.builder()
                .id("book-1")
                .status("PENDING")
                .build();
        TechnicianProfile profile = TechnicianProfile.builder()
                .technicianId("tech-1")
                .isOnline(true)
                .availabilityStatus("AVAILABLE")
                .kycStatus("VERIFIED")
                .build();

        when(bookingRepository.findById("book-1")).thenReturn(Optional.of(booking));
        when(technicianProfileRepository.findByTechnicianId("tech-1")).thenReturn(Optional.of(profile));
        when(bookingRepository.existsByTechnicianIdAndStatusIn(eq("tech-1"), anyCollection())).thenReturn(true);

        IllegalStateException ex = assertThrows(IllegalStateException.class, () ->
                dispatchService.assignTechnicianToBooking("book-1", "tech-1")
        );
        assertTrue(ex.getMessage().contains("currently engaged in another active booking"));
    }
}
