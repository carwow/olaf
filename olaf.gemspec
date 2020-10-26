Gem::Specification.new do |s|
  s.name        = 'olaf'
  s.version     = '0.1.2'
  s.date        = Time.now.strftime('%Y-%m-%d')
  s.summary     = 'Ruby wrapper for Snowflake queries.'
  s.authors     = ['Emiliano Mancuso']
  s.email       = ['emiliano.mancuso@gmail.com', 'developers@carwow.co.uk']
  s.homepage    = 'http://github.com/carwow/olaf'
  s.license     = 'MIT'

  s.files = Dir[
    'README.md',
    'rakefile',
    'lib/**/*.rb',
    '*.gemspec'
  ]
  s.test_files = Dir['test/*.*']

  s.add_runtime_dependency 'sequel', '~> 5.37'
  s.add_runtime_dependency 'ruby-odbc', '~> 0.99'
  s.add_development_dependency 'test-unit', '~> 3.3'
end
