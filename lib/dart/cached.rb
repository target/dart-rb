module Dart
  module Cached

    def [](key)
      reject unless defined?(super)

      # Short circuit our native extensions if we can.
      val = cache[key]
      return val unless val.nil?

      # We didn't have it, but cache whatever our
      # implementation returns.
      cache[key] = super
    end

    def []=(key, value)
      reject unless defined?(super)

      # Convert our value.
      raw, value = prepare(value)

      # Call through to our implementation.
      super(key, raw)

      # Update our cache so we can short-circuit
      # this value in the future.
      cache[key] = value
    end

    def insert(key, *values)
      # Make sure the class we're wrapping supports this operation.
      reject unless defined?(super)

      # Convert our value.
      raws, values = prepare(values)

      # Call through to our implementation.
      super(key, *raws)

      # Update our cache so we can short-circuit
      # this key in the future.
      cache.insert(key, *values)
      self
    end

    def delete(key)
      # Make sure the class we're wrapping supports this operation.
      reject unless defined?(super)

      # Call through to our implementation.
      super

      # Update our cache.
      cache.delete(key)
    end

    def delete_at(key)
      # Make sure the class we're wrapping supports this operation.
      reject unless defined?(super)

      # Call through to our implementation.
      super

      # Update our cache.
      cache.delete_at(key)
    end

    private

    def reject
      name = caller[0][/`.*'/][1..-2]
      raise NoMethodError, "Undefined method `#{name}' for #{self.class.name}:Class"
    end

    def prepare(values)
      impl = proc do |val|
        raw = to_dart(val)
        [raw, val.is_a?(Dart::Common) ? val : Helpers.wrap_ffi(raw)]
      end
      if values.is_a?(Array) then values.map(&impl).transpose
      else impl.call(values)
      end
    end

    def cache
      @cache ||= make_cache
    end
    
  end
end
