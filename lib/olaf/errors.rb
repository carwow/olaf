module Olaf
  class MissingArgumentsError < ArgumentError
    def initialize(olaf_query)
      @olaf_query = olaf_query
      msg = "Missing arguments: #{olaf_query.missing_arguments}"

      super(msg)
    end

    def metadata
      {
        query: @olaf_query.class.name,
        defined_arguments: @olaf_query.defined_arguments,
        missing_arguments: @olaf_query.missing_arguments,
        arguments: @olaf_query.variables
      }
    end
  end

  class UndefinedArgumentsError < StandardError
    def initialize(olaf_query)
      super("Undefined arguments: #{olaf_query.undefined_arguments}")
    end
  end

  class QueryExecutionError < StandardError
    attr_reader :metadata

    def initialize(message, olaf_query)
      @query = olaf_query
      @metadata = olaf_query.metadata
      super(message)
    end
  end
end
