package com.bookurtechnician.repository;

import com.bookurtechnician.model.BookingEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;

@Repository
public interface BookingRepository extends JpaRepository<BookingEntity, String> {
    List<BookingEntity> findByTechnicianIdAndStatusIn(String technicianId, Collection<String> statuses);
    boolean existsByTechnicianIdAndStatusIn(String technicianId, Collection<String> statuses);
}
