require_relative 'helper'

# Drivers pull in client libraries that not every consumer installs, so what
# gets loaded, and when, is part of the interface. These run in a subprocess:
# the rest of the suite has all of them loaded already.
class OlafLazyLoadingTest < Test::Unit::TestCase
  def test_requiring_olaf_loads_no_driver_dependency
    assert_equal loaded_after('require "olaf"'), []
  end

  def test_configuring_the_fake_driver_loads_no_driver_dependency
    assert_equal loaded_after('require "olaf"; Olaf.configure(olaf_driver: Olaf::Fake)'), []
  end

  def test_configuring_the_snowflake_driver_loads_sequel_only
    assert_equal loaded_after('require "olaf"; Olaf.configure(user: "olaf")'), ['sequel']
  end

  private

  DEPENDENCIES = {
    'sequel' => 'Sequel',
    'odbc_utf8' => 'ODBC',
    'google-cloud-bigquery' => 'Google::Cloud::Bigquery'
  }.freeze

  def loaded_after(script)
    report = "print #{DEPENDENCIES.values.inspect}.map { |c| Object.const_defined?(c) }.inspect"
    # RUBYOPT carries bundler into the subprocess, which is not what is measured.
    output = IO.popen({ 'RUBYOPT' => nil }, [RbConfig.ruby, '-I', lib_path, '-e', "#{script}; #{report}"], &:read)

    assert $?.success?, "Failed to run: #{script}"

    DEPENDENCIES.keys.zip(eval(output)).select { |_name, loaded| loaded }.map(&:first)
  end

  def lib_path
    File.expand_path('../lib', File.dirname(__FILE__))
  end
end
