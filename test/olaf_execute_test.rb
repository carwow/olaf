require_relative 'helper'

class OlafExecuteTest < Test::Unit::TestCase
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
    @query.row_object OpenStruct

    all_row_objects = Olaf.execute(@query_instance).all? { |e| e.is_a? OpenStruct }

    assert all_row_objects
  end

  def test_execute_returns_hashes_when_no_row_object_defined
    all_hashes = Olaf.execute(@query_instance).all? { |e| e.is_a? Hash }

    assert all_hashes
  end

  def test_execute_raises_error
    faulty_driver = Class.new do
      def initialize(**args); end

      def fetch(*args)
        raise Sequel::DatabaseError
      end
    end

    Olaf.configure(olaf_driver: faulty_driver)

    assert_raise Olaf::QueryExecutionError do
      Olaf.execute(@query_instance)
    end
  end
end
