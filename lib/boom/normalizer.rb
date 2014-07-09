module Boom
  class Normalizer
    def normalize(ast)
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
          [:abs, varname, nil, normalize(body)]
        }
        with(_[:APP, funexpr, argexpr]) {
          [:app, normalize(funexpr), normalize(argexpr)]
        }
        with(_[:SEQ, _[stmt]]) {
          normalize(stmt)
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
              body_ = body ? normalize(body) : [:lit, "Unit", :unit]
              [:let, funname,
                [:abs, argname_, argtyname_, body_],
                normalize([:SEQ, rest])]
            }
            with(_[:DEFVAR, varname, expr]) {
              [:let, varname,
                normalize(expr),
                normalize([:SEQ, rest])]
            }
            with(_) {
              [:seq, normalize(first),
                     normalize([:SEQ, rest])]
            }
          }
        }
        # When :DEFVAR is a last expression
        with(_[:DEFVAR, varname, expr]) {
          # Just place the rhs value
          normalize(expr)
        }
        with(_) {
          raise "no match/ast: #{ast.inspect}"
        }
      }
    end
  end
end
