# -*- mode: coffee; tab-width: 4 -*-
util = require('util')

analysis_dao = require('./analysis_dao')
request_handler = require('./request_handler')

#
# Creates a make-public request handler.
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
    # Recursively makes a list of analyses public.
    #
    # Parameters:
    #   res      - the HTTP response object
    #   dao      - the analysis DAO
    #   analyses - the list of analyses
    #   index    - the index of the current analysis
    #
    make_public = (res, dao, analyses, index) ->
        if index < analyses.length
            analysis = analyses[index]
            analysis.is_public = true
            dao.update_analysis analysis, (tito, data) ->
                make_public(res, dao, analyses, index + 1)
        else
            res.end()

    #
    # Handles an HTTP POST request.
    #
    # Parameters:
    #   parsed_url - the parsed URL from the request.
    #   data       - the data from the HTTP request body.
    #   res        - the HTTP response object.
    #
    self.do_post = (parsed_url, data, res) ->
        try
            if not parsed_url.query?
                this.error(400, "Missing query info from path\n", res)
            else
                if not parsed_url.query.user? or not parsed_url.query.tito?
                    this.error(400, "Missing 'user' or 'tito' query string parameter", res)
                else
                    dao = create_analysis_dao(res)
                    dao.get_analyses parsed_url.query, (analyses) ->
                        make_public(res, dao, analyses, 0)

        catch err
            console.log(err)
            self.error(500, err.toString(), res)

    return self
