require 'dart/version'
require 'dart/errors'
require 'dart/bindings'
require 'dart/helpers'

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

    def is_finalized
      @impl.is_finalized
    end

    def get_bytes
      @impl.get_bytes
    end

    def to_s
      @impl.to_s
    end

    def dup
      Helpers.construct_child(@impl.dup)
    end

    private

    def native
      @impl
    end

  end

  class Object
    include Enumerable
    include Common

    def initialize(val = nil, &block)
      if val.is_a?(Dart::FFI::Packet)
        @impl = val
      elsif block
        @def_val = proc { |h, k| block.call(h, k) }
        @impl = Dart::FFI::Packet.make_obj
      else
        @def_val = proc { Helpers.construct_child(Dart::FFI::Packet.convert(val)) }
        @impl = Dart::FFI::Packet.make_obj
      end
    end

    def [](key)
      if has_key?(key) then Helpers.construct_child(@impl.lookup(key))
      else @def_val.call(self, key)
      end
    end

    def []=(key, value)
      Helpers.construct_child(@impl.update(key, value))
    end

    def has_key?(key)
      @impl.has_key?(key)
    end

    def insert(key, value)
      self[key] = value
    end

    def size
      @impl.size
    end

    def empty?
      size == 0
    end

    def lower
      @impl = @impl.lower
    end

    def finalize
      lower
    end

    def lift
      @impl = @impl.lift
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
        while it.has_next
          key = Helpers.construct_child(key_it.unwrap)
          val = Helpers.construct_child(it.unwrap)
          y.yield(key, val)
          it.next
          key_it.next
        end
      end

      # Check if we can consume the enumerator.
      if block_given? then enum.each { |k, v| yield(k, v) } && self
      else enum
      end
    end
  end

  class Array
    include Enumerable
    include Common

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
      Helpers.construct_child(@impl.lookup(idx))
    end

    def []=(idx, elem)
      raise ArgumentError, 'Dart Arrays can only index with an integer' unless idx.is_a?(::Fixnum)
      @impl.resize(idx + 1) if idx >= size
      Helpers.construct_child(@impl.update(idx, elem))
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
      when ::Array then size == other.size && each.with_index { |v, i| return false unless v == other[i] } && true
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
          y << Helpers.construct_child(it.unwrap)
          it.next
        end
      end

      # Check if we can consume the enumerator.
      if block_given? then enum.each { |v| yield v } && self
      else enum
      end
    end
  end

  module Unwrappable
    def unwrap
      @unwrapped ||= @impl.unwrap
    end
  end

  class String
    include Common
    include Unwrappable

    def initialize(val)
      if val.is_a?(Dart::FFI::Packet)
        @impl = val
      else
        # Create our implementation as the given string.
        raise ArgumentError, 'Dart::String can only be constructed from a String' unless val.is_a?(::String)
        @impl = Dart::FFI::Packet.make_str(val)
      end
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
    include Unwrappable

    def initialize(val)
      if val.is_a?(Dart::FFI::Packet)
        @impl = val
      else
        # Create our implementation as the given integer.
        raise ArgumentError, 'Dart::Integer can only be constructed from a Fixnum' unless val.is_a?(::Fixnum)
        @impl = Dart::FFI::Packet.make_primitive(val, :int)
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
    include Unwrappable

    def initialize(val)
      if val.is_a?(Dart::FFI::Packet)
        @impl = val
      else
        # Create our implementation as the given decimal.
        raise ArgumentError, 'Dart::Decimal can only be constructed from a Float' unless val.is_a?(::Float)
        @impl = Dart::FFI::Packet.make_primitive(val, :dcm)
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

    def initialize(val)
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
    Helpers.construct_child(Dart::FFI::Packet.from_json(str, finalize))
  end

  def self.from_bytes(bytes)
    Helpers.construct_child(Dart::FFI::Packet.from_bytes(bytes))
  end

  module Patch
    def ==(other)
      if other.is_a?(Dart::Common) then other == self
      else super
      end
    end
  end

end

class Hash
  prepend Dart::Patch
end

class Array
  prepend Dart::Patch
end
