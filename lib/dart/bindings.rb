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

    class DartPointer < ::FFI::AutoPointer
      attr_reader :valid
      def initialize(*args)
        # Call our superclass.
        super(*args)

        # Mark ourselves as uninitialized.
        @valid = false
      end

      # Mark the pointer as destroyable.
      def mark_valid
        @valid = true
      end
    end

    # Bootstrap our FFI library
    extend ::FFI::Library
    ffi_lib 'dart_abi'

    class DartStruct < ::FFI::Struct
      # Hands out a pointer to raw, unconstructed, memory for the
      # given type.
      # Pointer must be marked valid after being constructed to free
      # its memory upon destruction.
      def self.alloc
        DartPointer.new(LibC.malloc(self.size), self.method(:destroy))
      end

      # Calls the type specific destructor for the given pointer if
      # the pointer is valid.
      # Will be called automatically by pointer returned by alloc
      # SHOULD NOT BE CALLED DIRECTLY
      def self.destroy(ptr)
        self.destructor(ptr) if ptr.valid
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

      extend Errors
      include Errors

      #----- Value Manipulation Methods -----#

      def lookup(key)
        # Make sure we've been given something we can use.
        enforce_types(key, object: [String, Symbol], array: Fixnum)

        # Perform the lookup.
        key = key.is_a?(Symbol) ? key.to_s : key
        ptr = self.class.alloc
        raising_errors do
          if obj?
            FFI.dart_obj_get_len_err(ptr, self, key, key.size) 
          else
            FFI.dart_arr_get_err(ptr, self, key)
          end
        end
        ptr.mark_valid

        # Wrap the pointer and return.
        self.class.new(ptr)
      end

      def insert(key, val)
        mutate(key, val, obj: :dart_obj_insert_dart_len, arr: :dart_arr_insert_dart)
      end

      def update(key, val)
        mutate(key, val, obj: :dart_obj_insert_dart_len, arr: :dart_arr_set_dart)
      end

      def set(key, val)
        mutate(key, val, obj: :dart_obj_set_dart_len, arr: :dart_arr_set_dart)
      end

      def remove(key)
        # Make sure we've been given something we can use.
        enforce_types(key, object: [String, Symbol], array: Fixnum)

        # Remove the key.
        key = key.is_a?(Symbol) ? key.to_s : key
        raising_errors do
          if obj?
            FFI.dart_obj_erase_len(self, key, key.size)
          else
            FFI.dart_arr_erase(self, key)
          end
        end
        nil
      end

      def unwrap
        # Make sure we're an unwrappable type.
        enforce_types(nil, string: nil, integer: nil, decimal: nil, boolean: nil)

        # Get our underlying value.
        begin
          case get_type
          when :string
            # Call through to our library to unwrap the string.
            size = size_cache
            ptr = FFI.dart_str_get_len(self, size)
            raise if ptr.null?

            # It worked, safely read the string value.
            len = FFI::SizeT.new(size)
            ptr.read_string(len[:value]).force_encoding(Encoding::UTF_8)
          when :integer
            # Call through to our library to unwrap the integer.
            int64 = int64_cache
            raising_errors { FFI.dart_int_get_err(self, int64) }

            # It worked, unwrap the integer.
            val = FFI::Int64.new(int64)
            val[:value]
          when :decimal
            # Call through to our library to unwrap the decimal.
            double = double_cache
            raising_errors { FFI.dart_dcm_get_err(self, double) }

            # It worked, unwrap the decimal.
            val = FFI::Double.new(double)
            val[:value]
          when :boolean
            # Call through to our library to unwrap the boolean.
            bool = int_cache
            raising_errors { FFI.dart_bool_get_err(self, bool) }

            # It worked, unwrap the boolean.
            val = FFI::Int.new(bool)
            val[:value] == 1
          end
        rescue
          raise InternalError, "Received unexpected result of unwrapping #{get_type}"
        end
      end

      #----- Introspection Methods -----#

      def obj?
        get_type == :object
      end

      def arr?
        get_type == :array
      end

      def aggr?
        obj? || arr?
      end

      def str?
        get_type == :string
      end

      def dcm?
        get_type == :decimal
      end

      def bool?
        get_type == :boolean
      end

      def null?
        get_type == :null
      end

      def get_type
        # Can't fail.
        FFI.dart_get_type(self)
      end

      def is_finalized
        # Can't fail.
        FFI.dart_is_finalized(self) != 0
      end

      def size
        # Dart returns an identifier type we don't have good access to
        # in the event dart_size fails, so just perform the check in advance.
        enforce_types(nil, object: nil, array: nil, string: nil)
        FFI.dart_size(self)
      end

      #----- JSON Methods -----#

      def self.from_json(str, finalize = true)
        # Allocate a structure and parse the json.
        # Note that I'm actually constructing a dart_heap_t in the case
        # that we've been asked to do non-finalized parsing.
        # The C api is actually intelligent enough to handle this, so
        # we should be good to go.
        ptr = alloc
        if finalize
          raising_errors { FFI.dart_from_json_len_err(ptr, str, str.size) }
        else
          raising_errors { FFI.dart_heap_from_json_len_err(ptr, str, str.size) }
        end
        ptr.mark_valid

        # Wrap the pointer as a packet and return.
        new(ptr)
      end

      def to_json
        # Need this to capture the size of the JSON string as an out-parameter.
        # Only way that Ruby FFI supports doing this is by allocating a new size_t.
        size = size_cache

        # Ruby FFI doesn't seem to have any way to allow a ruby string
        # to _steal_ an existing character pointer
        # So we need to do an ADDITIONAL allocation here which sucks.
        ptr = FFI.dart_to_json(self, size)
        raise 'Dart failed to create a JSON representation' if ptr.null?

        # Read the character pointer into a Ruby string.
        len = FFI::SizeT.new(size)
        str = ptr.read_string(len[:value])
        FFI::LibC.free(ptr)
        str
      end

      #----- Network Methods -----#
      
      def get_bytes
        # Get our network buffer, or throw if it doesn't exist.
        size = size_cache
        ptr = FFI.dart_get_bytes(self, size)
        if ptr.null?
          errmsg, _ = FFI.dart_get_error
          raise StateError, errmsg
        end

        # Read our buffer into a Ruby string.
        len = FFI::SizeT.new(size)
        str = ptr.read_string(len[:value]).force_encoding(Encoding::BINARY)
        str
      end

      def self.from_bytes(bytes)
        # Make sure we've been given something reasonable.
        raise ArgumentError, 'Can only reconstruct Dart object from a buffer of bytes' unless bytes.is_a?(String)

        # Unfortunately we have to copy here.
        # We're constrained by the API Ruby FFI exposes.
        space = ::FFI::MemoryPointer.new(:char, bytes.bytesize)
        space.put_bytes(0, bytes)

        # Attempt to reconstruct our buffer.
        ptr = alloc
        raising_errors { FFI.dart_from_bytes_err(ptr, space, bytes.bytesize) }
        ptr.mark_valid
        new(ptr)
      end

      #----- API Transition Methods -----#

      def lower
        # Allocate a pointer to write our lowered result into.
        ptr = self.class.alloc

        # Lower ourselves
        raising_errors { FFI.dart_lower_err(ptr, self) }
        ptr.mark_valid
        self.class.new(ptr)
      end

      def finalize
        lower
      end

      def lift
        # Allocate a pointer to write our lifted result into.
        ptr = self.class.alloc

        # Lift ourselves.
        raising_errors { FFI.dart_lift_err(ptr, self) }
        ptr.mark_valid
        self.class.new(ptr)
      end

      def definalize
        lift
      end

      #----- Language Overrides -----#

      def ==(other)
        return false unless other.is_a?(Packet)
        FFI.dart_equal(self, other) == 1
      end

      def dup
        ptr = self.class.alloc
        raising_errors { FFI.dart_copy_err(ptr, self) }
        self.class.new(ptr)
      end

      def to_s
        to_json
      end

      #----- Type Helpers -----#

      def enforce_types(arg, **types)
        # Lookup what we need to enforce.
        unless types.has_key?(get_type)
          raise TypeError, "`#{caller_name}' cannot be called on an instance of `#{get_type}'"
        end

        # Check that the argument is of the right type
        req = types[get_type]
        unless req.nil?
          req = req.is_a?(Array) ? req : [req]
          req.each { |type| return if arg.is_a?(type) }
          raise TypeError, "`#{caller_name}' must be called with an instance of [`#{req.join("', `")}']"
        end
      end

      #----- Native Memory Helpers -----#

      def convert(val)
        case val
        when Packet then val
        when Hash then const_obj.tap { |p| val.each_pair { |k, v| p.insert(k, v) } }
        when Array then const_arr.tap { |p| val.each.with_index { |v, i| p.insert(i, v) } }
        when String then const_str(val)
        when Symbol then const_str(val.to_s)
        when Fixnum then const_primitive(val, :int)
        when Float then const_primitive(val, :dcm)
        when TrueClass, FalseClass then const_primitive(val ? 1 : 0, :bool)
        when NilClass then const_null
        else raise TypeError, "Dart cannot convert value of type `#{val.class.name}'"
        end
      end

      def int_cache
        @int_cache ||= ::FFI::MemoryPointer.new(FFI::Int)
      end

      def int64_cache
        @int64_cache ||= ::FFI::MemoryPointer.new(FFI::Int64)
      end

      def size_cache
        @size_cache ||= ::FFI::MemoryPointer.new(FFI::SizeT)
      end

      def double_cache
        @double_cache ||= ::FFI::MemoryPointer.new(FFI::Double)
      end

      def alloc_obj
        ptr = self.class.alloc
        raising_errors { FFI.dart_obj_init_err(ptr) }
        ptr.mark_valid
        ptr
      end

      def const_obj
        Packet.new(alloc_obj)
      end

      def alloc_arr
        ptr = self.class.alloc
        raising_errors { FFI.dart_arr_init_err(ptr) }
        ptr.mark_valid
        ptr
      end

      def const_arr
        Packet.new(alloc_arr)
      end

      def alloc_str(str)
        ptr = self.class.alloc
        raising_errors { FFI.dart_str_init_err(ptr, str, str.size) }
        ptr.mark_valid
        ptr
      end

      def const_str(str)
        Packet.new(alloc_str(str))
      end

      def alloc_primitive(arg, type)
        ptr = self.class.alloc
        raising_errors { FFI.send("dart_#{type}_init_err", ptr, arg) }
        ptr.mark_valid
        ptr
      end

      def const_primitive(arg, type)
        Packet.new(alloc_primitive(arg, type))
      end

      def alloc_null
        ptr = self.class.alloc
        raising_errors { FFI.dart_null_init_err(ptr) }
        ptr.mark_valid
        ptr
      end

      def const_null
        Packet.new(alloc_null)
      end

      #----- General Purpose Helpers -----#

      def caller_name
        caller[1][/`.*'/][1..-2]
      end

      def mutate(key, val, obj:, arr:)
        # Make sure we've been given something we can use.
        enforce_types(key, object: [String, Symbol], array: Fixnum)

        # Convert the value we've been given to insert it.
        key = key.is_a?(Symbol) ? key.to_s : key
        raw_val = convert(val)
        raising_errors do
          if obj?
            FFI.send(obj, self, key, key.size, raw_val)
          else
            FFI.send(arr, self, key, raw_val)
          end
        end
        raw_val
      end

      def self.destructor(ptr)
        FFI.dart_destroy(ptr)
      end

    end

    class Int < ::FFI::Struct
      layout :value, :int
    end

    class Int64 < ::FFI::Struct
      layout :value, :int64
    end

    class SizeT < ::FFI::Struct
      layout :value, :size_t
    end

    class Double < ::FFI::Struct
      layout :value, :double
    end

    # Attach constructors.
    attach_function :dart_copy_err, [:pointer, :pointer], ErrorType
    attach_function :dart_obj_init_err, [:pointer], ErrorType
    attach_function :dart_arr_init_err, [:pointer], ErrorType
    attach_function :dart_str_init_err, [:pointer, :string, :size_t], ErrorType
    attach_function :dart_int_init_err, [:pointer, :int64], ErrorType
    attach_function :dart_dcm_init_err, [:pointer, :double], ErrorType
    attach_function :dart_bool_init_err, [:pointer, :int], ErrorType
    attach_function :dart_null_init_err, [:pointer], ErrorType
    attach_function :dart_destroy, [:pointer], ErrorType

    # Attach object insertion functions.
    attach_function :dart_obj_insert_dart_len, [:pointer, :string, :size_t, :pointer], ErrorType
    attach_function :dart_obj_insert_take_dart_len, [:pointer, :string, :size_t, :pointer], ErrorType

    # Attach object set functions.
    attach_function :dart_obj_set_dart_len, [:pointer, :string, :size_t, :pointer], ErrorType
    attach_function :dart_obj_set_take_dart_len, [:pointer, :string, :size_t, :pointer], ErrorType

    # Attach object erase functions.
    attach_function :dart_obj_erase_len, [:pointer, :string, :size_t], ErrorType

    # Attach object retrieval functions.
    attach_function :dart_obj_get_len_err, [:pointer, :pointer, :string, :size_t], ErrorType

    # Attach array insertion operations.
    attach_function :dart_arr_insert_dart, [:pointer, :size_t, :pointer], ErrorType
    attach_function :dart_arr_insert_take_dart, [:pointer, :size_t, :pointer], ErrorType

    # Attach array set functions.
    attach_function :dart_arr_set_dart, [:pointer, :size_t, :pointer], ErrorType
    attach_function :dart_arr_set_take_dart, [:pointer, :size_t, :pointer], ErrorType

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
    attach_function :dart_is_finalized, [:pointer], :int
    attach_function :dart_get_type, [:pointer], Type

    # Attach json functions.
    attach_function :dart_heap_from_json_len_err, [:pointer, :string, :size_t], ErrorType
    attach_function :dart_from_json_len_err, [:pointer, :string, :size_t], ErrorType
    attach_function :dart_to_json, [:pointer, :pointer], :pointer

    # Attach API transition functions.
    attach_function :dart_lower_err, [:pointer, :pointer], ErrorType
    attach_function :dart_lift_err, [:pointer, :pointer], ErrorType

    # Attach network functions.
    attach_function :dart_get_bytes, [:pointer, :pointer], :pointer
    attach_function :dart_from_bytes_err, [:pointer, :pointer, :size_t], ErrorType

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
