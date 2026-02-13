package demo

import java.nio.file.Paths

import cats.effect.{IO, IOApp}
import cats.implicits.*

import io.constellation.cache.memcached.{MemcachedCacheBackend, MemcachedConfig}
import io.constellation.execution.GlobalScheduler
import io.constellation.http.{
  AuthConfig,
  ConstellationServer,
  CorsConfig,
  DashboardConfig,
  ExecutionWebSocket,
  HealthCheckConfig,
  PipelineLoaderConfig,
  RateLimitConfig
}
import io.constellation.impl.ConstellationImpl
import io.constellation.lang.CachingLangCompiler
import io.constellation.provider.{ModuleProviderManager, ProviderManagerConfig}
import io.constellation.stdlib.StdLib

import org.typelevel.log4cats.Logger
import org.typelevel.log4cats.slf4j.Slf4jLogger

/** Constellation Demo Server — showcases all framework features.
  *
  * Integrates: priority scheduler, memcached cache, external module providers (gRPC), auth, CORS,
  * rate limiting, dashboard, pipeline auto-loading, and health checks.
  */
object DemoServer extends IOApp.Simple {
  private val logger: Logger[IO] =
    Slf4jLogger.getLoggerFromName[IO]("demo.DemoServer")

  private val memcachedAddress =
    sys.env.getOrElse("MEMCACHED_ADDRESS", "localhost:11211")

  private val grpcPort =
    sys.env.getOrElse("CONSTELLATION_GRPC_PORT", "9090").toInt

  private val pipelineDir =
    sys.env.getOrElse("CONSTELLATION_CST_DIR", "/app/pipelines")

  def run: IO[Unit] =
    ConstellationServer.schedulerResource.use { scheduler =>
      MemcachedCacheBackend.resource(MemcachedConfig.single(memcachedAddress)).use { cache =>
        for {
          _ <- logger.info(s"Memcached cache connected: $memcachedAddress")

          // Execution WebSocket for live dashboard events
          executionWs = ExecutionWebSocket()

          // Core engine with scheduler, cache, and execution listener
          constellation <- ConstellationImpl
            .builder()
            .withScheduler(scheduler)
            .withCache(cache)
            .withListener(executionWs.listener)
            .build()

          // Register stdlib modules
          stdModules = StdLib.allModules.values.toList
          _ <- stdModules.traverse(constellation.setModule)
          _ <- logger.info(s"Registered ${stdModules.size} stdlib modules")

          // Compiler with stdlib functions + caching
          baseCompiler = StdLib.compiler
          compiler     = CachingLangCompiler.withDefaults(baseCompiler)

          // Module provider manager — wraps constellation + starts gRPC server
          _ <- ModuleProviderManager(
            delegate = constellation,
            compiler = compiler,
            config = ProviderManagerConfig(grpcPort = grpcPort)
          ).use { manager =>
            for {
              _ <- logger.info(s"gRPC provider server listening on port $grpcPort")

              // Server configuration
              port = ConstellationServer.DefaultPort
              _ <- logger.info(s"Starting HTTP server on port $port")
              _ <- logger.info(s"Dashboard: http://localhost:$port/dashboard")
              _ <- logger.info(s"Pipeline directory: $pipelineDir")

              _ <- ConstellationServer
                .builder(manager, compiler)
                .withHost("0.0.0.0")
                .withDashboard(DashboardConfig.fromEnv)
                .withCors(CorsConfig(allowedOrigins = Set("*")))
                .withHealthChecks(HealthCheckConfig(enableDetailEndpoint = true))
                .withPipelineLoader(
                  PipelineLoaderConfig(directory = Paths.get(pipelineDir))
                )
                .withExecutionWebSocket(executionWs)
                .run
            } yield ()
          }
        } yield ()
      }
    }
}
