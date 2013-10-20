// Generated by CoffeeScript 1.6.2
var MetricWatcher, Plotter, map_object, metric_watcher, plotter;

MetricWatcher = (function() {
  function MetricWatcher(plotter) {
    this.plotter = plotter;
    this.chosen_metrics = [];
    this.stores = {};
  }

  MetricWatcher.prototype.init = function() {
    var _this = this;

    this.metrics_container = $("#id-metrics-container");
    return $.getJSON("/metrics/dump", function(data) {
      var k, store, v;

      for (k in data) {
        v = data[k];
        store = LimitedSizeStore();
        store.load(v);
        _this.stores[k] = store;
      }
      return _this.displayMetricsList();
    });
  };

  MetricWatcher.prototype.displayMetricsList = function() {
    var a, count, id, keys, li, name, _i, _len, _results,
      _this = this;

    this.metrics_container.empty();
    keys = (function() {
      var _results;

      _results = [];
      for (name in this.stores) {
        _results.push(name);
      }
      return _results;
    }).call(this);
    keys.sort();
    _results = [];
    for (_i = 0, _len = keys.length; _i < _len; _i++) {
      name = keys[_i];
      count = ((function() {
        var _results1;

        _results1 = [];
        for (id in this.stores[name]) {
          _results1.push(id);
        }
        return _results1;
      }).call(this)).length;
      li = $('<li class="metric-list-item">').attr("data-name", name);
      a = $('<a href="">').text("" + name + " ").attr("data-name", name).click(function(e) {
        return _this.toggleMetric($(e.delegateTarget).attr("data-name"));
      }).append($('<span class="badge">').text(count));
      _results.push(this.metrics_container.append(li.append(a)));
    }
    return _results;
  };

  MetricWatcher.prototype.toggleMetric = function(name) {
    var idx;

    idx = $.inArray(name, this.chosen_metrics);
    if (idx > -1) {
      this.chosen_metrics.splice(idx, 1);
    } else {
      this.chosen_metrics.push(name);
      if (this.chosen_metrics.length > 2) {
        this.chosen_metrics.shift();
      }
    }
    this.onChosenMetricUpdated_markList();
    this.onChosenMetricUpdated_redraw();
    return false;
  };

  MetricWatcher.prototype.onChosenMetricUpdated_markList = function() {
    var metric, _i, _len, _ref, _results;

    $("li.metric-list-item").removeClass("active");
    _ref = this.chosen_metrics;
    _results = [];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      metric = _ref[_i];
      _results.push($("li[data-name=\"" + metric + "\"]").addClass("active"));
    }
    return _results;
  };

  MetricWatcher.prototype.onChosenMetricUpdated_redraw = function() {
    var xdata, xlabel, ydata, ylabel;

    if (this.chosen_metrics.length === 0) {
      return;
    }
    if (this.chosen_metrics.length === 2) {
      xdata = map_object(this.stores[this.chosen_metrics[0]], function(v) {
        return v[0];
      });
      xlabel = this.chosen_metrics[0];
      ydata = map_object(this.stores[this.chosen_metrics[1]], function(v) {
        return v[0];
      });
      ylabel = this.chosen_metrics[1];
    } else if (this.chosen_metrics.length === 1) {
      xdata = map_object(this.stores[this.chosen_metrics[0]], function(v) {
        return Math.random();
      });
      xlabel = 'random';
      ydata = map_object(this.stores[this.chosen_metrics[0]], function(v) {
        return v[0];
      });
      ylabel = this.chosen_metrics[0];
    }
    return plotter.plotData(xdata, ydata, xlabel, ylabel);
  };

  return MetricWatcher;

})();

Plotter = (function() {
  function Plotter(svg, r, pad, left_pad) {
    this.svg = svg != null ? svg : d3.select("svg");
    this.r = r != null ? r : 3;
    this.pad = pad != null ? pad : 40;
    this.left_pad = left_pad != null ? left_pad : 60;
    this.w = $("svg").width();
    this.h = $("svg").height();
  }

  Plotter.prototype.plotData = function(xdata, ydata, xlabel, ylabel) {
    var data, g_objs, k, v, values, xaxis, xscale, yaxis, ylabel_ypos, yscale,
      _this = this;

    $("svg").empty();
    console.log(xdata, ydata, xlabel, ylabel);
    data = this.mergeData(xdata, ydata);
    values = (function() {
      var _results;

      _results = [];
      for (k in data) {
        v = data[k];
        _results.push([k, v[0], v[1]]);
      }
      return _results;
    })();
    xscale = d3.scale.linear().domain([
      0, d3.max(values, function(d) {
        return d[1];
      })
    ]).range([this.left_pad, this.w - this.pad]).nice();
    xaxis = d3.svg.axis().scale(xscale).orient("bottom");
    yscale = d3.scale.linear().domain([
      0, d3.max(values, function(d) {
        return d[2];
      })
    ]).range([this.h - this.pad, this.pad]).nice();
    yaxis = d3.svg.axis().scale(yscale).orient("left");
    this.svg.append("g").attr('transform', "translate(0," + (this.h - this.pad) + ")").attr("class", "axis").call(xaxis);
    this.svg.append("g").attr('transform', "translate(" + this.left_pad + ",0)").attr("class", "axis").call(yaxis);
    this.svg.append("text").text(xlabel).attr("class", "xlabel").attr("x", Math.round(this.w / 2)).attr("y", this.h - 8);
    ylabel_ypos = Math.round(this.h / 2);
    this.svg.append("text").text(ylabel).attr("class", "ylabel").attr("transform", "rotate(270, 20, " + ylabel_ypos + ")").attr("x", 20).attr("y", ylabel_ypos);
    g_objs = this.svg.selectAll("g.circ").data(values).enter().append("g").attr("class", "circ");
    g_objs.append("circle").attr("r", this.r).attr("cx", function(d) {
      return xscale(d[1]);
    }).attr("cy", function(d) {
      return yscale(d[2]);
    });
    return g_objs.append("text").text(function(d) {
      return d[0];
    }).attr("text-anchor", "middle").attr("x", function(d) {
      return xscale(d[1]);
    }).attr("y", function(d) {
      return yscale(d[2]) - _this.r - 3;
    });
  };

  Plotter.prototype.mergeData = function(data1, data2) {
    var k, ret, v, v2;

    ret = {};
    for (k in data1) {
      v = data1[k];
      if (v === null) {
        continue;
      }
      v2 = data2[k];
      if (v2 != null) {
        ret[k] = [v, v2];
      }
    }
    return ret;
  };

  return Plotter;

})();

map_object = function(obj, func) {
  var key, ret, value;

  ret = {};
  for (key in obj) {
    value = obj[key];
    ret[key] = func(value);
  }
  return ret;
};

plotter = new Plotter();

metric_watcher = new MetricWatcher(plotter);

$(function() {
  return metric_watcher.init();
});
