package com.bookurtechnician.technician.repository;

import com.bookurtechnician.auth.entity.User;
import com.bookurtechnician.technician.entity.TechnicianProfile;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface TechnicianProfileRepository extends JpaRepository<TechnicianProfile, UUID> {

    Optional<TechnicianProfile> findByUser(User user);
    Optional<TechnicianProfile> findByUserId(UUID userId);
    Optional<TechnicianProfile> findByTechnicianCode(String technicianCode);

    long countByKycStatus(String kycStatus);
    long countByOnlineTrue();

    // ─── POSTGIS NATIVE 10-KM SPATIAL DISPATCH QUERY ──────────────────────────
    @Query(value = """
        SELECT t.* FROM technician_profiles t
        WHERE t.is_online = true
          AND t.kyc_status = 'VERIFIED'
          AND t.current_location IS NOT NULL
          AND ST_DWithin(
                t.current_location::geography,
                ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography,
                :radiusMeters
          )
        ORDER BY ST_Distance(
                t.current_location::geography,
                ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography
        ) ASC
        LIMIT :limitCount
        """, nativeQuery = true)
    List<TechnicianProfile> findNearbyAvailableTechnicians(
            @Param("lat") double lat,
            @Param("lng") double lng,
            @Param("radiusMeters") double radiusMeters,
            @Param("limitCount") int limitCount
    );

    @Query(value = """
        SELECT ST_Distance(
            t.current_location::geography,
            ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography
        )
        FROM technician_profiles t
        WHERE t.id = :technicianId
        """, nativeQuery = true)
    Double calculateDistanceMeters(
            @Param("technicianId") UUID technicianId,
            @Param("lat") double lat,
            @Param("lng") double lng
    );
}
