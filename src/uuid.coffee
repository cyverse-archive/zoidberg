request_handler = require('./request_handler')

exports.create = (osm) ->
    self = Object.create(request_handler.create(), {})
    
    create_uuid = () ->
        return 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'.replace /[x]/g, (c) ->
            r = Math.random() * 16|0
            v = if c == 'x' then r else (r&0x3|0x8)
            return v.toString(16).toUpperCase()
            
    self.do_get = (parsed_url, data, res) ->
        res.end(create_uuid())
    
    return self