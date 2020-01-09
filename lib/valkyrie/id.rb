# frozen_string_literal: true
module Valkyrie
  # A simple ID class to keep IDs distinguished from strings
  # In order for an object to be queryable via joins, it needs
  # to be added as a reference via a Valkyrie::ID rather than just a string ID.
  class ID
    attr_reader :id
    delegate :empty?, to: :id
    def initialize(id)
      @id = id.to_s
    end

    def to_s
      id
    end

    delegate :hash, to: :state

    def eql?(other)
      return (default_equality(other) || string_equality(other)) if Valkyrie.config.id_string_equality == true
      default_equality(other)
    end
    alias == eql?

    protected

      def default_equality(other)
        output = (other.class == self.class && other.state == state)
        return output if output == true
        if output == false && string_equality(other) && Valkyrie.config.id_string_equality.nil?
          # :nocov:
          warn "[DEPRECATION] Valkyrie::IDs will always be equal to their string counterparts in 3.0.0. " \
            "To silence this message, please either compare IDs or set Valkyrie.config.id_string_equality = true."
          # :nocov:
        end
        false
      end

      def string_equality(other)
        other.to_s == to_s
      end

      def state
        [@id]
      end
  end
end
