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
