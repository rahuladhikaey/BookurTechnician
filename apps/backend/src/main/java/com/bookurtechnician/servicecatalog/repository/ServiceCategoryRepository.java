package com.bookurtechnician.servicecatalog.repository;

import com.bookurtechnician.servicecatalog.entity.ServiceCategory;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ServiceCategoryRepository extends JpaRepository<ServiceCategory, UUID> {
    List<ServiceCategory> findByActiveTrueOrderByDisplayOrderAsc();
    Optional<ServiceCategory> findBySlug(String slug);
    boolean existsBySlug(String slug);
}
