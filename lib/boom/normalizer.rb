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
      with(_[:SEQ, _[:DEFUN, funname, argname, argtyname, body], expr2]) {
        [:let, funname,
          [:abs, argname, argtyname, normalize(body)],
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
      with(_) {
        raise "no match: #{ast.inspect}"
      }
    }
  end
end

