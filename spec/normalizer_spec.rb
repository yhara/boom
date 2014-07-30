require_relative 'spec_helper'

module Boom
  describe Normalizer do
    def normalize(ast)
      Normalizer.new.normalize(ast)
    end

    it 'CONST' do
      ast = [:CONST, 1]
      expect(normalize(ast)).to eq(
        [:lit, "Int", 1]
      )
    end

    it 'VARREF' do
      ast = [:VARREF, "x"]
      expect(normalize(ast)).to eq(
        [:var, "x"]
      )
    end

    it 'FN' do
      ast = [:FN, "x", [:CONST, 1]]
      expect(normalize(ast)).to eq(
        [:abs, "x", nil, [:lit, "Int", 1]]
      )
    end

    it 'APP' do
      ast = [:APP, [:VARREF, "f"], [:CONST, 1]]
      expect(normalize(ast)).to eq(
        [:app, [:var, "f"], [:lit, "Int", 1]]
      )
    end

    context 'SEQ' do
      context 'DEFUN' do
        it 'ident, typeannot and expr' do
          ast = Parser.parse("
            def f(x: Int)
              1
            end
            f(2)
          ")
          expect(normalize(ast)).to eq(
            [:let, "f", [:abs, "x", "Int", [:lit, "Int", 1]],
              [:app, [:var, "f"], [:lit, "Int", 2]]]
          )
        end

        it 'no ident, typeannot or expr' do
          ast = Parser.parse("
            def f()
            end
            f
          ")
          expect(normalize(ast)).to eq(
            [:let, "f", [:abs, "%dummy", "Unit", [:lit, "Unit", :unit]],
              [:var, "f"]]
          )
        end
      end

      it 'DEFVAR' do
        ast = Parser.parse("
          x = 1
          y = 2
        ")
        expect(normalize(ast)).to eq(
          [:let, "x", [:lit, "Int", 1],
            [:lit, "Int", 2]]
        )
      end

      it 'SEQ' do
        ast = Parser.parse("
          f(x)
          g(x)
          h(x)
        ")
        expect(normalize(ast)).to eq(
          [:seq, [:app, [:var, "f"], [:var, "x"]],
            [:seq, 
               [:app, [:var, "g"], [:var, "x"]],
               [:app, [:var, "h"], [:var, "x"]]]]
        )
      end
    end

    it 'DEFCLASS' do
      ast = Parser.parse("
        print(1)
        class A; end
      ")
      expect(normalize(ast)).to eq(
        [:withdef,
          [[:defclass, "A"]],
          [[:app, [:var, "print"], [:lit, "Int", 1]]]],
      )
    end
  end
end
