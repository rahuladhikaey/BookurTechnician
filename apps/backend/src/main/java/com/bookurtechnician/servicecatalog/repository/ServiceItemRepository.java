package com.bookurtechnician.servicecatalog.repository;

import com.bookurtechnician.servicecatalog.entity.ServiceItem;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ServiceItemRepository extends JpaRepository<ServiceItem, UUID> {
    List<ServiceItem> findByCategoryIdAndActiveTrue(UUID categoryId);
    List<ServiceItem> findByPopularTrueAndActiveTrue();
    Optional<ServiceItem> findBySlug(String slug);
}
