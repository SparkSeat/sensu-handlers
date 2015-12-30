#!/usr/local/rvm/wrappers/default/ruby

require 'rubygems'
require 'sensu-handler'
require 'influxdb'

class SensuToInfluxDB < Sensu::Handler
  def filter; end

  def handle
    influxdb_server = settings['influxdb']['server']
    influxdb_port   = settings['influxdb']['port']
    influxdb_user   = settings['influxdb']['username']
    influxdb_pass   = settings['influxdb']['password']
    influxdb_db     = settings['influxdb']['database']

    influxdb_data = InfluxDB::Client.new influxdb_db, host: influxdb_server,
                                                      username: influxdb_user,
                                                      password: influxdb_pass,
                                                      port: influxdb_port,
                                                      server: influxdb_server
    mydata = []
    @event['check']['output'].each_line do |metric|
      m = metric.split
      next unless m.count == 3
      key = m[0].split('.', 2)[1]
      next unless key
      key.gsub!('.', '_')

      # Convert numbers to floats, keep strings unchanged...
      begin
        value = Float(m[1])
      rescue ArgumentError
        value = m[1]
      end

      mydata = { host: @event['client']['name'], value: value,
                 ip: @event['client']['address']
               }
      influxdb_data.write_point(key, values: mydata)
    end
  end
end
