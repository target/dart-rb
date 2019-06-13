module Dart
  module Helpers
    def wrap_ffi(raw)
      case raw.get_type
      when :object then Object.new(raw)
      when :array then Array.new(raw)
      when :string then String.new(raw)
      when :integer then Integer.new(raw)
      when :decimal then Decimal.new(raw)
      when :boolean then Boolean.new(raw)
      when :null then Null.new
      else raise InternalError, 'Encountered unexpected type while constructing child'
      end
    end

    extend self
  end
end
