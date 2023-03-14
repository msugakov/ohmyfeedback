FROM eclipse-temurin:19 AS base

SHELL ["/usr/bin/bash", "-euo", "pipefail", "-c"]
RUN apt-get update && \
    apt-get upgrade -y --no-install-recommends && \
    apt-get install -y --no-install-recommends \
    ca-certificates

FROM base AS builder

RUN apt-get install -y --no-install-recommends \
    curl unzip zip

WORKDIR /build

# Install gradle from wrapper
COPY gradle/ gradle/
COPY gradle* ./
RUN ./gradlew --no-daemon

# Install dependencies
RUN mkdir -p ./app
COPY settings.gradle.kts ./
COPY app/build.gradle.kts ./app/
RUN ./gradlew --no-daemon -i --refresh-dependencies

COPY . .
RUN ./gradlew --no-daemon -i buildFatJar

FROM base AS final

WORKDIR /app
COPY --from=builder /build/app/build/libs/app-all.jar ./

# Set user to nobody
USER 65534:65534

EXPOSE 8080

ENTRYPOINT ["/opt/java/openjdk/bin/java"]
CMD ["-jar", "/app/app-all.jar"]
