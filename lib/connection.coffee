debug = require('debug')('livereload:server')

{ EventEmitter } = require 'events'

Parser = require 'livereload-protocol'

HandshakeTimeout = 1000


class LRWebSocketConnection extends EventEmitter
  constructor: (@socket, @id, @options) ->
    protocols =
      monitoring: [Parser.protocols.MONITORING_7]
      conncheck:  [Parser.protocols.CONN_CHECK_1]

    if @options.protocols.saving >= 1
      protocols.saving = [Parser.protocols.SAVING_1]

    @parser = new Parser 'server', protocols

    @socket.on 'message', (data) =>
      debug "LRWebSocketConnection(#{@id}) received #{data}"
      @parser.received(data)

    @socket.on 'error', (err) =>
      debug "LRWebSocketConnection(#{@id}) got an error #{err}"
      @emit 'error', err

    @socket.on 'close', =>
      (clearTimeout @_handshakeTimeout; @_handshakeTimeout = null) if @_handshakeTimeout
      @emit 'disconnected'

    @parser.on 'error', (err) =>
      @socket.close()
      @emit 'error', err

    @parser.on 'command', (command) =>
      if command.command is 'ping'
        @send { command: 'pong', token: command.token }
      else
        @emit 'command', command

    @parser.on 'connected', =>
      (clearTimeout @_handshakeTimeout; @_handshakeTimeout = null) if @_handshakeTimeout
      @send @parser.hello(@options)
      @emit 'connected'

    @_handshakeTimeout = setTimeout((=> @_handshakeTimeout = null; @socket.close()), HandshakeTimeout)

  close: ->
    @socket.close()

  send: (command) ->
    @parser.sending command
    @socket.send JSON.stringify(command)

  isMonitoring: ->
    @parser.negotiatedProtocols?.monitoring >= 7


module.exports = LRWebSocketConnection

