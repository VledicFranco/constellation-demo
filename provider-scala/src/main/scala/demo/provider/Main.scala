package demo.provider

import cats.effect.{IO, IOApp}
import cats.implicits.*

import io.constellation.provider.JsonCValueSerializer
import io.constellation.provider.sdk.{
  ConstellationProvider,
  GrpcExecutorServerFactory,
  GrpcProviderTransport,
  SdkConfig
}

import io.grpc.ManagedChannelBuilder

import demo.provider.modules.{ClassifyTopic, ComputeReadability, ExtractEntities}

/** Scala module provider for the NLP entities namespace.
  *
  * Provides: ExtractEntities, ClassifyTopic, ComputeReadability
  */
object Main extends IOApp.Simple {

  private val constellationAddress =
    sys.env.getOrElse("CONSTELLATION_ADDRESS", "localhost:9090")

  private val executorPort =
    sys.env.getOrElse("EXECUTOR_PORT", "50052").toInt

  private val executorHost =
    sys.env.getOrElse("EXECUTOR_HOST", "localhost")

  def run: IO[Unit] = {
    for {
      _ <- IO.println(s"[provider-scala] Connecting to constellation server at $constellationAddress")
      _ <- IO.println(s"[provider-scala] Executor listening on $executorHost:$executorPort")

      provider <- ConstellationProvider.create(
        namespace = "nlp.entities",
        instances = List(constellationAddress),
        config = SdkConfig(executorPort = executorPort, executorHost = executorHost),
        transportFactory = { (addr: String) =>
          val Array(host, port) = addr.split(":")
          val channel = ManagedChannelBuilder.forAddress(host, port.toInt).usePlaintext().build()
          new GrpcProviderTransport(channel)
        },
        executorServerFactory = new GrpcExecutorServerFactory(),
        serializer = JsonCValueSerializer
      )

      _ <- provider.register(ExtractEntities.module)
      _ <- provider.register(ClassifyTopic.module)
      _ <- provider.register(ComputeReadability.module)

      modules <- provider.registeredModules
      _ <- IO.println(s"[provider-scala] Registered ${modules.size} modules:")
      _ <- modules.traverse_(m => IO.println(s"  - nlp.entities.${m.name}"))

      _ <- provider.start.use { _ =>
        IO.println("[provider-scala] Provider started and connected") *>
          IO.never
      }
    } yield ()
  }
}
