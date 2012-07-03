require 'omf-oml/table'
require 'omf-oml/sql_source'
require 'omf_common/lobject'
require 'omf_web'
require 'yaml'
require 'erb'
require 'sqlite3'
require 'pp'

OMF::Common::Loggable.init_log 'ireel'

# TODO use
#Dir.glob("#{File.dirname(__FILE__)}/data_sources/*.rb").each do |fn|
  #load fn
#end

db = SQLite3::Database.new("/tmp/345.sq3")

ep = OMF::OML::OmlSqlSource.new("/tmp/345.sq3")

ep.on_new_stream() do |stream|
  case stream.stream_name
  when 'iperf_losses'
    t = stream.capture_in_table(:oml_ts_server, :oml_sender, :lost_datagrams)
    #t.schema.hash_to_row(bob)
    #pp t.name
    #pp t.schema.hash_to_row
    #OMF::Web.register_datasource t
  end
  #init_graph(name + ' (T)', t, 'table', :schema => t.schema.describe)
  #create_table(select, stream, 'table')
end

ep.run()

schema = [[:oml_ts_server, :float], [:oml_sender, :string], [:lost_datagrams, :float]]
table = OMF::OML::OmlTable.new 'iperf_losses', schema, :max_size => 20

OMF::Web.register_datasource table

db.results_as_hash = false
tables = db.execute( "select name from sqlite_master where type = 'table'" ).flatten.find_all {|v| !(v =~ /^_/)}
tables.map do |table|
  db.results_as_hash = false
  nodes = db.execute( "select distinct name from #{table} join _senders on oml_sender_id = _senders.id")
  nodes.map do |node|
    db.results_as_hash = true
    rows = db.execute( "select * from #{table} join _senders on oml_sender_id = _senders.id and name = '#{node}'")
    graph_rows = rows.map do |row|
      {}.tap do |hash|
        row.keys.each do |key|
          if !(key =~ /^oml/ || key =~ /id$/ || key.class == Fixnum) && (Float(row[key]) rescue nil)
            hash[key] = row[key]
          end
        end
        hash['oml_ts_server'] = row['oml_ts_server']
      end
    end
    graph_rows = graph_rows.in_groups_of(rows.size / 1000).map {|v| v.sum / v.size } rescue graph_rows
    #build_dygraph(filename, table, node, graph_rows) unless graph_rows.empty? || graph_rows.first.keys.size < 2
    #pp graph_rows.first
  end
  #puts table
end

# ERB yaml template

x = 1

line_char_template = ERB.new <<-EOF
widget:
  id: line_chart
  name: Line Chart
  type: data/line_chart2
  data_source:
    name: ipref_losses
    dynamic: 1
  mapping:
    x_axis: oml_ts_server
    y_axis: lost_datagrams
    group_by: oml_sender
  margin:
    left: 100
EOF

h = YAML.load(line_char_template.result(binding))

if w = h['widget']
  OMF::Web.register_widget w
else
  OMF::Common::LObject.error "Don't know what to do with it"
end

opts = { :page_title => 'IREEL Demo' }

OMF::Web.start(opts)
