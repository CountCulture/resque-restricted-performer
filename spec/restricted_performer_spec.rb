require 'spec_helper'

describe Resque::Job do

  class PerformableObjectWithLockName
    def self.perform(*args)
      # do nothing
    end
    
    def self.queue
      :foo_queue
    end

    def self.performer_lock_name(args)
      'foobar'
    end
  end
  
  class PerformableObjectWithoutLockName
    def self.perform(*args)
      # do nothing
    end
    
    def self.queue
      :bar_queue
    end
    
    def self.after_perform_do_this(*args)
      
    end
  end
  
  describe 'reserving job from queue' do

    before do
      Resque.redis.stubs(:setnx)
      Resque::Job.stubs(:next_unlocked)
    end

    it 'should get next unlocked job from queue' do
      Resque::Job.expects(:next_unlocked).with('foo_queue')
      Resque::Job.reserve('foo_queue')
    end

    it 'should not pop from redis' do
      # i.e. normal behaviour
      Resque.redis.expects(:pop).never
      Resque::Job.reserve('foo_queue')
    end
    
    describe 'and unlocked job returns object' do
      before do
        @obj = stub('obj')
        Resque::Job.stubs(:next_unlocked).returns(@obj)
      end
      
      it 'should create new job with returned object' do
        Resque::Job.expects(:new).with('foo_queue', @obj)

        Resque::Job.reserve('foo_queue')
      end
      
      it 'should return new job' do
        Resque::Job.reserve('foo_queue').must_be_kind_of(Resque::Job)

        Resque::Job.reserve('foo_queue')
      end


    end

    describe 'and unlocked job returns nil' do

      it 'should not pop from redis' do
        Resque.redis.expects(:pop).never
        
        Resque::Job.reserve('foo_queue')
      end
      
      it 'should return nil' do
        Resque::Job.reserve('foo_queue').must_be_nil
      end

    end
  end

  describe 'getting next_unlocked entry from given queue' do
    before do
      Resque.redis.stubs(:setnx)
      @queue_response = [ {"args"=>['foo'], "class"=>"PerformableObjectWithLockName"}, 
                          {"args"=>['bar'], "class"=>"PerformableObjectWithLockName"},
                          {"args"=>['baz'], "class"=>"PerformableObjectWithLockName"}
                        ]
      Resque.stubs(:peek).returns(@queue_response)
    end

    it 'should peek at next 10 items from queue' do
      Resque.expects(:peek).with('foo_queue', 0, 10).returns([])
      Resque::Job.next_unlocked('foo_queue')
    end
    
    it 'should return nil if no items on queue' do
      Resque.stubs(:peek).returns([])
      Resque::Job.next_unlocked('foo_queue').must_be_nil
    end
    
    it 'should return first item from queue that returns true to lock_if_free' do
      Resque.stubs(:peek).returns(@queue_response)
      Resque::Job.stubs(:lock_if_free!) # returns nil
      Resque::Job.expects(:lock_if_free!).with(@queue_response[1], 'foo_queue').returns(true)
      Resque::Job.next_unlocked('foo_queue').must_equal( @queue_response[1] )
    end

    it 'should return nil if no item returns true to lock_if_free' do
      Resque::Job.next_unlocked('foo_queue').must_be_nil
    end
  end

  describe 'performer_lock_name from queued job' do
    before do
      Resque.redis.stubs(:setnx)
    end

    it 'should delegate to class of queued object' do
      PerformableObjectWithLockName.expects(:performer_lock_name).returns('foobar')
      Resque::Job.performer_lock_name({"args"=>['bar'], "class"=>"PerformableObjectWithLockName"}).must_equal 'foobar'
    end

    it "should build from queued object class name and object arguments when object class doesn't have performer_lock_name" do
      PerformableObjectWithLockName.expects(:performer_lock_name).never
      Resque::Job.performer_lock_name({"args"=>['bar','42'], "class"=>"PerformableObjectWithoutLockName"}).must_equal 'PerformableObjectWithoutLockName_bar_42'
    end

  end
  
  describe 'lock_if_free! class method' do
    before do
      Resque.redis.stubs(:setnx)
    end
    
    it 'should get performer_lock_name from queued object class given arguments' do
      Resque::Job.expects(:performer_lock_name).with({"args"=>['bar'], "class"=>"PerformableObjectWithLockName"})
      Resque::Job.lock_if_free!({"args"=>['bar'], "class"=>"PerformableObjectWithLockName"}, 'baz_queue')
    end
    
    it 'should try to set lock using lock_name and prefix for name and queue_name for value' do
      Resque::Job.stubs(:performer_lock_name).returns('foobar')
      Resque.redis.expects(:setnx).with("performer_lock:foobar", 'baz_queue')
      Resque::Job.lock_if_free!({"args"=>['bar'], "class"=>"PerformableObjectWithLockName"}, 'baz_queue')
    end
    
    it 'should return false if setting of lock unsuccessful' do
      Resque.redis.expects(:setnx).returns(false)
      Resque::Job.lock_if_free!({"args"=>['bar'], "class"=>"PerformableObjectWithLockName"}, 'baz_queue').wont_equal true
    end
    
    it 'should return true if setting of lock successful' do
      Resque.redis.expects(:setnx).returns(true)
      Resque::Job.lock_if_free!({"args"=>['bar'], "class"=>"PerformableObjectWithLockName"}, 'baz_queue').must_equal true
    end
  end
  
  describe 'clear_performed_lock' do
    before do
      Resque.redis.stubs(:setnx)
      @queue_name = PerformableObjectWithLockName.queue
      @queued_hash = {"args"=>['bar'], "class"=>"PerformableObjectWithLockName"}
      @another_queued_hash = {"args"=>['baz'], "class"=>"PerformableObjectWithLockName"}
      @lock_name = "performer_lock:#{PerformableObjectWithLockName.performer_lock_name(['bar'])}"
      @encoded_queued_hash =  ::MultiJson.encode(@queued_hash)
      @encoded_another_queued_hash =  ::MultiJson.encode(@another_queued_hash)
      # add objects onto queues
      Resque.push(@queue_name, @queued_hash)
      Resque.push(@queue_name, @another_queued_hash )
      Resque.push('bar_queue', @queued_hash)
      # set lock
      Resque.redis.set(@lock_name, @queue_name)
    end
    
    after do
      Resque.redis.flushall
    end

    it 'should remove job from queue' do
      Resque::Job.clear_performed_lock({"args"=>['bar'], "class"=>"PerformableObjectWithLockName"})
      Resque.redis.lrem("queue:#{@queue_name}", 1, @encoded_queued_hash).must_equal 0 # should be nothing matching on list
    end
    
    it 'should not remove other jobs from queue' do
      Resque::Job.clear_performed_lock({"args"=>['bar'], "class"=>"PerformableObjectWithLockName"})
      Resque.redis.lrem("queue:#{@queue_name}", 1, @encoded_another_queued_hash).must_equal 1 # should be nothing matching on list
    end
    
    it 'should not remove same job from other queues' do
      Resque::Job.clear_performed_lock({"args"=>['bar'], "class"=>"PerformableObjectWithLockName"})
      Resque.redis.lrem('queue:bar_queue', 1, @encoded_queued_hash).must_equal 1 # should be nothing matching on list
    end
    
    it 'should remove lock specified by performer_lock_name' do
      Resque::Job.clear_performed_lock({"args"=>['bar'], "class"=>"PerformableObjectWithLockName"})
      Resque.redis.get(@lock_name).must_be_nil
    end

    it 'should remove lock only after removing job from queue' do
      Resque.redis.stubs(:lrem).raises(Exception)
      begin
        Resque::Job.clear_performed_lock({"args"=>['bar'], "class"=>"PerformableObjectWithLockName"}) 
      rescue Exception => e
      end
      Resque.redis.get(@lock_name).wont_be_nil      
    end
    
    describe "when performing" do
      before do
        @job = Resque::Job.new('foo', {"args"=>['bar'], "class"=>"PerformableObjectWithLockName"})
      end
      
      it "should perform object" do
        # this tests normal behaviour is still followed
        PerformableObjectWithLockName.expects(:perform).with('bar')
        @job.perform
      end
      
      it "should should clear lock" do
        Resque::Job.expects(:clear_performed_lock).with('args' => ['bar'], 'class' => 'PerformableObjectWithLockName')
        @job.perform
      end
      
      it "should clear lock even if problem performing object" do
        PerformableObjectWithLockName.expects(:perform).raises("uh-oh. that wasn't supposed to happen")
        Resque::Job.expects(:clear_performed_lock).with('args' => ['bar'], 'class' => 'PerformableObjectWithLockName')
        begin
          @job.perform
        rescue Exception => e
        end
        
      end
    end
    
  end
  
  describe "when processing job" do
    # This is a sort of integration test, to check it all comes together, particularly the clearing of 
    # the lock after performing
    before do
      Resque.push('foobaz_queue', {"args"=>['foo'], "class"=>"PerformableObjectWithLockName"})
    end
    
    it "should clear lock" do
      queue = 'foobaz_queue'
      Resque::Job.reserve('foobaz_queue').perform
      Resque.redis.keys.detect{ |k| k.match(/performer_lock/) }.must_be_nil
    end
    
    it "should remove item from queue" do
      Resque::Job.reserve('foobaz_queue').perform
      Resque.pop('foobaz_queue').must_be_nil
    end
  end
end
