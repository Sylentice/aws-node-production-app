const http = require('http');

const server = http.createServer((req, res) => {
  res.writeHead(200, {'Content-Type': 'application/json'});
  res.end(JSON.stringify({
    message: "Hello from Shaylyn's AWS Server 🚀",
    timestamp: new Date()
  }));
});

server.listen(3000, () => {
  console.log("Server running on port 3000");
});
