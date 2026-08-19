// Tiny dependency-free static file server, dev-tooling only. Serves this
// repo's dev/ folder so the raw PeekPlus full-card templates under
// dev/services-plus/request-types/ - which only ever run embedded
// in real LB Phone/FiveM NUI - can be opened directly in a normal browser
// tab for visual testing, alongside dispatch-preview.html which feeds them
// mock postMessage payloads instead of a live PeekPlus controller.
const http = require('http')
const fs = require('fs')
const path = require('path')

const root = path.join(__dirname, '..')
const port = 5174
const types = {
    '.html': 'text/html', '.css': 'text/css', '.js': 'text/javascript',
    '.json': 'application/json', '.woff2': 'font/woff2', '.svg': 'image/svg+xml',
}

http.createServer((req, res) => {
    let urlPath = decodeURIComponent(req.url.split('?')[0])
    if (urlPath.endsWith('/')) urlPath += 'index.html'
    const filePath = path.join(root, urlPath)
    if (!filePath.startsWith(root)) { res.writeHead(403); res.end('Forbidden'); return }
    fs.readFile(filePath, (err, data) => {
        if (err) { res.writeHead(404, { 'Content-Type': 'text/plain' }); res.end(`Not found: ${req.url}`); return }
        res.writeHead(200, { 'Content-Type': types[path.extname(filePath)] || 'application/octet-stream' })
        res.end(data)
    })
}).listen(port, () => console.log(`Preview server on http://localhost:${port}`))
