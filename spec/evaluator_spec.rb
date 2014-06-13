require 'stringio'
require_relative 'spec_helper'

describe Evaluator do
  def run(str)
    Evaluator.run(str, io: [$stdin, @out])
  end

  before do
    @out = StringIO.new
  end
  
  it 'const' do
    expect(run("1")).to eq(1)
  end

  it 'funcall' do
    expect(run("fn(x){ 1 }(2)")).to eq(1)
  end

  it 'library' do
    run("print(\"Hello, world!\")")
    expect(@out.string).to eq("Hello, world!")
  end

  it 'defun' do
    src = <<-EOD
      def f(x : Int)
        x
      end
      f(1)
    EOD
    expect(run(src)).to eq(1) 
  end

  it 'defvar' do
    expect(run(<<-EOD)).to eq(1)
      x = 1
      x
    EOD
  end

  it 'seq' do
    src = <<-EOD
      print("a")
      print("b")
    EOD
    run(src)
    expect(@out.string).to eq("ab") 
  end

  context 'wrong program' do
    it 'parse error' do
      expect{
        run("print(")
      }.to raise_error(Racc::ParseError)
    end

    it 'type error' do
      expect{
        run("print(1)")
      }.to raise_error(TypeInference::InferenceError)
    end
  end
end
