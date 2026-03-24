const authenticateToken = require("../middleware/auth");
const { createUser, getAllUsers, getUserById, updateUser, deleteUser, loginUser } = require("../controllers/userController");
const validateUser = require("../middleware/validateUser");
const express = require('express');
const router = express.Router();
const pool = require('../db');

router.get("/", authenticateToken, getAllUsers);
router.get("/:id", getUserById);
router.post('/',validateUser, createUser);
router.put("/:id", updateUser);
router.delete("/:id", deleteUser);
router.post("/login", loginUser);

module.exports = router;
