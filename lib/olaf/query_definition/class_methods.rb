module Olaf
  module QueryDefinition
    module ClassMethods
      # Creates a new instance of the Query defined and validates
      # the parameters passed, leaving the instance in a ready-to-execute state.
      #   @return Snowflake::QueryDefinition instance
      def prepare(**vars)
        new(vars).prepare
      end

      # Returns ALL the arguments defined for the query, including options.
      #   @return Hash
      def arguments
        @arguments ||= {}
      end

      # Define an argument for the query matching a placeholder in the template.
      # The Sequel gem, will fill the placeholders in the SQL query escaping the
      # value passed as an argument. Sometimes, we need to pass an argument as
      # literal to avoid the single quotes added by Sequel (i.e. sending a table_name)
      #
      # options - Hash config for each argument
      #   :as - Argument Type
      #     * :literal - Forces a string substitution with the literal value
      #
      # Example:
      #
      #     class OneQuery
      #       include Snowflake::QueryDefinition
      #
      #       template 'reports/one.sql'
      #
      #       argument :dealersip_id
      #       argument :table_name, as: :literal
      #     end
      #
      #
      def argument(name, options = {})
        return if arguments.key?(name)

        arguments[name] = { literal: options[:as] == :literal }

        name
      end

      # Define the file path to the SQL template for this query.
      #
      # Example:
      #
      #     class OneQuery
      #       include Snowflake::QueryDefinition
      #
      #       template 'reports/one.sql'
      #     end
      #
      #
      def template(file_name = nil)
        @template ||= file_name
      end

      # Define the object representing each row of the result.
      # When not specified, each row will be a hash by default.
      #
      # Example:
      #
      #     class OneQuery
      #       include Snowflake::QueryDefinition
      #
      #       row_object MyOwnObject
      #     end
      #
      #
      def row_object(object_class = nil)
        @row_object ||= object_class
      end
    end
  end
end

