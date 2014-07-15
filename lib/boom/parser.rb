require 'parslet' 
 
module Boom
  class Parser < Parslet::Parser
    root :program

    rule(:program){ stmts }

    rule(:stmts){ expr }

    # -- expr --
    
    rule(:expr){ funcall | varref | literal }

    rule(:funcall){
      receiver.as(:receiver) >> str('(') >> varref.as(:argument) >> str(')')
    }

    rule(:receiver){ parenexpr | varref }
    rule(:parenexpr){ str('(') >> expr >> str(')') }

    rule(:varref){ ident.as(:varref) }

    rule(:ident){ match('[_a-z]') >> match('[_a-zA-Z0-9]').repeat }

    # -- literal --

    rule(:literal){ number | string }

    rule(:number){ match('[0-9]').repeat(1).as(:const_i) }
    rule(:string){
      str('"') >> match('[^"]').repeat.as(:const_s) >> str('"')
    }

#    rule(:expr) { add | integer }
#
#    rule(:integer) { match('[0-9]').repeat(1).as(:int) }
# 
#    rule(:add) { integer.as(:left) >> sp >> match('\+') >> sp >> expr.as(:right) }
#
#    rule(:space)  { match('\s').repeat(1) }
#    rule(:sp) { space.maybe }


    rule(:s){ match('[\s\t]').repeat(1) }
    rule(:s_){ s.maybe }
    rule(:n){ str("\n").repeat(1) }
    rule(:n_){ n.maybe }
    rule(:sp){ n | str(';') }
    rule(:sp_){ sp.maybe }
  end
 
  class Transformer < Parslet::Transform
    # funcall
    rule(:receiver => subtree(:receiver),
         :argument => subtree(:argument)) {
      [:APP, receiver, argument]
    }

    rule(:varref => simple(:s)){ [:VARREF, s.to_s] }

    # literal
    rule(:const_i => simple(:n)){ [:CONST, n.to_i] }
    rule(:const_s => simple(:s)){ [:CONST, s.to_s] }
  end
end
 
begin
  require 'pp'
  parser = Boom::Parser.new
  pp parser.root.to_s

  require 'parslet/convenience'
  s = 'asdf(foo)'
  p s: s
  ast = parser.parse_with_debug(s)
  #ast = parser.parse(s)

  p ast: ast
  p Boom::Transformer.new.apply(ast)
rescue Parslet::ParseFailed => e
  puts e.cause.ascii_tree
end
