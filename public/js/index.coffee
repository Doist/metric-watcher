class Plotter

    constructor: (@svg=d3.select("svg"), @r=3, @pad=40, @left_pad=60) ->
        @w = $("svg").width()
        @h = $("svg").height()

    plot: (metric1, metric2) ->
        $.when(
            $.getJSON("/metrics/get?name=#{metric1}"),
            $.getJSON("/metrics/get?name=#{metric2}")
        ).done((data1, data2 ) => @plotData(data1[0], data2[0], metric1, metric2))

    plotData: (data1, data2, metric1, metric2) ->
        data = @mergeData(data1, data2)
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
        @svg.append("text").text(metric1)
            .attr("class", "xlabel")
            .attr("x", Math.round(@w / 2)).attr("y", @h - 8)

        # y title
        y_title_ypos = Math.round(@h / 2)
        @svg.append("text").text(metric2)
            .attr("class", "ylabel")
            .attr("transform", "rotate(270, 20, #{y_title_ypos})")
            .attr("x", 20).attr("y", y_title_ypos)


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

$( ->
    hash = document.location.hash or "#"
    params = hash.substr(1).split(",")
    if params[0] and params[1]
        plotter = new Plotter()
        plotter.plot(params[0], params[1])
)
