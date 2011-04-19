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

  s.add_development_dependency 'gemma', '>= 1.0.1', '~> 1.0'
  s.add_development_dependency 'shoulda', '>= 2.11.3', '~> 2.11'
  s.add_development_dependency 'simplecov', '>= 0.4.0', '~> 0.4'
  s.add_development_dependency 'yard', '>= 0.6.7', '~> 0.6'

  # TODO need to rethink how gemma does this...
  s.add_development_dependency 'rdoc', '>= 3.5.3', '~> 3.5'

  s.files       = Dir.glob('{lib,bin}/**/*.rb') + %w(README.rdoc)
  s.test_files  = Dir.glob('test/*_test.rb')
  s.executables = Dir.glob('bin/*').map{|f| File.basename(f)}

  s.extensions = "ext/extconf.rb"
  s.require_paths << 'ext'

  s.rdoc_options = [
    "--main",    "README.rdoc",
    "--title",   "#{s.full_name} Documentation"]
  s.extra_rdoc_files << "README.rdoc"
end

