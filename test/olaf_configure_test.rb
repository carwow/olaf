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

  def test_configure_returns_the_default_driver
    assert_equal Olaf.configure(olaf_driver: Olaf::Fake), Olaf.instance
  end

  def test_configure_registers_several_drivers
    snowflake = MockDriver.new
    big_query = MockDriver.new

    Olaf.configure(drivers: { snowflake: snowflake, big_query: big_query }, default: :snowflake)

    assert_equal Olaf.instance, snowflake
    assert_equal Olaf.instance(:snowflake), snowflake
    assert_equal Olaf.instance(:big_query), big_query
  end

  def test_configure_defaults_to_the_first_driver_registered
    snowflake = MockDriver.new

    Olaf.configure(drivers: { snowflake: snowflake, big_query: MockDriver.new })

    assert_equal Olaf.instance, snowflake
  end

  def test_configure_rejects_a_default_that_was_not_registered
    assert_raise_message(/Unknown default driver :redshift/) do
      Olaf.configure(drivers: { snowflake: MockDriver.new }, default: :redshift)
    end
  end

  def test_configure_rejects_both_forms_at_once
    assert_raise ArgumentError do
      Olaf.configure(olaf_driver: MockDriver, drivers: { snowflake: MockDriver.new })
    end
  end

  def test_configure_rejects_an_empty_list_of_drivers
    assert_raise ArgumentError do
      Olaf.configure(drivers: {})
    end
  end

  def test_instance_serves_every_name_when_a_single_driver_is_configured
    Olaf.configure(olaf_driver: Olaf::Fake)

    assert_equal Olaf.instance(:big_query), Olaf.instance
  end

  def test_instance_raises_for_a_driver_that_was_not_registered
    Olaf.configure(drivers: { snowflake: MockDriver.new, big_query: MockDriver.new })

    assert_raise Olaf::UnknownDriverError do
      Olaf.instance(:redshift)
    end
  end

  def test_instance_raises_until_olaf_is_configured
    configured_drivers = Olaf.instance_variable_get(:@drivers)
    Olaf.instance_variable_set(:@drivers, nil)

    assert_raise_message(/You need to configure Olaf before using it!/) do
      Olaf.instance
    end
  ensure
    Olaf.instance_variable_set(:@drivers, configured_drivers)
  end
end
