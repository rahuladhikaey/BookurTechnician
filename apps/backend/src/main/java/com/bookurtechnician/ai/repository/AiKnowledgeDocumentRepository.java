package com.bookurtechnician.ai.repository;

import com.bookurtechnician.ai.entity.AiKnowledgeDocument;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface AiKnowledgeDocumentRepository extends JpaRepository<AiKnowledgeDocument, UUID> {
    List<AiKnowledgeDocument> findByIsActiveTrue();
    List<AiKnowledgeDocument> findByCategory(String category);
}
