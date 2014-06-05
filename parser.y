class Parser
  options no_result_var
rule
  toplevel: program

  program: stmts 

  stmts: 
    | stmts stmt
    { [:SEQ, val[0], val[1]] }
    | stmt

  stmt: expr | defun

  defun: 
    DEF_ _IDENT LPAREN _IDENT RPAREN expr END_
    { [:DEFUN, val[1], val[3], val[5]] }

  expr: value
  
  value: anonfunc | funcall | varref | literal

  anonfunc: 
    FN_ LPAREN _IDENT RPAREN LBRACE stmts RBRACE
    { [:FN, val[2], val[5]] }

  funcall:
    expr LPAREN expr RPAREN
    { [:APP, val[0], val[2]] } 

  varref:
    _IDENT
    { [:VARREF, val[0]] }

  literal: number | string

  number: 
    _INT { [:CONST, val[0]] }

  string:
    _STRING { [:CONST, val[0]] }

#  toplevel : Term { val[0] }
#
#  Term :
#    AppTerm
#      { val[0] }
#    | IF Term THEN Term ELSE Term
#      { [:If, val[1], val[3], val[5]] }
#
#  AppTerm :
#      ATerm
#        { val[0] }
#    | SUCC ATerm
#        { [:Succ, val[1]] }
#    | PRED ATerm
#        { [:Pred, val[1]] }
#    | ISZERO ATerm
#        { [:IsZero, val[1]] }
#
#  /* Atomic terms are ones that never require extra parentheses */
#  ATerm :
#      LPAREN Term RPAREN  
#        { val[1] } 
#    | TRUE
#        { [:True] }
#    | FALSE
#        { [:False] }
#    | INTV
#        { (0...val[0]).inject([:Zero]){|sum, item|
#            [:Succ, sum]
#          } }

#  hash    : '{' contents '}'   { val[1] }
#          | '{' '}'            { Hash.new }
#           
#  # Racc can handle string over 2 bytes.
#  contents: IDENT '=>' IDENT              { {val[0] => val[2]} }
#          | contents ',' IDENT '=>' IDENT { val[0][val[2]] = val[4]; val[0] }
end

---- header

require 'strscan'

---- inner

  def self.parse(str)
    ast = Parser.new.parse(str)
    Normalizer.new.normalize(ast)
  end

  def parse(str)
    @s = StringScanner.new(str)
    yyparse self, :scan
  end

  private

  KEYWORDS = %w(if then else true false succ pred iszero def fn end)
  KEYWORDS_REXP = Regexp.new(KEYWORDS.join("|"))
  SYMBOLS = {
    "_"   => "USCORE",
    "'"   => "APOSTROPHE",
    #"\""  => "DQUOTE",
    "!"   => "BANG",
    "#"   => "HASH",
    "$"   => "TRIANGLE",
    "*"   => "STAR",
    "|"   => "VBAR",
    "."   => "DOT",
    ";"   => "SEMI",
    ","   => "COMMA",
    "/"   => "SLASH",
    ":"   => "COLON",
    "::"  => "COLONCOLON",
    "="   => "EQ",
    "=="  => "EQEQ",
    "["   => "LSQUARE",
    "<"   => "LT",
    "{"   => "LBRACE",
    "("   => "LPAREN",
    "<-"  => "LEFTARROW",
    "{|"  => "LCURLYBAR",
    "[|"  => "LSQUAREBAR",
    "}"   => "RBRACE",
    ")"   => "RPAREN",
    "]"   => "RSQUARE",
    ">"   => "GT",
    "|}"  => "BARRCURLY",
    "|>"  => "BARGT",
    "|]"  => "BARRSQUARE",
    ":="  => "COLONEQ",
    "=>"  => "ARROW",
    "=>"  => "DARROW",
    "==>" => "DDARROW",
  }
  SYMBOLS_REXP = Regexp.new(SYMBOLS.map{|k, v| Regexp.quote(k)}.join("|"))

  def scan
    until @s.eos?
      case
      when (s = @s.scan(KEYWORDS_REXP))
        yield ["#{s.upcase}_".to_sym, "#{s.upcase}_".to_sym]
      when (s = @s.scan(SYMBOLS_REXP))
        name = SYMBOLS[s]
        yield [name.to_sym, name.to_sym]
      when (s = @s.scan(/\d+/))
        n = s.to_i
        yield [:_INT, n]
      when @s.scan(/"/)
        s = @s.scan_until(/"/)
        raise "unterminated string" if s.nil?
        yield [:_STRING, s.chop]
      when (s = @s.scan(/[A-Za-z][0-9A-Za-z]*/))
        yield [:_IDENT, s]
      when @s.scan(/\s+/)
        # skip
      else
        p "@s" => @s
        raise "Syntax Error"
      end
    end
    yield [false, '$']   # is optional from Racc 1.3.7
  end
