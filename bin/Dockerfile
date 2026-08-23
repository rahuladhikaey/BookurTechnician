# Multi-Stage Production Dockerfile for BookurTechnician (Spring Boot 3 + Java 21)

# ─── Stage 1: Build Java 21 Spring Boot Application ───────────────────────────
FROM maven:3.9.6-eclipse-temurin-21-alpine AS builder
WORKDIR /app

# Copy all project source files
COPY . .

# Build executable jar
RUN mvn clean package -DskipTests -B && cp target/*.jar app.jar

# ─── Stage 2: Minimal Distroless JRE 21 Runtime for Render Free Tier ──────────
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

# Create non-root system user for security compliance
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

# Copy compiled artifact from builder stage
COPY --from=builder --chown=appuser:appgroup /app/app.jar ./app.jar

# Render web service port
ENV PORT=8080
EXPOSE 8080

# Production memory tuning optimized for Render 512MB RAM constraint
ENTRYPOINT ["java", "-XX:+UseG1GC", "-XX:MaxRAMPercentage=75.0", "-Djava.net.preferIPv4Stack=true", "-Djava.security.egd=file:/dev/./urandom", "-jar", "app.jar"]
