const http = require('http');
const https = require('https');

const PORT = process.env.AI_PROXY_PORT || 8080;
const GEMINI_API_KEY = process.env.GEMINI_API_KEY || '';
const GEMINI_MODEL = process.env.GEMINI_MODEL || 'gemini-1.5-flash';

const server = http.createServer((req, res) => {
  if (req.method === 'GET' && req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({
      status: 'ok',
      service: 'toss-ai-proxy',
      model: GEMINI_MODEL,
      hasKey: Boolean(GEMINI_API_KEY)
    }));
  }

  if (req.method === 'POST' && req.url === '/api/structure') {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      try {
        const payload = JSON.parse(body || '{}');
        const rawInput = payload.input || '';
        const context = payload.context || '';

        if (!GEMINI_API_KEY) {
          res.writeHead(503, { 'Content-Type': 'application/json' });
          return res.end(JSON.stringify({ error: 'GEMINI_API_KEY not configured on server' }));
        }

        const prompt = `Convert the following user notes into a strict TOSS handoff JSON (schema 1.0.0):
Context: ${context}
Notes: ${rawInput}`;

        const reqBody = JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: { responseMimeType: 'application/json' }
        });

        const geminiReq = https.request({
          hostname: 'generativelanguage.googleapis.com',
          path: `/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`,
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(reqBody)
          }
        }, geminiRes => {
          let gData = '';
          geminiRes.on('data', c => { gData += c; });
          geminiRes.on('end', () => {
            res.writeHead(geminiRes.statusCode, { 'Content-Type': 'application/json' });
            res.end(gData);
          });
        });

        geminiReq.on('error', err => {
          res.writeHead(500, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: err.message }));
        });

        geminiReq.write(reqBody);
        geminiReq.end();
      } catch (err) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Invalid JSON payload' }));
      }
    });
    return;
  }

  res.writeHead(404, { 'Content-Type': 'text/plain' });
  res.end('Not Found');
});

server.listen(PORT, () => {
  console.log(`[TOSS AI Proxy] Running on http://localhost:${PORT}`);
});
