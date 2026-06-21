const test = require("node:test");
const assert = require("node:assert/strict");

process.env.DATABASE_URL = process.env.DATABASE_URL || "postgres://test:test@localhost:5432/test";
process.env.JWT_SECRET = process.env.JWT_SECRET || "test-jwt-secret";

const { validateEnv } = require("../config/env");

test("validateEnv passes when required variables exist", () => {
  const originalExample = process.env.EXAMPLE_REQUIRED_VAR;

  process.env.EXAMPLE_REQUIRED_VAR = "exists";

  assert.equal(validateEnv(["EXAMPLE_REQUIRED_VAR"]), true);

  if (originalExample === undefined) {
    delete process.env.EXAMPLE_REQUIRED_VAR;
  } else {
    process.env.EXAMPLE_REQUIRED_VAR = originalExample;
  }
});

test("validateEnv throws a clear error when required variables are missing", () => {
  const originalMissing = process.env.EXAMPLE_MISSING_VAR;

  delete process.env.EXAMPLE_MISSING_VAR;

  assert.throws(
    () => validateEnv(["EXAMPLE_MISSING_VAR"]),
    /Missing required environment variables: EXAMPLE_MISSING_VAR/
  );

  if (originalMissing !== undefined) {
    process.env.EXAMPLE_MISSING_VAR = originalMissing;
  }
});
