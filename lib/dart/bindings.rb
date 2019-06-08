require 'ffi'

module Dart
  module FFI
    # Bootstrap our FFI library
    extend ::FFI::Library
    ffi_lib 'dart_abi'

    BUFFER_MAX_SIZE = 1 << 5
    HEAP_MAX_SIZE = 1 << 6
    PACKET_MAX_SIZE = HEAP_MAX_SIZE
    ITERATOR_MAX_SIZE = 1 << 8

    # Define our type enum
    Type = enum :type, [
      :object, 1,
      :array,
      :string,
      :integer,
      :decimal,
      :boolean,
      :null,
      :invalid
    ]

    # Define our packet type enum
    PacketType = enum :packet_type, [
      :heap, 1,
      :buffer,
      :packet
    ]

    # Define our reference counter type enum
    RCType = enum :rc_type, [
      :rc_safe, 1,
      :rc_unsafe
    ]

    # Define our error type enum
    ErrorType = enum :err_type, [
      :no_error,
      :type_error,
      :logic_error,
      :state_error,
      :parse_error,
      :runtime_error,
      :client_error,
      :unknown_error
    ]

    # Define type type id struct used as RTTI
    class TypeID < ::FFI::Struct
      layout :p_id, PacketType, :rc_id, RCType
    end

    # Define our iterator struct
    class Iterator < ::FFI::Struct
      layout :rtti, TypeID, :bytes, [:char, ITERATOR_MAX_SIZE]
    end

    # Define our heap structure.
    class Heap < ::FFI::Struct
      layout :rtti, TypeID, :bytes, [:char, HEAP_MAX_SIZE]
    end

    # Define our buffer structure.
    class Buffer < ::FFI::Struct
      layout :rtti, TypeID, :bytes, [:char, BUFFER_MAX_SIZE]
    end

    # Define our packet structure.
    class Packet < ::FFI::Struct
      layout :rtti, TypeID, :bytes, [:char, PACKET_MAX_SIZE]
    end

    # Attach our functions.
    attach_function :dart_from_json_err, [:pointer, :string], ErrorType
    attach_function :dart_to_json, [:pointer, :pointer], :string

  end
end
