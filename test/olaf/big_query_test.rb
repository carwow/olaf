require_relative '../helper'

class OlafBigQueryTest < Test::Unit::TestCase
  class FakeJob
    attr_reader :rows

    def initialize(rows: [{ country: 'UK' }], error: nil)
      @rows = rows
      @error = error
    end

    def wait_until_done!; end

    def failed?
      !@error.nil?
    end

    def error
      @error
    end

    def data
      self
    end

    def all
      @rows
    end
  end

  class FakeClient
    attr_reader :sql, :options

    def initialize(job: FakeJob.new, error: nil)
      @job = job
      @error = error
    end

    def query_job(sql, **options)
      @sql = sql
      @options = options

      raise @error if @error

      @job
    end
  end

  def setup
    @client = FakeClient.new
    @driver = Olaf::BigQuery.new(project: 'carwow', labels: { service: 'Flatmin!', country: 'UK' }, client: @client)

    @query = query_class(template: 'big_query_template.sql')
    @query.argument :country
    @query_instance = @query.new(country: 'UK').prepare
  end

  def test_fetch_returns_the_rows
    assert_equal @driver.fetch(@query_instance), [{ country: 'UK' }]
  end

  def test_fetch_rewrites_placeholders_into_named_parameters
    @driver.fetch(@query_instance)

    assert @client.sql.include?('WHERE country = @country')
    reject @client.sql.include?(' :country')
  end

  def test_fetch_leaves_anything_that_is_not_a_placeholder_alone
    @driver.fetch(@query_instance)

    assert @client.sql.include?("'::country'")
  end

  def test_fetch_binds_the_arguments_as_parameters
    @driver.fetch(@query_instance)

    assert_equal @client.options.fetch(:params), { country: 'UK' }
  end

  def test_fetch_does_not_bind_literal_arguments_substituted_by_prepare
    query = query_class(template: 'big_query_template_with_literal.sql')
    query.argument :table_name, as: :literal
    query.argument :country

    @driver.fetch(query.new(table_name: 'some_table', country: 'UK').prepare)

    assert @client.sql.include?('FROM some_table')
    assert_equal @client.options.fetch(:params), { country: 'UK' }
  end

  def test_fetch_caps_the_bytes_billed_with_the_driver_default
    @driver.fetch(@query_instance)

    assert_equal @client.options.fetch(:maximum_bytes_billed), Olaf::BigQuery::DEFAULT_MAXIMUM_BYTES_BILLED
  end

  def test_fetch_caps_the_bytes_billed_with_the_driver_configuration
    driver = Olaf::BigQuery.new(project: 'carwow', maximum_bytes_billed: 42, client: @client)

    driver.fetch(@query_instance)

    assert_equal @client.options.fetch(:maximum_bytes_billed), 42
  end

  def test_fetch_lets_a_query_raise_its_own_cap
    @query.driver :big_query, maximum_bytes_billed: 10 * Olaf::BigQuery::GIGABYTE

    @driver.fetch(@query_instance)

    assert_equal @client.options.fetch(:maximum_bytes_billed), 10 * Olaf::BigQuery::GIGABYTE
  end

  def test_fetch_labels_the_job_with_the_query_and_the_driver_labels
    @driver.fetch(@query_instance)

    assert_equal @client.options.fetch(:labels),
                 { service: 'flatmin_', country: 'uk', query: 'big_query_template' }
  end

  def test_fetch_truncates_labels_to_what_big_query_accepts
    driver = Olaf::BigQuery.new(project: 'carwow', labels: { service: 'a' * 100 }, client: @client)

    driver.fetch(@query_instance)

    assert_equal @client.options.fetch(:labels)[:service].size, Olaf::BigQuery::LABEL_MAX_LENGTH
  end

  def test_fetch_raises_when_the_job_fails
    driver = Olaf::BigQuery.new(project: 'carwow', client: FakeClient.new(job: FakeJob.new(error: { 'message' => 'boom' })))

    error = assert_raise Olaf::QueryExecutionError do
      driver.fetch(@query_instance)
    end

    assert_equal error.message, 'boom'
    assert_equal error.metadata, @query_instance.metadata
  end

  def test_fetch_wraps_errors_reported_by_the_api
    driver = Olaf::BigQuery.new(project: 'carwow', client: FakeClient.new(error: Google::Cloud::Error.new('quota')))

    error = assert_raise Olaf::QueryExecutionError do
      driver.fetch(@query_instance)
    end

    assert_equal error.message, 'quota'
  end

  def test_fetch_wraps_credential_errors
    driver = Olaf::BigQuery.new(
      project: 'carwow',
      client: FakeClient.new(error: Google::Auth::InitializationError.new('no credentials'))
    )

    error = assert_raise Olaf::QueryExecutionError do
      driver.fetch(@query_instance)
    end

    assert_equal error.message, 'no credentials'
  end

  def test_run_returns_the_finished_job
    assert_equal @driver.run(@query_instance).rows, [{ country: 'UK' }]
  end

  private

  def query_class(template:)
    Class.new.include(Olaf::QueryDefinition).tap do |klass|
      klass.template File.join(File.dirname(__FILE__), '../fixtures', template)
    end
  end
end
