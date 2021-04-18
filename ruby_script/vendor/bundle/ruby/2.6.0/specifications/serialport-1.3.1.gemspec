# -*- encoding: utf-8 -*-
# stub: serialport 1.3.1 ruby lib
# stub: ext/native/extconf.rb

Gem::Specification.new do |s|
  s.name = "serialport".freeze
  s.version = "1.3.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Guillaume Pierronnet".freeze, "Alan Stern".freeze, "Daniel E. Shipton".freeze, "Tobin Richard".freeze, "Hector Parra".freeze, "Ryan C. Payne".freeze]
  s.date = "2014-07-27"
  s.description = "Ruby/SerialPort is a Ruby library that provides a class for using RS-232 serial ports.".freeze
  s.email = "hector@hectorparra.com".freeze
  s.extensions = ["ext/native/extconf.rb".freeze]
  s.extra_rdoc_files = ["LICENSE".freeze, "README.md".freeze]
  s.files = ["LICENSE".freeze, "README.md".freeze, "ext/native/extconf.rb".freeze]
  s.homepage = "http://github.com/hparra/ruby-serialport/".freeze
  s.licenses = ["GPL-2".freeze]
  s.rubygems_version = "3.0.3".freeze
  s.summary = "Library for using RS-232 serial ports.".freeze

  s.installed_by_version = "3.0.3" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<bundler>.freeze, [">= 0"])
      s.add_development_dependency(%q<rake>.freeze, [">= 0"])
      s.add_development_dependency(%q<rake-compiler>.freeze, [">= 0.4.1"])
    else
      s.add_dependency(%q<bundler>.freeze, [">= 0"])
      s.add_dependency(%q<rake>.freeze, [">= 0"])
      s.add_dependency(%q<rake-compiler>.freeze, [">= 0.4.1"])
    end
  else
    s.add_dependency(%q<bundler>.freeze, [">= 0"])
    s.add_dependency(%q<rake>.freeze, [">= 0"])
    s.add_dependency(%q<rake-compiler>.freeze, [">= 0.4.1"])
  end
end
