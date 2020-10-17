require_relative 'helper'

class OlafConfigureTest < Test::Unit::TestCase
  class MockDriver
    attr_reader :config

    def initialize(**config)
      @config = config
    end

    def instance
      self
    end
  end

  def test_configure_initializes_driver_instance
    Olaf.configure(olaf_driver: MockDriver, other: 'configs', like: 'user and passwd')

    assert Olaf.instance.is_a?(MockDriver)
    assert_equal Olaf.instance.config, { other: 'configs', like: 'user and passwd' }
  end

  def test_configure_defaults_to_snowflake
    Olaf.configure(random: 'stuff')

    assert Olaf.instance.is_a?(Olaf::Snowflake)
  end
end
