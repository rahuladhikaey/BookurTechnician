# Multi-Stage Production Dockerfile for BookurTechnician (React Admin + Spring Boot 3 + Java 21)

# ─── Stage 1: Build React Admin Panel (Vite + React) ──────────────────────────
FROM node:20-alpine AS frontend-builder
WORKDIR /admin
COPY apps/admin_panel/package*.json ./
RUN npm ci --prefer-offline || npm install
COPY apps/admin_panel/ ./
RUN npm run build

# ─── Stage 2: Build Java 21 Spring Boot Application with Admin Assets ─────────
FROM maven:3.9.6-eclipse-temurin-21-alpine AS backend-builder
WORKDIR /app

# Copy all backend & project files
COPY . .

# Copy built admin static assets into Spring Boot static resources (both /admin and root /)
COPY --from=frontend-builder /admin/dist/ apps/backend/src/main/resources/static/admin/
COPY --from=frontend-builder /admin/dist/ apps/backend/src/main/resources/static/

# Build unified executable JAR
RUN mvn clean package -DskipTests -B && cp target/*.jar app.jar

# ─── Stage 3: Minimal Distroless JRE 21 Runtime for Render / VPS ──────────────
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

# Create non-root system user for security compliance
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

# Copy compiled artifact from builder stage
COPY --from=backend-builder --chown=appuser:appgroup /app/app.jar ./app.jar

# Port configuration
ENV PORT=8080
EXPOSE 8080

# Production memory tuning optimized for Render 512MB RAM constraint
ENTRYPOINT ["java", "-XX:+UseG1GC", "-XX:MaxRAMPercentage=75.0", "-Djava.net.preferIPv4Stack=true", "-Djava.security.egd=file:/dev/./urandom", "-jar", "app.jar"]
