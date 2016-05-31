#!/usr/local/rvm/wrappers/default/ruby
#
# See https://github.com/sensu-plugins/sensu-plugins-influxdb/blob/master/bin/metrics-influxdb.rb
#
#   metrics-influx.rb
#
# DESCRIPTION:
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: influxdb
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright (C) 2015, Sensu Plugins
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems'
require 'sensu-handler'
require 'influxdb'

#
# Sensu To Influxdb
#
class SensuToInfluxDB < Sensu::Handler
  option :config,
         description: 'Configuration information to use',
         short: '-c CONFIG',
         long: '--config CONFIG',
         default: 'influxdb'

  def filter; end

  def create_point(series, value, time)
    {
      series: series,
      tags: {
        host: @event['client']['name'],
        ip: @event['client']['address'],
        metric: @event['check']['name']
      },
      values: { value: value },
      timestamp: time
    }
  end

  def parse_output
    metric_raw = @event['check']['output']

    metric_raw.split("\n").map do |metric|
      m = metric.split
      next unless m.count == 3

      key = m[0].split('.', 2)[1]
      key.tr!('.', '_')

      # Convert numbers to floats, keep strings unchanged...
      begin
        value = Float(m[1])
      rescue ArgumentError
        value = m[1]
      end

      time = m[2]

      create_point(key, value, time)
    end
  end

  def handle
    opts = settings[config[:config]].each_with_object({}) do |(k, v), sym|
      sym[k.to_sym] = v
    end
    database = opts[:database]

    influxdb_data = InfluxDB::Client.new database, opts
    influxdb_data.create_database(database) # Ensure the database exists

    influxdb_data.write_points(parse_output)
  end
end
