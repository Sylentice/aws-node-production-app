const logger = require("../utils/logger");

function errorHandler(err, req, res, next) {
  logger.error(err.stack);

  // PostgreSQL duplicate key
  if (err.code === "23505") {
    return res.status(409).json({
      error: "Duplicate value violates unique constraint"
    });
  }

  res.status(500).json({
    error: "Internal server error"
  });
}

module.exports = errorHandler;
