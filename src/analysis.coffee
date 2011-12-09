# -*- mode: coffee; tab-width: 4 -*-
util = require('util')
http = require('http')
querystring = require('querystring')

analysis_dao = require('./analysis_dao')
request_handler = require('./request_handler')

#
# Used to persist analyses
#
exports.create = (osm_conf, post_conf) ->
    self = Object.create(request_handler.create(), {})

    #
    # Creates an analysis DAO and automatcially sets up an error
    # event handler.
    #
    # Parameters:
    #   res - the response object to use when sending an error response.
    #
    # Returns:
    #   the analysis DAO
    #
    create_analysis_dao = (res) ->
        dao = analysis_dao.create osm_conf

        dao.on 'error', (err) ->
            self.error(500, err, res)

        return dao

    #
    # Creates the Post options when doing a post to the Analysis Import
    # service.
    #
    # Parameters:
    #   post_conf - Post configuration options
    #   data      - data to be posted
    #
    # Returns:
    #   options that can be passed to http.createClient
    #
    create_post_options = (post_conf, data) ->
        host    : post_conf.host
        port    : post_conf.port
        path    : post_conf.path
        method  : 'POST'
        headers :
            'Content-Type'   : 'application/json'
            'Content-Length' : data.length

    #
    # Changes the status of the given analysis to 'Published'.
    #
    # Parameters:
    #   analysis_json - the JSON describing the analysis.
    #   res           - the HTTP response object.
    #
    update_analysis_status = (analysis_json, res) ->
        dao = create_analysis_dao res
        dao.on 'unknown_analysis', (tito) ->
            self.error(500, "unknown analysis ID: #{tito}")
        analysis_json.status = 'Published'
        dao.update_analysis analysis_json, (tito) ->
            res.end tito

    #
    # Imports an analysis
    #
    # Parameters:
    #   analysis_json - Raw document to be imported.  Expects JSON.
    #   res           - Result object of the request.  Used for error reporting.
    #
    # Results:
    #
    self.import_analysis = (analysis_json, res) ->
        # Create the client and request to post to the import service
        post_options = create_post_options post_conf, analysis_json
        client       = http.createClient post_conf.port, post_conf.host
        post_req     = client.request 'POST', post_options.path, post_options

        console.log "Post options: \n" + JSON.stringify(post_options, null, 2)
        console.log "Post req: \n" + JSON.stringify(post_req, null, 2)

        post_req.on 'response', (endpoint_res) ->
            console.log 'Received response: ' + JSON.stringify(
                status  : endpoint_res.statusCode
                headers : endpoint_res.headers,
            null, 2)

            response_body = ''
            endpoint_res.on 'data', (chunk) ->
                response_body += chunk

            endpoint_res.on 'end', () ->
                # Check error status
                if endpoint_res.statusCode isnt 200
                    console.log "Error sending data. Received  #{endpoint_res.statusCode} from remote endpoint: #{response_body}"
                    self.error 400, response_body, res
                else
                    update_analysis_status analysis_json, res

        post_req.end JSON.stringify(analysis_json)

    #
    # Handles HTTP PUT requests.  Call through to POST (they preform the same
    # operations).  See do_post for more information.
    #
    self.do_put = (parsed_url, data, res) ->
        console.log("top of do_put - data = " + data)
        self.do_post parsed_url, data, res

    #
    # Handles HTTP POST requests.  Saves an analysis to the osm and imports it.
    #
    # Parameters:
    #   parsed_url - Parsed request url
    #   data       - Data passed to this post request.  Contains the document
    #                to import.
    #   res        - Response object used to report results
    self.do_post = (parsed_url, data, res) ->
        console.log("top of do_post - data = " + data)
        try
            dao = create_analysis_dao res
            analysis = JSON.parse data

            if not analysis.user?
                self.error(400, "Missing 'user' field from JSON.\n", res)

            if (analysis.tito? && analysis.tito != '')
                console.log "attempting to update analysis #{analysis.tito}"
                dao.update_analysis analysis, (obj_id) ->
                    self.find_and_import_analysis dao, obj_id, res
            else
                console.log "saving new analysis #{analysis.name}"
                dao.save_analysis analysis, (obj_id) ->
                    self.find_and_import_analysis dao, obj_id, res

        catch err
            console.log(err)
            self.error(500, err.toString(), res)

    #
    # Finds an analysis and imports it into the DE.
    #
    # Parameters:
    #   dao    - the analysis DAO.
    #   obj_id - the analysis identifier.
    #   res    - the HTTP response object.
    #
    self.find_and_import_analysis = (dao, obj_id, res) ->
        req_query =
            id: obj_id

        dao.get_analyses req_query, (retdoc) ->
            if (retdoc.length == 0)
                msg = "analysis #{obj_id} not found"
                console.log msg
                self.error 500, msg, res
            else
                console.log "analysis #{obj_id} found - updating"
                self.import_analysis retdoc[0], res

    #
    # Handles HTTP GET requests.  Used to process analysis.
    #
    # Parameters:
    #   parsed_url - Parsed request url
    #   data       - data passed to this get request
    #   res        - response object used to write back response data
    #
    # Returns:
    #   Nothing
    #
    self.do_get = (parsed_url, data, res) ->
        console.log("top of do_get - data = " + data);
        try
            dao = create_analysis_dao res

            if not parsed_url.query? or not parsed_url.query.id?
                self.error 400, "Missing ID of analysis", res

            retval = dao.get_analyses parsed_url.query, (data) ->
                console.log 'grabbed analysis from osm'

                # Make sure we got somthing back before we process
                if data.length isnt 0
                    post_data = data[0]
                    console.log JSON.stringify(post_data)

                    # Import the analysis
                    self.import_analysis post_data, res
                else
                    console.log 'No data for id'
                    self.error 400, 'No data for id.', res

        catch err
            console.log err
            @error 400, err.stack, res

    return self
