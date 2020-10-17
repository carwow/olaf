require_relative '../helper'

class OlafFakeTest < Test::Unit::TestCase
  def setup
    @instance = Olaf::Fake.new
    @query = Class.new.include(Olaf::QueryDefinition)
  end

  def test_public_methods
    assert @instance.respond_to?(:config)
    assert @instance.respond_to?(:execution_log)
    assert @instance.respond_to?(:recorded_responses)
    assert @instance.respond_to?(:fetch)
    assert @instance.respond_to?(:register_result)
  end

  def test_register_result_stores_a_result_ignoring_arguments
    assert @instance.recorded_responses.empty?

    @instance.register_result(@query, [])

    assert @instance.recorded_responses.any?
    assert @instance.recorded_responses.key?(@query)
  end

  def test_register_result_keeps_multiple_results_for_same_query
    @instance.register_result(@query, [])
    @instance.register_result(@query, [], with: { arg_set: 1 })
    @instance.register_result(@query, [], with: { arg_set: 2 })

    assert_equal @instance.recorded_responses.fetch(@query).size, 3
  end

  def test_fetch_logs_query_executed
    assert @instance.execution_log.empty?

    @instance.register_result(@query, [])
    query_instance = @query.new

    @instance.fetch(query_instance)

    assert_equal @instance.execution_log, [query_instance]
  end

  def test_fetch_returns_most_specific_result
    @instance.register_result(@query, [{ common: 111 }])
    @instance.register_result(@query, [{ only_for: 1 }], with: { arg_set: 1 })

    assert_equal @instance.fetch(@query.new), [{ common: 111 }]
    assert_equal @instance.fetch(@query.new(arg_set: 1)), [{ only_for: 1 }]
    assert_equal @instance.fetch(@query.new(arg_set: 2)), [{ common: 111 }]
  end

  def test_fetch_fails_when_no_results_were_registered
    assert_raise_message(/No Query result registered for/) do
      suppress_output { @instance.fetch(@query.new) }
    end
  end

  private

  # Temporarily redirects STDOUT and STDERR to /dev/null
  # but does print exceptions should there occur any.
  # Call as:
  #   suppress_output { puts 'never printed' }
  #
  def suppress_output
    @original_stdout = $stdout
    @original_stderr = $stderr
    $stdout = File.open(File::NULL, 'w')
    $stderr = File.open(File::NULL, 'w')

    yield
  ensure
    $stdout = @original_stdout
    $stderr = @original_stderr
    @original_stdout = nil
    @original_stderr = nil
  end
end
