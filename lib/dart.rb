require 'dart/version'
require 'dart/bindings'

module Dart

  class Packet
    def initialize(ptr)
      @native = ptr
    end

    def to_json
      FFI.dart_to_json(@native, nil)
    end

    def to_s
      to_json
    end
  end

  def self.from_json(str)
    ptr = ::FFI::MemoryPointer.new(FFI::Packet)
    err = FFI.dart_from_json_err(ptr, str)
    raise 'Oops' if err != :no_error
    Packet.new(ptr)
  end

end
