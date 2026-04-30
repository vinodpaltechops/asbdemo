# syntax=docker/dockerfile:1.7
# Build context: app/ (multi-module parent)

FROM maven:3.9.9-eclipse-temurin-21 AS build
WORKDIR /workspace

COPY pom.xml ./
COPY orders-service/pom.xml orders-service/
COPY payments-service/pom.xml payments-service/

RUN --mount=type=cache,target=/root/.m2 \
    mvn -B -pl payments-service -am dependency:go-offline -DskipTests

COPY payments-service/src payments-service/src
RUN --mount=type=cache,target=/root/.m2 \
    mvn -B -pl payments-service -am package -DskipTests

FROM eclipse-temurin:21-jre
ARG OTEL_AGENT_VERSION=2.11.0
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates \
 && curl -fsSL -o /opt/opentelemetry-javaagent.jar \
      https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v${OTEL_AGENT_VERSION}/opentelemetry-javaagent.jar \
 && rm -rf /var/lib/apt/lists/* \
 && useradd -r -u 10001 -g users app
USER 10001
WORKDIR /app
COPY --from=build /workspace/payments-service/target/payments-service.jar /app/app.jar
EXPOSE 8080
ENTRYPOINT ["java","-javaagent:/opt/opentelemetry-javaagent.jar","-XX:+UseContainerSupport","-XX:MaxRAMPercentage=75","-jar","/app/app.jar"]
