Gem::Specification.new do |s|
  s.name        = 'olaf'
  s.version     = '0.2.0'
  s.date        = Time.now.strftime('%Y-%m-%d')
  s.summary     = 'Ruby wrapper for warehouse queries.'
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

  # Drivers load their own client libraries, so consumers only install the ones
  # they configure:
  #   Olaf::Snowflake - sequel and ruby-odbc
  #   Olaf::BigQuery  - google-cloud-bigquery
  s.add_development_dependency 'google-cloud-bigquery', '~> 1.64'
  s.add_development_dependency 'sequel', '~> 5.37'
  s.add_development_dependency 'test-unit', '~> 3.3'
end
