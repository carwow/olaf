require_relative 'olaf/errors'
require_relative 'olaf/query_definition'

module Olaf
  # Autoloaded: each driver pulls in its own client library.
  autoload :BigQuery, File.expand_path('olaf/drivers/big_query', __dir__)
  autoload :Fake, File.expand_path('olaf/drivers/fake', __dir__)

  DEFAULT_DRIVER = :default

  # Configures the drivers used to execute queries, either a single one built
  # from the arguments given:
  #
  #     Olaf.configure(olaf_driver: Olaf::Fake)  # ideal for testing
  #
  # or several instantiated ones, which queries pick by name with `driver`:
  #
  #     Olaf.configure(
  #       drivers: { big_query: Olaf::BigQuery.new(project: 'carwow'), fake: Olaf::Fake.new },
  #       default: :big_query
  #     )
  #
  #   @return the default Olaf driver instance
  def self.configure(olaf_driver: nil, drivers: nil, default: nil, **args)
    @drivers, @default_driver =
      if drivers
        raise ArgumentError, 'Pass `drivers:` or a single `olaf_driver:`, not both' if olaf_driver || args.any?
        raise ArgumentError, 'No drivers given to configure' if drivers.empty?

        default_driver = default || drivers.keys.first
        unless drivers.key?(default_driver)
          raise ArgumentError, "Unknown default driver #{default_driver.inspect}, given: #{drivers.keys.inspect}"
        end

        [drivers.dup, default_driver]
      else
        raise ArgumentError, 'Pass `drivers:` or a single `olaf_driver:` to configure' unless olaf_driver

        [{ DEFAULT_DRIVER => olaf_driver.new(**args) }, DEFAULT_DRIVER]
      end

    instance
  end

  # Executes a query defined by Olaf::QueryDefinition with the driver the query
  # declares, or with the default driver when it declares none.
  #
  #   @return Enumerable of results.
  #     (i.e. Array of Hashes or `row_objects` when specified)
  #
  #   @raises Olaf::QueryExecutionError
  #   @raises Olaf::UnknownDriverError
  def self.execute(olaf_query)
    row_object = olaf_query.class.row_object
    row_transformer = row_object ? ->(r) { row_object.new(**r) } : Proc.new(&:itself)

    instance(driver_name(olaf_query))
      .fetch(olaf_query)
      .map!(&row_transformer)
  end

  # Returns an instance to execute queries when its configured. Without a name,
  # the default driver. A single configured driver serves every name, which is
  # what keeps `Olaf::Fake` covering every query in tests.
  #
  #   @return Olaf driver instance
  #     * Olaf::Fake     - Ideal for testing
  #     * Olaf::BigQuery - google-cloud-bigquery driver to run queries in BigQuery
  #
  def self.instance(name = nil)
    drivers = @drivers || raise('You need to configure Olaf before using it!')

    return drivers.fetch(@default_driver) if name.nil? || drivers.size == 1

    drivers.fetch(name) { raise UnknownDriverError.new(name, drivers.keys) }
  end

  def self.driver_name(olaf_query)
    olaf_query.class.driver if olaf_query.class.respond_to?(:driver)
  end
  private_class_method :driver_name
end
