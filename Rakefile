file "lib/boom/parser.rb" => ["lib/boom/parser.y"] do
  sh "bundle exec racc lib/boom/parser.y -o lib/boom/parser.rb"
end
task :parser => "lib/boom/parser.rb"

desc "Run test"
task :spec => :parser do
  sh "bundle exec rspec"
end

desc "Run main"
task :run => :parser do
  sh "bundle exec bin/boom #{ARGV.last}"
end

task :a => :parser do
  sh "bundle exec bin/boom a.boom"
end

task default: :spec
