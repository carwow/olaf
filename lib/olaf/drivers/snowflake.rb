module Olaf
  class Snowflake
    def initialize(**config)
      @config = config
    end

    def fetch(olaf_query)
      conn.fetch(olaf_query.sql_template, **olaf_query.variables).all
    end

    private

    def conn
      @conn ||= Sequel.odbc('snowflake', **@config)
    end
  end
end
