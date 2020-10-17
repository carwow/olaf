require 'sequel'
require 'odbc_utf8'

require_relative 'olaf/errors'
require_relative 'olaf/query_definition'
require_relative 'olaf/drivers/fake'
require_relative 'olaf/drivers/snowflake'

module Olaf
  # Configures Olaf module to execute queries in Snowflake or in a local object
  # to prevent external calls. Arguments passed will be forwarded directly
  # to the `olaf_driver` class specified.
  #
  # By default, it will set a connection with Snowflake
  def self.configure(olaf_driver: Olaf::Snowflake, **args)
    @instance = olaf_driver.new(**args)
  end

  # Executes a query defined by Olaf::QueryDefinition with the driver
  # configured previously.
  #
  #   @return Enumerable of results.
  #     (i.e. Array of Hashes or `row_objects` when specified)
  #
  #   @raises Olaf::QueryExecutionError
  def self.execute(olaf_query)
    row_object = olaf_query.class.row_object
    row_transformer = row_object ? ->(r) { row_object.new(**r) } : Proc.new(&:itself)

    instance
      .fetch(olaf_query)
      .map!(&row_transformer)
  rescue Sequel::DatabaseError => error
    raise QueryExecutionError.new(error.message, olaf_query)
  end

  # Returns an instance to execute queries when its configured.
  #
  #   @return Olaf driver instance
  #     * Olaf::Fake      - Ideal for testing
  #     * Olaf::Snowflake - Sequel.odbc driver to run queries in Snowflake
  #
  def self.instance
    @instance || raise('You need to configure Olaf before using it!')
  end
end
