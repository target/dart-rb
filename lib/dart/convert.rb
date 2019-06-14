module Dart
  module Convert

    def to_dart(val = self, wrap: true)
      # Short-circuit if we already have a
      # Dart object.
      if wrap && val.is_a?(Dart::Common)
        return val
      elsif val.is_a?(Dart::Common)
        return val.send(:native)
      end

      # General conversion case.
      val = case val
      when FFI::Packet
        val
      when ::Hash
        obj = FFI::Packet.make_obj
        val.each_pair { |k, v| obj.insert(k, to_dart(v, wrap: false)) }
        obj
      when ::Array
        arr = FFI::Packet.make_arr
        val.each.with_index { |v, i| arr.insert(i, to_dart(v, wrap: false)) }
        arr
      when ::String
        FFI::Packet.make_str(val)
      when ::Symbol
        FFI::Packet.make_str(val.to_s)
      when ::Fixnum
        FFI::Packet.make_primitive(val, :int)
      when ::Float
        FFI::Packet.make_primitive(val, :dcm)
      when ::TrueClass, ::FalseClass
        FFI::Packet.make_primitive(val ? 1 : 0, :bool)
      when ::NilClass
        FFI::Packet.make_null
      else
        val.respond_to?(:to_dart) ? val.to_dart(wrap: false) : raise(TypeError, 'Given type is not coercible to Dart')
      end

      # Wrap and return.
      if wrap then Helpers.wrap_ffi(val)
      else val
      end
    end

  end
end
