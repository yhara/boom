require 'forwardable'

class Evaluator
  def self.run(str, library=LIBRARY)
    expr = Parser.parse(str)
    TypeInference.infer(expr, library)

    env = Env.new(library.map{|name, (type, block)|
      [name, Func.new(&block)]
    }.to_h)
    new.eval(env, expr)
  end

  include TypeInference::Type
  INT = TyRaw["int"]
  STRING = TyRaw["string"]
  LIBRARY = {
    "print" => [TyFun[STRING, STRING], ->(arg) { $stdout.print(arg); arg }]
  }

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

  class Func
    def initialize(&block)
      @block = block
    end

    def invoke(arg)
      @block.call(arg)
    end
  end

  def eval(env, expr)
    match(expr) {
      with(_[:lit, typename, val]) {
        val
      }
      with(_[:var, name]) {
        unless env.key?(name)
          raise "undefined variable: #{name} (#{env.inspect})"
        end
        env[name]
      }
      with(_[:abs, name, body]) {
        name_, body_ = name, body
        Func.new{|arg|
          eval(env.merge(name_, arg), body_)
        }
      }
      with(_[:app, funexpr, argexpr]) {
        arg = eval(env, argexpr)
        fun = eval(env, funexpr)
        unless fun.is_a?(Func)
          raise "cannot apply: #{fun.inspect} (#{arg.inspect})"
        end
        fun.invoke(arg)
      }
      with(_[:let, name, varexpr, bodyexpr]) {
        var = eval(env, varexpr)
        eval(env.merge(name, var), bodyexpr)
      }
      with(_){ raise "no match: #{expr.inspect}" }
    }
  end
end
