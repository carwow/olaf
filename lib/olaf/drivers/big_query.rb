# Not a dependency of the gem: consumers of this driver add it themselves.
require 'google/cloud/bigquery'
require 'securerandom'

# The API client debug-logs whole response bodies, which for a warehouse query
# is the entire result set.
Google::Apis.logger.level = [Google::Apis.logger.level, Logger::INFO].max

module Olaf
  class BigQuery
    GIGABYTE = 1024**3

    # Restrictive on purpose: a query that scans more says so with
    # `driver :big_query, maximum_bytes_billed: ...`.
    DEFAULT_MAXIMUM_BYTES_BILLED = GIGABYTE

    # Labels only accept lowercase letters, numbers, dashes and underscores.
    LABEL_FORMAT = /[^a-z0-9_-]/.freeze
    LABEL_MAX_LENGTH = 63

    RETRY_DELAYS = [1, 2].freeze

    # Credentials default to the ambient Google ones, and the client is built
    # from the arguments unless one is given.
    def initialize(project: nil, credentials: nil, maximum_bytes_billed: DEFAULT_MAXIMUM_BYTES_BILLED,
                   labels: {}, retry_delays: RETRY_DELAYS, client: nil)
      @project = project
      @credentials = credentials
      @maximum_bytes_billed = maximum_bytes_billed
      @labels = labels
      @retry_delays = retry_delays
      @client = client
    end

    def fetch(olaf_query)
      run(olaf_query).data.all.to_a
    end

    # Returns the finished job, so callers can read its stats (bytes billed,
    # cache hit) on top of its rows.
    #
    #   @raises Olaf::QueryExecutionError, or OpenSSL::SSL::SSLError when the
    #   connection keeps dropping
    def run(olaf_query)
      job = start_job(olaf_query)
      retrying_dropped_connections { job.wait_until_done! }

      raise QueryExecutionError.new(job.error.to_h['message'].to_s, olaf_query) if job.failed?

      job
    rescue *wrapped_errors => error
      raise QueryExecutionError.new(error.message, olaf_query)
    end

    private

    def client
      @client ||= Google::Cloud::Bigquery.new(project: @project, credentials: @credentials)
    end

    # A connection can drop after BigQuery has started the job, so every attempt
    # reuses one job ID: BigQuery refuses the retry as a duplicate, rather than
    # running and billing the query twice.
    def start_job(olaf_query)
      job_id = "job_#{SecureRandom.urlsafe_base64(21)}"
      attempts = 0

      retrying_dropped_connections do
        attempts += 1
        client.query_job(
          sql(olaf_query),
          params: params(olaf_query),
          maximum_bytes_billed: maximum_bytes_billed(olaf_query),
          labels: labels(olaf_query),
          job_id: job_id
        )
      rescue Google::Cloud::AlreadyExistsError
        raise if attempts == 1

        client.job(job_id)
      end
    end

    # google-cloud-bigquery switches off google-apis-core's retries.
    def retrying_dropped_connections
      @retry_delays.each do |delay|
        return yield
      rescue StandardError => error
        raise unless dropped_connection?(error)

        sleep delay
      end

      yield
    end

    def dropped_connection?(error)
      error.is_a?(OpenSSL::SSL::SSLError)
    end

    # Google::Cloud::Error covers everything the API reports, Google::Auth::Error
    # credentials missing or expired before a call is made. The second one only
    # exists in googleauth 1.14 and later. A dropped connection is left out, so
    # once its retries run out the caller's job runner can still retry it.
    def wrapped_errors
      @wrapped_errors ||= [
        Google::Cloud::Error,
        (Google::Auth::Error if defined?(Google::Auth::Error))
      ].compact
    end

    # olaf validates `:foo` placeholders, BigQuery binds `@foo`. Only declared
    # argument names are rewritten, so casts and time literals are left alone.
    def sql(olaf_query)
      params(olaf_query).keys.reduce(olaf_query.sql_template) do |sql, name|
        sql.gsub(/(?<!:):#{name}\b/, "@#{name}")
      end
    end

    # Literal arguments were substituted into the template by `prepare`.
    def params(olaf_query)
      literal_arguments = literal_arguments(olaf_query)

      olaf_query.variables.reject { |name, _value| literal_arguments.include?(name) }
    end

    def literal_arguments(olaf_query)
      olaf_query.class.arguments.select { |_name, options| options[:literal] }.keys
    end

    def maximum_bytes_billed(olaf_query)
      olaf_query.class.driver_options.fetch(:maximum_bytes_billed, @maximum_bytes_billed)
    end

    def labels(olaf_query)
      @labels
        .merge(query: File.basename(olaf_query.class.template.to_s, '.sql'))
        .transform_values { |value| label_value(value) }
    end

    def label_value(value)
      value.to_s.downcase.gsub(LABEL_FORMAT, '_')[0, LABEL_MAX_LENGTH]
    end
  end
end
