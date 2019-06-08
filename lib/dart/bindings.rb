require 'ffi'

module Dart
  module FFI
    module LibC
      extend ::FFI::Library
      ffi_lib ::FFI::Library::LIBC

      # Allocation
      attach_function :malloc, [:size_t], :pointer
      attach_function :free, [:pointer], :void
    end

    # Bootstrap our FFI library
    extend ::FFI::Library
    ffi_lib 'dart_abi'

    class DartStruct < ::FFI::Struct
      def self.alloc
        ptr = ::FFI::AutoPointer.new(LibC.malloc(self.size), self.method(:destroy))
        self.new(ptr)
      end
      def self.destroy(ptr)
        self.destructor(ptr)
        LibC.free(ptr)
      end
    end

    PACKET_MAX_SIZE = 1 << 6
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
    class Iterator < DartStruct
      layout :rtti, TypeID, :bytes, [:char, ITERATOR_MAX_SIZE]

      def self.destructor(ptr)
        FFI.dart_iterator_destroy(ptr)
      end
    end

    # Define our packet structure.
    class Packet < DartStruct
      layout :rtti, TypeID, :bytes, [:char, PACKET_MAX_SIZE]

      def self.destructor(ptr)
        FFI.dart_destroy(ptr)
      end
    end

    class Size < ::FFI::Struct
      layout :value, :size_t
    end

    # Attach constructors.
    attach_function :dart_obj_init_err, [:pointer], ErrorType
    attach_function :dart_arr_init_err, [:pointer], ErrorType
    attach_function :dart_str_init_err, [:pointer, :size_t], ErrorType
    attach_function :dart_int_init_err, [:pointer, :int64], ErrorType
    attach_function :dart_dcm_init_err, [:pointer, :double], ErrorType
    attach_function :dart_bool_init_err, [:pointer, :int], ErrorType
    attach_function :dart_null_init_err, [:pointer], ErrorType
    attach_function :dart_destroy, [:pointer], ErrorType

    # Attach object insertion functions.
    attach_function :dart_obj_insert_dart_len, [:pointer, :pointer, :size_t, :pointer], ErrorType
    attach_function :dart_obj_insert_take_dart_len, [:pointer, :pointer, :size_t, :pointer], ErrorType
    attach_function :dart_obj_insert_str_len, [:pointer, :pointer, :size_t, :pointer, :size_t], ErrorType
    attach_function :dart_obj_insert_int_len, [:pointer, :pointer, :size_t, :int64], ErrorType
    attach_function :dart_obj_insert_dcm_len, [:pointer, :pointer, :size_t, :double], ErrorType
    attach_function :dart_obj_insert_bool_len, [:pointer, :pointer, :size_t, :int], ErrorType
    attach_function :dart_obj_insert_null_len, [:pointer, :pointer, :size_t], ErrorType

    # Attach object set functions.
    attach_function :dart_obj_set_dart_len, [:pointer, :pointer, :size_t, :pointer], ErrorType
    attach_function :dart_obj_set_take_dart_len, [:pointer, :pointer, :size_t, :pointer], ErrorType
    attach_function :dart_obj_set_str_len, [:pointer, :pointer, :size_t, :pointer, :size_t], ErrorType
    attach_function :dart_obj_set_int_len, [:pointer, :pointer, :size_t, :int64], ErrorType
    attach_function :dart_obj_set_dcm_len, [:pointer, :pointer, :size_t, :double], ErrorType
    attach_function :dart_obj_set_bool_len, [:pointer, :pointer, :size_t, :int], ErrorType
    attach_function :dart_obj_set_null_len, [:pointer, :pointer, :size_t], ErrorType

    # Attach object erase functions.
    attach_function :dart_obj_erase_len, [:pointer, :pointer, :size_t], ErrorType

    # Attach object retrieval functions.
    attach_function :dart_obj_get_len_err, [:pointer, :pointer, :pointer, :size_t], ErrorType

    # Attach array insertion operations.
    attach_function :dart_arr_insert_dart, [:pointer, :size_t, :pointer], ErrorType
    attach_function :dart_arr_insert_take_dart, [:pointer, :size_t, :pointer], ErrorType
    attach_function :dart_arr_insert_str_len, [:pointer, :size_t, :pointer, :size_t], ErrorType
    attach_function :dart_arr_insert_int, [:pointer, :size_t, :int64], ErrorType
    attach_function :dart_arr_insert_dcm, [:pointer, :size_t, :double], ErrorType
    attach_function :dart_arr_insert_bool, [:pointer, :size_t, :int], ErrorType
    attach_function :dart_arr_insert_null, [:pointer, :size_t], ErrorType

    # Attach array set functions.
    attach_function :dart_arr_set_dart, [:pointer, :size_t, :pointer], ErrorType
    attach_function :dart_arr_set_take_dart, [:pointer, :size_t, :pointer], ErrorType
    attach_function :dart_arr_set_str_len, [:pointer, :size_t, :pointer, :size_t], ErrorType
    attach_function :dart_arr_set_int, [:pointer, :size_t, :int64], ErrorType
    attach_function :dart_arr_set_dcm, [:pointer, :size_t, :double], ErrorType
    attach_function :dart_arr_set_bool, [:pointer, :size_t, :int], ErrorType
    attach_function :dart_arr_set_null, [:pointer, :size_t], ErrorType

    # Attach array erase functions.
    attach_function :dart_arr_erase, [:pointer, :size_t], ErrorType

    # Attach array retrieval functions.
    attach_function :dart_arr_get_err, [:pointer, :pointer, :size_t], ErrorType

    # Attach primitive retrival functions.
    attach_function :dart_str_get_len, [:pointer, :pointer], :pointer
    attach_function :dart_int_get_err, [:pointer, :pointer], ErrorType
    attach_function :dart_dcm_get_err, [:pointer, :pointer], ErrorType
    attach_function :dart_bool_get_err, [:pointer, :pointer], ErrorType

    # Attach introspection functions.
    attach_function :dart_size, [:pointer], :size_t
    attach_function :dart_equal, [:pointer, :pointer], :int
    attach_function :dart_is_obj, [:pointer], :int
    attach_function :dart_is_arr, [:pointer], :int
    attach_function :dart_is_str, [:pointer], :int
    attach_function :dart_is_int, [:pointer], :int
    attach_function :dart_is_dcm, [:pointer], :int
    attach_function :dart_is_bool, [:pointer], :int
    attach_function :dart_is_null, [:pointer], :int
    attach_function :dart_is_finalized, [:pointer], :int
    attach_function :dart_get_type, [:pointer], Type

    # Attach json functions.
    attach_function :dart_from_json_len_err, [:pointer, :string, :size_t], ErrorType
    attach_function :dart_to_json, [:pointer, :pointer], :pointer

    # Attach API transition functions.
    attach_function :dart_lower_err, [:pointer, :pointer], ErrorType
    attach_function :dart_lift_err, [:pointer, :pointer], ErrorType

    # Attach network functions.
    attach_function :dart_get_bytes, [:pointer, :pointer], ErrorType
    attach_function :dart_dup_bytes, [:pointer, :pointer], :pointer
    attach_function :dart_from_bytes_err, [:pointer, :pointer, :size_t], ErrorType
    attach_function :dart_take_bytes_err, [:pointer, :pointer], ErrorType

    # Attach iterator functions.
    attach_function :dart_iterator_init_err, [:pointer, :pointer], ErrorType
    attach_function :dart_iterator_init_key_err, [:pointer, :pointer], ErrorType
    attach_function :dart_iterator_copy_err, [:pointer, :pointer], ErrorType
    attach_function :dart_iterator_move_err, [:pointer, :pointer], ErrorType
    attach_function :dart_iterator_destroy, [:pointer], ErrorType
    attach_function :dart_iterator_get_err, [:pointer, :pointer], ErrorType
    attach_function :dart_iterator_next, [:pointer], ErrorType
    attach_function :dart_iterator_done, [:pointer], :int

    # Attach error handling functions.
    attach_function :dart_get_error, [], :strptr

  end
end
