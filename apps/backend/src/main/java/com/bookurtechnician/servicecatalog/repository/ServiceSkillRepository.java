package com.bookurtechnician.servicecatalog.repository;

import com.bookurtechnician.servicecatalog.entity.ServiceSkill;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ServiceSkillRepository extends JpaRepository<ServiceSkill, UUID> {
    List<ServiceSkill> findByActiveTrueOrderByDisplayOrderAscNameAsc();
    List<ServiceSkill> findByCategoryIdAndActiveTrueOrderByDisplayOrderAscNameAsc(UUID categoryId);
    List<ServiceSkill> findByServiceItemIdAndActiveTrueOrderByDisplayOrderAscNameAsc(UUID serviceItemId);
    Optional<ServiceSkill> findBySlug(String slug);
    boolean existsBySlug(String slug);
}
