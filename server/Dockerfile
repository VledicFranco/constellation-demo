# Pre-built jar (built locally with publishLocal artifacts)
FROM eclipse-temurin:17-jre-jammy
WORKDIR /app

COPY target/scala-3.3.4/constellation-demo-server-assembly-*.jar app.jar

EXPOSE 8080 9090

ENTRYPOINT ["java", "-jar", "app.jar"]
