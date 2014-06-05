require_relative 'spec_helper'
include TypeInference::Type

describe TypeInference do
  describe "#infer" do
    def infer(expr, env={})
      TypeInference.infer(expr, env)
    end

    it 'lit' do
      expr = [:lit, "int", 7]
      expect(infer(expr)).to eq(
        [{}, TyRaw["int"]]
      )
    end

    it 'abs' do
      expr = [:abs, "x", [:var, "x"]]
      expect(infer(expr)).to eq(
        [{}, TyFun[TyVar[1], TyVar[1]]]
      )
    end

    it 'app' do
      expr = [:app, [:abs, "x", [:var, "x"]], [:lit, "int", 7]]
      expect(infer(expr)).to eq(
        [{1 => TyRaw["int"], 2 => TyRaw["int"]},
          TyRaw["int"]]
      )
    end

    it 'let value' do
      expr = [:let, "x", [:lit, "int", 7], [:lit, "int", 8]]
      expect(infer(expr)).to eq(
        [{}, TyRaw["int"]]
      )
    end

    it 'let func' do
      expr = [:let, "f", [:abs, "x", [:var, "x"]],
               [:app, [:var, "f"], [:lit, "int", 7]]]
      expect(infer(expr)).to eq(
        [{2 => TyRaw["int"], 3 => TyRaw["int"]},
          TyRaw["int"]]
      )
    end

    it 'with predefined funcs' do
      expr = [:let, "f", [:abs, "x", [:var, "x"]],
                [:app, [:var, "f"], [:var, "succ"]]]
      ty_int_int = TyFun[TyRaw["int"], TyRaw["int"]]
      env = {
        "succ" => ty_int_int,
      }
      expect(TypeInference.infer(expr, env)).to eq(
        [{2 => ty_int_int, 3 => ty_int_int},
         ty_int_int]
      )
    end
  end
end
