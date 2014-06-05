require 'forwardable'
require 'pattern-match'

class TypeInference
  class InferenceError < StandardError; end
  class ProgramError < StandardError; end

  class Constraint 
    def initialize(lt, rt)
      @lt, @rt = lt, rt
    end
    attr_reader :lt, :rt

    def self.deconstruct(val)
      accept_self_instance_only(val)
      [val.lt, val.rt]
    end

    def swap
      Constraint.new(@rt, @lt)
    end
  end

  class Subst
    extend Forwardable

    def initialize(hash={})
      @hash = hash  # id(String) => type
    end

    def_delegators :@hash, :key?, :[], :==

    def to_h
      @hash
    end

    def add!(other)
      @hash = @hash.map{|id, type|
        [id, type.substitute(other)]
      }.to_h
      @hash.merge!(other.to_h)
    end

    def merge(*others)
      constraints = others.flat_map(&:to_constr)
      return TypeInference.unify(*constraints)
    end

    def to_constr
      @hash.map{|id, ty|
        Constraint.new(Type::TyVar[id], ty)
      }
    end
  end

  class Assump
    extend Forwardable

    def initialize(hash={})
      @hash = hash  # String => TypeScheme
    end

    def_delegators :@hash, :key?, :[], :inject

    def merge(hash)
      Assump.new(@hash.merge(hash))
    end

    def substitute(subst)
      Assump.new(@hash.map{|key, ts|
        [key, TypeScheme.new(ts.ids, ts.type.substitute(subst))]
      }.to_h)
    end

    def generalize(type)
      assump_vars = @hash.flat_map{|_, ts| vars_in(ts.type) - ts.ids}
      return TypeScheme.new(vars_in(type) - assump_vars, type)
    end

    private

    # Returns Array of Fixnum(id)
    def vars_in(type)
      match(type) {
        with(Type::TyRaw) { [] }
        with(Type::TyVar.(id)) { [id] }
        with(Type::TyFun.(ty1, ty2)) { vars_in(ty1) + vars_in(ty2) }
      }
    end
  end

  class TypeScheme
    # - ids : Array of Fixnum
    def initialize(ids, type)
      @ids = ids.uniq
      @type = type
    end
    attr_reader :ids, :type

    # Create (monomorphic) type from this type scheme
    def instantiate(idgen)
      subst = Subst.new(@ids.map{|id|
        [id, Type::TyVar[idgen.new_id()]]
      }.to_h)

      return @type.substitute(subst)
    end
  end

  module Type
    class Base
      include PatternMatch::Deconstructable

      def self.deconstruct(val); accept_self_instance_only(val); end
    end

    class TyRaw < Base
      def initialize(name)
        @name = name
      end
      attr_reader :name

      def self.[](name); new(name); end
      def ==(other); other.is_a?(TyRaw) && other.name == @name; end
      def self.deconstruct(val); super; [val.name]; end

      def substitute(subst); self; end
      def occurs?(id); false; end
    end

    class TyVar < Base
      def initialize(id)
        @id = id
      end
      attr_reader :id

      def self.[](id); new(id); end
      def ==(other); other.is_a?(TyVar) && other.id == @id; end
      def self.deconstruct(val); super; [val.id]; end

      def substitute(subst)
        if subst.key?(@id) then subst[@id] else self end
      end

      def occurs?(id); @id == id; end
    end

    class TyFun < Base
      def initialize(ty1, ty2)
        @ty1, @ty2 = ty1, ty2
      end
      attr_reader :ty1, :ty2

      def self.[](ty1, ty2); new(ty1, ty2); end
      def ==(other)
        other.is_a?(TyFun) && other.ty1 == @ty1 && other.ty2 == @ty2
      end
      def self.deconstruct(val); super; [val.ty1, val.ty2]; end

      def substitute(subst)
        TyFun.new(@ty1.substitute(subst), @ty2.substitute(subst))
      end

      def occurs?(id)
        @ty1.occurs?(id) || @ty2.occurs?(id)
      end
    end
  end
  include Type

  class IdGen
    def initialize
      @lastid = 0
    end

    def new_id
      @lastid += 1
      @lastid
    end
  end


  def self.infer(expr, env)
    new(env).infer(Assump.new, expr)
  end

  def initialize(env)
    @env = env
    @idgen = IdGen.new
  end

  # Returns [subst, type]
  def infer(assump, expr)
    match(expr) {
      with(_[:lit, typename, val]) {
        [Subst.new, TyRaw[typename]]
      }
      with(_[:ref, name]) {
        raise ProgramError if not @env.key?(name)
        [Subst.new, @env[name]]
      }
      with(_[:var, name]) {
        raise InferenceError if not assump.key?(name)
        var_type = assump[name].instantiate(@idgen)

        [Subst.new, var_type]
      }
      with(_[:app, func_expr, arg_expr]) {
        result_type = TyVar[gen_id()]

        s1, func_type = infer(assump, func_expr)
        s2, arg_type = infer(assump.substitute(s1), arg_expr)

        func_type = func_type.substitute(s2)
        s3 = TypeInference.unify(Constraint.new(func_type,
                                                TyFun[arg_type, result_type]))

        [s1.merge(s2, s3), result_type.substitute(s3)]
      }
      with(_[:abs, name, body]) {
        arg_type = TyVar[gen_id()]
        newassump = assump.merge(name => TypeScheme.new([], arg_type))

        s, t = infer(newassump, body)
        [s, TyFun[arg_type, t].substitute(s)]
      }
      with(_[:let, name, var_expr, body_expr]) {
        s1, var_type = infer(assump, var_expr)
        newassump = assump.substitute(s1)
        var_ts = newassump.generalize(var_type)

        s2, body_type = infer(newassump.merge(name => var_ts), body_expr)

        [s1.merge(s2), body_type]
      }
      with(_) {
        raise ArgumentError, "no match: #{expr.inspect}"
      }
    }
  end

  def self.unify(*constraints)
    subst = Subst.new
    consts = constraints.dup

    until consts.empty?
      con = consts.pop
      match(con) {
        with(Constraint.(TyFun.(lty1, lty2), TyFun.(rty1, rty2))) {
          consts.push Constraint.new(lty1, rty1)
          consts.push Constraint.new(lty2, rty2)
        }
        with(Constraint.(TyVar.(id), TyVar.(id))) {
          # just skip
        }
        with(Constraint.(TyVar.(id), ty2)) {
          raise InferenceError if ty2.occurs?(id)

          sub = Subst.new({id => ty2})
          subst.add!(sub)
          consts.map!{|c| Constraint.new(c.lt.substitute(sub),
                                         c.rt.substitute(sub))}
        }
        with(Constraint.(ty1, TyVar.(id))) {
          consts.push con.swap
        }
        with(Constraint.(TyRaw.(name1), TyRaw.(name2))) {
          if name1 != name2
            raise InferenceError, "type mismatch: #{name1} vs #{name2}"
          end
        }
      }
    end

    return subst
  end

  def gen_id
    @idgen.new_id
  end
end

if $0==__FILE__

  # f = ^(x){ x }
  # f(succ)

  expr = [:let, "f", [:abs, "x", [:var, "x"]],
            [:app, [:var, "f"], [:ref, "succ"]]]
  env = {
    "succ" => [:FUN, [:LIT, "int"], [:LIT, "int"]],
    #"plus" => [:FUN, [:VAR, 0], [:VAR, 0]]
  }
  require 'pp'
  pp TypeInference.infer(expr, env)
end
