require_relative '../helper'

class OlafSnowflakeTest < Test::Unit::TestCase
  class FakeConnection
    attr_reader :sql, :variables

    def initialize(error: nil, rows: [{ company: 'carwow' }])
      @error = error
      @rows = rows
    end

    def fetch(sql, **variables)
      @sql = sql
      @variables = variables

      raise @error if @error

      self
    end

    def all
      @rows
    end
  end

  def setup
    @driver = Olaf::Snowflake.new(user: 'olaf')

    @query = Class.new.include(Olaf::QueryDefinition)
    @query.template File.join(File.dirname(__FILE__), '../fixtures/query_with_arguments.sql')
    @query.argument :id

    @query_instance = @query.new(id: 1).prepare
  end

  def test_fetch_runs_the_template_with_its_arguments
    connection = connect(FakeConnection.new)

    assert_equal @driver.fetch(@query_instance), [{ company: 'carwow' }]
    assert_equal connection.sql, @query_instance.sql_template
    assert_equal connection.variables, { id: 1 }
  end

  def test_fetch_wraps_database_errors
    connect(FakeConnection.new(error: Sequel::DatabaseError.new('syntax error')))

    error = assert_raise Olaf::QueryExecutionError do
      @driver.fetch(@query_instance)
    end

    assert_equal error.message, 'syntax error'
    assert_equal error.metadata, @query_instance.metadata
  end

  def test_fetch_does_not_wrap_other_errors
    connect(FakeConnection.new(error: ArgumentError.new('not a database error')))

    assert_raise ArgumentError do
      @driver.fetch(@query_instance)
    end
  end

  private

  def connect(connection)
    @driver.instance_variable_set(:@conn, connection)

    connection
  end
end
