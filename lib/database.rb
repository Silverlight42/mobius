module Mobius
  class Database
    def self.init
      log "INIT", "Connecting to Database..."

      Sequel.extension(:migration)
      Sequel::Model.plugin(:timestamps, update_on_create: true)

      @db = Sequel.sqlite(Config.database_path)
      migrations_path = File.expand_path("./db/migrations", __dir__)

      unless Sequel::Migrator.is_current?(@db, migrations_path)
        log "DATABASE", "Applying new migrations..."
        Sequel::Migrator.run(@db, migrations_path)
        log "DATABASE", "Done migrating."
      end

      require_relative "db/models/plugin_data"
      require_relative "db/models/log"
      require_relative "db/models/ip"
      require_relative "db/models/ban"
      require_relative "db/models/kick"
    end

    def self.transaction(&block)
      @db.transaction do
        block&.call
      end
    end

    def self.teardown
      log "TEARDOWN", "Closing Database..."
    end
  end
end
