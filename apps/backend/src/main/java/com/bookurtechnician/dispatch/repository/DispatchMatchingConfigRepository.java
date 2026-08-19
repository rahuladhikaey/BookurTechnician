package com.bookurtechnician.dispatch.repository;

import com.bookurtechnician.dispatch.entity.DispatchMatchingConfig;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface DispatchMatchingConfigRepository extends JpaRepository<DispatchMatchingConfig, UUID> {
    Optional<DispatchMatchingConfig> findFirstByOrderByCreatedAtAsc();
}
