require 'forwardable'
require 'pattern-match'

system 'racc parser.y -o parser.rb'
require_relative 'parser.rb'
require_relative 'normalizer.rb'
require_relative 'inferer.rb'
require_relative 'evaluator.rb'

if $0==__FILE__
  Evaluator.run(ARGF.read)
end
