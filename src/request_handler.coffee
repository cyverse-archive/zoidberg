#
# Creates a new request handler.
#
exports.create = () ->
    self = {}

    #
    # Sends an error response.
    #
    self.error = (code, msg, res) ->
        console.log "returning error response code " + code + ": " + msg
        res.writeHead(code, {
            'Content-Length' : msg.length,
            'Content-Type' : 'text/plain'
        })
        res.write(msg)
        res.end()
        return

    #
    # Handles a request.
    #
    self.handle = (method, parsed_url, data, res) ->
        sub_name = "do_" + method.toLowerCase()
        if this[sub_name]?
            sub = this[sub_name]
            sub.call(this, parsed_url, data, res)
        else
            this.error(400, "Unsupported HTTP request method: #{method}")
        return

    return self
