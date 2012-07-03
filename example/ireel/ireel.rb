require 'omf-oml/table'
require 'omf-oml/sql_source'
require 'omf_common/lobject'
require 'omf_web'
require 'yaml'
require 'erb'
require 'sqlite3'
require 'optparse'
require 'ostruct'
require 'pp'

DB_DIR = "/tmp"

OMF::Common::Loggable.init_log 'ireel'

@line_chart_template = ERB.new <<-EOF
  widget:
    id: line_chart_<%= schema %>
    name: Line Chart
    type: data/line_chart2
    data_source:
      name: <%= schema %>
      dynamic: 1
    mapping:
      x_axis: <%= x %>
      y_axis: <%= y %>
      group_by: <%= group %>
    axis:
      x:
        legend: <%= x %>
      y:
        legend: <%= y %>
    margin:
      left: 100
EOF

# Give me an experiment id
@options = OpenStruct.new

OptionParser.new do |opts|
  opts.banner = "Usage: ireel.rb start [options]"
  opts.separator ""
  opts.separator "Options:"

  opts.on("-e", "--exp EXPID", "Experiment sql file") do |experiment_id|
    @options.experiment_id = experiment_id
  end
  opts.on("-p", "--port Port", "Port") do |port|
    @options.port = port
  end
end.parse!

raise "Missing experiment id" if @options.experiment_id.nil?
raise "Missing port number" if @options.port.nil?

ep = OMF::OML::OmlSqlSource.new("#{DB_DIR}/#{@options.experiment_id}.sq3")

ep.on_new_stream() do |stream|
  case stream.stream_name
  when 'iperf_transfer'
    t = stream.capture_in_table(:oml_ts_server, :oml_sender, :size)
    OMF::Web.register_datasource t
    x, y, group, schema = 'oml_ts_server', 'size', 'oml_sender', 'iperf_transfer'
    OMF::Web.register_widget YAML.load(@line_chart_template.result(binding))['widget']
  when 'iperf_losses'
    t = stream.capture_in_table(:oml_ts_server, :oml_sender, :lost_datagrams)
    OMF::Web.register_datasource t
    x, y, group, schema = 'oml_ts_server', 'lost_datagrams', 'oml_sender', 'iperf_losses'
    OMF::Web.register_widget YAML.load(@line_chart_template.result(binding))['widget']
  end
end

ep.run()

OMF::Web.start( { :port => @options.port, :page_title => 'IREEL Demo' } )
