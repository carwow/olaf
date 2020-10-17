require_relative '../helper'

class QueryDefinitionTest < Test::Unit::TestCase
  def setup
    @query = Class.new.include(Olaf::QueryDefinition)
  end

  def test_implements_common_interface
    @instance = @query.new

    assert @instance.respond_to? :prepare
    assert @instance.respond_to? :metadata
    assert @instance.respond_to? :defined_arguments
    assert @instance.respond_to? :missing_arguments
    assert @instance.respond_to? :undefined_arguments
  end

  def test_prepare_fails_when_no_template_defined
    assert_raise TypeError do
      @query.new.prepare
    end
  end

  def test_prepare_fails_with_undefined_arguments
    @query.template File.join(File.dirname(__FILE__), '../fixtures/query_with_arguments.sql')

    assert_raise Olaf::UndefinedArgumentsError do
      @query.new.prepare
    end
  end

  def test_prepare_fails_with_missing_arguments
    @query.template File.join(File.dirname(__FILE__), '../fixtures/query_with_arguments.sql')
    @query.argument :id

    assert_raise Olaf::MissingArgumentsError do
      @query.new(anything_except_id: 123).prepare
    end
  end

  def test_prepare_fills_sql_template
    @query.template File.join(File.dirname(__FILE__), '../fixtures/query_with_arguments.sql')
    @query.argument :id

    @instance = @query.new(id: 1)

    assert_equal @instance.sql_template, nil

    @instance.prepare

    assert_equal @instance.sql_template, "SELECT 1 FROM some_table WHERE id = :id;\n"
  end

  def test_prepare_replaces_literal_arguments
    @query.template File.join(File.dirname(__FILE__), '../fixtures/query_with_literal_arguments.sql')
    @query.argument :table_name, as: :literal

    @instance = @query.new(table_name: 'dynamic_table')

    assert_equal @instance.sql_template, nil

    @instance.prepare

    assert_equal @instance.sql_template, "SELECT 1 FROM dynamic_table;\n"
  end

  def test_metadata_exposes_information_about_query
    @instance = @query.new

    assert @instance.metadata.key?(:query_class)
    assert @instance.metadata.key?(:arguments)
    assert @instance.metadata.key?(:sql_template)
  end

  def test_defined_arguments_return_arguments_required
    @query.argument :arg1
    @query.argument :arg2
    @query.argument :arg3

    assert_equal @query.new.defined_arguments, [:arg1, :arg2, :arg3]
  end

  def test_missing_arguments_returns_arguments_without_a_value_assigned
    @query.argument :arg1
    @query.argument :arg2

    @instance = @query.new(arg1: 1)

    assert_equal @instance.missing_arguments, [:arg2]
  end

  def test_undefined_arguments_fails_when_query_was_not_prepared
    @query.template File.join(File.dirname(__FILE__), '../fixtures/query_with_arguments.sql')

    assert_raise NoMethodError do
      @query.new.undefined_arguments
    end
  end

  def test_undefined_arguments_captures_arguments_in_template_that_were_not_declared
    @query.template File.join(File.dirname(__FILE__), '../fixtures/query_with_arguments.sql')

    @instance = @query.new

    assert_raise Olaf::UndefinedArgumentsError do
      @instance.prepare
    end

    assert_equal @instance.undefined_arguments, [:id]
  end
end
