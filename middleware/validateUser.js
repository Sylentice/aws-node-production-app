const validator = require("validator");

function validateUser(req, res, next) {
const { name, email } = req.body;

if (!name || !email) {
return res.status(400).json({
error: "Name and email are required"
});
}

if (!validator.isEmail(email)) {
return res.status(400).json({
error: "Invalid email format"
});
}

next();
}

module.exports = validateUser;
