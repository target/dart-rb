require 'dart/version'
require 'dart/errors'
require 'dart/bindings'
require 'dart/helpers'
require 'dart/convert'
require 'dart/cached'

module Dart

  module Common

    #----- Introspection Methods -----#

    def obj?
      @impl.obj?
    end

    def object?
      obj?
    end

    def arr?
      @impl.arr?
    end

    def array?
      arr?
    end

    def aggr?
      @impl.aggr?
    end

    def aggregate?
      aggr?
    end

    def str?
      @impl.str?
    end

    def string?
      str?
    end

    def int?
      @impl.int?
    end

    def integer?
      int?
    end

    def dcm?
      @impl.dcm?
    end

    def decimal?
      dcm?
    end

    def bool?
      @impl.bool?
    end

    def boolean?
      bool?
    end

    def null?
      @impl.null?
    end

    def get_type
      @impl.get_type
    end

    def finalized?
      @impl.finalized?
    end

    def get_bytes
      @impl.get_bytes
    end

    def to_s
      @impl.to_s
    end

    def to_json
      to_s
    end

    def dup
      Helpers.wrap_ffi(@impl.dup)
    end

    private

    def native
      @impl
    end

  end

  module Unwrappable
    def unwrap
      @unwrapped ||= @impl.unwrap
    end
  end

  # God I love ruby sometimes.
  # This would've taken literally hundreds of lines in C++
  module Arithmetic
    ops = %w{ + - * / % ** & | ^ <=> }.each do |op|
      eval <<-METHOD
      def #{op}(num)
        if num.is_a?(Arithmetic) then unwrap #{op} num.unwrap
        else unwrap #{op} num
        end
      end
      METHOD
    end

    def -@
      -unwrap
    end

    def coerce(num)
      [num, unwrap]
    end
  end

  module Bitwise
    ops = %w{ & | ^ }.each do |op|
      eval <<-METHOD
      def #{op}(num)
        if num.is_a?(Bitwise) then unwrap #{op} num.unwrap
        else unwrap #{op} num
        end
      end
      METHOD
    end

    def ~
      ~unwrap
    end
  end

  class Object
    include Enumerable
    include Convert
    include Common
    prepend Cached

    def initialize(val = nil)
      if val.is_a?(Dart::FFI::Packet)
        @def_val = proc { nil }
        @impl = val
      elsif block_given?
        @def_val = proc { |h, k| yield(h, k) }
        @impl = Dart::FFI::Packet.make_obj
      else
        @def_val = proc { val }
        @impl = Dart::FFI::Packet.make_obj
      end
    end

    def [](key)
      if has_key?(key) then @impl.lookup(key)
      else @def_val.call(self, key)
      end
    end

    def []=(key, value)
      # Perform the insertion.
      @impl.update(key, value)
    end

    def delete(key)
      val = self[key]
      @impl.remove(key)
      val
    end

    def clear
      @impl.clear
      self
    end

    def has_key?(key)
      contains?(key)
    end

    def size
      @impl.size
    end

    def empty?
      size == 0
    end

    def lower
      @impl = @impl.lower
      self
    end

    def finalize
      lower
    end

    def lift
      @impl = @impl.lift
      self
    end

    def definalize
      lift
    end

    #----- Language Overrides -----#

    def ==(other)
      return true if equal?(other)
      case other
      when Object then @impl == other.send(:native)
      when ::Hash then size == other.size && other.each { |k, v| return false unless self[k] == v } && true
      else false
      end
    end

    def each
      # Create an enumerator to either consume or return.
      enum = Enumerator.new do |y|
        # Get an iterator from our implementation
        it = @impl.iterator
        key_it = @impl.key_iterator

        # Call our block for each child.
        args = ::Array.new
        while it.has_next
          args[0] = Helpers.wrap_ffi(key_it.unwrap)
          args[1] = Helpers.wrap_ffi(it.unwrap)
          y.yield(args)
          it.next
          key_it.next
        end
      end

      # Check if we can consume the enumerator.
      if block_given? then enum.each { |a| yield a } && self
      else enum
      end
    end

    private

    def make_cache
      ::Hash.new
    end

    def contains?(key)
      @impl.has_key?(key)
    end
  end

  class Array
    include Enumerable
    include Convert
    include Common
    prepend Cached

    def initialize(val_or_size = nil, def_val = nil)
      if val_or_size.is_a?(Dart::FFI::Packet) && def_val.nil?
        @impl = val_or_size
      elsif val_or_size.is_a?(Fixnum)
        @impl = Dart::FFI::Packet.make_arr
        if def_val.nil? then @impl.resize(val_or_size)
        else val_or_size.times { push(def_val) }
        end
      else
        @impl = Dart::FFI::Packet.make_arr
      end
    end

    def [](idx)
      # Invert our index if it's negative
      idx = size + idx if idx < 0
      @impl.lookup(idx)
    end

    def first
      self[0]
    end

    def last
      self[-1]
    end

    def []=(idx, elem)
      raise ArgumentError, 'Dart Arrays can only index with an integer' unless idx.is_a?(::Fixnum)
      @impl.resize(idx + 1) if idx >= size
      @impl.update(idx, elem)
    end

    def insert(idx, *elems)
      raise ArgumentError, 'Dart Arrays can only index with an integer' unless idx.is_a?(::Fixnum)

      # Iterate over the supplied elements and insert them.
      @impl.resize(idx) if idx > size
      elems.each.with_index { |v, i| @impl.insert(idx + i, v) }
      self
    end

    def delete_at(idx)
      val = self[idx]
      @impl.remove(idx)
      val
    end

    def unshift(*elems)
      insert(0, *elems)
    end

    def shift
      delete_at(0) unless empty?
    end

    def push(*elems)
      insert(size, *elems)
    end

    def pop
      delete_at(size - 1) unless empty?
    end

    def clear
      @impl.clear
      self
    end

    def size
      @impl.size
    end

    def empty?
      size == 0
    end

    #----- Language Overrides -----#

    def ==(other)
      return true if equal?(other)
      case other
      when Array then @impl == other.send(:native)
      when ::Array then size == other.size && each_with_index { |v, i| return false unless v == other[i] } && true
      else false
      end
    end

    def each
      # Create an enumerator to either consume or return.
      enum = Enumerator.new do |y|
        # Get an iterator from our implementation
        it = @impl.iterator

        # Call our block for each child.
        while it.has_next
          y << Helpers.wrap_ffi(it.unwrap)
          it.next
        end
      end

      # Check if we can consume the enumerator.
      if block_given? then enum.each { |v| yield v } && self
      else enum
      end
    end

    private

    def make_cache
      ::Array.new
    end

    def contains?(idx)
      idx < size
    end
  end

  class String
    include Common
    include Unwrappable

    def initialize(val = ::String.new)
      if val.is_a?(Dart::FFI::Packet)
        @impl = val
      else
        # Create our implementation as the given string.
        raise ArgumentError, 'Dart::String can only be constructed from a String' unless val.is_a?(::String)
        @impl = Dart::FFI::Packet.make_str(val)
      end
    end

    def [](idx)
      unwrap[idx]
    end

    def size
      @impl.size
    end

    def empty?
      size == 0
    end

    def ==(other)
      return true if equal?(other)
      case other
      when String then @impl == other.send(:native)
      when ::String then unwrap == other
      else false
      end
    end
  end

  class Integer
    include Common
    include Bitwise
    include Arithmetic
    include Unwrappable
    include ::Comparable

    def initialize(val = 0)
      if val.is_a?(Dart::FFI::Packet)
        @impl = val
      else
        # Create our implementation as the given integer.
        raise ArgumentError, 'Dart::Integer can only be constructed from a Numeric type' unless val.is_a?(::Numeric)
        raise ArgumentError, 'Dart::Integer conversion would lose precision' unless val.to_i == val
        @impl = Dart::FFI::Packet.make_primitive(val.to_i, :int)
      end
    end

    def ==(other)
      return true if equal?(other)
      case other
      when Integer then @impl == other.send(:native)
      when ::Fixnum then unwrap == other
      else false
      end
    end
  end

  class Decimal
    include Common
    include Arithmetic
    include Unwrappable
    include ::Comparable

    def initialize(val = 0.0)
      if val.is_a?(Dart::FFI::Packet)
        @impl = val
      else
        # Create our implementation as the given decimal.
        raise ArgumentError, 'Dart::Decimal can only be constructed from a Numeric type' unless val.is_a?(::Numeric)
        @impl = Dart::FFI::Packet.make_primitive(val.to_f, :dcm)
      end
    end

    def ==(other)
      return true if equal?(other)
      case other
      when Decimal then @impl == other.send(:native)
      when ::Float then unwrap == other
      else false
      end
    end
  end

  class Boolean
    include Common
    include Unwrappable

    def initialize(val = false)
      if val.is_a?(Dart::FFI::Packet)
        @impl = val
      else
        # Create our implementation as the given decimal.
        unless val.is_a?(TrueClass) || val.is_a?(FalseClass)
          raise ArgumentError, 'Dart::Decimal can only be constructed from a Boolean'
        end
        @impl = Dart::FFI::Packet.make_primitive(val ? 1 : 0, :bool)
      end
    end

    def ==(other)
      return true if equal?(other)
      case other
      when Boolean then @impl == other.send(:native)
      when ::TrueClass then unwrap
      when ::FalseClass then !unwrap
      else false
      end
    end
  end

  class Null
    include Common

    def initialize
      @impl = Dart::FFI::Packet.make_null
    end

    def ==(other)
      return true if equal?(other)
      case other
      when Null then true
      when NilClass then true
      else false
      end
    end
  end

  def self.from_json(str, finalize = true)
    Helpers.wrap_ffi(Dart::FFI::Packet.from_json(str, finalize))
  end

  def self.from_bytes(bytes)
    Helpers.wrap_ffi(Dart::FFI::Packet.from_bytes(bytes))
  end

  module Patch
    def ==(other)
      if other.is_a?(Dart::Common) then other == self
      else super
      end
    end
  end

end

# XXX: Doesn't feel good.
#----- Monkey Patches -----#

class Hash
  prepend Dart::Patch
  include Dart::Convert
end

class Array
  prepend Dart::Patch
  include Dart::Convert
end

class String
  prepend Dart::Patch
  include Dart::Convert
end

class Fixnum
  include Dart::Convert
end

class Float
  include Dart::Convert
end

class NilClass
  include Dart::Convert
end
