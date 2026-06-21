const validator = require("validator");

function validateUser(req, res, next) {
  const { name, email, password } = req.body;

  if (!name || !email || !password) {
    return res.status(400).json({
      error: "Name, email, and password are required"
    });
  }

  if (
    typeof name !== "string" ||
    typeof email !== "string" ||
    typeof password !== "string"
  ) {
    return res.status(400).json({
      error: "Name, email, and password must be text values"
    });
  }

  const cleanName = name.trim();
  const cleanEmail = email.trim().toLowerCase();

  if (!cleanName) {
    return res.status(400).json({
      error: "Name is required"
    });
  }

  if (!validator.isEmail(cleanEmail)) {
    return res.status(400).json({
      error: "Invalid email format"
    });
  }

  if (password.length < 8) {
    return res.status(400).json({
      error: "Password must be at least 8 characters long"
    });
  }

  req.body.name = cleanName;
  req.body.email = validator.normalizeEmail(cleanEmail) || cleanEmail;
  req.body.password = password;

  next();
}

module.exports = validateUser;
