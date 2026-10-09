// 冒烟用的「集群入口」替身：自签 HTTPS，回显 Host 与 X-Forwarded-*，/sse 慢慢推三条事件，/ws 回 101。
import https from 'node:https'
import fs from 'node:fs'
const [key, cert, port] = process.argv.slice(2)
const server = https.createServer({ key: fs.readFileSync(key), cert: fs.readFileSync(cert) }, (req, res) => {
  if (req.url === '/sse') {
    res.writeHead(200, { 'content-type': 'text/event-stream', 'cache-control': 'no-store' })
    let n = 0
    const timer = setInterval(() => {
      res.write(`data: tick ${++n} ${Date.now()}\n\n`)
      if (n === 3) { clearInterval(timer); res.end() }
    }, 1500)
    return
  }
  res.writeHead(200, { 'content-type': 'application/json' })
  res.end(JSON.stringify({ host: req.headers.host, xff: req.headers['x-forwarded-for'] ?? null, proto: req.headers['x-forwarded-proto'] ?? null, path: req.url }))
})
server.on('upgrade', (req, socket) => {
  socket.end('HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nX-Smoke-Host: ' + req.headers.host + '\r\n\r\n')
})
server.listen(Number(port), '127.0.0.1')
