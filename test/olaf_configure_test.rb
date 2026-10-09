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

  def test_configure_requires_a_driver
    assert_raise ArgumentError do
      Olaf.configure(random: 'stuff')
    end
  end

  def test_configure_returns_the_default_driver
    assert_equal Olaf.configure(olaf_driver: Olaf::Fake), Olaf.instance
  end

  def test_configure_registers_several_drivers
    postgres = MockDriver.new
    big_query = MockDriver.new

    Olaf.configure(drivers: { postgres: postgres, big_query: big_query }, default: :postgres)

    assert_equal Olaf.instance, postgres
    assert_equal Olaf.instance(:postgres), postgres
    assert_equal Olaf.instance(:big_query), big_query
  end

  def test_configure_defaults_to_the_first_driver_registered
    postgres = MockDriver.new

    Olaf.configure(drivers: { postgres: postgres, big_query: MockDriver.new })

    assert_equal Olaf.instance, postgres
  end

  def test_configure_rejects_a_default_that_was_not_registered
    assert_raise_message(/Unknown default driver :redshift/) do
      Olaf.configure(drivers: { postgres: MockDriver.new }, default: :redshift)
    end
  end

  def test_configure_rejects_both_forms_at_once
    assert_raise ArgumentError do
      Olaf.configure(olaf_driver: MockDriver, drivers: { postgres: MockDriver.new })
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
    Olaf.configure(drivers: { postgres: MockDriver.new, big_query: MockDriver.new })

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
