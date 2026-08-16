package com.bookurtechnician.ai.repository;

import com.bookurtechnician.ai.entity.AiFaq;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface AiFaqRepository extends JpaRepository<AiFaq, UUID> {
    List<AiFaq> findByIsActiveTrue();
    List<AiFaq> findByCategory(String category);
}
