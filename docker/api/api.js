'use strict';

const http = require('http');
const port = 3001;

const server = http.createServer((req, res) => {

    const auth = req.headers['authorization'];
    let accessToken = '[NONE]';
    if (auth && auth.startsWith('Bearer ')) {
        accessToken = auth.substring(7);
    }

    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({accessToken: accessToken}));
});

server.listen(port, () => {
    console.log(`API listening on port ${port}`);
});