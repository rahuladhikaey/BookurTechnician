# Multi-stage Dockerfile for BookurTechnician Spring Boot 3 Backend
FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /app
COPY pom.xml .
COPY src ./src

# Install maven and build production jar
RUN apk add --no-cache maven && \
    mvn clean package -DskipTests

# Runtime stage
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar

EXPOSE 8080
ENTRYPOINT ["java", "-Xmx320m", "-Xms128m", "-XX:+UseSerialGC", "-XX:MaxRAMPercentage=65.0", "-jar", "app.jar"]
