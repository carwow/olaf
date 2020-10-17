module Olaf
  class Fake
    attr_reader :config, :execution_log, :recorded_responses

    def initialize(**config)
      @config = config
      @execution_log = []
      @recorded_responses = {}
    end

    def fetch(olaf_query)
      @execution_log << olaf_query

      generic_response = @recorded_responses.dig(olaf_query.class, :generic)
      specific_response = @recorded_responses.dig(olaf_query.class, olaf_query.variables)

      specific_response || generic_response || raise_developer_error!(olaf_query)
    end

    def register_result(olaf_query_class, result, with: :generic)
      @recorded_responses[olaf_query_class] ||= {}
      @recorded_responses[olaf_query_class].merge!(with => result)
    end

    private

    def raise_developer_error!(query)
      error_msg = "No Query result registered for '#{query.class}' with: #{query.variables} found!"

      available_responses =
        @recorded_responses
          .map { |k, v| [k, ['', *v.keys].join("\n\t\t=> ")] }
          .map { |klass, args| "\t #{klass}#{args}" }
          .join("\n\n")
          .then { |str| "Queries responses registered: \n\n #{str}" unless str.empty?}

      puts %{
        #{error_msg}

        This is a testing environment and the query has no result registered.
        To register a query result call `Olaf.instance.register_result`
        during the test setup or before executing the query.


            Olaf.instance.register_result(#{query.class}, [])


        To register a result for specific arguments you can specify the variables:


            Olaf.instance.register_result(#{query.class}, [], with: #{query.variables})


        #{available_responses}
      }

      raise error_msg
    end
  end
end
