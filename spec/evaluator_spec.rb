require_relative 'spec_helper'

describe Evaluator do
  it 'const' do
    expect(Evaluator.run("1")).to eq(1)
  end

  it 'funcall' do
    expect(Evaluator.run("fn(x){ 1 }(2)")).to eq(1)
  end
end
