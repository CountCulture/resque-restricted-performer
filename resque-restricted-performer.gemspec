Gem::Specification.new do |s|
  s.name              = "resque-restricted-performer"
  s.version           = "0.1.0"
  s.date              = Time.now.strftime('%Y-%m-%d')
  s.summary           = "A Resque plugin for ensuring only one instance of your job is performed at a time."
  s.homepage          = "http://github.com/CountCulture/resque-restricted-performer"
  s.email             = "countculture@gmail.com"
  s.authors           = [ "Chris Taggart" ]
  s.has_rdoc          = false

  s.files             = %w( README.md Rakefile LICENSE )
  s.files            += Dir.glob("lib/**/*")
  s.files            += Dir.glob("test/**/*")
  s.require_paths     = ["lib"]

  s.description       = <<desc
A Resque plugin. If you want only one instance of your job, or class,
performed at a time, use this gem to overwrite standard Resque::Job
behaviour. This is similar to https://github.com/defunkt/resque-lock
but allows multiple similar objects to be queued, but not performed
at the same time. There are a avariety of use cases, but we use it 
to ensure we don't hit APIs with more than one client at a time (or
whatever the limit is).

desc
end
