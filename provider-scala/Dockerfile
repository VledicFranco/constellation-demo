# Pre-built jar (built locally with publishLocal artifacts)
FROM eclipse-temurin:17-jre-jammy
WORKDIR /app

COPY target/scala-3.3.4/constellation-demo-provider-scala-assembly-*.jar app.jar

EXPOSE 50052

ENTRYPOINT ["java", "-jar", "app.jar"]
