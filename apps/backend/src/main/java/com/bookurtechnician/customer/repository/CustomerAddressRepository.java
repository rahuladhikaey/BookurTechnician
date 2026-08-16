package com.bookurtechnician.customer.repository;

import com.bookurtechnician.customer.entity.CustomerAddress;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface CustomerAddressRepository extends JpaRepository<CustomerAddress, UUID> {
    List<CustomerAddress> findByCustomerId(UUID customerId);
    List<CustomerAddress> findByCustomerIdOrderByCreatedAtDesc(UUID customerId);
    Optional<CustomerAddress> findByCustomerIdAndPrimaryTrue(UUID customerId);
    long countByCustomerId(UUID customerId);
}
