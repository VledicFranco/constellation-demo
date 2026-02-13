import {
  ConstellationProvider,
  GrpcProviderTransport,
  GrpcExecutorServerFactory,
} from "@constellation-engine/provider-sdk";

import { analyzeSentimentModule } from "./modules/analyze-sentiment.js";
import { detectLanguageModule } from "./modules/detect-language.js";
import { extractKeywordsModule } from "./modules/extract-keywords.js";

const constellationAddress = process.env.CONSTELLATION_ADDRESS ?? "localhost:9090";
const executorPort = Number(process.env.EXECUTOR_PORT ?? "50051");
const executorHost = process.env.EXECUTOR_HOST ?? "localhost";

async function main() {
  console.log(`[provider-ts] Connecting to constellation server at ${constellationAddress}`);
  console.log(`[provider-ts] Executor listening on ${executorHost}:${executorPort}`);

  const provider = await ConstellationProvider.create({
    namespace: "nlp.sentiment",
    instances: [constellationAddress],
    transportFactory: (addr) => {
      const [host, port] = addr.split(":");
      return new GrpcProviderTransport(host, Number(port));
    },
    executorServerFactory: new GrpcExecutorServerFactory(),
    config: {
      executorPort,
      executorHost,
    },
  });

  provider.register(analyzeSentimentModule);
  provider.register(detectLanguageModule);
  provider.register(extractKeywordsModule);

  console.log(`[provider-ts] Registered ${provider.registeredModules.length} modules:`);
  for (const mod of provider.registeredModules) {
    console.log(`  - nlp.sentiment.${mod.name}`);
  }

  await provider.start();
  console.log("[provider-ts] Provider started and connected");

  // Keep the process alive
  const shutdown = async () => {
    console.log("[provider-ts] Shutting down...");
    await provider.stop();
    process.exit(0);
  };

  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);

  // Block forever
  await new Promise(() => {});
}

main().catch((err) => {
  console.error("[provider-ts] Fatal error:", err);
  process.exit(1);
});
