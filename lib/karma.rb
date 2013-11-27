require "rack/server"
require "net/http"
require "webrick"

module Karma
  def self.start!(opts = {})
    Dir.mktmpdir do |dir|
      confjs = File.join(dir, "karma.conf.js")

      adapter = case opts[:adapter]
        when :angular then "ng-scenario"
        when :jasmine then "jasmine"
      end

      files = <<-EOS
        [
          #{opts[:files].map(&:dump).join(",\n")}
        ]
      EOS

      proxies = if opts[:proxy]
        "proxies : #{opts[:proxy].to_json},"
      else
        ""
      end

      File.open(confjs, "w") do |f|
        f.write <<-EOS
          module.exports = function (config) {
            config.set({
              basePath : '/',
              frameworks : ["#{adapter}"],
              files : #{files},
              exclude : [],
              autoWatch : #{!opts[:single_run]},
              browsers : ['Chrome'],
              singleRun : #{!!opts[:single_run]},
              reporters : ['progress'],
              port : 9876,
              runnerPort : 9100,
              colors : true,
              #{proxies}
              urlRoot : '/__karma__/',
              captureTimeout : 60000
            });
          }
        EOS
      end

      system "karma start #{confjs}"
    end
  end

  class RailsServer
    attr_accessor :host, :port

    def self.run
      ENV["RAILS_ENV"] = "test"
      ENV["RACK_ENV"] = "test"
      require Rails.root.join("config", "environment")
      server = new(Rails.application)
      server.boot
      yield server
      server.shutdown
    end

    def initialize(app, opts={})
      @app = app
      @thread = nil

      @host = opts[:host] || "127.0.0.1"
      @port = opts[:port] || 3333
    end

    def root_url
      "http://#{@host}:#{@port}/"
    end

    def call(env)
      if env["PATH_INFO"] == "/__identify__"
        [200, {}, [@app.object_id.to_s]]
      else
        begin
          @app.call(env)
        rescue StandardError => e
          @error = e unless @error
          raise e
        end
      end
    end

    def up?
      return false if @thread && @thread.join(0)

      res = Net::HTTP.start(@host, @port) { |http| http.get('/__identify__') }

      if res.is_a?(Net::HTTPSuccess) or res.is_a?(Net::HTTPRedirection)
        return res.body == @app.object_id.to_s
      end
    rescue SystemCallError
      return false
    end

    def access_log
      file = File.open(Rails.root.join("log", "test.log"), "a+")
      log = WEBrick::Log.new(file)
      [log, WEBrick::AccessLog::COMBINED_LOG_FORMAT]
    end

    def boot
      @thread = Thread.new do
        Rack::Server.start(
          :Host => @host,
          :Port => @port,
          :app => self,
          :AccessLog => [access_log],
          :environment => "test"
        )
      end

      Timeout.timeout(60) { @thread.join(0.1) until up? }
    rescue Timeout::Error
      raise "Rack application timed out during boot"
    else
      self
    end

    def shutdown
      @thread.kill
    end
  end
end
