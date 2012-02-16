require 'rubygems'
require 'bundler/setup'
require 'gemma'

Gemma::RakeTasks.with_gemspec_file 'si_taxi.gemspec'

$rakefile_dir = File.dirname(__FILE__)
CLOBBER.include('ext/*{.o,.so,.log,.cxx}')
CLOBBER.include('ext/si_taxi/{Debug,Coverage,Profile,Release}')
CLOBBER.include('ext/si_taxi/si_taxi/stdafx.h.gch')
CLOBBER.include(%w(ext/Makefile))
CLOBBER.include('lcov')

def num_processors
  n = ENV['NUMBER_OF_PROCESSORS'];
  return n.to_i if n
  File.new('/proc/cpuinfo').readlines.select{|l| l =~ /processor\s*:/}.size
end

SI_TAXI_DIR = File.expand_path(File.join($rakefile_dir, 'ext', 'si_taxi'))

#
# SWIG
#
SI_TAXI_WRAP = 'ext/siTaxi_wrap.cxx'
SI_TAXI_WRAP_DEPS = Dir['ext/*.i'] + Dir["ext/**/*.h"]
file SI_TAXI_WRAP => SI_TAXI_WRAP_DEPS do |t|
  Dir.chdir('ext') do
    sh "swig -Wall -c++ -ruby -I#{SI_TAXI_DIR} siTaxi.i"
  end
end

SWIG_EXT_DEPS = Dir["ext/**/*.cpp}"] + ['ext/extconf.rb', SI_TAXI_WRAP]
desc 'generate wrapper with swig'
task :ext, [:args] => SWIG_EXT_DEPS do |t, args|
  args = args[:args] || ''
  # HACK: save typing...
  if `uname -n`.chomp == 'enm-jdlm'
    args += ' --with-boost=/usr/local/include/boost-1_39'
  end
  Dir.chdir('ext') do
    ruby "extconf.rb #{args}"
    sh "make -j#{num_processors}"
  end
  cp "ext/siTaxi.so", "lib"
end

# note: this doesn't seem to work in lcov 1.8; works with lcov 1.9, though
LCOV_DIR = '../ext'
LCOV_BASE_DIR = '../ext/si_taxi/Coverage/'

desc 'zero coverage counters'
task 'lcov:zero' do
  mkdir_p 'lcov' 
  Dir.chdir('lcov') do
    sh "lcov --directory #{LCOV_DIR} --zerocounters"
  end
end

desc 'generate coverage report'
task 'lcov:capture' do
  mkdir_p 'lcov' 
  Dir.chdir('lcov') do
    sh "lcov --directory #{LCOV_DIR} --base-directory #{LCOV_BASE_DIR}"\
         " --capture --output-file ext.info"
    sh "genhtml ext.info"
  end
end

# NOTE: to avoid lots of spurious leaks, it should be possible to install 
# ruby with
#   rvm install 1.9.2 -C --with-valgrind
# but I haven't actually seen this work (still get lots of spurious leaks)
desc 'run tests under valgrind'
task 'test:valgrind' do
  sh "valgrind --partial-loads-ok=yes --undef-value-errors=no rake test"
end

desc 'build libsi_taxi'
task 'eclipse:build' do
  si_taxi_project = File.join(File.expand_path('.'), 'ext', 'si_taxi')
  # note that eclipse must be on the PATH
  sh "eclipse -nosplash"\
    " -application org.eclipse.cdt.managedbuilder.core.headlessbuild"\
    " -import #{si_taxi_project}"\
    " -build si_taxi"
end

task :default => :test

task :sim_sarsa do
  require 'si_taxi'
  include SiTaxi

  gamma = 0.95
  od = [[0,0.0],[0.1,0]]
  od_wrapper = ODMatrixWrapper.new(od)
  trip_time = [[0, 2], [2, 0]]
  max_queue = 1
  num_veh = 1

  mdp_model = MDPModelB.new(trip_time, num_veh, od_wrapper, max_queue)
  hash_model = FiniteMDP::HashModel.new(mdp_model.to_hash)
  #p FiniteMDP::TableModel.from_model(hash_model)
  
  dp_solver = FiniteMDP::Solver.new(hash_model, gamma)
  dp_solver.policy_iteration_exact 

  ruby_sarsa_solver = FiniteMDP::SarsaSolver.new(hash_model, gamma)
  ruby_sarsa_solver.action_selection = :epsilon_greedy
  ruby_sarsa_solver.alpha = 0.05
  ruby_sarsa_solver.epsilon = 1.0
  1.upto(100000) do |t|
    p ruby_sarsa_solver.q if t % 10000 == 0
    ruby_sarsa_solver.epsilon *= 0.99992
    #ruby_sarsa_solver.temperature *= 0.99995
    ruby_sarsa_solver.sarsa_step
  end

  #SiTaxi.seed_rng 42 # (rand(0x7fffffff))
  #m = MDPSim.new
  #m.trip_time = trip_time
  #m.queue_max = max_queue
  #m.init
  #m.add_vehicles_in_turn num_veh

  #solver = TabularSarsaSolver.new(m)
  #actor = EpsilonGreedySarsaActor.new(solver)
  #solver.actor = actor
  #solver.gamma = gamma
  #solver.init

  #scheme = [
  #  [0.05, 0.1, 50000],
  #  [0.01, 0.05, 50000],
  #  [0.001, 0.01, 50000],
  #  [0.0001, 0.001, 100000]]*2 + [[0.0001, 0.001, 100000]]

  #for epsilon, alpha, num_pax in scheme
  #  p [epsilon, alpha, num_pax]
  #  actor.epsilon = epsilon
  #  solver.alpha = alpha
  #  stream = BWPoissonPaxStream.new(m.now, od) # NB must reset stream from now
  #  solver.handle_pax_stream(num_pax, stream)

  #  p solver.q_size
  #  p solver.policy([0,0,1,0,0])
  #  p solver.policy([0,0,0,1,0])
  #  solver.dump_q
  #end

  #dp_solver.state_action_value.
  #  sort_by{|(s,a),q_dp| [s.to_a + a.flatten]}.each do |(s,a), q_dp|
  #  q_sarsa = solver.lookup_q(s.to_a + a.flatten)
  #  sarsa_action, _ = solver.policy(s.to_a)
  #  dp_opt = (a == dp_solver.policy[s]) ? '*' : ' '
  #  sarsa_opt = (a.flatten == sarsa_action.to_a) ? '*' : ' '
  #  err = 100*(q_dp - q_sarsa) / q_dp

  #  puts "#{s.inspect}, #{a.inspect}: %.4f  %.4f  %.1f\t#{dp_opt} #{sarsa_opt}"\
  #    % [q_dp, q_sarsa, err]
  #end
end

#
# Compare SARSA and DP on small example.
#
task :finite_mdp_sarsa do
  require 'si_taxi'
  include SiTaxi

  trip_time = [[0,2],[2,0]]
  num_veh   = 3
  demand    = [[0,0.1],[0.4,0]]
  queue_max = 5
  gamma     = 0.99

  puts "BUILDING"
  mdp_model  = MDPModelC.new(trip_time, num_veh, demand, queue_max)
  hash_model = FiniteMDP::HashModel.from_model(mdp_model)
  #p FiniteMDP::TableModel.from_model(hash_model)
  
  puts "SOLVING WITH DP (#{hash_model.states.size} states)"
  dp_solver = FiniteMDP::Solver.new(hash_model, gamma)
  dp_solver.policy_iteration_exact 

  puts "SOLVING WITH SARSA"
  ruby_sarsa_solver = FiniteMDP::SarsaSolver.new(hash_model, gamma)
  ruby_sarsa_solver.action_selection = :epsilon_greedy
  ruby_sarsa_solver.alpha = 0.02
  ruby_sarsa_solver.epsilon = 1.0
  ruby_sarsa_solver.lambda_e = 0.95
  1.upto(1000000) do |t|
    ruby_sarsa_solver.epsilon *= 0.999993
    ruby_sarsa_solver.sarsa_step
  end
  puts "FINAL EPSILON: #{ruby_sarsa_solver.epsilon}"

  puts "RESULTS"
  dp_pi = dp_solver.policy
  dp_q = dp_solver.state_action_value
  sarsa_pi = ruby_sarsa_solver.policy
  sarsa_q = ruby_sarsa_solver.state_action_value
  hash_model.states.each do |state|
    state_actions = hash_model.actions(state)
    if state_actions.size > 1
      state_actions.each do |action|
        dp_q_sa = dp_q[[state,action]]
        dp_opt = dp_pi[state] == action ? '*' : ' '
        sarsa_q_sa = sarsa_q[[state,action]]
        sarsa_opt = sarsa_pi[state] == action ? '*' : ' '
        puts "#{state.inspect}\t#{action.to_a.inspect}\t"\
          "%.4f\t%.4f\t#{dp_opt}\t#{sarsa_opt}" % [dp_q_sa, sarsa_q_sa]
      end
      puts
    end
  end

  #dp_solver.policy.each do |state, action|
  #  puts "#{state.inspect}\t#{action.to_a.inspect}"
  #end

  #m = MDPModelC.new
  #tm = FiniteMDP::TableModel.from_model(m)
  #puts tm.rows.map{|s,a,ss,pr,r|
  #  "[#{s.inspect},#{a.to_a.inspect},#{ss.inspect},%.4f,#{r}]" % pr
  #}
  #tm.check_transition_probabilities_sum

  #m_states = m.states
  #m_states.each do |s|
  #  puts "STATE: #{s.inspect}"
  #  m.actions(s).each do |a|
  #    puts "ACTION: #{a.inspect}"
  #    puts m.next_states(s, a).map(&:inspect)
  #  end
  #  exit
  #end
end

