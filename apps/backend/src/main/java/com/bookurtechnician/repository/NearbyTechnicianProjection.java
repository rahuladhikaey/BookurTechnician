package com.bookurtechnician.repository;

/**
 * Spring Data JPA native projection interface for nearby technician geospatial queries.
 * Maps exact PostGIS ST_Distance calculation and technician profile attributes.
 */
public interface NearbyTechnicianProjection {

    String getTechnicianId();

    String getTechnicianCode();

    String getFullName();

    String getPhone();

    String getCategory();

    Integer getExperienceYears();

    Double getRating();

    Integer getTotalRatingsCount();

    Integer getTotalJobsCompleted();

    Double getCurrentLatitude();

    Double getCurrentLongitude();

    Boolean getIsOnline();

    String getAvailabilityStatus();

    String getProfileImageUrl();

    Double getDistanceMeters();
}
