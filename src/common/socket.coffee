# SauceBot JSON Sockets

io    = require './ioutil'

color = require 'colors'
net   = require 'net'

class Socket

    constructor: (@sock, @endHandler) ->
        @sock.setEncoding 'utf8'
        @queue = []
        
        @handlers = {}
        
        @sock.on 'data', (data) =>
            @handleData data
            
        @sock.on 'end', =>
            @handleEnd()
            
        @sock.on 'error', (error) =>
            @handleEnd()
        
        @sock.on 'connect', =>
            @addr = @sock.remoteAddress
            @handleConnect()


    close: ->
        @sock.end() if @sock?


    on: (cmd, handler) ->
        @handlers[cmd] = handler

        # Handle unprocessed data
        for elem, i in @queue when elem.cmd is cmd
            delete @queue[i]
            handler elem.data
        
    
    handleData: (rawdata) ->
        for line in rawdata.split '\n'
            try
                json = JSON.parse(line)
                cmd  = json.cmd
                data = json.data
                
            catch error
                return

            if (h = @handlers[cmd])?
                h(data)
            else
                @queue.push cmd: cmd, data: data
                @queue.shift() while @queue.length > 20


    handleEnd: ->
        @endHandler() if @endHandler?
        @sock.end() if @sock?


    handleConnect: ->
        @handlers['connect']?()
        
    emit: (cmd, data) ->
        json = JSON.stringify
            cmd : cmd
            data: data

        try
            @sock.write json + "\n"
        catch error
            @handleEnd()

    emitRaw: (data) ->
        json = JSON.stringify data
       
        try
            @sock.write json + "\n"
        catch error
            @handleEnd()
            
    remoteAddress: ->
        @addr
        

class Client
    
    constructor: (@host, @port) ->
        @sock     = null
        @handlers = {}

        @connect @host, @port
    
    
    connect: (host, port) ->
        try
            socket = new net.Socket()
            socket.connect port, host
            @sock = new Socket socket, =>
                @sock = null
                @reconnect()
                
            for cmd, handler of @handlers
                @sock.on cmd, handler
        catch error
            
    
    reconnect: ->
        unless @sock?
            setTimeout =>
                @connect @host, @port
                @reconnect()
            , 2000
            
    
    on: (cmd, handler) ->
        @handlers[cmd] = handler
        @sock.on cmd, handler if @sock?
        
    emit: (msg, data) ->
        @sock.emit msg, data if @sock?

class Server
    
    constructor: (@port, @connectHandler, @endHandler) ->
        @serv     = null
        
        @handlers = {}
        @sockets  = []

        @listen(@port)
        
        
    listen: (port) ->
        @disconnect()
        
        @serv = net.createServer (stream) =>
            @handleConnection stream

        @serv.listen port, '0.0.0.0'
        
        io.socket "Server started on port #{port}"
        
        
    disconnect: ->
        @forAll (socket) ->
            socket.close()
            
        @serv.close() if @serv

    
    handleConnection: (stream) ->
        socket = new Socket stream, =>
            @endHandler socket
            @sockets.splice @sockets.indexOf(socket), 1
        
        for cmd, handler of @handlers
            socket.on cmd, (data) ->
                handler socket, data
            
        @sockets.push socket
        @connectHandler socket if @connectHandler?
        
    
    on: (cmd, handler) ->
        @handlers[cmd] = handler
        @forAll (socket) ->
            socket.on cmd, (data) ->
                handler socket, data
        
        
    forAll: (cb) ->
        cb(socket) for socket in @sockets
        

    broadcast: (cmd, data) ->
        @forAll (socket) ->
            socket.emit cmd, data
            
            
            
exports.Socket = Socket
exports.Server = Server
exports.Client = Client
