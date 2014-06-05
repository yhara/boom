class Normalizer
  def normalize(ast)
    match(ast) {
      with(_[:CONST, val]) {
        case val
        when Integer
          [:lit, "int", val]
        when String
          [:lit, "string", val]
        else raise
        end
      }
      with(_[:VARREF, varname]) {
        [:var, varname]
      }
      with(_[:FN, varname, body]) {
        [:abs, varname, normalize(body)]
      }
      with(_[:APP, funexpr, argexpr]) {
        [:app, normalize(funexpr), normalize(argexpr)]
      }
      with(_[:SEQ, _[:DEFUN, funname, argname, body], expr2]) {
        [:let, funname,
          [:abs, argname, normalize(body)],
          normalize(expr2)]
      }
      with(_[:SEQ, _[:DEFVAR, varname, expr], expr2]) {
        [:let, varname,
          normalize(expr),
          normalize(expr2)]
      }
      with(_[:SEQ, expr1, expr2]) {
        [:seq, normalize(expr1), normalize(expr2)]
      }
    }
  end
end

