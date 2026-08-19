package com.bookurtechnician.technician.repository;

import com.bookurtechnician.technician.entity.TechnicianSkill;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface TechnicianSkillRepository extends JpaRepository<TechnicianSkill, UUID> {

    List<TechnicianSkill> findByTechnicianIdOrderByCreatedAtAsc(UUID technicianId);

    List<TechnicianSkill> findByTechnicianIdAndEnabledTrue(UUID technicianId);

    Optional<TechnicianSkill> findByTechnicianIdAndSkillId(UUID technicianId, UUID skillId);

    boolean existsByTechnicianIdAndSkillId(UUID technicianId, UUID skillId);

    @Query("SELECT ts FROM TechnicianSkill ts " +
           "WHERE ts.technician.id = :technicianId " +
           "AND ts.verificationStatus = 'VERIFIED' " +
           "AND ts.enabled = true")
    List<TechnicianSkill> findVerifiedAndEnabledSkillsByTechnicianId(@Param("technicianId") UUID technicianId);

    @Query("SELECT COUNT(ts) > 0 FROM TechnicianSkill ts " +
           "WHERE ts.technician.id = :technicianId " +
           "AND (ts.skill.id = :skillId OR ts.skill.category.id = :categoryId) " +
           "AND ts.verificationStatus = 'VERIFIED' " +
           "AND ts.enabled = true")
    boolean hasVerifiedSkillForCategoryOrSkill(
            @Param("technicianId") UUID technicianId,
            @Param("skillId") UUID skillId,
            @Param("categoryId") UUID categoryId);
}
