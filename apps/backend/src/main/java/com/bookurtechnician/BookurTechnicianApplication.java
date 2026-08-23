package com.bookurtechnician;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.domain.EntityScan;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;

@SpringBootApplication
@EntityScan(basePackages = "com.bookurtechnician.model")
@EnableJpaRepositories(basePackages = "com.bookurtechnician.repository")
public class BookurTechnicianApplication {

    public static void main(String[] args) {
        SpringApplication.run(BookurTechnicianApplication.class, args);
        System.out.println("===============================================================");
        System.out.println("☕ Java 21 / Spring Boot 3 Financial Ledger Service is running");
        System.out.println("💰 Port: 8080 | ACID Ledger & High-Performance Settlements Active");
        System.out.println("===============================================================");
    }
}
