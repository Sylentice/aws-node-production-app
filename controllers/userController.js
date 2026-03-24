const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const pool = require("../db");

async function createUser(req, res, next) {
  try {
    const { name, email, password } = req.body;

    const hashedPassword = await bcrypt.hash(password, 10);

    const result = await pool.query(
      "INSERT INTO users (name, email, password) VALUES ($1, $2, $3) RETURNING id, name, email",
      [name, email, hashedPassword]
    );

    res.status(201).json({
      message: "User created successfully",
      user: result.rows[0]
    });
  } catch (err) {
    next(err);
  }
}
async function getAllUsers(req, res, next) {
  try {
    const { email, name } = req.query;

    let query = "SELECT * FROM users";
    let values = [];

    if (email) {
      query += " WHERE email = $1";
      values.push(email);
    } else if (name) {
      query += " WHERE name ILIKE $1";
      values.push(`%${name}%`);
    }

    query += " ORDER BY id ASC";

    const result = await pool.query(query, values);
    res.json(result.rows);
  } catch (err) {
    next(err);
  }
}
async function getUserById(req, res, next) {
  try {
    const { id } = req.params;

    const result = await pool.query(
      "SELECT * FROM users WHERE id = $1",
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "User not found" });
    }

    res.json(result.rows[0]);
  } catch (err) {
    next(err);
  }
}
async function updateUser(req, res, next) {
  try {
    const { id } = req.params;
    const { name, email } = req.body;

    const result = await pool.query(
      "UPDATE users SET name = $1, email = $2 WHERE id = $3 RETURNING *",
      [name, email, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "User not found" });
    }

    res.json({
      message: "User updated successfully",
      user: result.rows[0]
    });
  }
    catch (err) {
    next(err);
  }
}
async function deleteUser(req, res, next) {
  try {
    const { id } = req.params;

    const result = await pool.query(
      "DELETE FROM users WHERE id = $1 RETURNING *",
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "User not found" });
    }

    res.json({ message: "User deleted successfully" });
  } catch (err) {
    next(err);
  }
}
async function loginUser(req, res, next) {
  try {
    const { email, password } = req.body;

    const result = await pool.query(
      "SELECT * FROM users WHERE email = $1",
      [email]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: "Invalid credentials" });
    }

    const user = result.rows[0];

    const validPassword = await bcrypt.compare(password, user.password);

    if (!validPassword) {
      return res.status(401).json({ error: "Invalid credentials" });
    }

    const token = jwt.sign(
      { id: user.id, email: user.email },
      "supersecretkey",
      { expiresIn: "1h" }
    );

    res.json({
      message: "Login successful",
      token
    });
  } catch (err) {
    next(err);
  }
}
module.exports = {
  createUser,
  getAllUsers,
  getUserById,
  updateUser,
  deleteUser,
  loginUser
};
