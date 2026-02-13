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
    val Array(host, port) = constellationAddress.split(":")

    for {
      _ <- IO.println(s"[provider-scala] Connecting to constellation server at $constellationAddress")
      _ <- IO.println(s"[provider-scala] Executor listening on $executorHost:$executorPort")

      // WORKAROUND: The Scala SDK builds executorUrl as "$instanceAddress:$executorPort".
      // In Docker, instanceAddress would be "constellation-server:9090" producing the
      // malformed URL "constellation-server:9090:50052". To work around this, we pass
      // the executor host as the "instance" address (so executorUrl = "provider-scala:50052")
      // and ignore the addr parameter in the transport factory, connecting directly to the
      // constellation server instead. See: https://github.com/VledicFranco/constellation-engine/issues/214
      provider <- ConstellationProvider.create(
        namespace = "nlp.entities",
        instances = List(executorHost),
        config = SdkConfig(executorPort = executorPort),
        transportFactory = { (_: String) =>
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
