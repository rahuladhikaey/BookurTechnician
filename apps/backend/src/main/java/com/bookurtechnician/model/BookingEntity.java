package com.bookurtechnician.model;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Entity
@Table(name = "bookings")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class BookingEntity {

    @Id
    @Column(length = 64)
    private String id;

    @Column(name = "booking_code", length = 30, unique = true, nullable = false)
    private String bookingCode;

    @Column(name = "customer_id", length = 64, nullable = false)
    private String customerId;

    @Column(name = "technician_id", length = 64)
    private String technicianId;

    @Column(name = "service_id", length = 64)
    private String serviceId;

    @Column(name = "service_name", length = 150)
    private String serviceName;

    @Column(length = 50)
    private String category;

    @Column(length = 50, nullable = false)
    private String status; // PENDING, DISPATCHED, ACCEPTED, TECHNICIAN_ARRIVED, IN_PROGRESS, COMPLETED, CANCELLED

    @Column(name = "full_address", columnDefinition = "TEXT")
    private String fullAddress;

    private Double latitude;

    private Double longitude;

    @Column(name = "total_amount", precision = 10, scale = 2)
    private BigDecimal totalAmount;

    @Column(name = "start_otp", length = 6)
    private String startOtp;

    @Column(name = "end_otp", length = 6)
    private String endOtp;

    @Column(name = "created_at")
    private OffsetDateTime createdAt;

    @Column(name = "updated_at")
    private OffsetDateTime updatedAt;
}
