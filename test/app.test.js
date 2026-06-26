process.env.DATABASE_URL = process.env.DATABASE_URL || "postgres://test:test@localhost:5432/test";
process.env.JWT_SECRET = process.env.JWT_SECRET || "test-jwt-secret";
const test = require("node:test");
const assert = require("node:assert/strict");
const request = require("supertest");

const pool = require("../db");
const app = require("../app");

test("GET / returns the application response", async () => {
  const response = await request(app).get("/");

  assert.equal(response.status, 200);
  assert.equal(response.body.message, "Structured Express app running!");
  assert.equal(Number.isNaN(Date.parse(response.body.timestamp)), false);
});

test("unknown routes return JSON 404", async () => {
  const response = await request(app).get("/does-not-exist");

  assert.equal(response.status, 404);
  assert.deepEqual(response.body, {
    error: "Route not found"
  });
});

test("GET /health reports a connected database", async (t) => {
  t.mock.method(pool, "query", async (sql) => {
    assert.equal(sql, "SELECT 1");
    return { rows: [] };
  });

  const response = await request(app).get("/health");

  assert.equal(response.status, 200);
  assert.equal(response.body.status, "OK");
  assert.equal(response.body.database, "connected");
  assert.equal(typeof response.body.hostname, "string");
});

test("GET /health reports a disconnected database", async (t) => {
  t.mock.method(pool, "query", async () => {
    throw new Error("Test database failure");
  });

  const response = await request(app).get("/health");

  assert.equal(response.status, 500);
  assert.equal(response.body.status, "ERROR");
  assert.equal(response.body.database, "disconnected");
});

test("responses include security headers", async () => {
  const response = await request(app).get("/");

  assert.equal(response.status, 200);
  assert.equal(response.headers["x-content-type-options"], "nosniff");
  assert.equal(response.headers["x-frame-options"], "SAMEORIGIN");
  assert.equal(response.headers["referrer-policy"], "no-referrer");
  assert.equal(response.headers["x-powered-by"], undefined);
});

test("GET /live reports the app process is alive", async () => {
  const response = await request(app).get("/live");

  assert.equal(response.status, 200);
  assert.equal(response.body.status, "OK");
  assert.equal(response.body.service, "alive");
  assert.equal(typeof response.body.hostname, "string");
});

test("GET /ready reports the app is ready when database is connected", async (t) => {
  t.mock.method(pool, "query", async (sql) => {
    assert.equal(sql, "SELECT 1");
    return { rows: [] };
  });

  const response = await request(app).get("/ready");

  assert.equal(response.status, 200);
  assert.equal(response.body.status, "OK");
  assert.equal(response.body.service, "ready");
  assert.equal(response.body.database, "connected");
});

test("GET /ready reports not ready when database is disconnected", async (t) => {
  t.mock.method(pool, "query", async () => {
    throw new Error("Test database failure");
  });

  const response = await request(app).get("/ready");

  assert.equal(response.status, 500);
  assert.equal(response.body.status, "ERROR");
  assert.equal(response.body.service, "not ready");
  assert.equal(response.body.database, "disconnected");
});

test("responses include a generated request ID", async () => {
  const response = await request(app).get("/");

  assert.equal(response.status, 200);
  assert.equal(typeof response.headers["x-request-id"], "string");
  assert.match(
    response.headers["x-request-id"],
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
  );
});

test("responses preserve an incoming request ID", async () => {
  const requestId = "shay-test-request-id";

  const response = await request(app)
    .get("/")
    .set("X-Request-Id", requestId);

  assert.equal(response.status, 200);
  assert.equal(response.headers["x-request-id"], requestId);
});

test("GET /version returns deployment metadata", async () => {
  const response = await request(app).get("/version");

  assert.equal(response.status, 200);
  assert.equal(response.body.service, "myapp-api");
  assert.equal(typeof response.body.commit, "string");
  assert.equal(typeof response.body.environment, "string");
  assert.equal(typeof response.body.hostname, "string");
  assert.equal(Number.isNaN(Date.parse(response.body.timestamp)), false);
});

test("GET /version uses GIT_COMMIT when provided", async () => {
  const originalCommit = process.env.GIT_COMMIT;
  process.env.GIT_COMMIT = "test-commit-sha";

  const response = await request(app).get("/version");

  assert.equal(response.status, 200);
  assert.equal(response.body.commit, "test-commit-sha");

  if (originalCommit === undefined) {
    delete process.env.GIT_COMMIT;
  } else {
    process.env.GIT_COMMIT = originalCommit;
  }
});
