package com.bookurtechnician.config;

import com.bookurtechnician.servicecatalog.entity.ServiceCategory;
import com.bookurtechnician.servicecatalog.entity.ServiceItem;
import com.bookurtechnician.servicecatalog.entity.ServiceSkill;
import com.bookurtechnician.servicecatalog.repository.ServiceCategoryRepository;
import com.bookurtechnician.servicecatalog.repository.ServiceItemRepository;
import com.bookurtechnician.servicecatalog.repository.ServiceSkillRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Component
@RequiredArgsConstructor
@Slf4j
public class CatalogDataSeeder implements CommandLineRunner {

    private final ServiceCategoryRepository categoryRepository;
    private final ServiceItemRepository serviceItemRepository;
    private final ServiceSkillRepository skillRepository;

    @Override
    @Transactional
    public void run(String... args) {
        try {
            seedComprehensiveCatalog();
        } catch (Exception ex) {
            log.warn("Catalog data seeding note: {}", ex.getMessage());
        }
    }

    private void seedComprehensiveCatalog() {
        // Define Categories and their Skills hierarchy
        Map<String, CategoryDefinition> catalog = new LinkedHashMap<>();

        // 1. Electrical & Home Electrical
        catalog.put("Electrical & Home Electrical", new CategoryDefinition(
                "electrical-services",
                "https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500",
                1,
                List.of(
                        new ServiceDefinition("Fan & Lighting Services", "fan-lighting-services", new BigDecimal("299.00")),
                        new ServiceDefinition("Switchboard & Wiring", "switchboard-wiring", new BigDecimal("399.00")),
                        new ServiceDefinition("Inverter & Motor Services", "inverter-motor-services", new BigDecimal("599.00"))
                ),
                List.of(
                        "Basic Electrician", "Light Repair", "LED Installation/Repair",
                        "Ceiling Fan Installation", "Ceiling Fan Repair", "Stand Fan Repair", "Exhaust Fan",
                        "Switch Board Repair", "Socket Repair", "MCB Installation", "MCB/Distribution Board Repair",
                        "Wiring Repair", "Short Circuit Troubleshooting", "Full House Wiring",
                        "New Electrical Installation", "Inverter Installation", "Inverter Repair",
                        "Motor Wiring", "Water Pump/Motor Repair", "Doorbell Installation",
                        "Electrical Appliance Connection"
                )
        ));

        // 2. AC Services
        catalog.put("AC Services", new CategoryDefinition(
                "ac-services",
                "https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500",
                2,
                List.of(
                        new ServiceDefinition("Split AC Deep Cleaning & Servicing", "split-ac-cleaning", new BigDecimal("499.00")),
                        new ServiceDefinition("AC Gas Charging & Inspection", "ac-gas-charging", new BigDecimal("1499.00")),
                        new ServiceDefinition("AC Installation & Uninstallation", "ac-install-uninstall", new BigDecimal("899.00"))
                ),
                List.of(
                        "AC Installation", "AC Uninstallation", "AC General Service",
                        "AC Deep Cleaning", "AC Gas Charging", "AC Gas Leakage Inspection",
                        "AC Cooling Problem", "AC Electrical Repair", "Split AC", "Window AC", "Inverter AC"
                )
        ));

        // 3. Refrigerator
        catalog.put("Refrigerator", new CategoryDefinition(
                "refrigerator-services",
                "https://images.unsplash.com/photo-1584992236310-6edddc08acff?w=500",
                3,
                List.of(
                        new ServiceDefinition("Single & Double Door Refrigerator Repair", "refrigerator-repair", new BigDecimal("399.00")),
                        new ServiceDefinition("Refrigerator Gas Refill & Compressor Check", "refrigerator-gas-refill", new BigDecimal("999.00"))
                ),
                List.of(
                        "Refrigerator Repair", "Refrigerator Cooling Problem", "Gas Charging",
                        "Compressor Related Service", "Refrigerator Electrical Repair", "Door/Gasket Repair"
                )
        ));

        // 4. Washing Machine
        catalog.put("Washing Machine", new CategoryDefinition(
                "washing-machine-services",
                "https://images.unsplash.com/photo-1626806787461-102c1bfaaea1?w=500",
                4,
                List.of(
                        new ServiceDefinition("Automatic Washing Machine Servicing", "washing-machine-servicing", new BigDecimal("399.00")),
                        new ServiceDefinition("Drum & Motor Repair", "drum-motor-repair", new BigDecimal("699.00"))
                ),
                List.of(
                        "Washing Machine Repair", "Washing Machine Installation", "Front Load",
                        "Top Load", "Semi Automatic", "Drainage Problem", "Spin Problem",
                        "Water Inlet Problem", "Washing Machine Electrical Repair"
                )
        ));

        // 5. Computer & Laptop
        catalog.put("Computer & Laptop", new CategoryDefinition(
                "computer-laptop-services",
                "https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500",
                5,
                List.of(
                        new ServiceDefinition("Laptop Diagnosis & Chip-level Repair", "laptop-repair", new BigDecimal("499.00")),
                        new ServiceDefinition("OS Installation & Software Troubleshooting", "os-installation", new BigDecimal("349.00"))
                ),
                List.of(
                        "Computer Repair", "Laptop Repair", "Laptop Screen Replacement",
                        "Keyboard Replacement", "Battery Replacement", "Charging Port Repair",
                        "Windows/OS Installation", "Software Troubleshooting", "Hardware Troubleshooting",
                        "Desktop Assembly", "Computer Networking"
                )
        ));

        // 6. TV & Entertainment
        catalog.put("TV & Entertainment", new CategoryDefinition(
                "tv-entertainment-services",
                "https://images.unsplash.com/photo-1593359677879-a4bb92f829d1?w=500",
                6,
                List.of(
                        new ServiceDefinition("Smart TV Wall Mount Installation", "tv-wall-mounting", new BigDecimal("349.00")),
                        new ServiceDefinition("LED / Smart TV Repair", "led-tv-repair", new BigDecimal("549.00"))
                ),
                List.of(
                        "LED TV Repair", "Smart TV Repair", "TV Installation",
                        "TV Wall Mounting", "Set-top Box Installation", "Speaker Installation",
                        "CCTV Installation", "Wi-Fi/Router Setup", "Door Lock Repair",
                        "Appliance Installation", "General Home Maintenance"
                )
        ));

        for (Map.Entry<String, CategoryDefinition> entry : catalog.entrySet()) {
            String catName = entry.getKey();
            CategoryDefinition catDef = entry.getValue();

            ServiceCategory category = categoryRepository.findBySlug(catDef.slug)
                    .orElseGet(() -> categoryRepository.save(ServiceCategory.builder()
                            .name(catName)
                            .slug(catDef.slug)
                            .bannerUrl(catDef.bannerUrl)
                            .iconUrl(catDef.bannerUrl)
                            .displayOrder(catDef.displayOrder)
                            .active(true)
                            .build()));

            // Seed services
            ServiceItem firstService = null;
            for (ServiceDefinition srvDef : catDef.services) {
                ServiceItem srv = serviceItemRepository.findBySlug(srvDef.slug)
                        .orElseGet(() -> serviceItemRepository.save(ServiceItem.builder()
                                .category(category)
                                .name(srvDef.name)
                                .slug(srvDef.slug)
                                .price(srvDef.price)
                                .durationMinutes(45)
                                .warrantyText("30-Day Service Warranty")
                                .description("Professional certified service by BookurTechnician partners")
                                .active(true)
                                .popular(true)
                                .build()));
                if (firstService == null) firstService = srv;
            }

            // Seed skills
            int order = 1;
            for (String skillName : catDef.skills) {
                String skillSlug = generateSlug(category.getName() + "-" + skillName);
                if (!skillRepository.existsBySlug(skillSlug)) {
                    skillRepository.save(ServiceSkill.builder()
                            .category(category)
                            .serviceItem(firstService)
                            .name(skillName)
                            .slug(skillSlug)
                            .description("Certified skills for " + skillName)
                            .displayOrder(order++)
                            .active(true)
                            .build());
                }
            }
        }
        log.info("Comprehensive Skill & Service Catalog successfully populated.");
    }

    private String generateSlug(String text) {
        return text.toLowerCase()
                .replaceAll("[^a-z0-9\\s-]", "")
                .replaceAll("\\s+", "-");
    }

    private static class CategoryDefinition {
        final String slug;
        final String bannerUrl;
        final int displayOrder;
        final List<ServiceDefinition> services;
        final List<String> skills;

        CategoryDefinition(String slug, String bannerUrl, int displayOrder, List<ServiceDefinition> services, List<String> skills) {
            this.slug = slug;
            this.bannerUrl = bannerUrl;
            this.displayOrder = displayOrder;
            this.services = services;
            this.skills = skills;
        }
    }

    private static class ServiceDefinition {
        final String name;
        final String slug;
        final BigDecimal price;

        ServiceDefinition(String name, String slug, BigDecimal price) {
            this.name = name;
            this.slug = slug;
            this.price = price;
        }
    }
}
