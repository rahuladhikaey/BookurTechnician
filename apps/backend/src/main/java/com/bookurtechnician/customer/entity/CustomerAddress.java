package com.bookurtechnician.customer.entity;

import com.bookurtechnician.auth.entity.User;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;
import org.locationtech.jts.geom.Point;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "customer_addresses")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class CustomerAddress {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "customer_id", nullable = false)
    private User customer;

    @Column(name = "address_type", nullable = false, length = 20)
    private String addressType; // HOME, WORK, OTHER

    @Column(name = "house_flat", nullable = false, length = 100)
    private String houseFlat;

    @Column(nullable = false)
    private String street;

    @Column(nullable = false)
    private String area;

    @Column(nullable = false, length = 100)
    private String city;

    @Column(nullable = false, length = 100)
    private String state;

    @Column(name = "postal_code", nullable = false, length = 10)
    private String postalCode;

    private String landmark;

    @Column(columnDefinition = "geometry(Point, 4326)")
    private Point coordinates;

    @Column(name = "is_primary")
    private boolean primary = false;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private Instant createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private Instant updatedAt;

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public User getCustomer() { return customer; }
    public void setCustomer(User customer) { this.customer = customer; }

    public String getAddressType() { return addressType; }
    public void setAddressType(String addressType) { this.addressType = addressType; }

    public String getHouseFlat() { return houseFlat; }
    public void setHouseFlat(String houseFlat) { this.houseFlat = houseFlat; }

    public String getStreet() { return street; }
    public void setStreet(String street) { this.street = street; }

    public String getArea() { return area; }
    public void setArea(String area) { this.area = area; }

    public String getCity() { return city; }
    public void setCity(String city) { this.city = city; }

    public String getState() { return state; }
    public void setState(String state) { this.state = state; }

    public String getPostalCode() { return postalCode; }
    public void setPostalCode(String postalCode) { this.postalCode = postalCode; }

    public String getLandmark() { return landmark; }
    public void setLandmark(String landmark) { this.landmark = landmark; }

    public Point getCoordinates() { return coordinates; }
    public void setCoordinates(Point coordinates) { this.coordinates = coordinates; }

    public boolean isPrimary() { return primary; }
    public void setPrimary(boolean primary) { this.primary = primary; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }

    public Instant getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }

    @com.fasterxml.jackson.annotation.JsonProperty("latitude")
    public Double getLatitude() {
        return coordinates != null ? coordinates.getY() : null;
    }

    @com.fasterxml.jackson.annotation.JsonProperty("longitude")
    public Double getLongitude() {
        return coordinates != null ? coordinates.getX() : null;
    }

    public static Builder builder() { return new Builder(); }

    public static class Builder {
        private UUID id;
        private User customer;
        private String addressType;
        private String houseFlat;
        private String street;
        private String area;
        private String city;
        private String state;
        private String postalCode;
        private String landmark;
        private Point coordinates;
        private boolean primary = false;
        private Instant createdAt;
        private Instant updatedAt;

        public Builder id(UUID id) { this.id = id; return this; }
        public Builder customer(User customer) { this.customer = customer; return this; }
        public Builder addressType(String addressType) { this.addressType = addressType; return this; }
        public Builder houseFlat(String houseFlat) { this.houseFlat = houseFlat; return this; }
        public Builder street(String street) { this.street = street; return this; }
        public Builder area(String area) { this.area = area; return this; }
        public Builder city(String city) { this.city = city; return this; }
        public Builder state(String state) { this.state = state; return this; }
        public Builder postalCode(String postalCode) { this.postalCode = postalCode; return this; }
        public Builder landmark(String landmark) { this.landmark = landmark; return this; }
        public Builder coordinates(Point coordinates) { this.coordinates = coordinates; return this; }
        public Builder primary(boolean primary) { this.primary = primary; return this; }
        public Builder createdAt(Instant createdAt) { this.createdAt = createdAt; return this; }
        public Builder updatedAt(Instant updatedAt) { this.updatedAt = updatedAt; return this; }

        public CustomerAddress build() {
            CustomerAddress a = new CustomerAddress();
            a.id = this.id;
            a.customer = this.customer;
            a.addressType = this.addressType;
            a.houseFlat = this.houseFlat;
            a.street = this.street;
            a.area = this.area;
            a.city = this.city;
            a.state = this.state;
            a.postalCode = this.postalCode;
            a.landmark = this.landmark;
            a.coordinates = this.coordinates;
            a.primary = this.primary;
            a.createdAt = this.createdAt;
            a.updatedAt = this.updatedAt;
            return a;
        }
    }
}
