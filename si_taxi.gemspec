# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)
 
require 'si_taxi/version'
 
Gem::Specification.new do |s|
  s.name              = 'si_taxi'
  s.version           = SiTaxi::VERSION
  s.platform          = Gem::Platform::RUBY
  s.authors           = ['John Lees-Miller']
  s.email             = ['jdleesmiller@gmail.com']
  s.homepage          = 'http://seis.bris.ac.uk/~enjdlm'
  s.summary           = %q{High-level taxi stochastic simulation.}
  s.description       = %q{High-level taxi stochastic simulation.}

  s.rubyforge_project = 'si_taxi'

  s.add_runtime_dependency 'facets', '~> 2.9'
  s.add_runtime_dependency 'hpricot', '~> 0.8.4'

  # gemma now in Gemfile -- using local copy
  #s.add_development_dependency 'gemma', '~> 2.0.0'
  s.add_development_dependency 'shoulda', '>= 2.11.3', '~> 2.11'
  s.add_development_dependency 'simplecov', '>= 0.4.0', '~> 0.4'

  s.files       = Dir.glob('{lib,bin}/**/*.rb') + %w(README.rdoc)
  s.test_files  = Dir.glob('test/si_taxi/*_test.rb')
  s.executables = Dir.glob('bin/*').map{|f| File.basename(f)}
  s.extensions = ["ext/extconf.rb"]

  s.rdoc_options = [
    "--main",    "README.rdoc",
    "--title",   "#{s.full_name} Documentation"]
  s.extra_rdoc_files << "README.rdoc"
end

