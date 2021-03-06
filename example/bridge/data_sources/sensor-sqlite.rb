require 'omf_web'
require 'omf_base/lobject'
require 'omf_oml/table'
require 'omf_oml/sql_source'

class LazySlicableTable < OMF::Base::LObject

  attr_reader :name
#  attr_accessor :max_size
  attr_reader :schema
#  attr_reader :offset

  def initialize(name, schema, &block)
    @name = name
    @schema = schema
    @block = block
  end

  def create_sliced_table(col_name, col_value, table_opts = {})
    @block.call(col_name, col_value, table_opts)
  end

end

class BridgeSensor < OMF::Base::LObject
  attr_reader :table

  def initialize(db_name, fake_bridge_events)
    @db_name = db_name
    @fake_bridge_events = fake_bridge_events
  end

  # oml_sender_id INTEGER, oml_seq INTEGER, oml_ts_client REAL, oml_ts_server REAL, "eventID" TEXT, "sensorID" TEXT, "time" REAL, "x" REAL, "y" REAL, "z" REAL, "v1" REAL, "v2" REAL
  def process_acceleration(stream)
    #puts stream.class
    @table = stream.to_table(:sensors_raw, :include_oml_internals => true)

    #OMF::Web.register_datasource @table
    OMF::Web.register_datasource(LazySlicableTable.new(:sensors, @table.schema) do |col_name, col_value, table_opts|
      @table.create_sliced_table(col_name, col_value, table_opts)
    end)
  end

  def process_health(stream)
    if $fake_bridge_events
      fake_health
      return
    end

    @table = stream.to_table(:health, :include_oml_internals => true)
    OMF::Web.register_datasource @table
  end

  def run
    #ep = OMF::OML::OmlSqlSource.new(@db_name, :offset => -500, :check_interval => 1.0)
    ep = OMF::OML::OmlSqlSource.new(@db_name, :check_interval => 3.0)
    ep.on_new_stream() do |stream|
      #puts "NEW STREAM: #{stream.inspect}"
      case stream.stream_name
      when 'SydneyHarbourBridge_acceleration'
        process_acceleration(stream)
      when 'SydneyHarbourBridge_correlation'
      when 'SydneyHarbourBridge_energy'
      when 'SydneyHarbourBridge_health'
        process_health(stream)
      else
        error("Don't know what to do with table '#{stream.stream_name}'")
      end
    end
    ep.run
    self
  end

  def fake_health()
    # oml_sender_id INTEGER, oml_seq INTEGER, oml_ts_client REAL, oml_ts_server REAL, "eventID" TEXT, "jointID" TEXT, "health" REAL
    schema = [[:oml_sender_id, :integer], [:oml_seq, :integer], [:oml_ts_client, :float], [:oml_ts_server, :float], [:eventID, :string], [:jointID, :string], [:health, :float]]
    table = OMF::OML::OmlTable.new 'health', schema, :max_size => 20
    OMF::Web.register_datasource table

    Thread.new do
      begin
        seq_no = 1
        loop do
          #2012-07-21-17:03:25|node49|0.600000023841858
          ev_id = Time.now.iso8601
          [['node47', 0, '2012-07-21-17:04:22'], ['node48', 0.2, ev_id], ['node49', 0.6, ev_id]].each do |r|
            joint_id, health, ev_id = r
            table.add_row [0, seq_no, 0.0, 0.0, ev_id, joint_id, health]
          end
          seq_no += 1
          sleep 5
          #break if seq_no > 3
        end
      rescue Exception => ex
        puts ex
        puts ex.backtrace.join("\n")
      end
    end
  end
end
wv = BridgeSensor.new($oml_database, $fake_bridge_events).run()
