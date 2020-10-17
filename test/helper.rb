$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/../lib"))

require 'olaf'
require 'test/unit'

def reject(condition, message="Expected condition to be unsatisfied")
  assert !condition, message
end
