const morgan = require("morgan");
const logger = require("./utils/logger");
const errorHandler = require("./middleware/errorHandler");
const express = require('express');
const usersRoutes = require('./routes/users');
const rateLimit = require('express-rate-limit');
const app = express();
app.set('trust proxy', 1);
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
// Health route
app.get('/health', (req, res) => {
  throw new Error("test failure");
  });
  res.json({
    status: "OK - Day32",
    uptime: process.uptime(),
    timestamp: new Date()
  });
});

// DB test route
const pool = require('./db');
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

