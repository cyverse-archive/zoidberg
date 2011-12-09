events = require('events')
http = require('http')
url = require('url')

#
# Creates an OSM client.
#
# Parameters:
#   osm_base   - the base URL to use to connect to the OSM.
#   osm_bucket - the OSM bucket to use.
#
exports.create = (osm_base, osm_bucket) ->
    osm = Object.create new events.EventEmitter, {}
    osm_settings = url.parse(osm_base)

    #
    # Builds the full path to the OSM resource that is being accessed, taking
    # care to avoid adding a double slash.
    #
    # Parameters:
    #   relative_path - the relative path to the resource
    # Returns:
    #   the absolute path to the resource.
    #
    build_full_path = (relative_path) ->
        base_path = osm_settings.pathname || '';
        base_path.replace(/\/$/, '') + '/' + relative_path.replace(/^\//, '')

    #
    # Builds the request options for the given relative path and HTTP request
    # method.
    #
    # Parameters:
    #   relative_path - the relative path to the resource
    #   method        - the HTTP method to use.
    # Returns:
    #   the HTTP request options.
    #
    build_request_opts = (relative_path, method) ->
        host : osm_settings.hostname
        port : osm_settings.port
        path : build_full_path(relative_path)
        method : method

    #
    # Asynchronously gets an object from the OSM.
    #
    # Parameters:
    #   obj_id   - the object identifier.
    #   callback - called when the object has been retrieved.
    #
    osm.get = (obj_id, callback) ->
        req_opts = build_request_opts("/#{osm_bucket}/#{obj_id}", 'GET')

        req = http.get req_opts, (res) ->
            data = ""
            res.on('data', (chunk) -> data += chunk.toString())
            res.on('end', () -> callback(obj_id, data))

        req.on 'error', (err) ->
            osm.emit 'error', err

    #
    # Asynchronously updates an object in the OSM.
    #
    # Parameters:
    #   obj_id   - the object identifier.
    #   obj      - the updated object.
    #   callback - called when the response is received from the OSM.
    #
    osm.set = (obj_id, obj, callback) ->
        req_opts = build_request_opts("/#{osm_bucket}/#{obj_id}", 'POST')

        req = http.request req_opts, (res) ->
            data = ""
            res.on('data', (chunk) -> data += chunk.toString())
            res.on('end', () -> callback(obj_id, data))

        req.on 'error', (err) ->
            osm.emit 'error', err

        req.write(JSON.stringify(obj))
        req.end()

    #
    # Asynchronously adds an object to the OSM.
    #
    # Parameters:
    #   obj      - the object to insert into the OSM.
    #   callback - called when the response is received from the OSM.
    #
    osm.add = (obj, callback) ->
        req_opts = build_request_opts("/#{osm_bucket}", 'POST')

        req = http.request req_opts, (res) ->
            data = ""
            res.on('data', (chunk) -> data += chunk.toString())
            res.on('end', () -> callback(data))

        req.on 'error', (err) ->
            osm.emit 'error', err

        req.write(JSON.stringify(obj))
        req.end()

    #
    # Asynchronously searches the OSM for documents that match the given
    # query.
    #
    # Parameters:
    #   query_obj - the object representing the OSM query.
    #   callback  - called when the response is received from the OSM.
    #
    osm.query = (query_obj, callback) ->
        req_opts = build_request_opts("/#{osm_bucket}/query", 'POST')

        req = http.request(req_opts, (res) ->
            data = ""
            res.on('data', (chunk) -> data += chunk.toString())
            res.on('end', () -> callback(data)))

        req.on 'error', (err) ->
            osm.emit 'error', err

        req.write(JSON.stringify(query_obj))
        req.end()

    #
    # Queries the OSM for a given TITO ID and passes true or false
    # to the callback depending on whether or not the object exists.
    #
    # Parameters:
    #     tito_id - the TITO ID to look for
    #     callback - called when the response is received from the OSM
    #         and is passed true or false.
    #
    osm.exists = (tito_id, callback) ->
        req_opts = build_request_opts("/#{osm_bucket}/query", 'POST')

        req = http.request req_opts, (res) ->
            data = ""
            res.on('data', (chunk) -> data += chunk.toString())
            res.on 'end', () ->
                try
                    retval = false
                    osm_objs = JSON.parse(data)
                    if osm_objs.objects.length > 0
                        retval = true
                    callback(retval)
                catch err
                    msg = "unable to parse OSM response: #{err}"
                    console.log msg
                    osm.emit 'error', err

        req.on 'error', (err) ->
            osm.emit 'error', err

        req.write(JSON.stringify({"state.tito" : tito_id}))
        req.end()

    return osm

