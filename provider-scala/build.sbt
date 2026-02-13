val constellationVersion = "0.7.0"

lazy val root = (project in file("."))
  .settings(
    name := "constellation-demo-provider-scala",
    version := "0.1.0",
    scalaVersion := "3.3.4",
    organization := "io.constellation.demo",
    libraryDependencies ++= Seq(
      "io.github.vledicfranco" %% "constellation-module-provider-sdk" % constellationVersion,
      "ch.qos.logback"          % "logback-classic"                   % "1.4.14"
    ),
    Compile / run / fork := true,
    assembly / mainClass := Some("demo.provider.Main"),
    assembly / assemblyMergeStrategy := {
      case PathList("META-INF", "services", _*) => MergeStrategy.concat
      case PathList("META-INF", _*)             => MergeStrategy.discard
      case "reference.conf"                     => MergeStrategy.concat
      case _                                    => MergeStrategy.first
    }
  )
