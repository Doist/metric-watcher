# LimiterSizeStore is basically a key-value store with limited capacity.
# For every key, stored with the "set" method, it keeps an insertion/update
# timestamp and a number of times the value has been updated.
# Then periodically the store is cleaned up by removing oldest records.
#
# You may set up the store limit, the frequency of "cleaning up procedure",

class LimitedSizeStore

    constructor: (@limit=1000, @ensure_limit_rate=0.01) ->
        @store = {}
        @ts = {}
        @cnt = {}

    keys: () ->
        (key for key of @store)

    values: () ->
        @store

    set: (key, value, ts=new Date().getTime() / 1000) ->
        key = key.toString()
        @store[key] = value
        @ts[key] = ts
        @cnt[key] = (@cnt[key] or 0) + 1
        if Math.random() < @ensure_limit_rate
            @ensureLimit()
        return undefined

    get: (key) ->
        return [@store[key], @ts[key], @cnt[key] or 0]

    ensureLimit: () ->
        ts_list = ([k, v] for k, v of @ts)
        # sorted desc by timestamps
        ts_list.sort((v1, v2) -> v2[1] - v1[1])
        to_remove = ts_list.splice(@limit)
        for element in to_remove
            delete @store[element[0]]
            delete @ts[element[0]]
            delete @cnt[element[0]]
        return undefined

    dump: (cnt_threshold=0) ->
        # Dump data to JSON
        # @cnt_limit prevents records from returning, unless they were
        # updated at least certain amount of time.
        ret = {}
        for key of @store
            if cnt_threshold == 0 or @cnt[key] >= cnt_threshold
                ret[key] = @get(key)
        return ret

    toJSON: () -> @dump(cnt_limit=0)

    load: (json) ->
        # Load data to store from JSON object
        # json object is a result of toJSON call:
        # key -> (value, timestamp)
        for key, value of json
            @store[key] = value[0]
            @ts[key] = value[1]
            @cnt[key] = value[2]


exports.LimitedSizeStore = LimitedSizeStore
