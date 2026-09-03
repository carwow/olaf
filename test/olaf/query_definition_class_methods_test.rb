require_relative '../helper'

class QueryDefinitionClassMethodsTest < Test::Unit::TestCase
  def setup
    @query = Class.new.include(Olaf::QueryDefinition)
  end

  def test_implements_common_interface
    assert @query.respond_to? :argument
    assert @query.respond_to? :arguments
    assert @query.respond_to? :driver
    assert @query.respond_to? :driver_options
    assert @query.respond_to? :prepare
    assert @query.respond_to? :row_object
    assert @query.respond_to? :template
  end

  def test_define_argument
    assert @query.arguments.empty?

    @query.argument :an_argument, with: 'ignored options'

    assert @query.arguments.key?(:an_argument)
  end

  def test_define_argument_as_literal
    @query.argument :literal_argument, as: :literal
    @query.argument :nonliteral_argument

    assert @query.arguments.dig(:literal_argument, :literal)
    reject @query.arguments.dig(:nonliteral_argument, :literal)
  end

  def test_driver_is_not_declared_by_default
    assert_equal @query.driver, nil
    assert_equal @query.driver_options, {}
  end

  def test_declare_driver_with_options
    @query.driver :big_query, maximum_bytes_billed: 42

    assert_equal @query.driver, :big_query
    assert_equal @query.driver_options, { maximum_bytes_billed: 42 }
  end

  def test_driver_can_be_declared_once
    @query.driver :big_query, maximum_bytes_billed: 42
    @query.driver :snowflake, maximum_bytes_billed: 1

    assert_equal @query.driver, :big_query
    assert_equal @query.driver_options, { maximum_bytes_billed: 42 }
  end

  def test_template_can_be_defined_once
    assert_equal @query.template, nil

    @query.template 'my_template.sql'
    @query.template 'ignore_this_template.sql'

    assert_equal @query.template, 'my_template.sql'
  end

  def test_row_object_can_be_defined_once
    assert_equal @query.row_object, nil

    row_object = Struct.new(:id)

    @query.row_object row_object
    @query.row_object Struct.new(:name)

    assert_equal @query.row_object, row_object
  end
end
