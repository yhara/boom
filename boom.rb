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
    new(env).infer(1, {}, expr)
  end

  def initialize(env)
    @env = env
  end

  # - assump : Hash(String => TypeScheme)
  # Returns [newid, subst, type]
  def infer(newid, assump, expr)
    match(expr) {
      with(_[:lit, typename, val]) {
        [newid, {}, [:LIT, typename]]
      }
      with(_[:ref, name]) {
        raise ProgramError if not @env.key?(name)
        [newid, {}, @env[name]]
      }
      with(_[:var, name]) {
        raise InferenceError if not assump.key?(name)
        newid, var_type = instantiate(newid, assump[name])

        [newid, {}, var_type]
      }
      with(_[:app, func_expr, arg_expr]) {
        result_type = [:VAR, newid]

        newid, s1, func_type = infer(newid+1, assump, func_expr)
        newid, s2, arg_type = infer(newid, substitute_assump(assump, s1), arg_expr)

        func_type = substitute(func_type, s2)
        s3 = unify(Constraint.new(func_type, [:FUN, arg_type, result_type]))

        [newid, merge_substs(s1, s2, s3), substitute(result_type, s3)]
      }
      with(_[:abs, name, body]) {
        arg_type = [:VAR, newid]
        newassump = assump.merge(name => TypeScheme.new([], arg_type))

        newid, s, t = infer(newid+1, newassump, body)
        [newid, s, substitute([:FUN, arg_type, t], s)]
      }
      with(_[:let, name, var_expr, body_expr]) {
        newid, s1, var_type = infer(newid, assump, var_expr)
        newassump = substitute_assump(assump, s1)
        var_ts = generalize(newassump, var_type)

        newid, s2, body_type = infer(newid, newassump.merge(name => var_ts), body_expr)

        [newid, merge_substs(s1, s2), body_type]
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
      case type.first
      when :LIT then false
      when :VAR then type[1] == id
      when :FUN then occurs?(type[1], id) or occurs?(type[2], id)
      else raise ArgumentError
      end
    end

  # Returns a new type
  def substitute(type, subst)
    case type.first
    when :LIT
      type
    when :VAR
      _, id = *type
      if subst.key?(id) then subst[id] else type end
    when :FUN
      _, tl, tr = *type
      [:FUN, substitute(tl, subst), substitute(tr, subst)]
    end
  end

  def substitute_assump(assump, subst)
    hash_map(assump) do |ts| 
      TypeScheme.new(ts.ids, substitute(ts.type, subst))
    end
  end

  def instantiate(newid, ts)
    subst = {}
    ts.ids.each{|id|
      subst[id] = [:VAR, newid]
      newid += 1
    }

    [newid, substitute(ts.type, subst)]
  end

  def generalize(assump, type)
    assump_vars = assump.flat_map{|_, ts| vars_in(ts.type) - ts.ids}
    TypeScheme.new(vars_in(type) - assump_vars, type)
  end

    # Returns Array of Fixnum(id)
    def vars_in(type)
      case type.first
      when :LIT then []
      when :VAR then [type[1]]
      when :FUN then vars_in(type[1]) + vars_in(type[2])
      else raise ArgumentError
      end
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
