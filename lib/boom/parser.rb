require 'parslet' 
 
module Boom
  class Parser < Parslet::Parser
    root :program

    rule(:program){ stmts }

    rule(:stmts){ defun | defvar | expr }
    
    # -- stmt --

    rule(:defun){
      str('def') >> s >> ident.as(:fname) >> str('(') >>
        ident.maybe.as(:argname) >>
        # TODO: typeannot
        str(')') >>
        stmts.maybe.as(:stmts) >>
      str('end')
    }

    rule(:defvar){ ident.as(:varname) >> str('=') >> expr.as(:expr) }

    # -- expr --
    
    rule(:expr){ anonfunc | funcall | varref | literal }

    rule(:anonfunc){
      str('fn(') >> ident.as(:parameter) >> str('){') >>
      stmts.as(:stmts) >> str('}')
    }

    rule(:funcall){
      receiver.as(:receiver) >> str('(') >> expr.as(:argument) >> str(')')
    }

    rule(:receiver){ parenexpr | varref }
    rule(:parenexpr){ str('(') >> expr >> str(')') }

    rule(:varref){ ident.as(:varref) }

    # -- names --

    rule(:ident){
      (
        keyword.absent? >> match('[_a-z]') >> match('[_a-zA-Z0-9]').repeat
      ).as(:ident)
    }

    rule(:keyword){
      %w(if end def).map{|x| str(x)}.inject(:|)
    }

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
    def self.rule_(*keys, &block)
      hash = keys.inject({}){|sum, item| sum[item] = subtree(item); sum}
      rule(hash, &block)
    end

    # defun
    rule_(:fname, :argname, :stmts){ [:DEFUN, fname, argname, stmts] }

    # defvar
    rule_(:varname, :expr){ [:DEFVAR, varname, expr] }

    # anonfunc
    rule_(:parameter, :stmts){ [:ABS, parameter, stmts] }
    
    # funcall
    rule_(:receiver, :argument){ [:APP, receiver, argument] }

    rule_(:varref){ [:VARREF, varref] }

    rule(:ident => simple(:s)){ s.to_s }

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
  s = 'def f(x)1end'
  p s: s
  ast = parser.parse_with_debug(s)
  #ast = parser.parse(s)

  p ast: ast
  p Boom::Transformer.new.apply(ast)
rescue Parslet::ParseFailed => e
  puts e.cause.ascii_tree
end
