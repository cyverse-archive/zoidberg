request_handler = require('./request_handler')

#
# Creates a request for an unknown URL path.  This request handler overrides
# request_hander.handle so that it always responds with an error.
#
exports.create = () ->
    self = Object.create(request_handler.create(), {})

    # Handles an HTTP request.
    #
    # Parameters:
    #   method     - the HTTP request method.
    #   parsed_url - the parsed URL from the request.
    #   data       - the data from the HTTP request body.
    #   res        - the HTTP response object.
    #
    self.handle = (method, parsed_url, data, res) ->
        path = parsed_url.pathname
        msg = if path? then "#{path} not found" else "URL path was missing"
        console.log(msg)
        this.error(404, msg, res)

    return self
