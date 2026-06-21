process.env.DATABASE_URL = process.env.DATABASE_URL || "postgres://test:test@localhost:5432/test";
process.env.JWT_SECRET = process.env.JWT_SECRET || "test-jwt-secret";

const test = require("node:test");
const assert = require("node:assert/strict");
const request = require("supertest");
const jwt = require("jsonwebtoken");
const bcrypt = require("bcrypt");

const pool = require("../db");
const app = require("../app");

test("GET /users requires an access token", async () => {
  const response = await request(app).get("/users");

  assert.equal(response.status, 401);
  assert.deepEqual(response.body, {
    error: "Access token required"
  });
});

test("GET /users rejects an invalid token", async () => {
  const response = await request(app)
    .get("/users")
    .set("Authorization", "Bearer invalid-token");

  assert.equal(response.status, 403);
  assert.deepEqual(response.body, {
    error: "Invalid or expired token"
  });
});

test("GET /users allows a valid token and returns users", async (t) => {
  const token = jwt.sign(
    { id: 1, email: "test@example.com" },
    process.env.JWT_SECRET,
    { expiresIn: "1h" }
  );

  t.mock.method(pool, "query", async (sql, values) => {
    assert.equal(sql, "SELECT id, name, email, created_at FROM users ORDER BY id ASC");
    assert.deepEqual(values, []);

    return {
      rows: [
        {
          id: 1,
          name: "Test User",
          email: "test@example.com"
        }
      ]
    };
  });

  const response = await request(app)
    .get("/users")
    .set("Authorization", `Bearer ${token}`);

  assert.equal(response.status, 200);
  assert.deepEqual(response.body, [
    {
      id: 1,
      name: "Test User",
      email: "test@example.com"
    }
  ]);
});

test("POST /users requires name, email, and password", async () => {
  const response = await request(app)
    .post("/users")
    .send({
      email: "test@example.com",
      password: "password123"
    });

  assert.equal(response.status, 400);
  assert.deepEqual(response.body, {
    error: "Name, email, and password are required"
  });
});

test("POST /users rejects invalid email format", async () => {
  const response = await request(app)
    .post("/users")
    .send({
      name: "Test User",
      email: "not-an-email",
      password: "password123"
    });

  assert.equal(response.status, 400);
  assert.deepEqual(response.body, {
    error: "Invalid email format"
  });
});

test("POST /users/login returns a JWT for valid credentials", async (t) => {
  const hashedPassword = await bcrypt.hash("password123", 10);

  t.mock.method(pool, "query", async (sql, values) => {
    assert.equal(sql, "SELECT id, email, password FROM users WHERE email = $1");
    assert.deepEqual(values, ["test@example.com"]);

    return {
      rows: [
        {
          id: 1,
          email: "test@example.com",
          password: hashedPassword
        }
      ]
    };
  });

  const response = await request(app)
    .post("/users/login")
    .send({
      email: "test@example.com",
      password: "password123"
    });

  assert.equal(response.status, 200);
  assert.equal(response.body.message, "Login successful");
  assert.equal(typeof response.body.token, "string");

  const decoded = jwt.verify(response.body.token, process.env.JWT_SECRET);

  assert.equal(decoded.id, 1);
  assert.equal(decoded.email, "test@example.com");
});

test("POST /users/login rejects invalid credentials", async (t) => {
  const hashedPassword = await bcrypt.hash("password123", 10);

  t.mock.method(pool, "query", async () => {
    return {
      rows: [
        {
          id: 1,
          email: "test@example.com",
          password: hashedPassword
        }
      ]
    };
  });

  const response = await request(app)
    .post("/users/login")
    .send({
      email: "test@example.com",
      password: "wrong-password"
    });

  assert.equal(response.status, 401);
  assert.deepEqual(response.body, {
    error: "Invalid credentials"
  });
});

test("POST /users requires a password", async () => {
  const response = await request(app)
    .post("/users")
    .send({
      name: "Test User",
      email: "test@example.com"
    });

  assert.equal(response.status, 400);
  assert.deepEqual(response.body, {
    error: "Name, email, and password are required"
  });
});

test("POST /users rejects short passwords", async () => {
  const response = await request(app)
    .post("/users")
    .send({
      name: "Test User",
      email: "test@example.com",
      password: "short"
    });

  assert.equal(response.status, 400);
  assert.deepEqual(response.body, {
    error: "Password must be at least 8 characters long"
  });
});

test("GET /users does not expose password hashes", async (t) => {
  const token = jwt.sign(
    { id: 1, email: "test@example.com" },
    process.env.JWT_SECRET,
    { expiresIn: "1h" }
  );

  t.mock.method(pool, "query", async () => {
    return {
      rows: [
        {
          id: 1,
          name: "Test User",
          email: "test@example.com",
          password: "hashed-password-value",
          created_at: "2026-06-21T00:00:00.000Z"
        }
      ]
    };
  });

  const response = await request(app)
    .get("/users")
    .set("Authorization", `Bearer ${token}`);

  assert.equal(response.status, 200);
  assert.equal(response.body[0].password, undefined);
  assert.deepEqual(response.body[0], {
    id: 1,
    name: "Test User",
    email: "test@example.com",
    created_at: "2026-06-21T00:00:00.000Z"
  });
});

test("GET /users/:id does not expose password hashes", async (t) => {
  t.mock.method(pool, "query", async (sql, values) => {
    assert.equal(sql, "SELECT id, name, email, created_at FROM users WHERE id = $1");
    assert.deepEqual(values, ["1"]);

    return {
      rows: [
        {
          id: 1,
          name: "Test User",
          email: "test@example.com",
          password: "hashed-password-value",
          created_at: "2026-06-21T00:00:00.000Z"
        }
      ]
    };
  });

  const response = await request(app).get("/users/1");

  assert.equal(response.status, 200);
  assert.equal(response.body.password, undefined);
  assert.deepEqual(response.body, {
    id: 1,
    name: "Test User",
    email: "test@example.com",
    created_at: "2026-06-21T00:00:00.000Z"
  });
});
