require 'parslet' 
 
module Boom
  class Parser < Parslet::Parser
    def self.parse(str)
      ast = new.parse(str)
      return Transformer.new.apply(ast)
    end

    #
    # Naming conventions
    # - Add suffix `_' for something optional
    # 

    root :program

    rule(:program){ stmts.maybe }

    rule(:stmts){ 
      ss_ >>
      (
        stmt.as(:first_stmt) >>
        (sp >> stmt).repeat(0).as(:rest_stmts)
      ) >>
      ssp_
    }
      
    rule(:stmt){ defclass | defun | defvar | expr }
    
    # -- stmt --
    
    rule(:defclass){
      str('class') >> s >> classname.as(:classname) >> sp >>
        stmts.maybe.as(:stmts) >>
      str('end')
    }

    rule(:defun){
      str('def') >> s >> methodname.as(:fname) >> str('(') >> ss_ >>
        methodname.maybe.as(:argname) >> s_ >>
        typeannot.maybe >> s_ >>
        str(')') >> sp_ >>
        (stmts.as(:stmts) | s_) >>
      str('end')
    }

    rule(:defvar){
      varname.as(:varname) >> s_ >> str('=') >> s_ >> expr.as(:expr)
    }

    # -- expr --
    
    rule(:expr){
      anonfunc | invocation | funcall | varref | literal | parenexpr
    }

    rule(:anonfunc){
      str('fn(') >> varname.as(:parameter) >> str('){') >>
        stmts.as(:stmts) >>
      str('}')
    }

    rule(:invocation){
      (funcall | varref | literal | parenexpr).as(:receiver) >>
        str('.') >> methodname >> str('(') >>
        expr.maybe.as(:argument) >>
      str(')')
    }

    rule(:funcall){
      (parenexpr | varref).as(:callee) >> str('(') >>
        expr.as(:argument) >>
      str(')')
    }

    rule(:parenexpr){ str('(') >> expr >> str(')') }

    rule(:varref){ (varname | classname).as(:varref) }

    # -- util --

    rule(:typeannot){
      str(":") >> s_ >> typename.as(:typename)
    }

    # -- names --

    rule(:smallname){
      keyword.absent? >> match('[_a-z]') >> match('[_a-zA-Z0-9]').repeat
    }
    rule(:varname){ smallname.as(:varname) }
    rule(:methodname){ smallname.as(:methodname) }
    rule(:typename){
      (
        keyword.absent? >> match('[A-Z]') >> match('[_a-zA-Z0-9]').repeat
      ).as(:typename)
    }
    rule(:classname){
      typename
    }

    rule(:keyword){
      %w(fn if end def class).map{|x| str(x)}.inject(:|)
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


    # space (except newline)
    rule(:s){ match('[ \t]').repeat(1) }
    rule(:s_){ s.maybe }
    # newline
    rule(:n){ str("\n").repeat(1) }
    rule(:n_){ n.maybe }
    # space or newline
    rule(:ss){ (s | n).repeat(1) }
    rule(:ss_){ ss.maybe }
    # separator(s) with surrounding space
    rule(:sp){ (s_ >> (n | str(';')) >> s_).repeat(1) }
    rule(:sp_){ sp.maybe }
    # space, newline or separator
    rule(:ssp_){ (s | n | str(';')).repeat(0) }
  end
 
  class Transformer < Parslet::Transform
    def self.rule_(*keys, &block)
      hash = keys.inject({}){|sum, item| sum[item] = subtree(item); sum}
      rule(hash, &block)
    end

    rule_(:first_stmt, :rest_stmts){
      stmts = [first_stmt] + (rest_stmts || [])
      [:SEQ, stmts]
    }

    # defclass
    rule_(:classname, :stmts){
      if stmts.nil?
        [:DEFCLASS, classname, []]
      else
        raise "stmts not wrapped with :SEQ: #{stmts.inspect}" unless stmts[0] == :SEQ
        [:DEFCLASS, classname, stmts[1]]
      end
    }

    # defun
    rule_(:fname, :argname, :typename, :stmts){ [:DEFUN, fname, argname, typename, stmts] }
    rule_(:fname, :argname, :typename){ [:DEFUN, fname, argname, typename, nil] }
    rule_(:fname, :argname, :stmts){ [:DEFUN, fname, argname, nil, stmts] }
    rule_(:fname, :argname){         [:DEFUN, fname, argname, nil, nil] }

    # defvar
    rule_(:varname, :expr){ [:DEFVAR, varname, expr] }

    # anonfunc
    rule_(:parameter, :stmts){ [:FN, parameter, stmts] }

    # invocation
    rule_(:receiver, :methodname, :argument){
      if argument
        [:INVOKE, receiver, methodname, [argument]]
      else
        [:INVOKE, receiver, methodname, []]
      end
    }

    # funcall
    rule_(:callee, :argument){ [:APP, callee, argument] }

    rule_(:varref){ [:VARREF, varref] }

    rule(:varname => simple(:s)){ s.to_s }
    rule(:methodname => simple(:s)){ s.to_s }
    rule(:typename => simple(:s)){ s.to_s }

    # literal
    rule(:const_i => simple(:n)){ [:CONST, n.to_i] }
    rule(:const_s => simple(:s)){ [:CONST, s.to_s] }
  end
end
 
if $0 == __FILE__
begin
  require 'pp'
  parser = Boom::Parser.new

  require 'parslet/convenience'
  #s = 'def f(x)1;end'
  s = "
fn(x){ 1 }
      "
  p s: s
  ast = parser.parse_with_debug(s)
  #ast = parser.parse(s)

  p ast: ast
  p Boom::Transformer.new.apply(ast)
rescue Parslet::ParseFailed => e
  puts e.cause.ascii_tree
  puts "--"
  puts e
end
end
