namespace :test do
  task :karma => :"karma:all"

  namespace :karma do
    desc "Run all karma tests"
    task :all => :environment do
      require Rails.root.join("lib", "karma")
      Karma::RailsServer.run do |server|
        Karma.start!(files: scenario_files, adapter: :angular, proxy: {"/" => server.root_url}, single_run: true)
        Karma.start!(files: unit_files, adapter: :jasmine, single_run: true)
      end
    end

    desc "Run scenarios tests (test/karma/scenarios) and watch for changes"
    task :scenarios => :environment do
      require Rails.root.join("lib", "karma")
      Karma::RailsServer.run do |server|
        Karma.start!(files: scenario_files, adapter: :angular, proxy: {"/" => server.root_url})
      end
    end

    desc "Run unit tests (test/karma/unit) and watch for changes"
    task :unit => :environment do
      require Rails.root.join("lib", "karma")
      Karma::RailsServer.run do
        Karma.start!(files: unit_files, adapter: :jasmine)
      end
    end

    def unit_files
      sprockets = Rails.application.assets
      sprockets.append_path Rails.root.join("test/karma")
      files = sprockets.find_asset("unit.js").to_a.map do |asset|
        "http://127.0.0.1:3333/assets/#{asset.logical_path}"
      end
      files << Rails.root.join("test/karma/unit/*_test.coffee").to_s
    end

    def scenario_files
      [Rails.root.join("test/karma/scenarios/*_test.coffee").to_s]
    end
  end
end
