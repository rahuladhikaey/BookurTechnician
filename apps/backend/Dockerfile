# Multi-Stage Production Dockerfile for BookurTechnician Java 21 Spring Boot ACID Ledger
FROM maven:3.9.6-eclipse-temurin-21-alpine AS builder
WORKDIR /build

# Copy Maven pom and backend source code
COPY pom.xml ./
COPY apps/backend ./apps/backend

# Build production executable JAR
RUN mvn clean package -DskipTests -B && cp target/*.jar /build/app.jar

# ─── Minimal Distroless JRE 21 Runtime (~180MB) ──────────────────────────
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

# Run as non-root user for security compliance
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

# Copy compiled artifact from builder stage
COPY --from=builder --chown=appuser:appgroup /build/app.jar ./app.jar

ENV PORT=8080
EXPOSE 8080

# Production memory tuning
ENTRYPOINT ["java", "-XX:+UseG1GC", "-XX:MaxRAMPercentage=75.0", "-Djava.net.preferIPv4Stack=true", "-Djava.security.egd=file:/dev/./urandom", "-jar", "app.jar"]
