package com.bookurtechnician.repository;

import com.bookurtechnician.model.TechnicianServiceEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface TechnicianServiceRepository extends JpaRepository<TechnicianServiceEntity, String> {

    List<TechnicianServiceEntity> findByTechnicianId(String technicianId);

    List<TechnicianServiceEntity> findByTechnicianIdAndActiveTrue(String technicianId);

    Optional<TechnicianServiceEntity> findByTechnicianIdAndServiceId(String technicianId, String serviceId);

    @Modifying
    @Query("DELETE FROM TechnicianServiceEntity ts WHERE ts.technicianId = :technicianId")
    void deleteByTechnicianId(@Param("technicianId") String technicianId);

    @Modifying
    @Query("UPDATE TechnicianServiceEntity ts SET ts.active = :active WHERE ts.id = :id")
    void updateActiveStatus(@Param("id") String id, @Param("active") Boolean active);
}
