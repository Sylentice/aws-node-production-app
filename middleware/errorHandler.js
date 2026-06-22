const logger = require("../utils/logger");

function logRequestError(err, req) {
  logger.error("Request error", {
    requestId: req.id,
    method: req.method,
    path: req.originalUrl,
    errorCode: err.code,
    message: err.message,
    stack: err.stack
  });
}

function errorHandler(err, req, res, next) {
  logRequestError(err, req);

  // PostgreSQL duplicate key
  if (err.code === "23505") {
    return res.status(409).json({
      error: "Duplicate value violates unique constraint",
      requestId: req.id
    });
  }

  res.status(500).json({
    error: "Internal server error",
    requestId: req.id
  });
}

module.exports = errorHandler;
