require_relative 'helper'

class OlafExecuteTest < Test::Unit::TestCase
  Company = Struct.new(:company, keyword_init: true)

  class RecordingDriver
    attr_reader :executed

    def initialize(**config)
      @config = config
      @executed = []
    end

    def fetch(olaf_query)
      @executed << olaf_query

      [{ company: 'carwow' }]
    end
  end

  def setup
    Olaf.configure(olaf_driver: Olaf::Fake)

    @query = Class.new.include(Olaf::QueryDefinition)
    @query.template File.join(File.dirname(__FILE__), './fixtures/query_with_arguments.sql')
    @query.argument :id

    Olaf.instance.register_result(@query, [{ company: 'carwow' }])
    @query_instance = @query.new(id: 1).prepare
  end

  def test_execute_returns_an_enumerable
    assert Olaf.execute(@query_instance).is_a?(Enumerable)
  end

  def test_execute_returns_a_list_of_row_objects_when_defined
    @query.row_object Company

    all_row_objects = Olaf.execute(@query_instance).all? { |e| e.is_a? Company }

    assert all_row_objects
  end

  def test_execute_returns_hashes_when_no_row_object_defined
    all_hashes = Olaf.execute(@query_instance).all? { |e| e.is_a? Hash }

    assert all_hashes
  end

  def test_execute_lets_the_error_wrapped_by_the_driver_through
    faulty_driver = Class.new do
      def initialize(**args); end

      def fetch(olaf_query)
        raise Olaf::QueryExecutionError.new('something went wrong', olaf_query)
      end
    end

    Olaf.configure(olaf_driver: faulty_driver)

    assert_raise Olaf::QueryExecutionError do
      Olaf.execute(@query_instance)
    end
  end

  def test_execute_uses_the_driver_declared_by_the_query
    default_driver = RecordingDriver.new
    other_driver = RecordingDriver.new

    Olaf.configure(drivers: { default: default_driver, big_query: other_driver })

    @query.driver :big_query

    Olaf.execute(@query_instance)

    assert_equal other_driver.executed, [@query_instance]
    assert_equal default_driver.executed, []
  end

  def test_execute_uses_the_default_driver_when_the_query_declares_none
    default_driver = RecordingDriver.new
    other_driver = RecordingDriver.new

    Olaf.configure(drivers: { big_query: other_driver, postgres: default_driver }, default: :postgres)

    Olaf.execute(@query_instance)

    assert_equal default_driver.executed, [@query_instance]
    assert_equal other_driver.executed, []
  end

  def test_execute_uses_the_only_driver_configured_whatever_the_query_declares
    @query.driver :big_query

    Olaf.execute(@query_instance)

    assert_equal Olaf.instance.execution_log, [@query_instance]
  end

  def test_execute_raises_when_the_driver_declared_is_not_configured
    Olaf.configure(drivers: { default: RecordingDriver.new, postgres: RecordingDriver.new })

    @query.driver :big_query

    assert_raise_message(/Unknown driver :big_query/) do
      Olaf.execute(@query_instance)
    end
  end
end
