
OML.require_dependency('vendor/slickgrid/slick.formatters', ['vendor/slickgrid/slick.core']);
OML.require_dependency('vendor/slickgrid/slick.editors', ['vendor/slickgrid/slick.core']);
OML.require_dependency('vendor/slickgrid/plugins/slick.rowselectionmodel', ['vendor/slickgrid/slick.core']);
OML.require_dependency('vendor/slickgrid/slick.grid', ['vendor/slickgrid/slick.core']);
OML.require_dependency('vendor/slickgrid/slick.dataview', ['vendor/slickgrid/slick.core']);
OML.require_dependency('vendor/slickgrid/controls/slick.pager', ['vendor/slickgrid/slick.core']);
OML.require_dependency('vendor/slickgrid/controls/slick.columnpicker', ['vendor/slickgrid/slick.core']);


define(["graph/abstract_widget",
                 'vendor/jquery/jquery.event.drag',
                 'vendor/slickgrid/slick.formatters',
                 'vendor/slickgrid/slick.editors',
                 'vendor/slickgrid/plugins/slick.rowselectionmodel',
                 'vendor/slickgrid/slick.grid',
                 'vendor/slickgrid/slick.dataview',
                 'vendor/slickgrid/controls/slick.pager',
                 'vendor/slickgrid/controls/slick.columnpicker',
                 'css!theme/bright/css/slickgrid'], function(abstract_widget) {

  var table2 = abstract_widget.extend({
    defaults: function() {
      return this.deep_defaults({
        // add defaults
        topts: {
          enableCellNavigation: false,
          enableColumnReorder: false,
          forceFitColumns: true,
          //autoHeight: true
        },
        margin: {
          left: 20,
          top:  2,
          right: 20,
          bottom: 2
        },
      }, table2.__super__.defaults.call(this));
    },

    initialize: function(opts) {
      table2.__super__.initialize.call(this, opts);
      // var ca = this.widget_area;
      // this.base_el
        // .style('height', ca.h + 'px')
        // .style('width', ca.w + 'px')
        // .style('margin-left', ca.x + 'px')
        // .style('margin-top', ca.ty + 'px')
        // ;
      $(opts.base_el).focus(function(e) {
        // all your magic resize mojo goes here
        var i = 0;
      });
      this.init_grid();
      this.update();
    },

    resize: function() {
      table2.__super__.resize.call(this);
      // var ca = this.widget_area;
      // this.base_el
        // .style('height', ca.oh + 'px')
        // .style('width', ca.w + 'px')
        // .style('margin-left', ca.x + 'px')
        // .style('margin-right', ca.ow - ca.w - ca.x + 'px')
        // .style('margin-top', ca.ty + 'px')
        // ;
      if (this.grid) {
        this.grid.resizeCanvas();
        //this.grid.setColumns(this.columns);
      }

      return this;
    },

    redraw: function(data) {
      //this.resize();

      this.data = data;
      var self = this;
      // Should sort first
      if (this.sort_on_column) {
        var sid = this.sort_on_column.id;
        var asc = this.is_ascending;
        data = data.sort(function(a, b) {
          var x = a[sid], y = b[sid];
          var cmp = (x == y ? 0 : (x > y ? 1 : -1));
          return  asc ? cmp : -1 * cmp;
        });
      }
      this.sorted_data = data;

      this.grid.updateRowCount(); // fixes scroll bar
      this.grid.invalidateAllRows();
      this.grid.render();
    },

    init_grid: function() {
      var schema = this.data_source.schema;
      var opts = this.opts;
      var self = this;

      var columns = this.init_columns();

      // Define function used to get the data.
      //var currentSortCol = { id: "title" };
      var self = this;
      this.sorted_data = []; // initially empty
      function getItem(index) {
        //return isAsc ? data[indices[currentSortCol.id][index]] : data[indices[currentSortCol.id][(data.length - 1) - index]];
        return self.sorted_data[index];
      }
      function getLength() {
        return self.sorted_data.length;
      }

      var topts = this.opts.topts;
      topts.dataItemColumnValueExtractor = function(item, columnDef) {
        var i = 0;
        return item[columnDef.id];
      };

      this.is_ascending = true;
      this.sort_on_column = null;
      this.columns = columns;
      var grid = this.grid = new Slick.Grid(this.opts.base_el, {getLength: getLength, getItem: getItem}, columns, topts);
      grid.onSort.subscribe(function (e, args) {
        self.sort_on_column = args.sortCol;
        self.is_ascending = args.sortAsc;
        self.redraw(self.data);
        // grid.invalidateAllRows();
        // grid.render();
      });
      //grid.setSelectionModel(new Slick.RowSelectionModel());
      // grid.onSelectedRowsChanged.subscribe(function(e, args) {
        // var i = 0;
      // });

    },

    /*
     * Return an array of columns definitions to be used for the slick grid constructor
     */
    init_columns: function() {
      var schema = this.data_source.schema;
      var opts = this.opts;
      var self = this;

      var columns;
      if (opts.columns) {
        var sh = {}; _.each(schema, function(e) { sh[e.name] = e; });
        columns = _.map(opts.columns, function(c) {
          if (typeof c === 'string') {
            c = {field: c};
          }
          var s = sh[c.field];
          c.id = s.index;
          _.defaults(c, {
            name: s.title || s.name,
            width: 0,
            sortable: true,
          });
          if (c.format) {
            c.formatter = self.find_formatter(c.type || s.type, c);
          }
          return c;
        });
        var i = 0;
      } else {
        columns = _.map(schema, function(col) {
                        return { id: col.index, name: col.title, field: col.name, width: 0, sortable: true };
                    });
        // Remove the leading __id__ column
        if (columns[0].field == '__id__') {
          columns.splice(0, 1);
        }
      }
      return columns;
    },

    find_formatter: function(type, opts) {
      if (type == 'date' || type == 'dateTime') {
        var d_f = d3.time.format(opts.format || "%X");
        return function(r, c, v) {
          var date = new Date(1000 * v);  // TODO: Implicitly assuming that value is in seconds is most likely NOT a good idea
          var fs = d_f(date);
          return fs;
        };
      } else if (type == 'key') {
        var lm = opts.format;
        return function(r, c, v) {
          var l = lm[v] || ('??-' + v);
          return l;
        };
      } else {
        var formatter = d3.format(opts.format);
        return function(r, c, v) {
          return formatter(v);
        };
      }
    }
  });

  return table2;
});
