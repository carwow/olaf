require 'sequel'

module Olaf
  class Snowflake
    WRAPPED_ERRORS = [Sequel::DatabaseError].freeze

    def initialize(**config)
      @config = config
    end

    def fetch(olaf_query)
      conn.fetch(olaf_query.sql_template, **olaf_query.variables).all
    rescue *WRAPPED_ERRORS => error
      raise QueryExecutionError.new(error.message, olaf_query)
    end

    private

    def conn
      # Only opening a connection needs the ODBC system library.
      @conn ||= begin
        require 'odbc_utf8'

        Sequel.odbc('snowflake', **@config)
      end
    end
  end
end
