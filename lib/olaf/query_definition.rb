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
      raise UnknownArgumentsError, self if unknown_arguments.any?

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

    def ==(other)
      self.class == other.class && self.variables == other.variables
    end

    def defined_arguments
      self.class.arguments.keys
    end

    def missing_arguments
      defined_arguments - @variables.keys
    end

    # Every placeholder MUST be declared as an `argument` of the query.
    def undefined_arguments
      placeholders - defined_arguments
    end

    # Every `argument` declared in the query MUST have a placeholder in the SQL file.
    def unknown_arguments
      defined_arguments - placeholders
    end

    private

    # Find placeholders in the SQL file.
    def placeholders
      @placeholders ||= @sql_template.scan(/[^:]:(\w+)/).flatten.map(&:to_sym).uniq
    end
  end
end
