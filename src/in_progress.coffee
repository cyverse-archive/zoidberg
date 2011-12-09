# -*- mode: coffee; tab-width: 4 -*-
util = require('util')

analysis_dao = require('./analysis_dao')
request_handler = require('./request_handler')

#
# Creates an in-progress request handler.
#
# Parameters
#   osm_conf - the OSM configuration settings.
#
exports.create = (osm_conf) ->
    self = Object.create(request_handler.create(), {})

    #
    # Creates an analysis DAO and automatcially sets up error and
    # unknown_analysis event handlers.
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

        dao.on 'unknown_analysis', (id) ->
            self.error(400, "TITO ID #{id} doesn't exist.", res)

        return dao

    #
    # Handles an HTTP GET request.
    #
    # Parameters:
    #   parsed_url - the parsed URL from the request.
    #   data       - the data from the HTTP request body.
    #   res        - the HTTP response object.
    #
    self.do_get = (parsed_url, data, res) ->
        try
            if not parsed_url.query?
                this.error(400, "Missing query info from path.\n", res)
            else
                if not parsed_url.query.user? and not parsed_url.query.tito?
                    this.error(400, "Missing both the tito and user fields from query.", res)
                else
                    dao = create_analysis_dao res
                    dao.get_analyses parsed_url.query, (retval) ->
                        res.end JSON.stringify({'objects' : retval}) + "\n"

        catch err
            console.log(err)
            self.error(500, err.toString(), res)

    #
    # Handles an HTTP PUT request.
    #
    # Parameters:
    #   parsed_url - the parsed URL from the request.
    #   data       - the data from the HTTP request body.
    #   res        - the HTTP response object.
    #
    self.do_put = (parsed_url, data, res) ->
        try
            data_obj = JSON.parse(data)

            if not data_obj.user?
                self.error(400, "Missing 'user' field from JSON.\n", res)
            else
                dao = create_analysis_dao res
                dao.save_analysis data_obj, (retval) ->
                    res.end retval

        catch err
            console.log(err)
            self.error(500, err.toString(), res)

    #
    # Handles an HTTP POST request.
    #
    # Parameters:
    #   parsed_url - the parsed URL from the request.
    #   data       - the data from the HTTP request body.
    #   res        - the HTTP response object.
    #
    # Comments:
    #   The Java HTTP client library that the UI is using doesn't allow
    #   DELETE requests with a body, so a POST with an "action" element
    #   set to "delete" is treated as a DELETE request.
    #
    self.do_post = (parsed_url, data, res) ->
        try
            data_obj = JSON.parse(data)

            if data_obj.action? && data_obj.action == "delete"
                self.do_delete parsed_url, data, res
                return

            if not data_obj.user? || not data_obj.tito?
                self.error(400, "Missing 'user' or 'tito' field from JSON.\n", res)
            else
                dao = create_analysis_dao res
                dao.update_analysis data_obj, (obj_id) ->
                    res.end obj_id

        catch err
            console.log(err)
            self.error(500, err.toString(), res)

    #
    # Handles an HTTP DELETE request.
    #
    # Parameters:
    #   parsed_url - the parsed URL from the request.
    #   data       - the data from the HTTP request body.
    #   res        - the HTTP response object.
    #
    self.do_delete = (parsed_url, data, res) ->
        try
            data_obj = JSON.parse(data)

            if not data_obj.user? || not data_obj.tito?
                self.error(400, "Missing 'user' or 'tito' field from JSON.\n", res)
            else
                dao = create_analysis_dao res
                dao.delete_analysis data_obj, (obj_id) ->
                    res.end obj_id

        catch err
            console.log(err)
            self.error(500, err.toString(), res)

    return self
