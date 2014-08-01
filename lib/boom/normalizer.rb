module Boom
  class Normalizer
    def normalize(ast)
      ast_ = match(ast) {
        with(_[:SEQ, args]) {
          defklasses, others = args.partition{|x| x.is_a?(Array) && x[0] == :DEFCLASS}
          if defklasses.empty?
            [:SEQ, others]
          else
            [:WITHDEF, defklasses, [:SEQ, others]]
          end
        }
        with(_[:DEFCLASS, *args]){
          [:WITHDEF, [ast], []]
        }
        with(_){
          ast
        }
      }
      normalize_(ast_)
    end

    def normalize_(ast)
      match(ast) {
        with(_[:CONST, val]) {
          case val
          when Integer
            [:lit, "Int", val]
          when String
            [:lit, "String", val]
          else raise
          end
        }
        with(_[:VARREF, varname]) {
          [:var, varname]
        }
        with(_[:FN, varname, body]) {
          [:abs, varname, nil, normalize_(body)]
        }
        with(_[:APP, funexpr, argexpr]) {
          [:app, normalize_(funexpr), normalize_(argexpr)]
        }
        with(_[:INVOKE, _[:VARREF, classname], name, args]){
          raise "TODO" unless name == "new"
          [:app, [:var, "#{classname}.new"], [:lit, "Unit", :unit]]
        }
        with(_[:SEQ, _[stmt]]) {
          normalize_(stmt)
        }
        with(_[:SEQ, stmts]) {
          first, *rest = *stmts
          match(first) {
            with(_[:DEFUN, funname, argname, argtyname, body]) {
              if argname.nil?
                raise "missing arg name" if argtyname != nil
                argname_ = "%dummy"
                argtyname_ = "Unit"
              else
                argname_ = argname
                argtyname_ = argtyname
              end
              body_ = body ? normalize_(body) : [:lit, "Unit", :unit]
              [:let, funname,
                [:abs, argname_, argtyname_, body_],
                normalize_([:SEQ, rest])]
            }
            with(_[:DEFVAR, varname, expr]) {
              [:let, varname,
                normalize_(expr),
                normalize_([:SEQ, rest])]
            }
            with(_) {
              [:seq, normalize_(first),
                     normalize_([:SEQ, rest])]
            }
          }
        }
        # When :DEFVAR is a last expression
        with(_[:DEFVAR, varname, expr]) {
          # Just place the rhs value
          normalize_(expr)
        }
        with(_[:WITHDEF, defs, body]) {
          [:withdef, defs.map{|x| normalize_(x)}, normalize_(body)]
        }
        with(_[:DEFCLASS, name]){
          [:defclass, name]
        }
        with(_) {
          raise "no match/ast: #{ast.inspect}"
        }
      }
    end
  end
end
