package com.bookurtechnician.repository;

import com.bookurtechnician.model.TechnicianProfile;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

@Repository
public interface TechnicianProfileRepository extends JpaRepository<TechnicianProfile, String> {

    Optional<TechnicianProfile> findByTechnicianId(String technicianId);

    @Query(value = """
        SELECT 
            s.id AS serviceId,
            s.name AS serviceName,
            COUNT(DISTINCT tp.technician_id) AS technicianCount
        FROM services s
        LEFT JOIN technician_services ts ON ts.service_id = s.id AND ts.active = true
        LEFT JOIN technician_profiles tp ON tp.technician_id = ts.technician_id
            AND tp.is_online = true
            AND (tp.availability_status = 'AVAILABLE' OR tp.availability_status IS NULL)
            AND tp.kyc_status = 'VERIFIED'
            AND tp.last_location_update >= (NOW() - (:staleSeconds * INTERVAL '1 second'))
            AND ST_DWithin(
                tp.location, 
                ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography, 
                :radiusMeters
            )
            AND NOT EXISTS (
                SELECT 1 FROM bookings b 
                WHERE b.technician_id = tp.technician_id 
                  AND b.status IN ('ACCEPTED', 'DISPATCHED', 'TECHNICIAN_ARRIVED', 'IN_PROGRESS')
            )
        WHERE s.is_active = true
        GROUP BY s.id, s.name
        ORDER BY s.name ASC
        """, nativeQuery = true)
    List<ServiceCountProjection> findServiceAvailabilityWithinRadius(
            @Param("lat") double lat,
            @Param("lon") double lon,
            @Param("radiusMeters") double radiusMeters,
            @Param("staleSeconds") int staleSeconds
    );

    @Query(value = """
        SELECT tp.*
        FROM technician_profiles tp
        JOIN technician_services ts ON ts.technician_id = tp.technician_id AND ts.active = true
        WHERE ts.service_id = :serviceId
          AND tp.is_online = true
          AND (tp.availability_status = 'AVAILABLE' OR tp.availability_status IS NULL)
          AND tp.kyc_status = 'VERIFIED'
          AND tp.last_location_update >= (NOW() - (:staleSeconds * INTERVAL '1 second'))
          AND ST_DWithin(
              tp.location, 
              ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography, 
              :radiusMeters
          )
          AND NOT EXISTS (
              SELECT 1 FROM bookings b 
              WHERE b.technician_id = tp.technician_id 
                AND b.status IN ('ACCEPTED', 'DISPATCHED', 'TECHNICIAN_ARRIVED', 'IN_PROGRESS')
          )
        ORDER BY ST_Distance(
            tp.location, 
            ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography
        ) ASC
        """, nativeQuery = true)
    List<TechnicianProfile> findEligibleTechniciansForService(
            @Param("serviceId") String serviceId,
            @Param("lat") double lat,
            @Param("lon") double lon,
            @Param("radiusMeters") double radiusMeters,
            @Param("staleSeconds") int staleSeconds
    );

    long countByIsOnlineTrue();

    long countByIsOnlineTrueAndAvailabilityStatus(String availabilityStatus);

    @Query("SELECT COUNT(tp) FROM TechnicianProfile tp WHERE tp.isOnline = true AND (tp.lastLocationUpdate IS NULL OR tp.lastLocationUpdate < :cutoff)")
    long countStaleTechnicians(@Param("cutoff") OffsetDateTime cutoff);
}
