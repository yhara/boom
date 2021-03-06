require_relative 'spec_helper'

module Boom
  include TypeInference::Type

  describe TypeInference do
    def process(str)
      Normalizer.new.normalize(Parser.parse(str))
    end

    describe "#infer" do
      before :each do
        TyVar.reset_id
      end

      def infer(expr, env={})
        subst, type = *TypeInference.infer(expr, env)
        return type
      end

      it 'lit' do
        expr = [:lit, "Int", 7]
        expect(infer(expr)).to eq(TyRaw["Int"])
      end

      it 'abs' do
        expr = [:abs, "x", nil, [:var, "x"]]
        expect(infer(expr)).to eq(TyFun[TyVar[1], TyVar[1]])
      end

      it 'app' do
        expr = [:app, [:abs, "x", nil, [:var, "x"]], [:lit, "Int", 7]]
        expect(infer(expr)).to eq(TyRaw["Int"])
      end

      it 'let value' do
        expr = [:let, "x", [:lit, "Int", 7], [:lit, "Int", 8]]
        expect(infer(expr)).to eq(TyRaw["Int"])
      end

      it 'let func' do
        expr = [:let, "f", [:abs, "x", nil, [:var, "x"]],
                 [:app, [:var, "f"], [:lit, "Int", 7]]]
        expect(infer(expr)).to eq(TyRaw["Int"])
      end

      it 'seq' do
        expr = [:let, "f", [:abs, "x", nil, [:lit, "Int", 8]],
                 [:seq, [:app, [:var, "f"], [:lit, "Int", 7]],
                 [:seq, [:app, [:var, "f"], [:lit, "String", "hi"]],
                        [:var, "f"]]]]
                       
        expect(infer(expr)).to eq(TyFun[TyVar[6], TyRaw["Int"]])
      end

      it 'with predefined funcs' do
        expr = [:let, "f", [:abs, "x", nil, [:var, "x"]],
                  [:app, [:var, "f"], [:var, "succ"]]]
        ty_int_int = TyFun[TyRaw["Int"], TyRaw["Int"]]
        env = {
          "succ" => ty_int_int,
        }
        expect(infer(expr, env)).to eq(ty_int_int)
      end

      it 'abs with type annotation' do
        expr = [:abs, "x", "Int", [:var, "x"]]
        expect(infer(expr)).to eq(TyFun[TyRaw["Int"], TyRaw["Int"]])
      end

      it 'defclass' do
        expr = process("
          class A; end
          A
        ")
        expect(infer(expr)).to eq(TyRaw["Class"])
      end

      it 'instance' do
        expr = process("
          class A; end
          A.new()
        ")
        expect(infer(expr)).to eq(TyRaw["A"])
      end
    end
  end
end
