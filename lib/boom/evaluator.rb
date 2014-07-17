require 'forwardable'

module Boom
  class Evaluator
    def self.run(str, library: LIBRARY, io: [$stdin, $stdout])
      ast = Parser.parse(str)
      #pp ast: ast
      expr = Normalizer.new.normalize(ast)
      #pp expr: expr
      TypeInference.infer(expr, library)

      system = System.new(io)
      env = Env.new(library.map{|name, (type, block)|
        [name, block]
      }.to_h)
      new(system).eval(env, expr)
    end

    include TypeInference::Type
    UNIT = TyRaw["Unit"]
    class Unit
      UNIT = Unit.new
    end
    INT = TyRaw["Int"]
    STRING = TyRaw["String"]
    LIBRARY = {
      "print" => [TyFun[STRING, STRING],
        ->(system, arg) { system.out.print(arg); arg }],
      "inspect" => [TyFun[TyVar.new, STRING],
        ->(system, arg) { arg.inspect }],
      "p" => [TyFun[TyVar.new, STRING],
        ->(system, arg) { system.out.puts(arg.inspect) }]
    }

    class System
      def initialize(io)
        @io = io
      end
      def in; @io[0]; end
      def out; @io[1]; end
    end

    class Env
      extend Forwardable

      def initialize(hash={})
        @hash = hash
      end
      def_delegators :@hash, :key?, :[]

      def merge(name, value)
        Env.new(@hash.merge(name => value))
      end
    end

    def initialize(system)
      @system = system
    end

    def eval(env, expr)
      match(expr) {
        with(_[:lit, typename, val]) {
          (typename == "Unit" ? Unit::UNIT : val)
        }
        with(_[:var, name]) {
          unless env.key?(name)
            raise "undefined variable: #{name} (#{env.inspect})"
          end
          env[name]
        }
        with(_[:abs, name, opt_typename, body]) {
          name_, body_ = name, body
          lambda{|system, arg|
            eval(env.merge(name_, arg), body_)
          }
        }
        with(_[:app, funexpr, argexpr]) {
          arg = eval(env, argexpr)
          fun = eval(env, funexpr)
          unless fun.is_a?(Proc)
            raise "cannot apply: #{fun.inspect} (#{arg.inspect})"
          end
          fun.call(@system, arg)
        }
        with(_[:let, name, varexpr, bodyexpr]) {
          var = eval(env, varexpr)
          eval(env.merge(name, var), bodyexpr)
        }
        with(_[:seq, expr1, expr2]) {
          eval(env, expr1)
          eval(env, expr2)
        }
        with(_){ raise "no match: #{expr.inspect}" }
      }
    end
  end
end
