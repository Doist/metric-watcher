
class LimitedSizeStore

    constructor: (@limit=1000, @ensure_limit_rate=0.01) ->
        @store = {}
        @ts = {}

    keys: () ->
        (key for key of @store)

    values: () ->
        @store

    set: (key, value, ts=new Date().getTime() / 1000) ->
        key = key.toString()
        @store[key] = value
        @ts[key] = ts
        if Math.random() < @ensure_limit_rate
            @ensureLimit()
        return undefined

    get: (key) ->
        return [@store[key], @ts[key]]

    ensureLimit: () ->
        ts_list = ([k, v] for k, v of @ts)
        # sorted desc by timestamps
        ts_list.sort((v1, v2) -> v2[1] - v1[1])
        to_remove = ts_list.splice(@limit)
        for element in to_remove
            delete @store[element[0]]
            delete @ts[element[0]]
        return undefined

    toJSON: () ->
        ret = {}
        for key of @store
            ret[key] = @get(key)
        return ret

    load: (json) ->
        # Load data to store from JSON object
        # json object is a result of toJSON call:
        # key -> (value, timestamp)
        for key, value of json
            @store[key] = value[0]
            @ts[key] = value[1]


exports.LimitedSizeStore = LimitedSizeStore
