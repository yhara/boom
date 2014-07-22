desc "Run test"
task :spec do
  sh "bundle exec rspec"
end

desc "Run main"
task :run do
  sh "bundle exec bin/boom #{ARGV.last}"
end

task :a do
  sh "bundle exec bin/boom a.boom"
end

task default: :spec
