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
            AND (tp.kyc_status != 'REJECTED' OR tp.kyc_status IS NULL)
            AND (tp.last_location_update IS NULL OR tp.last_location_update >= (NOW() - (:staleSeconds * INTERVAL '1 second')))
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
          AND (tp.kyc_status != 'REJECTED' OR tp.kyc_status IS NULL)
          AND (tp.last_location_update IS NULL OR tp.last_location_update >= (NOW() - (:staleSeconds * INTERVAL '1 second')))
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

    @Query(value = """
        SELECT 
            tp.technician_id AS technicianId,
            tp.technician_code AS technicianCode,
            tp.full_name AS fullName,
            tp.phone AS phone,
            tp.category AS category,
            tp.experience_years AS experienceYears,
            tp.rating AS rating,
            tp.total_ratings_count AS totalRatingsCount,
            tp.total_jobs_completed AS totalJobsCompleted,
            tp.current_latitude AS currentLatitude,
            tp.current_longitude AS currentLongitude,
            tp.is_online AS isOnline,
            tp.availability_status AS availabilityStatus,
            COALESCE(u.profile_image_url, '') AS profileImageUrl,
            ST_Distance(
                tp.location, 
                ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography
            ) AS distanceMeters
        FROM technician_profiles tp
        LEFT JOIN users u ON u.id = tp.technician_id
        JOIN technician_services ts ON ts.technician_id = tp.technician_id AND ts.active = true
        WHERE ts.service_id = :serviceId
          AND tp.is_online = true
          AND (tp.availability_status = 'AVAILABLE' OR tp.availability_status IS NULL)
          AND (tp.kyc_status != 'REJECTED' OR tp.kyc_status IS NULL)
          AND (tp.last_location_update IS NULL OR tp.last_location_update >= (NOW() - (:staleSeconds * INTERVAL '1 second')))
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
        ORDER BY distanceMeters ASC
        """, nativeQuery = true)
    List<NearbyTechnicianProjection> findNearbyTechniciansByService(
            @Param("serviceId") String serviceId,
            @Param("lat") double lat,
            @Param("lon") double lon,
            @Param("radiusMeters") double radiusMeters,
            @Param("staleSeconds") int staleSeconds
    );

    @Query(value = """
        SELECT DISTINCT
            tp.technician_id AS technicianId,
            tp.technician_code AS technicianCode,
            tp.full_name AS fullName,
            tp.phone AS phone,
            tp.category AS category,
            tp.experience_years AS experienceYears,
            tp.rating AS rating,
            tp.total_ratings_count AS totalRatingsCount,
            tp.total_jobs_completed AS totalJobsCompleted,
            tp.current_latitude AS currentLatitude,
            tp.current_longitude AS currentLongitude,
            tp.is_online AS isOnline,
            tp.availability_status AS availabilityStatus,
            COALESCE(u.profile_image_url, '') AS profileImageUrl,
            ST_Distance(
                tp.location, 
                ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography
            ) AS distanceMeters
        FROM technician_profiles tp
        LEFT JOIN users u ON u.id = tp.technician_id
        JOIN technician_services ts ON ts.technician_id = tp.technician_id AND ts.active = true
        JOIN services s ON s.id = ts.service_id AND s.is_active = true
        WHERE s.category_id = :categoryId
          AND tp.is_online = true
          AND (tp.availability_status = 'AVAILABLE' OR tp.availability_status IS NULL)
          AND (tp.kyc_status != 'REJECTED' OR tp.kyc_status IS NULL)
          AND (tp.last_location_update IS NULL OR tp.last_location_update >= (NOW() - (:staleSeconds * INTERVAL '1 second')))
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
        ORDER BY distanceMeters ASC
        """, nativeQuery = true)
    List<NearbyTechnicianProjection> findNearbyTechniciansByCategory(
            @Param("categoryId") String categoryId,
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
