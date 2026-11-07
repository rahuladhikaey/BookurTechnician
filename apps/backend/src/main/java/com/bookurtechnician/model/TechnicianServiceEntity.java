package com.bookurtechnician.model;

import jakarta.persistence.*;
import lombok.*;

import java.time.OffsetDateTime;

@Entity
@Table(name = "technician_services")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TechnicianServiceEntity {

    @Id
    @Column(length = 64)
    private String id;

    @Column(name = "technician_id", length = 64, nullable = false)
    private String technicianId;

    @Column(name = "service_id", length = 64, nullable = false)
    private String serviceId;

    @Column(name = "active")
    private Boolean active;

    @Column(name = "created_at")
    private OffsetDateTime createdAt;
}
