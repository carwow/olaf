require_relative 'errors'
require_relative 'query_definition/class_methods'

module Olaf
  module QueryDefinition
    attr_reader :variables, :sql_template

    def self.included(base)
      base.extend(Olaf::QueryDefinition::ClassMethods)
    end

    def initialize(**variables)
      @variables = variables
      @sql_template = nil
    end

    # Loads the SQL template and validate all the arguments are
    # defined AND present.
    # The instance will be ready to be executed.
    #
    #   @return QueryDefinition instance
    #
    #   @raises Snowflake::UndefinedArgumentsError
    #   @raises Snowflake::MissingArgumentsError
    def prepare
      @sql_template ||= File.read(self.class.template)

      raise UndefinedArgumentsError, self if undefined_arguments.any?
      raise MissingArgumentsError, self if missing_arguments.any?

      literal_arguments = self.class.arguments.select { |_k, v| v[:literal] }.keys

      variables.slice(*literal_arguments).each do |placeholder, literal_value|
        @sql_template.gsub!(":#{placeholder}", literal_value)
      end

      self
    end

    def metadata
      {
        query_class: self.class.name,
        arguments: variables,
        sql_template: sql_template,
      }
    end

    def defined_arguments
      self.class.arguments.keys
    end

    def missing_arguments
      defined_arguments - @variables.keys
    end

    # Find placeholders in the SQL file.
    # Every placeholder MUST be declared as an `argument` of the query.
    def undefined_arguments
      @sql_template
        .scan(/[^:]:(\w+)/)
        .flatten
        .map(&:to_sym)
        .then { |required_arguments| required_arguments - defined_arguments }
        .uniq
    end
  end
end
