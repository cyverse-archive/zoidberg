http = require('http')
path = require('path')
fs = require('fs')
url = require('url')

in_progress = require('./in_progress')
unknown = require('./unknown')
uuid = require('./uuid')
analysis = require('./analysis')
make_public = require('./make_public')

#
# Reads and validates the configuration file.
#
# Returns:
#   the configuration as a JavaScript object.
#
get_conf = () ->
    conf_file = process.argv[2]

    if not path.existsSync(conf_file)
        console.log("File #{conf_file} doesn't exist.")
        process.exit(1)

    conf = JSON.parse(fs.readFileSync(conf_file))

    if not conf['port']?
        console.log("Missing port option in #{conf_file}.")
        process.exit(1)

    if not conf['osm_base']?
        console.log("Missing osm_base option in #{conf_file}.")
        process.exit(1)

    if not conf['osm_bucket']?
        console.log("Missing osm_bucket option in #{conf_file}.")
        process.exit(1)

    if not conf['logfile']?
        console.log("Missing logfile option in #{conf_file}.")
        process.exit(1)

    if not conf['analysis_publisher']?
        console.log("Missing analysis_publisher option in #{conf_file}.")
        process.exit(1)

    return conf

#
# Sets up logging to a file.
#
# Params:
#   log_file - String containing the path to a file or 'stdout' if
#      you want logging to stay on stdout.
#
setup_logging = (log_file) ->
    if log_file != "stdout"
        out_stream = fs.createWriteStream(log_file, {'flags' : 'a'})
        console.log = (msg) ->
            now = new Date()
            out_stream.write("[#{now.toString()}] #{msg}\n")

#
# Writes out the processes PID to a file.
#
# Params:
#   pidfile - The path to the file that should contain the pid.
#
write_pid = () ->
    pid_file = process.argv[3] or "/var/run/zoidberg.pid"
    console.log("Writing PID #{process.pid} to file #{pid_file}")
    fs.writeFileSync(pid_file, "#{process.pid}")
    console.log("Done writing PID #{process.pid} to file #{pid_file}")

#
# Pipes a request for a particular path to another service.
# The response from the other service then becomes the response
# from this service.
#
# Params:
#   svr_req - The ReadableStream created by a client hitting this
#       service
#
#   svr_resp - The WriteableStream representing this service's response
#       to the request.
#
#   out_conf - An object describing the port, path, and host of the
#       external service to call.
#
pipe_request = (svr_req, svr_resp, out_conf) ->
    data = ""

    svr_req.on('data', (chunk) -> data += chunk)

    svr_req.on 'end', () ->
        console.log("Received a #{svr_req.method} request on #{svr_req.url}.")
        console.log("Forwarding request to #{out_conf.host}:#{out_conf.port}#{out_conf.path}.")

        out_req_opts =
            method : svr_req.method
            port : out_conf.port
            path : out_conf.path
            host : out_conf.host

        out_req = http.request out_req_opts, (out_resp) ->
            out_resp.pipe(svr_resp)

        out_req.on 'error', (err) ->
            console.log(err)
            msg = "unable to connect to #{out_conf.host}: #{err.message}"
            console.log(msg)

            headers =
                'Content-Length' : msg.length,
                'Content-Type' : 'text/plain'
            svr_resp.writeHead('500', headers)
            svr_resp.write(msg)
            svr_resp.end()

        out_req.write(data)
        out_req.end()

#
# Creates the entry point for the HTTP server.
#
# Parameters:
#   conf - the process configuration.
#
# Returns:
#   the entry point.
#
create_entry_point = (conf) ->
    osm_conf =
        'base':  conf.osm_base,
        'bucket': conf.osm_bucket

    # URLs that are pass-throughs to DE services.
    de_base = conf.de_base ? ''
    de_services = conf.de_services ? {}

    #
    # Concatenates two components of a URL path.
    #
    # Parameters:
    #   head - the first component of the URL path.
    #   tail - the second component of the URL path.
    # Returns:
    #   the full URL path.
    #
    concatenate_path = (head, tail) ->
        "#{head.replace(/\/$/, '')}/#{tail.replace(/^\//, '')}"

    #
    # Builds the settings used to forward a request to the DE.
    #
    # Parameters:
    #   path - the relative path to use when forwarding requests to the DE.
    # Returns:
    #   the request settings to pass to pipe_request.
    #
    build_de_request_settings = (path) ->
        de_settings = url.parse(de_base)
        result =
            'host' : de_settings.hostname
            'port' : de_settings.port
            'path' : concatenate_path(de_settings.pathname, path)
        result

    # The configurations used by the publish and export services.
    post_conf = build_de_request_settings(conf.analysis_publisher)

    # URLs that are pass-throughs to other services
    pass_thrus = conf.passthru ? {}

    # The various request handlers.
    handler_for =
        '/in-progress'     : in_progress.create(osm_conf)
        '/uuid'            : uuid.create()
        '/analysis-import' : analysis.create(osm_conf, post_conf)
        '/make-public'     : make_public.create(osm_conf)
    unknown_handler = unknown.create()

    #
    # Extracts the field names from a DE forwarding URL pattern.
    #
    # Parameters:
    #   pattern - the URL pattern.
    # Returns:
    #   the array of field names.
    #
    extract_field_names = (pattern) ->
        regex = /\/\{([^\}]+)\}/g
        match = regex.exec(pattern)
        while match?
            result = match[1]
            match = regex.exec(pattern)
            result

    #
    # Extracts the field values from a path for the corresponding URL pattern.
    #
    # Parameters:
    #   fields  - the array of field names.
    #   pattern - the URL pattern.
    #   path    - the path from the incoming request.
    # Returns:
    #   a map of field names to field values or undefined if the path doesn't
    #   match the pattern.
    #
    extract_values = (fields, pattern, path) ->
        values = path.match(new RegExp(pattern.replace(/\/\{[^\}]+\}/g, "(?:\\/([^/]+)|$)")));
        if values?
            result = {}
            for i of fields
                result[fields[i]] = values[parseInt(i) + 1]
            return result
        return

    #
    # Gets the path to use when forwarding a request to the DE.
    #
    # Parameters:
    #   path - the path from the incoming request.
    # Returns:
    #   the path to forward the request to or undefined if the request
    #   shouldn't be forwarded to the DE.
    #
    get_de_path = (path) ->
        for pattern of de_services
            fields = extract_field_names(pattern)
            values = extract_values(fields, pattern, path)
            if values?
                key_regex = new RegExp("{(#{fields.join("|")})(?:\\|([^}]+))?}", "g")
                return de_services[pattern].replace key_regex, (match, field_name, default_value) ->
                    values[field_name] ? default_value
        return

    #
    # Forwards a request to the DE if the request should be forwarded to the DE.
    #
    # Parameters:
    #   req  - the incoming request.
    #   res  - the response.
    #   path - the path from the request URL.
    # Returns:
    #   true if the request was forwarded to the DE.
    #
    handle_de_proxy = (req, res, path) ->
        de_path = get_de_path(path)
        if de_path?
            pipe_request(req, res, build_de_request_settings(de_path))
        de_path?

    #
    # Serves as the entry point for the HTTP server.  This function reads the
    # body of the HTTP request and passes control to the appropriate request
    # handler for processing.
    #
    # Parameters:
    #   req - the HTTP request object.
    #   res - the HTTP response object.
    #
    entry_point = (req, res) ->
        url_parts = url.parse(req.url, parseQueryString=true)
        url_path = if url_parts.pathname? then url_parts.pathname else ""

        if pass_thrus[url_path]?
            pipe_request(req, res, pass_thrus[url_path])
        else if handle_de_proxy(req, res, url_path)
            console.log("request for #{url_path} forwarded to DE")
        else
            data = ""

            req.on('data', (chunk) -> data += chunk.toString())

            req.on 'end', () ->
                url_parts = url.parse(req.url, parseQueryString=true)
                path = if url_parts.pathname? then url_parts.pathname else ""
                handler = handler_for[path]
                handler ?= unknown_handler
                handler.handle(req.method, url_parts, data, res)

    return entry_point

#
# Creates the entry point and runs the HTTP server.
#
main = () ->
    conf = get_conf()
    setup_logging(conf.logfile)
    write_pid()
    http.createServer(create_entry_point(conf)).listen(parseInt(conf.port))

main()
