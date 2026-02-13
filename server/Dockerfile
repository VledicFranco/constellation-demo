# Stage 1: Build
FROM sbtscala/scala-sbt:eclipse-temurin-jammy-17.0.10_7_1.10.7_3.3.4 AS build
WORKDIR /app

COPY project/build.properties project/
COPY project/plugins.sbt project/
COPY build.sbt .

# Pre-fetch dependencies
RUN sbt update

COPY src/ src/
RUN sbt assembly

# Stage 2: Runtime
FROM eclipse-temurin:17-jre-jammy
WORKDIR /app

COPY --from=build /app/target/scala-3.3.4/constellation-demo-server-assembly-*.jar app.jar

EXPOSE 8080 9090

ENTRYPOINT ["java", "-jar", "app.jar"]
