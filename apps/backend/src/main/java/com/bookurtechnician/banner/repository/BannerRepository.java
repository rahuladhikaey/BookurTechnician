package com.bookurtechnician.banner.repository;

import com.bookurtechnician.banner.entity.Banner;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface BannerRepository extends JpaRepository<Banner, UUID> {

    List<Banner> findByBannerTypeAndActiveTrueOrderByDisplayOrderAsc(String bannerType);

    List<Banner> findByActiveTrueOrderByDisplayOrderAsc();

    List<Banner> findAllByOrderByDisplayOrderAsc();
}
