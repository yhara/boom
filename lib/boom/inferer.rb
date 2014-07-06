class TypeInference
  module HashApply
    refine Hash do
      def apply(&block)
        self.map{|k, v| [k, block.call(v)]}.to_h
      end
    end
  end
  using HashApply

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

    def substitute(subst)
      Constraint.new(@lt.substitute(subst),
                     @rt.substitute(subst))
    end
  end

  class Subst
    extend Forwardable

    def self.[](id, ty)
      Subst.new({id => ty})
    end

    def self.empty
      Subst.new({})
    end

    def initialize(hash={})
      @hash = hash  # id(String) => type
    end

    def_delegators :@hash, :key?, :[], :==

    def to_h
      @hash
    end

    def add(id, type)
      Subst.new(
        @hash.apply{|ty| ty.substitute(Subst[id, type])}
             .merge({id => type})
      )
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

  # Type environment
  class Assump
    extend Forwardable

    def initialize(hash={})
      @hash = hash  # String(ident) => TypeScheme
    end

    def_delegators :@hash, :key?, :[], :inject

    def merge(hash)
      Assump.new(@hash.merge(hash))
    end

    def substitute(subst)
      Assump.new(@hash.apply{|ts| ts.substitute(subst)})
    end

    # Create polymorphic typescheme
    def generalize(type)
      tss = @hash.values
      free_type_ids = tss.flat_map(&:free_type_ids)

      # Types defined in elsewhere should not be type varible 
      typevars = type.var_ids - free_type_ids
      return TypeScheme.new(typevars, type)
    end
  end

  class TypeScheme
    # - ids : Array of Fixnum
    def initialize(ids, type)
      @ids = ids.uniq
      @type = type
    end
    attr_reader :ids, :type

    def substitute(subst)
      TypeScheme.new(@ids, @type.substitute(subst))
    end

    # Create (monomorphic) type from this type scheme
    def instantiate
      subst = Subst.new(@ids.map{|id|
        [id, Type::TyVar.new]
      }.to_h)

      return @type.substitute(subst)
    end

    # Variables of outer environment
    def free_type_ids
      @type.var_ids - @ids
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
      def inspect(inner=false); inner ? @name : "Ty(#{@name})"; end

      def substitute(subst); self; end
      def occurs?(id); false; end
      def var_ids; []; end
    end

    class TyVar < Base
      @@lastid = 0

      # For unittest
      def self.reset_id
        @@lastid = 0
      end

      def initialize(id=nil)
        if id
          @id = id
        else
          @@lastid += 1
          @id = @@lastid
        end
      end
      attr_reader :id

      def self.[](id); new(id); end
      def ==(other); other.is_a?(TyVar) && other.id == @id; end
      def self.deconstruct(val); super; [val.id]; end
      def inspect(inner=false); inner ? @id.to_s : "Ty(#{@id})"; end

      def substitute(subst)
        if subst.key?(@id) then subst[@id] else self end
      end
      def occurs?(id); @id == id; end
      def var_ids; [@id]; end
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
      def inspect(inner=false); "Ty(#{@ty1.inspect(true)} -> #{@ty2.inspect(true)})"; end

      def substitute(subst)
        TyFun.new(@ty1.substitute(subst), @ty2.substitute(subst))
      end
      def occurs?(id); @ty1.occurs?(id) || @ty2.occurs?(id); end
      def var_ids; @ty1.var_ids + @ty2.var_ids; end
    end
  end
  include Type

  def self.infer(expr, library={})
    assump = Assump.new(library.map{|name, (type, block)|
      [name, TypeScheme.new([], type)]
    }.to_h)
    new.infer(assump, expr)
  end

  # Returns [subst, type]
  def infer(assump, expr)
    match(expr) {
      with(_[:lit, typename, val]) {
        [Subst.empty, TyRaw[typename]]
      }
      with(_[:var, name]) {
        raise InferenceError, "undefined: #{name}" if not assump.key?(name)
        var_type = assump[name].instantiate

        [Subst.empty, var_type]
      }
      with(_[:app, func_expr, arg_expr]) {
        result_type = TyVar.new

        s1, func_type = infer(assump, func_expr)
        s2, arg_type = infer(assump.substitute(s1), arg_expr)

        func_type = func_type.substitute(s2)
        s3 = TypeInference.unify(Constraint.new(func_type,
                                                TyFun[arg_type, result_type]))

        [s1.merge(s2, s3), result_type.substitute(s3)]
      }
      with(_[:abs, name, opt_tyname, body]) {
        arg_ty = opt_tyname ? TyRaw[opt_tyname] : TyVar.new
        arg_ts = TypeScheme.new([], arg_ty)
        inner_assump = assump.merge(name => arg_ts)

        s, body_type = infer(inner_assump, body)
        [s, TyFun[arg_ts.type, body_type].substitute(s)]
      }
      with(_[:let, name, var_expr, body_expr]) {
        s1, var_type = infer(assump, var_expr)
        inner_assump = assump.substitute(s1)
        var_ts = inner_assump.generalize(var_type)

        s2, body_type = infer(inner_assump.merge(name => var_ts), body_expr)

        [s1.merge(s2), body_type]
      }
      with(_[:seq, expr1, expr2]) {
        s1, ty1 = infer(assump, expr1)
        s2, ty2 = infer(assump.substitute(s1), expr2)
        [s1.merge(s2), ty2]
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

          subst = subst.add(id, ty2)
          consts.map!{|con| con.substitute(Subst[id, ty2])}
        }
        with(Constraint.(ty1, TyVar.(id))) {
          consts.push con.swap
        }
        with(Constraint.(TyRaw.(name1), TyRaw.(name2))) {
          if name1 != name2
            raise InferenceError, "type mismatch: #{name1} vs #{name2}"
          end
        }
        with(Constraint.(ty1, ty2)) {
          raise InferenceError, "unification error\n"+
                                "  ty1: #{ty1.inspect}\n"+
                                "  ty2: #{ty2.inspect}\n"
        }
      }
    end

    return subst
  end
end
