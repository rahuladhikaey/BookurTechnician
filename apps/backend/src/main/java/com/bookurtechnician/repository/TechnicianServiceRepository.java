package com.bookurtechnician.repository;

import com.bookurtechnician.model.TechnicianServiceEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface TechnicianServiceRepository extends JpaRepository<TechnicianServiceEntity, String> {
    List<TechnicianServiceEntity> findByTechnicianIdAndActiveTrue(String technicianId);
    List<TechnicianServiceEntity> findByServiceIdAndActiveTrue(String serviceId);
}
