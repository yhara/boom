file "parser.rb" => ["parser.y"] do
  sh "bundle exec racc parser.y -o parser.rb"
end

desc "Run test"
task :spec => ["parser.rb"] do
  sh "bundle exec rspec"
end

desc "Run main"
task :run => ["parser.rb"] do
  sh "bundle exec ruby boom.rb"
end

task default: :spec
