require_relative 'spec_helper'

describe Parser do
  def parse(str)
    Parser.new.parse(str)
  end

  def parse_(str)
    Parser.parse(str)
  end

  it 'stmts' do
    src = "1\n2\n3"
    expect(parse(src)).to eq(
      [:SEQ, [[:CONST, 1], [:CONST, 2], [:CONST, 3]]]
    )
  end

  context 'value' do
    it 'anonfunc' do
      src = "fn(x){ 1 }"
      expect(parse_(src)).to eq(
        [:abs, "x", nil, [:lit, "Int", 1]]
      )
    end

    it 'funcall' do
      src = "print(1)"
      expect(parse_(src)).to eq(
        [:app, [:var, "print"], [:lit, "Int", 1]]
      )
    end

    it 'varref' do
      src = "print"
      expect(parse_(src)).to eq(
        [:var, "print"]
      )
    end

    context 'literal' do
      it 'number' do
        src = "1"
        expect(parse_(src)).to eq(
          [:lit, "Int", 1]
        )
      end

      it 'string' do
        src = '"a"'
        expect(parse_(src)).to eq(
          [:lit, "String", "a"]
        )
      end
    end
  end
end
