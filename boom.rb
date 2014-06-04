require 'pattern-match'

class TypeInference
  class InferenceError < StandardError; end
  class ProgramError < StandardError; end

  class Constraint < Struct.new(:lt, :rt)
    def swap; Constraint.new(rt, lt); end
  end

  class TypeScheme
    # - ids : Array of Fixnum
    def initialize(ids, type)
      @ids = ids.uniq
      @type = type
    end
    attr_reader :ids, :type
  end

  # - subst : Hash(Fixnum => Type)

  def self.infer(expr, env)
    new(env).infer({}, expr)
  end

  def initialize(env)
    @env = env
    @lastid = 0
  end

  # - assump : Hash(String => TypeScheme)
  # Returns [subst, type]
  def infer(assump, expr)
    match(expr) {
      with(_[:lit, typename, val]) {
        [{}, [:LIT, typename]]
      }
      with(_[:ref, name]) {
        raise ProgramError if not @env.key?(name)
        [{}, @env[name]]
      }
      with(_[:var, name]) {
        raise InferenceError if not assump.key?(name)
        var_type = instantiate(assump[name])

        [{}, var_type]
      }
      with(_[:app, func_expr, arg_expr]) {
        result_type = [:VAR, gen_id()]

        s1, func_type = infer(assump, func_expr)
        s2, arg_type = infer(substitute_assump(assump, s1), arg_expr)

        func_type = substitute(func_type, s2)
        s3 = unify(Constraint.new(func_type, [:FUN, arg_type, result_type]))

        [merge_substs(s1, s2, s3), substitute(result_type, s3)]
      }
      with(_[:abs, name, body]) {
        arg_type = [:VAR, gen_id()]
        newassump = assump.merge(name => TypeScheme.new([], arg_type))

        s, t = infer(newassump, body)
        [s, substitute([:FUN, arg_type, t], s)]
      }
      with(_[:let, name, var_expr, body_expr]) {
        s1, var_type = infer(assump, var_expr)
        newassump = substitute_assump(assump, s1)
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
    subst = {}
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

        sub = ->(type){ substitute(type, id => rt) }

        subst = hash_map(subst, &sub).merge({id => rt})
        consts.map!{|c| Constraint.new(sub[c.lt], sub[c.rt]) }
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

  # Returns a new type
  def substitute(type, subst)
    match(type) {
      with(_[:LIT, _]) {
        type
      }
      with(_[:VAR, id]) {
        if subst.key?(id) then subst[id] else type end
      }
      with(_[:FUN, tl, tr]) {
        [:FUN, substitute(tl, subst), substitute(tr, subst)]
      }
      with(_) {
        raise "no match: #{type.inspect}"
      }
    }
  end

  def substitute_assump(assump, subst)
    hash_map(assump) do |ts| 
      TypeScheme.new(ts.ids, substitute(ts.type, subst))
    end
  end

  def instantiate(ts)
    subst = {}
    ts.ids.each{|id|
      subst[id] = [:VAR, gen_id()]
    }

    substitute(ts.type, subst)
  end

  def gen_id
    @lastid += 1
    @lastid
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
    constraints = substs.flat_map{|subst|
      subst.map{|id, ty|
        Constraint.new([:VAR, id], ty)
      }
    }
    unify(*constraints)
  end

  def hash_map(hash, &block)
    hash.inject({}) do |h, (k, v)|
      h[k] = yield v
      h
    end
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
