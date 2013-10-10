fs = require("fs")
url = require("url")
http = require("http")
connect = require("connect")
dgram = require("dgram")
argv = require('optimist').argv
lss = require("./lss.js")

stores = {}

error_handler = (req, res) ->
    res.writeHead(404, {'Content-Type': 'text/plain'})
    res.end("not found")


http_handlers = {
    "/metrics/dump": (req, res) ->
        res.writeHead(200, {'Content-Type': 'application/json'})
        res.end(JSON.stringify(stores))
    "/metrics": (req, res) ->
        res.writeHead(200, {'Content-Type': 'application/json'})
        keys = {}
        for key, value of stores
            keys[key] = value.keys().length
        res.end(JSON.stringify(keys))
    "/metrics/get": (req, res) ->
        name = req.query.name
        store = stores[name]
        if not store
            return error_handler(req, res)
        res.writeHead(200, {'Content-Type': 'application/json'})
        res.end(JSON.stringify(store.values()))
}

udp_handlers = {
    "gauge": (args) ->
        key = args[1]
        id = args[2]
        value = parseFloat(args[3])
        gamma0 = parseFloat(args[4]) or 1.0
        timestamp = parseFloat(args[5]) or new Date().getTime() / 1000
        reset = Boolean(parseInt(args[6])) or false
        if key and value != NaN
            gauge(key, id, value, gamma0, timestamp, reset)

    "counter": (args) ->
        key = args[1]
        id = args[2]
        gamma0 = parseFloat(args[3]) or 1.0
        timestamp = parseFloat(args[4]) or new Date().getTime() / 1000
        reset = Boolean(parseInt(args[5])) or false
        if key
            counter(key, id, gamma0, timestamp, reset)
}

# on exit handler: try to dump data to a file

shutdownStores = () ->
    stores_file = argv['stores']
    if not stores_file
        process.exit()
        return

    fs.writeFile(stores_file, JSON.stringify(stores), (err) ->
        if err
            console.log("Error: #{err}")
        else
            console.log("Stores saved to #{stores_file}")
        process.exit()
    )

process.on('SIGINT', shutdownStores)
process.on('SIGTERM', shutdownStores)


# on startup handler: try to load stores from a file
initStores = (filename) ->
    if not filename
        return
    fs.readFile(filename, 'utf8', (err, data) ->
        if err
            console.log('Error: ' + err)
            return
        data = JSON.parse(data)
        for key, value of data
            store = getStore(key)
            store.load(value)
        console.log("Stores loaded from #{filename}")
    )

startUDP = (udp_port) ->
    socket = dgram.createSocket("udp4")
    socket.on("message", (msg, rinfo) ->
        message = msg.toString()
        rows = message.split("\n")
        for row in rows
            chunks = row.split(" ")
            metric_type = chunks[0]  # "gauge" or "counter"
            handler = udp_handlers[metric_type]
            if handler
                handler(chunks)

    )
    socket.bind(udp_port)
    console.log("UDP server running at 0.0.0.0:#{udp_port}")


startHTTP = (http_port) ->

    connect()
        .use(connect.logger('dev'))
        .use(connect.static("#{__dirname}/public"))
        .use(connect.static("#{__dirname}/bower_components"))
        .use(connect.query())
        .use((req, res) ->
            url_data = url.parse(req.url);
            handler = http_handlers[url_data.pathname]
            if not handler
                error_handler(req, res)
            else
                handler(req, res)
        )
        .listen(1234)

    console.log("HTTP server running at http://0.0.0.0:#{http_port}/")


gauge = (key, id, value, gamma0, timestamp, reset) ->
    key = key.toString()
    id = id.toString()

    store = getStore(key)
    [prev_value, prev_timestamp] = store.get(id)
    if reset or prev_value is undefined
        # shortcut, there was nothing in there
        store.set(id, value, timestamp)
        return value

    dt = timestamp - prev_timestamp

    gamma = 1.0 / (dt / gamma0 + 1)
    new_value = gamma * prev_value + (1 - gamma) * value
    store.set(id, new_value, timestamp)
    return new_value


counter = (key, id, gamma0, timestamp, reset) ->
    key = key.toString()
    id = id.toString()
    store = getStore(key)

    [prev_value, prev_timestamp] = store.get(id)
    if reset or not prev_timestamp
        value = undefined
    else
        value = 1 / (timestamp - prev_timestamp)

    return gauge(key, id, value, gamma0, timestamp, reset)


getStore = (key) ->
    store = stores[key]
    if not store
        store = new lss.LimitedSizeStore(argv['store-limit'])
        stores[key] = store
    return store

initStores(argv['stores'])
startUDP(argv['udp-port'] or 1234)
startHTTP(argv['http-port'] or 1234)
