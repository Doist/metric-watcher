class MetricWatcher

    constructor: (@plotter) ->
        @chosen_metrics = []
        @stores = {}

    init: () ->
        @metrics_container = $("#id-metrics-container")
        @socket = io.connect("http://localhost:1234")
        $.getJSON("/metrics/dump", (data) =>
            for k, v of data
                store = new LimitedSizeStore()
                store.load(v)
                @stores[k] = store
            @displayMetricsList()
            @socket.on("set_store_values", (data) => @setStoreValues(data))
        )

    setStoreValues: (data) ->
        for record in data
            [store_key, key, value, ts] = record
            store = @stores[store_key]
            if not store
                store = new LimitedSizeStore()
                @stores[store_key] = store
            store.set(key, value, ts)
            @displayMetricsList()
            @onChosenMetricUpdated_markList()
            @onChosenMetricUpdated_redraw()

    displayMetricsList: () ->
        @metrics_container.empty()
        keys = (name for name of @stores)
        keys.sort()
        for name in keys
            count = (id for id of @stores[name].values()).length
            li = $('<li class="metric-list-item">')
                    .attr("data-name", name)

            a = $('<a href="">')
                    .text("#{name} ")
                    .attr("data-name", name)
                    .click((e) =>
                        @toggleMetric($(e.delegateTarget).attr("data-name"))
                    )
                    .append($('<span class="badge">').text(count))
            @metrics_container.append(li.append(a))

    toggleMetric: (name) ->
        idx = $.inArray(name, @chosen_metrics)
        if idx > -1
            @chosen_metrics.splice(idx, 1)
        else
            @chosen_metrics.push(name)
            if @chosen_metrics.length > 2
                @chosen_metrics.shift()
        @onChosenMetricUpdated_markList()
        @onChosenMetricUpdated_redraw()
        return false

    onChosenMetricUpdated_markList: () ->
        $("li.metric-list-item").removeClass("active")
        for metric in @chosen_metrics
            $("li[data-name=\"#{metric}\"]").addClass("active")

    onChosenMetricUpdated_redraw: () ->
        if @chosen_metrics.length == 0
            return

        if @chosen_metrics.length == 2
            xdata = @stores[@chosen_metrics[0]].values()
            xlabel = @chosen_metrics[0]
            ydata = @stores[@chosen_metrics[1]].values()
            ylabel = @chosen_metrics[1]
        else if @chosen_metrics.length == 1
            xdata = map_object(@stores[@chosen_metrics[0]].values(), (v) -> Math.random())
            xlabel = 'random'
            ydata = @stores[@chosen_metrics[0]].values()
            ylabel = @chosen_metrics[0]
        plotter.plotData(xdata, ydata, xlabel, ylabel)



class Plotter

    constructor: (@svg=d3.select("svg"), @r=3, @pad=40, @left_pad=60) ->
        @w = $("svg").width()
        @h = $("svg").height()

    plotData: (xdata, ydata, xlabel, ylabel) ->
        $("svg").empty()
        data = @mergeData(xdata, ydata)
        values = ([k, v[0], v[1]] for k, v of data)

        xscale = d3.scale.linear()
                        .domain([0, d3.max(values, (d) -> d[1] )])
                        .range([@left_pad, @w-@pad]).nice();

        xaxis = d3.svg.axis().scale(xscale).orient("bottom")

        yscale = d3.scale.linear()
                        .domain([0, d3.max(values, (d) -> d[2] )])
                        .range([@h-@pad, @pad]).nice()

        yaxis = d3.svg.axis().scale(yscale).orient("left")

        @svg.append("g")
            .attr('transform', "translate(0,#{(@h-@pad)})")
            .attr("class", "axis")
            .call(xaxis)
        @svg.append("g")
            .attr('transform', "translate(#{@left_pad},0)")
            .attr("class", "axis")
            .call(yaxis)

        # x title
        @svg.append("text").text(xlabel)
            .attr("class", "xlabel")
            .attr("x", Math.round(@w / 2)).attr("y", @h - 8)

        # y title
        ylabel_ypos = Math.round(@h / 2)
        @svg.append("text").text(ylabel)
            .attr("class", "ylabel")
            .attr("transform", "rotate(270, 20, #{ylabel_ypos})")
            .attr("x", 20).attr("y", ylabel_ypos)


        g_objs = @svg.selectAll("g.circ").data(values).enter()
            .append("g")
            .attr("class", "circ")

        g_objs.append("circle")
            .attr("r", @r)
            .attr("cx", (d) -> xscale(d[1]))
            .attr("cy", (d) -> yscale(d[2]))

        g_objs.append("text")
            .text((d) -> d[0])
            .attr("text-anchor", "middle")
            .attr("x", (d) -> xscale(d[1]))
            .attr("y", (d) => yscale(d[2]) - @r - 3)

    mergeData: (data1, data2) ->
        ret = {}
        for k, v of data1
            if v is null
                continue
            v2 = data2[k]
            if v2?
                ret[k] = [v, v2]
        return ret


# helper functions
map_object = (obj, func) ->
    ret = {}
    for key, value of obj
        ret[key] = func(value)
    return ret

# Global objects

plotter = new Plotter()
metric_watcher = new MetricWatcher(plotter)

$( ->
    metric_watcher.init()
)
