require("./config/env");

const pool = require('./db');
const os = require("os");
const helmet = require("helmet");
const morgan = require("morgan");
const logger = require("./utils/logger");
const errorHandler = require("./middleware/errorHandler");
const express = require('express');
const usersRoutes = require('./routes/users');
const rateLimit = require('express-rate-limit');
const app = express();

app.disable("x-powered-by");

app.set('trust proxy', 1);

app.use(helmet());
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  message: { error: "Too many requests, please try again later." }
});
app.use(limiter);
app.use(express.json());
//Logger
app.use(
  morgan("combined", {
    stream: {
      write: (message) => logger.info(message.trim())
    }
  })
);

// Liveness route
app.get("/live", (req, res) => {
  res.status(200).json({
    status: "OK",
    service: "alive",
    hostname: os.hostname(),
    uptime: process.uptime(),
    timestamp: new Date()
  });
});

async function readinessHandler(req, res) {
  try {
    await pool.query("SELECT 1");

    res.status(200).json({
      status: "OK",
      service: "ready",
      database: "connected",
      hostname: os.hostname(),
      uptime: process.uptime(),
      timestamp: new Date()
    });

  } catch (err) {
    res.status(500).json({
      status: "ERROR",
      service: "not ready",
      hostname: os.hostname(),
      database: "disconnected",
      error: err.message
    });
  }
}

// Readiness route
app.get("/ready", readinessHandler);

// Compatibility health route
app.get("/health", readinessHandler);

// DB test route
app.get('/db-test', async (req, res) => {
  try {
    const result = await pool.query('SELECT NOW()');
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).send("Database connection error");
  }
});

// Mount users routes
app.use('/users', usersRoutes);

// Default route
app.get('/', (req, res) => {
  res.json({
    message: "Structured Express app running!",
    timestamp: new Date()
  });
});
// 404 Handler
app.use((req, res) => {
  res.status(404).json({
    error: "Route not found"
  });
});
// Global Error Handler
app.use(errorHandler);
module.exports = app;

