$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../../lib')

require 'icuke/cucumber'

World(ICukeWorld)
