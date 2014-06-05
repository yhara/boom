class Normalizer
  def normalize(ast)
    match(ast) {
      with(_[:CONST, val]) {
        case val
        when Integer
          [:lit, "int", val]
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
    }
  end
end

