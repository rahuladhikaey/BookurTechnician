package com.bookurtechnician.technician.repository;

import com.bookurtechnician.technician.entity.TechnicianDocument;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface TechnicianDocumentRepository extends JpaRepository<TechnicianDocument, UUID> {
    List<TechnicianDocument> findByTechnicianId(UUID technicianId);
}
