require_relative 'spec_helper'

describe Parser do
  def parse(str)
    Parser.parse(str)
  end

  it 'literal' do
    src = "1"
    expect(parse(src)).to eq(
      [:lit, "int", 1]
    )
  end

  it 'anonfunc' do
    src = "fn(x){ 1 }"
    expect(parse(src)).to eq(
      [:abs, "x", [:lit, "int", 1]]
    )
  end

  it 'varref' do
    src = "print"
    expect(parse(src)).to eq(
      [:var, "print"]
    )
  end

  it 'funcall' do
    src = "print(1)"
    expect(parse(src)).to eq(
      [:app, [:var, "print"], [:lit, "int", 1]]
    )
  end
end
