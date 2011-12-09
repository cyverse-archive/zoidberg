# -*- mode: coffee; tab-width: 4 -*-
events = require('events')
http = require('http')
util = require('util')

#
# Creates a new simple HTTP client.
#
# Parameters:
#   conf - the client's configuration settings.
#
exports.create = (conf) ->
    self = Object.create new events.EventEmitter, {}

    #
    # Builds the full path to the resource we're trying to access.
    #
    # Params:
    #   relative_path - the relative path to the resource
    # Returns
    #   the full path to the resuorce.
    #
    build_full_path = (relative_path) ->
        base_path = conf.path || ''
        base_path.replace(/\/$/, '') + '/' + relative_path.replace(/^\//, '')

    #
    # Builds the request options for the the given relative path and HTTP
    # request method.
    #
    # Params:
    #   relative_path - the relative path to the resource
    #   method        - the HTTP request method
    # Returns:
    #   the full path to the resource.
    #
    build_request_opts = (relative_path, method) ->
        host : conf.host
        port : conf.port
        path : build_full_path(relative_path)
        method : method

    #
    # Performs an HTTP get request.
    #
    # Params:
    #   relative_path - the relative path to the resource
    #   body          - the request body
    #
    self.get = (relative_path, body) ->
        req_opts = build_request_opts(relative_path)

        req = http.request req_opts, (res) ->
            data = ''
            res.on 'data', (chunk) ->
                data += chunk.toString()
            res.on 'end', () ->
                self.emit('response', data)

        req.on 'error', (err) ->
            self.emit('error', err)

        if body?
            req.write(body)

        req.end()

    self
