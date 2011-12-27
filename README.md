Resque Lock
===========

A [Resque][rq] plugin. Requires Resque 1.7.0.

If you want only one instance of your job performed by workers at a time (e.g. to avoid hitting an external
service by multiple workers) use this plugin. 
It overrides the default behaviour of Resque::Job to add a lock to each job based on the class and the arguments
for the queued job, and ensures that other jobs with the same lock won't be processed. The lock\_name can be
overridden in the performed object class with the #performer\_lock\_name class method, which will be passed 
the job's arguments. 
This can ensure that only one instance of that class is performed at any one time, or some other, more complex
behaviour. We use a number of APIs that fail if you use the same API key simultaneously, and also scrape a 
number of web sites that either struggle or perceive a DOS attack if you make simultaneous requests.


For example:

    class SuperSensitiveApiClient

      def self.performer_lock_name(args)
        'supersensitiveapiclient' # this ensures only one call made at a time
      end
    end

    class LessSensitiveApiClient

      def self.performer\_lock\_name(args) 
        # converts the args to a hash number, and then converts to 0-2, to 3 poss values, 
        # meaning 3 simultaneous clients 
        "lesssensitiveapiclient_#{args.to_s.hash%3}"
      end
    end

[rq]: http://github.com/defunkt/resque
