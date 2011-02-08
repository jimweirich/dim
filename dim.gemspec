require './lib/dim/version'

Gem::Specification.new do |s|
  s.name = %q{dim}
  s.version = Dim::VERSION
  s.authors = ["Jim Weirich", "Mike Subelsky"]
  s.date = Time.now.utc.strftime("%Y-%m-%d")
  s.email = %q{mike@subelsky.com}
  s.extra_rdoc_files = [
    "README.md"
  ]
  s.files = `git ls-files`.split("\n")
  s.homepage = %q{http://github.com/subelsky/dim}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.5.0}
  s.summary = %q{Minimalistic dependency injection framework}
  s.description = %q{Minimalistic dependency injection framework}
  s.test_files = `git ls-files spec`.split("\n")
  s.add_development_dependency 'rspec'
end
