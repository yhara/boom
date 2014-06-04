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

    # TODO: better name
    def merge!(other)
      @hash = @hash.map{|id, type|
        [id, other.apply(type)]
      }.to_h
      @hash.merge!(other.to_h)
    end

    def to_constr
      @hash.map{|id, ty|
        Constraint.new([:VAR, id], ty)
      }
    end

    def apply(type)
      match(type) {
        with(_[:LIT, _]) {
          type
        }
        with(_[:VAR, id]) {
          if @hash.key?(id) then @hash[id] else type end
        }
        with(_[:FUN, tl, tr]) {
          [:FUN, apply(tl), apply(tr)]
        }
        with(_) {
          raise "no match: #{type.inspect}"
        }
      }
    end
  end

  class Assump
    extend Forwardable

    def initialize(hash={})
      @hash = hash  # String => TypeScheme
    end

    def_delegators :@hash, :key?, :[], :inject, :flat_map

    def merge(hash)
      Assump.new(@hash.merge(hash))
    end

    def substitute(subst)
      Assump.new(@hash.map{|key, ts|
        [key, TypeScheme.new(ts.ids, subst.apply(ts.type))]
      }.to_h)
    end
  end

  class TypeScheme
    # - ids : Array of Fixnum
    def initialize(ids, type)
      @ids = ids.uniq
      @type = type
    end
    attr_reader :ids, :type

    def instantiate(idgen)
      subst = Subst.new(@ids.map{|id|
        [id, [:VAR, idgen.new_id()]]
      }.to_h)

      return subst.apply(@type)
    end
  end

  class IdGen
    def initialize
      @lastid = 0
    end

    def new_id
      @lastid += 1
      @lastid
    end
  end

  # - subst : Hash(Fixnum => Type)

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
        [Subst.new, [:LIT, typename]]
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
        result_type = [:VAR, gen_id()]

        s1, func_type = infer(assump, func_expr)
        s2, arg_type = infer(assump.substitute(s1), arg_expr)

        func_type = s2.apply(func_type)
        s3 = unify(Constraint.new(func_type, [:FUN, arg_type, result_type]))

        [merge_substs(s1, s2, s3), s3.apply(result_type)]
      }
      with(_[:abs, name, body]) {
        arg_type = [:VAR, gen_id()]
        newassump = assump.merge(name => TypeScheme.new([], arg_type))

        s, t = infer(newassump, body)
        [s, s.apply([:FUN, arg_type, t])]
      }
      with(_[:let, name, var_expr, body_expr]) {
        s1, var_type = infer(assump, var_expr)
        newassump = assump.substitute(s1)
        var_ts = generalize(newassump, var_type)

        s2, body_type = infer(newassump.merge(name => var_ts), body_expr)

        [merge_substs(s1, s2), body_type]
      }
      with(_) {
        raise ArgumentError, "no match: #{expr.inspect}"
      }
    }
  end

  private

  def unify(*constraints)
    subst = Subst.new
    consts = constraints.dup

    until consts.empty?
      con = consts.pop
      case
      when con.lt.first == :FUN && con.rt.first == :FUN
        consts.push Constraint.new(con.lt[1], con.rt[1])
        consts.push Constraint.new(con.lt[2], con.rt[2])
      when con.lt.first == :VAR
        next if con.rt == con.lt
        
        id = con.lt[1]; rt = con.rt
        raise InferenceError if occurs?(rt, id)

        sub = Subst.new({id => rt})
        subst.merge!(sub)
        consts.map!{|c| Constraint.new(sub.apply(c.lt), sub.apply(c.rt))}
      when con.rt.first == :VAR
        consts.push con.swap
      when con.lt.first == :LIT && con.rt.first == :LIT
        if con.lt[1] != con.rt[1]
          raise InferenceError, "type mismatch: #{con.lt[1]} vs #{con.rt[1]}"
        end
      else
        raise
      end
    end

    return subst
  end

    def occurs?(type, id)
      match(type) {
        with(_[:LIT, _]) { false }
        with(_[:VAR, name]) { name == id }
        with(_[:FUN, ty1, ty2]) { occurs?(ty1, id) || occurs?(ty2, id) }
      }
    end

  def gen_id
    @idgen.new_id
  end

  def generalize(assump, type)
    assump_vars = assump.flat_map{|_, ts| vars_in(ts.type) - ts.ids}
    TypeScheme.new(vars_in(type) - assump_vars, type)
  end

    # Returns Array of Fixnum(id)
    def vars_in(type)
      match(type) {
        with(_[:LIT, _]) { [] }
        with(_[:VAR, name]) { [name] }
        with(_[:FUN, ty1, ty2]) { vars_in(ty1) + vars_in(ty2) }
      }
    end

  def merge_substs(*substs)
    constraints = substs.flat_map(&:to_constr)
    unify(*constraints)
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
