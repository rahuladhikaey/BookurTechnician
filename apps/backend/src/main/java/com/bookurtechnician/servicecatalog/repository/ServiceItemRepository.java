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

    @org.springframework.data.jpa.repository.Query("SELECT s FROM ServiceItem s WHERE s.active = true ORDER BY s.price ASC")
    List<ServiceItem> findByActiveTrueOrderByPriceAsc();

    @org.springframework.data.jpa.repository.Query("SELECT s FROM ServiceItem s WHERE s.active = true")
    List<ServiceItem> findByActiveTrue();

    Optional<ServiceItem> findBySlug(String slug);
    boolean existsBySlug(String slug);
}
