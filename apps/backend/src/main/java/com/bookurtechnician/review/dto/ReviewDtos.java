package com.bookurtechnician.review.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

import java.time.Instant;
import java.util.UUID;

public class ReviewDtos {

    public static class CreateReviewRequest {
        @NotNull(message = "Booking ID is required")
        private UUID bookingId;

        @NotNull(message = "Rating is required")
        @Min(value = 1, message = "Rating must be at least 1 star")
        @Max(value = 5, message = "Rating cannot exceed 5 stars")
        private Integer rating;

        private String reviewText;

        public CreateReviewRequest() {}

        public UUID getBookingId() { return bookingId; }
        public void setBookingId(UUID bookingId) { this.bookingId = bookingId; }
        public Integer getRating() { return rating; }
        public void setRating(Integer rating) { this.rating = rating; }
        public String getReviewText() { return reviewText; }
        public void setReviewText(String reviewText) { this.reviewText = reviewText; }
    }

    public static class ReviewResponse {
        private UUID id;
        private UUID bookingId;
        private String customerName;
        private String customer;
        private String technicianName;
        private String technician;
        private String technicianCode;
        private String techId;
        private String serviceName;
        private String service;
        private Integer rating;
        private String reviewText;
        private String comment;
        private boolean hidden;
        private boolean flagged;
        private Instant createdAt;
        private String date;

        public ReviewResponse() {}

        public static Builder builder() { return new Builder(); }

        public static class Builder {
            private UUID id;
            private UUID bookingId;
            private String customerName;
            private String customer;
            private String technicianName;
            private String technician;
            private String technicianCode;
            private String techId;
            private String serviceName;
            private String service;
            private Integer rating;
            private String reviewText;
            private String comment;
            private boolean hidden;
            private boolean flagged;
            private Instant createdAt;
            private String date;

            public Builder id(UUID id) { this.id = id; return this; }
            public Builder bookingId(UUID bookingId) { this.bookingId = bookingId; return this; }
            public Builder customerName(String customerName) { this.customerName = customerName; return this; }
            public Builder customer(String customer) { this.customer = customer; return this; }
            public Builder technicianName(String technicianName) { this.technicianName = technicianName; return this; }
            public Builder technician(String technician) { this.technician = technician; return this; }
            public Builder technicianCode(String technicianCode) { this.technicianCode = technicianCode; return this; }
            public Builder techId(String techId) { this.techId = techId; return this; }
            public Builder serviceName(String serviceName) { this.serviceName = serviceName; return this; }
            public Builder service(String service) { this.service = service; return this; }
            public Builder rating(Integer rating) { this.rating = rating; return this; }
            public Builder reviewText(String reviewText) { this.reviewText = reviewText; return this; }
            public Builder comment(String comment) { this.comment = comment; return this; }
            public Builder hidden(boolean hidden) { this.hidden = hidden; return this; }
            public Builder flagged(boolean flagged) { this.flagged = flagged; return this; }
            public Builder createdAt(Instant createdAt) { this.createdAt = createdAt; return this; }
            public Builder date(String date) { this.date = date; return this; }

            public ReviewResponse build() {
                ReviewResponse r = new ReviewResponse();
                r.id = this.id;
                r.bookingId = this.bookingId;
                r.customerName = this.customerName;
                r.customer = this.customer;
                r.technicianName = this.technicianName;
                r.technician = this.technician;
                r.technicianCode = this.technicianCode;
                r.techId = this.techId;
                r.serviceName = this.serviceName;
                r.service = this.service;
                r.rating = this.rating;
                r.reviewText = this.reviewText;
                r.comment = this.comment;
                r.hidden = this.hidden;
                r.flagged = this.flagged;
                r.createdAt = this.createdAt;
                r.date = this.date;
                return r;
            }
        }

        public UUID getId() { return id; }
        public void setId(UUID id) { this.id = id; }
        public UUID getBookingId() { return bookingId; }
        public void setBookingId(UUID bookingId) { this.bookingId = bookingId; }
        public String getCustomerName() { return customerName; }
        public void setCustomerName(String customerName) { this.customerName = customerName; }
        public String getCustomer() { return customer; }
        public void setCustomer(String customer) { this.customer = customer; }
        public String getTechnicianName() { return technicianName; }
        public void setTechnicianName(String technicianName) { this.technicianName = technicianName; }
        public String getTechnician() { return technician; }
        public void setTechnician(String technician) { this.technician = technician; }
        public String getTechnicianCode() { return technicianCode; }
        public void setTechnicianCode(String technicianCode) { this.technicianCode = technicianCode; }
        public String getTechId() { return techId; }
        public void setTechId(String techId) { this.techId = techId; }
        public String getServiceName() { return serviceName; }
        public void setServiceName(String serviceName) { this.serviceName = serviceName; }
        public String getService() { return service; }
        public void setService(String service) { this.service = service; }
        public Integer getRating() { return rating; }
        public void setRating(Integer rating) { this.rating = rating; }
        public String getReviewText() { return reviewText; }
        public void setReviewText(String reviewText) { this.reviewText = reviewText; }
        public String getComment() { return comment; }
        public void setComment(String comment) { this.comment = comment; }
        public boolean isHidden() { return hidden; }
        public void setHidden(boolean hidden) { this.hidden = hidden; }
        public boolean isFlagged() { return flagged; }
        public void setFlagged(boolean flagged) { this.flagged = flagged; }
        public Instant getCreatedAt() { return createdAt; }
        public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
        public String getDate() { return date; }
        public void setDate(String date) { this.date = date; }
    }
}
