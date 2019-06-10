require 'dart/version'
require 'dart/errors'
require 'dart/bindings'

module Dart

  class Base

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
      self.class.construct_child(@impl.dup)
    end

    #----- Private Helpers -----#

    def self.construct_child(raw)
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

  end

  class Object < Base
    include Enumerable

    def initialize(val = nil)
      if val.is_a?(Dart::FFI::Packet)
        @impl = val
      elsif val.nil?
        @impl = Dart::FFI::Packet.make_obj
      else
        @impl = Dart::FFI::Packet.convert(val)
      end
      raise ArgumentError, 'Dart::Object can only be contructed as an object' unless obj?
    end

    def [](key)
      self.class.construct_child(@impl.lookup(key))
    end

    def []=(key, value)
      self.class.construct_child(@impl.update(key, value))
    end

    def insert(key, value)
      self[key] = value
    end

    def size
      @impl.size
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

    def each(&block)
      # Get an iterator from our implementation
      it = @impl.iterator
      key_it = @impl.key_iterator

      # Call our block for each child.
      while it.has_next
        key = self.class.construct_child(key_it.unwrap)
        val = self.class.construct_child(it.unwrap)
        block.call(key, val)
        it.next
        key_it.next
      end
    end
  end

  class Array < Base
    include Enumerable

    def initialize(val = nil)
      if val.is_a?(Dart::FFI::Packet)
        @impl = val
      elsif val.nil?
        @impl = Dart::FFI::Packet.make_arr
      else
        @impl = Dart::FFI::Packet.convert(val)
      end
      raise ArgumentError, 'Dart::Array can only be contructed as an array' unless arr?
    end

    def [](idx)
      self.class.construct_child(@impl.lookup(idx))
    end

    def []=(idx, elem)
      raise ArgumentError, 'Dart Arrays can only index with an integer' unless idx.is_a?(::Fixnum)
      @impl.resize(idx + 1) if idx >= size
      self.class.construct_child(@impl.update(idx, elem))
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

    def each(&block)
      # Get an iterator from our implementation
      it = @impl.iterator

      # Call our block for each child.
      while it.has_next
        block.call(self.class.construct_child(it.unwrap))
        it.next
      end
    end
  end

  class Unwrappable < Base
    def initialize(*args)
      super(*args)
    end

    def unwrap
      @impl.unwrap
    end
  end

  class String < Unwrappable
    def initialize(val)
      if val.is_a?(Dart::FFI::Packet)
        @impl = val
      else
        # Create our implementation as the given string.
        raise ArgumentError, 'Dart::String can only be constructed from a String' unless val.is_a?(::String)
        @impl = Dart::FFI::Packet.make_str(val)
      end
    end
  end

  class Integer < Unwrappable
    def initialize(val)
      if val.is_a?(Dart::FFI::Packet)
        @impl = val
      else
        # Create our implementation as the given integer.
        raise ArgumentError, 'Dart::Integer can only be constructed from a Fixnum' unless val.is_a?(::Fixnum)
        @impl = Dart::FFI::Packet.make_primitive(val, :int)
      end
    end
  end

  class Decimal < Unwrappable
    def initialize(val)
      if val.is_a?(Dart::FFI::Packet)
        @impl = val
      else
        # Create our implementation as the given decimal.
        raise ArgumentError, 'Dart::Decimal can only be constructed from a Float' unless val.is_a?(::Float)
        @impl = Dart::FFI::Packet.make_primitive(val, :dcm)
      end
    end
  end

  class Boolean < Unwrappable
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
  end

  class Null < Base
    def initialize
      @impl = Dart::FFI::Packet.make_null
    end
  end

  def self.from_json(str, finalize = true)
    Base.construct_child(Dart::FFI::Packet.from_json(str, finalize))
  end

  def self.from_bytes(bytes)
    Base.construct_child(Dart::FFI::Packet.from_bytes(bytes))
  end

end
