package com.bookurtechnician.servicecatalog.repository;

import com.bookurtechnician.servicecatalog.entity.SkillServiceCompatibility;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface SkillServiceCompatibilityRepository extends JpaRepository<SkillServiceCompatibility, UUID> {
    List<SkillServiceCompatibility> findBySkillId(UUID skillId);
    List<SkillServiceCompatibility> findByServiceItemId(UUID serviceItemId);
    void deleteBySkillId(UUID skillId);
    boolean existsBySkillIdAndServiceItemId(UUID skillId, UUID serviceItemId);
}
