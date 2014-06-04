require 'simplecov'
SimpleCov.start

require_relative '../boom.rb'

describe TypeInference do
  describe "#infer" do
    def infer(expr, env={})
      TypeInference.infer(expr, env)
    end

    it 'lit' do
      expr = [:lit, "int", 7]
      expect(infer(expr)).to eq(
        [1, {}, [:LIT, "int"]]
      )
    end

    it 'abs' do
      expr = [:abs, "x", [:var, "x"]]
      expect(infer(expr)).to eq(
        [2, {}, [:FUN, [:VAR, 1], [:VAR, 1]]]
      )
    end

    it 'app' do
      expr = [:app, [:abs, "x", [:var, "x"]], [:lit, "int", 7]]
      expect(infer(expr)).to eq(
        [3, {1 => [:LIT, "int"], 2 => [:LIT, "int"]},
          [:LIT, "int"]]
      )
    end

    it 'let value' do
      expr = [:let, "x", [:lit, "int", 7], [:lit, "int", 8]]
      expect(infer(expr)).to eq(
        [1, {}, [:LIT, "int"]]
      )
    end

    it 'let func' do
      expr = [:let, "f", [:abs, "x", [:var, "x"]],
               [:app, [:var, "f"], [:lit, "int", 7]]]
      expect(infer(expr)).to eq(
        [4, {2 => [:LIT, "int"], 3 => [:LIT, "int"]},
          [:LIT, "int"]]
      )
    end
  end
end
