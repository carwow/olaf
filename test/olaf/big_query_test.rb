require_relative '../helper'

class OlafBigQueryTest < Test::Unit::TestCase
  class FakeJob
    attr_reader :rows, :waits

    def initialize(rows: [{ country: 'UK' }], error: nil, wait_errors: [])
      @rows = rows
      @error = error
      @wait_errors = wait_errors
      @waits = 0
    end

    def wait_until_done!
      @waits += 1

      raise @wait_errors.shift if @wait_errors.any?
    end

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
    attr_reader :sql, :options, :query_jobs, :job_ids, :loaded_job_ids

    def initialize(job: FakeJob.new, errors: [], loaded_job: job)
      @job = job
      @errors = errors
      @loaded_job = loaded_job
      @query_jobs = 0
      @job_ids = []
      @loaded_job_ids = []
    end

    def query_job(sql, **options)
      @sql = sql
      @options = options
      @query_jobs += 1
      @job_ids << options[:job_id]

      raise @errors.shift if @errors.any?

      @job
    end

    def job(job_id)
      @loaded_job_ids << job_id

      @loaded_job
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
    driver = Olaf::BigQuery.new(project: 'carwow', client: FakeClient.new(errors: [Google::Cloud::Error.new('quota')]))

    error = assert_raise Olaf::QueryExecutionError do
      driver.fetch(@query_instance)
    end

    assert_equal error.message, 'quota'
  end

  def test_fetch_wraps_credential_errors
    driver = Olaf::BigQuery.new(
      project: 'carwow',
      client: FakeClient.new(errors: [Google::Auth::InitializationError.new('no credentials')])
    )

    error = assert_raise Olaf::QueryExecutionError do
      driver.fetch(@query_instance)
    end

    assert_equal error.message, 'no credentials'
  end

  def test_run_returns_the_finished_job
    assert_equal @driver.run(@query_instance).rows, [{ country: 'UK' }]
  end

  def test_run_retries_a_job_whose_connection_dropped
    client = FakeClient.new(errors: [OpenSSL::SSL::SSLError.new('SSL_read: unexpected eof while reading')])
    driver = Olaf::BigQuery.new(project: 'carwow', retry_delays: [0, 0], client: client)

    assert_equal driver.run(@query_instance).rows, [{ country: 'UK' }]
    assert_equal client.query_jobs, 2
  end

  def test_run_raises_the_dropped_connection_once_the_retries_run_out
    dropped_connection = OpenSSL::SSL::SSLError.new('SSL_read: unexpected eof while reading')
    client = FakeClient.new(errors: [dropped_connection] * 3)
    driver = Olaf::BigQuery.new(project: 'carwow', retry_delays: [0, 0], client: client)

    error = assert_raise OpenSSL::SSL::SSLError do
      driver.run(@query_instance)
    end

    assert_same error, dropped_connection
    assert_equal client.query_jobs, 3
  end

  def test_run_starts_every_attempt_with_the_same_job_id
    dropped_connection = OpenSSL::SSL::SSLError.new('SSL_read: unexpected eof while reading')
    client = FakeClient.new(errors: [dropped_connection] * 2)
    driver = Olaf::BigQuery.new(project: 'carwow', retry_delays: [0, 0], client: client)

    driver.run(@query_instance)

    assert_equal client.job_ids.size, 3
    assert_equal client.job_ids.uniq.size, 1
    assert_not_nil client.job_ids.first
  end

  def test_run_loads_the_job_a_dropped_attempt_already_started
    client = FakeClient.new(
      errors: [
        OpenSSL::SSL::SSLError.new('SSL_read: unexpected eof while reading'),
        Google::Cloud::AlreadyExistsError.new('Already Exists: Job carwow:EU.job_1')
      ]
    )
    driver = Olaf::BigQuery.new(project: 'carwow', retry_delays: [0, 0], client: client)

    assert_equal driver.run(@query_instance).rows, [{ country: 'UK' }]
    assert_equal client.loaded_job_ids, [client.job_ids.first]
  end

  def test_run_loads_a_job_that_already_exists_on_the_first_attempt
    client = FakeClient.new(errors: [Google::Cloud::AlreadyExistsError.new('Already Exists: Job carwow:EU.job_1')])
    driver = Olaf::BigQuery.new(project: 'carwow', retry_delays: [0, 0], client: client)

    assert_equal driver.run(@query_instance).rows, [{ country: 'UK' }]
    assert_equal client.loaded_job_ids, [client.job_ids.first]
  end

  def test_run_wraps_a_job_that_already_exists_but_cannot_be_found
    client = FakeClient.new(
      errors: [Google::Cloud::AlreadyExistsError.new('Already Exists: Job carwow:europe-west2.job_1')],
      loaded_job: nil
    )
    driver = Olaf::BigQuery.new(project: 'carwow', retry_delays: [0, 0], client: client)

    error = assert_raise Olaf::QueryExecutionError do
      driver.run(@query_instance)
    end

    assert_equal error.message, 'Already Exists: Job carwow:europe-west2.job_1'
  end

  def test_run_does_not_retry_errors_reported_by_the_api
    client = FakeClient.new(errors: [google_error_caused_by(Google::Apis::ClientError.new('quota'))])
    driver = Olaf::BigQuery.new(project: 'carwow', retry_delays: [0, 0], client: client)

    assert_raise Olaf::QueryExecutionError do
      driver.run(@query_instance)
    end

    assert_equal client.query_jobs, 1
  end

  def test_run_retries_a_dropped_connection_the_google_client_wrapped
    dropped_connection = google_error_caused_by(Google::Apis::TransmissionError.new('Connection reset by peer'))
    client = FakeClient.new(errors: [dropped_connection])
    driver = Olaf::BigQuery.new(project: 'carwow', retry_delays: [0, 0], client: client)

    assert_equal driver.run(@query_instance).rows, [{ country: 'UK' }]
    assert_equal client.query_jobs, 2
  end

  def test_run_wraps_a_dropped_connection_the_google_client_wrapped_once_the_retries_run_out
    dropped_connection = google_error_caused_by(Google::Apis::TransmissionError.new('Connection reset by peer'))
    client = FakeClient.new(errors: [dropped_connection] * 3)
    driver = Olaf::BigQuery.new(project: 'carwow', retry_delays: [0, 0], client: client)

    error = assert_raise Olaf::QueryExecutionError do
      driver.run(@query_instance)
    end

    assert_equal error.message, 'Connection reset by peer'
    assert_equal client.query_jobs, 3
  end

  def test_run_retries_waiting_for_the_job_without_starting_another
    job = FakeJob.new(wait_errors: [OpenSSL::SSL::SSLError.new('SSL_read: unexpected eof while reading')])
    client = FakeClient.new(job: job)
    driver = Olaf::BigQuery.new(project: 'carwow', retry_delays: [0, 0], client: client)

    driver.run(@query_instance)

    assert_equal job.waits, 2
    assert_equal client.query_jobs, 1
  end

  private

  # Exception#cause can only be set by raising.
  def google_error_caused_by(cause)
    raise Google::Cloud::Error, cause.message, cause: cause
  rescue Google::Cloud::Error => error
    error
  end

  def query_class(template:)
    Class.new.include(Olaf::QueryDefinition).tap do |klass|
      klass.template File.join(File.dirname(__FILE__), '../fixtures', template)
    end
  end
end
