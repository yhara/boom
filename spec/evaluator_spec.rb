require 'stringio'
require_relative 'spec_helper'

describe Evaluator do
  def run(str)
    Evaluator.run(str)
  end
  
  def capture(&block)
    io = StringIO.new
    orig_out = $stdout
    $stdout = io
    block.call
    io.string
  ensure
    $stdout = orig_out
  end

  it 'const' do
    expect(run("1")).to eq(1)
  end

  it 'funcall' do
    expect(run("fn(x){ 1 }(2)")).to eq(1)
  end

  it 'library' do
    expect(capture{ run("print(\"Hello, world!\")") }).to eq(
      "Hello, world!"
    )
  end

  context 'wrong program' do
    it 'type error' do
      expect{
        run("print(1)")
      }.to raise_error(TypeInference::InferenceError)
    end
  end
end
