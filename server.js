require("dotenv").config();

const app = require("./app");
const pool = require("./db");

const PORT = process.env.PORT || 3000;

const server = app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

async function shutdown(signal) {
  console.log(`${signal} received. Starting graceful shutdown...`);

  const forceExitTimer = setTimeout(() => {
    console.error("Graceful shutdown timed out. Forcing exit.");
    process.exit(1);
  }, 10000);

  forceExitTimer.unref();

  server.close(async (err) => {
    if (err) {
      console.error("Error closing HTTP server:", err);
      process.exit(1);
    }

    console.log("HTTP server closed.");

    try {
      await pool.end();
      console.log("Database pool closed.");
      process.exit(0);
    } catch (poolError) {
      console.error("Error closing database pool:", poolError);
      process.exit(1);
    }
  });
}

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));
