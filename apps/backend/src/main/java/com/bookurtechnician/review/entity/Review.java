package com.bookurtechnician.review.entity;

import com.bookurtechnician.auth.entity.User;
import com.bookurtechnician.booking.entity.Booking;
import com.bookurtechnician.technician.entity.TechnicianProfile;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "reviews")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Review {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "booking_id", nullable = false, unique = true)
    private Booking booking;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "customer_id", nullable = false)
    private User customer;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "technician_id", nullable = false)
    private TechnicianProfile technician;

    @Column(nullable = false)
    private Integer rating; // 1 to 5

    @Column(name = "review_text", columnDefinition = "TEXT")
    private String reviewText;

    @Builder.Default
    @Column(name = "is_hidden")
    private boolean hidden = false;

    @Builder.Default
    @Column(name = "is_flagged")
    private boolean flagged = false;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private Instant createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private Instant updatedAt;
}
