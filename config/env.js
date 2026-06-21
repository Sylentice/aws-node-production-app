require("dotenv").config();

const REQUIRED_ENV_VARS = [
  "DATABASE_URL",
  "JWT_SECRET"
];

function validateEnv(requiredVars = REQUIRED_ENV_VARS) {
  const missingVars = requiredVars.filter((name) => {
    return !process.env[name];
  });

  if (missingVars.length > 0) {
    throw new Error(
      `Missing required environment variables: ${missingVars.join(", ")}`
    );
  }

  return true;
}

validateEnv();

module.exports = {
  REQUIRED_ENV_VARS,
  validateEnv
};
