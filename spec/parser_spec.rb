require_relative 'spec_helper'

module Boom
  describe Parser do
    def parse(str)
      Parser.parse(str)
    end

    it 'stmts' do
      src = "1\n2\n3"
      expect(parse(src)).to eq(
        [:SEQ, [[:CONST, 1], [:CONST, 2], [:CONST, 3]]]
      )
    end

    context 'stmt' do
      it 'defklass' do
        src = "class A; end"
        expect(parse(src)).to eq(
          [:SEQ, [[:DEFCLASS, "A"]]]
        )
      end

      context 'defun' do
        it 'ident, typeannot and expr' do
          src = "def f(x: Int) 1 end"
          expect(parse(src)).to eq(
            [:SEQ, [[:DEFUN, "f", "x", "Int", [:SEQ, [[:CONST, 1]]]]]]
          )
        end

        it 'no ident, typeannot or expr' do
          src = "def f() end"
          expect(parse(src)).to eq(
            [:SEQ, [[:DEFUN, "f", nil, nil, nil]]]
          )
        end
      end
    end

    context 'value' do
      it 'anonfunc' do
        src = "fn(x){ 1 }"
        expect(parse(src)).to eq(
          [:SEQ, [[:FN, "x", [:SEQ, [[:CONST, 1]]]]]]
        )
      end

      it 'funcall' do
        src = "print(1)"
        expect(parse(src)).to eq(
          [:SEQ, [[:APP, [:VARREF, "print"], [:CONST, 1]]]]
        )
      end

      it 'varref' do
        src = "print"
        expect(parse(src)).to eq(
          [:SEQ, [[:VARREF, "print"]]]
        )
      end

      context 'literal' do
        it 'number' do
          src = "1"
          expect(parse(src)).to eq(
            [:SEQ, [[:CONST, 1]]]
          )
        end

        it 'string' do
          src = '"a"'
          expect(parse(src)).to eq(
            [:SEQ, [[:CONST, "a"]]]
          )
        end
      end
    end
  end
end
