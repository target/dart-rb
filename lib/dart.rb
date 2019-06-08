require 'dart/version'
require 'dart/errors'
require 'dart/bindings'

module Dart

  class Packet
    def initialize(ptr)
      @native = ptr
    end

    def self.from_json(str)
      Dart.from_json(str)
    end

    def to_json
      # Have to allocate a size_t to get the size of the pointer.
      # At the very least, only do it once.
      @size_cache ||= ::FFI::MemoryPointer.new(FFI::Size)

      # Ruby FFI doesn't seem to have any way to allow a ruby string
      # to _steal_ an existing character pointer
      # So we need to do an ADDITIONAL allocation here which sucks.
      ptr = FFI.dart_to_json(@native, @size_cache)
      len = FFI::Size.new(@size_cache)
      str = ptr.read_string(len[:value])
      FFI::LibC.free(ptr)
      str
    end

    def to_s
      to_json
    end
  end

  def self.from_json(str)
    ptr = FFI::Packet.alloc
    err = FFI.dart_from_json_len_err(ptr, str, str.size)
    handle_error(err)
    Packet.new(ptr)
  end

end
