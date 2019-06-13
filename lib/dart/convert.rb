module Dart
  module Convert

    def to_dart(val = self)
      # Short-circuit if we already have a
      # Dart object.
      return val.send(:native) if val.is_a?(Dart::Common)

      # General conversion case.
      case val
      when FFI::Packet then val
      when ::Hash then FFI::Packet.make_obj.tap { |o| val.each_pair { |k, v| o.insert(k, to_dart(v)) } }
      when ::Array then FFI::Packet.make_arr.tap { |a| val.each.with_index { |v, i| a.insert(i, to_dart(v)) } }
      when ::String then FFI::Packet.make_str(val)
      when ::Symbol then FFI::Packet.make_str(val.to_s)
      when ::Fixnum then FFI::Packet.make_primitive(val, :int)
      when ::Float then FFI::Packet.make_primitive(val, :dcm)
      when ::TrueClass, ::FalseClass then FFI::Packet.make_primitive(val ? 1 : 0, :bool)
      when ::NilClass then FFI::Packet.make_null
      else val.respond_to?(:to_dart) ? val.to_dart.send(:native) : raise(TypeError, 'Given type is not coercible to Dart')
      end
    end

  end
end
