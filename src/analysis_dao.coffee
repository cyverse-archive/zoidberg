# -*- mode: coffee; tab-width: 4 -*-
events = require('events')
util = require('util')

osm_client = require('./osm_client')

#
# Creates an analysis DAO.
#
# Parameters:
#   osm_conf - the OSM configuration settings.
#
exports.create = (osm_conf) ->
    self = Object.create new events.EventEmitter, {}

    #
    # Creates an OSM client and automatically sets up an error event
    # handler for it.
    #
    # Returns:
    #   the OSM client
    #
    create_osm_client = () ->
        osm = osm_client.create osm_conf.base, osm_conf.bucket

        osm.on 'error', (err) ->
            console.log err
            msg = "unable to connect to OSM: " + err.toString()
            self.emit "error", msg;

        return osm

    #
    # Determines whether or not an analysis has properties.
    #
    # Parameters:
    #   obj - the object representing the analysis.
    # Returns:
    #   true if the analysis has properties.
    #
    analysis_has_properties = (obj) ->
        groups = obj.groups.groups ? []
        return (group for group in groups when group.properties? and group.properties.length > 0).length > 0

    #
    # Determines whether or not an analysis is publishable.
    #
    # Parameters:
    #   obj - the object representing the analysis.
    # Returns:
    #   true if the analysis is publishable.
    #
    analysis_publishable = (obj) ->
        result = obj.is_publishable
        if not result?
            component_selected = obj.component_id? and obj.component_id != ''
            analysis_named = obj.name? and obj.name != ''
            has_properties = analysis_has_properties(obj)
            result = component_selected and analysis_named and has_properties
        return result

    #
    # Determines whether or not all properties in a property group are
    # ordered.
    #
    # Parameters:
    #   group - the object representing the property group.
    # Returns:
    #   true if all properties in the group are ordered.
    #
    group_ordered = (group) ->
        props = group.properties ? []
        ordered_props = (prop for prop in props when prop.order? and prop.order > 0)
        return props.length == ordered_props.length

    #
    # Determines whether or not all properties in an analysis are ordered.
    #
    # Parameters:
    #   obj - the object representing the analysis.
    # Returns:
    #   true if all properties in the analysis are ordered.
    #
    analysis_ordered = (obj) ->
        groups = obj.groups.groups ? []
        ordered_groups = (group for group in groups when group_ordered(group))
        return groups.length == ordered_groups.length

    #
    # Summarizes the results for a single in-progress workflow.
    #
    # Parameters:
    #   obj - the object representing the in-progress workflow.
    # Returns:
    #   the summarized workflow.
    #
    build_summary = (obj) ->
        "tito": obj.tito,
        "name": obj.name,
        "status": obj.status or "Not published",
        "edited_date": obj.edited_date or "",
        "published_date": obj.published_date or "",
        "is_public": obj.is_public or false,
        "is_publishable": analysis_publishable(obj),
        "is_ordered": analysis_ordered(obj)

    #
    # Summarizes the results for in-progress workflows.
    #
    # Parameters:
    #   results - the original results.
    #
    # Returns:
    #   the summarized results.
    #
    summarize = (results) ->
        (build_summary(obj) for obj in results)

    #
    # Removes leading and trailing whitespace from a string.
    #
    # Parameters:
    #   str - the string to trim.
    #
    # Returns:
    #   the trimmed string.
    #
    trim = (str) -> str.replace(/^\s/g, '').replace(/\s$/g, '')

    #
    # Gets one or more analyses.
    #
    # Parameters:
    #   req_query - the query from the request.
    #   callback  - function called back when results have been recieved from OSM.
    #               Note that this will summarize for us.
    #
    # Returns:
    #   None
    #
    self.get_analyses = (req_query, callback) ->
        osm = create_osm_client()
        query = {}

        if req_query.user?
            query["state.user"] = req_query.user

        if req_query.tito?
            query["state.tito"] = req_query.tito

        if req_query.id?
            query["state.id"] = req_query.id

        osm.query query, (data) ->
            try
                res_obj = JSON.parse data
                retval = (obj.state for obj in res_obj.objects when not obj.state.deleted)
                if req_query.summary? and req_query.summary == 'true'
                    retval = summarize retval
                callback retval
            catch err
                msg = "unable to parse OSM response: #{err}"
                console.log msg
                self.emit 'error', msg

    #
    # Saves a new analysis.
    #
    # Parameters:
    #   data_obj - the object representing the analysis.
    #   callback - function called back when results have been received from OSM.
    #
    # Returns:
    #    None
    #
    self.save_analysis = (data_obj, callback) ->
        data_obj.deleted = false

        osm = create_osm_client()
        osm.add data_obj, (res_data) ->
            osm_id = trim res_data

            osm.get osm_id, (tito_id, tito_data) ->
                try
                    tito_obj = JSON.parse(tito_data).state
                    tito_obj.tito = trim tito_id
                    tito_obj.id = trim tito_id
                    osm.set tito_id, tito_obj, (obj_id, obj_data) ->
                        callback obj_id, obj_data
                catch err
                    msg = "unable to parse OSM response: #{err}"
                    console.log msg;
                    self.emit 'error', msg;

    #
    # Updates an existing analysis.
    #
    # Parameters:
    #   data_obj - the object representing the analysis.
    #   callback - function called back when results have been received from OSM.
    #
    # Returns:
    #   None
    #
    self.update_analysis = (data_obj, callback) ->
        osm = create_osm_client()
        osm.exists data_obj.tito, (obj_exists) ->
            if obj_exists
                osm.set data_obj.tito, data_obj, (obj_id, res_data) ->
                    callback obj_id
            else
                self.emit "unknown_analysis", data_obj.tito

    #
    # Deletes an existing analysis.
    #
    # Parameters:
    #   data_obj - the object representing the analysis.
    #   callback - function called back when results have been received from OSM.
    #
    # Returns:
    #   None
    #
    self.delete_analysis = (data_obj, callback) ->
        data_obj.deleted = true
        self.update_analysis data_obj, callback

    return self
