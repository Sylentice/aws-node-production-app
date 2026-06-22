const crypto = require("crypto");

function requestId(req, res, next) {
  const incomingRequestId = req.headers["x-request-id"];

  req.id = incomingRequestId || crypto.randomUUID();

  res.setHeader("X-Request-Id", req.id);

  next();
}

module.exports = requestId;
