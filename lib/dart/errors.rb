module Dart

  TypeError = Class.new(RuntimeError)
  LogicError = Class.new(StandardError)
  StateError = Class.new(RuntimeError)
  ParseError = Class.new(RuntimeError)
  ClientError = Class.new(LogicError)
  InternalError = Class.new(RuntimeError)

  module Errors
    def handle_error(err)
      errmsg, _ = FFI.dart_get_error
      case err
      when :no_error then return
      when :type_error then raise TypeError, errmsg
      when :state_error then raise StateError, errmsg
      when :parse_error then raise ParseError, errmsg
      when :client_error then raise ClientError, errmsg
      else raise RuntimeError, errmsg
      end
    end

    def raising_errors
      handle_error yield
    end
  end

end
