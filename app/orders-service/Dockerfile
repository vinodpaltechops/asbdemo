# syntax=docker/dockerfile:1.7
# Build context: app/ (multi-module parent)

FROM maven:3.9.9-eclipse-temurin-21 AS build
WORKDIR /workspace

COPY pom.xml ./
COPY orders-service/pom.xml orders-service/
COPY payments-service/pom.xml payments-service/

RUN --mount=type=cache,target=/root/.m2 \
    mvn -B -pl orders-service -am dependency:go-offline -DskipTests

COPY orders-service/src orders-service/src
RUN --mount=type=cache,target=/root/.m2 \
    mvn -B -pl orders-service -am package -DskipTests

FROM eclipse-temurin:21-jre
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl \
 && rm -rf /var/lib/apt/lists/* \
 && useradd -r -u 10001 -g users app
USER 10001
WORKDIR /app
COPY --from=build /workspace/orders-service/target/orders-service.jar /app/app.jar
EXPOSE 8080
ENTRYPOINT ["java","-XX:+UseContainerSupport","-XX:MaxRAMPercentage=75","-jar","/app/app.jar"]
