#!/usr/bin/ruby
# coding: utf-8

def usage
  puts <<EOF
  usage: $ #{$0} <setup|delete> file ...

  ENVIRONMENT
  It uses the following environment variables:

  * RQAPI_URLBASE (default: http://127.0.0.1:15672/api)
  * RQAPI_USER (default: guest)
  * RQAPI_PASS (default: guest)

  EXAMPLE of FILE FORMAT
  The user can configure the arbitrary number of files as arguments.
  Following is an example of the file.
  ---------------------------------
  {
    "appname":"app01",
    "password":"secret",
    "node":"rabbit@2478a000dddd",
    "queues":["queue01", "queue02"]
  }
  ---------------------------------
EOF
end

require 'bundler/setup'
Bundler.require

## Setup the RQAPI_URLBASE variable
if ENV.has_key?("RQAPI_URLBASE")
  RQAPI_URLBASE = ENV['RQAPI_URLBASE']
else
  RQAPI_URLBASE = "http://127.0.0.1:15672/api"
end
if ENV.has_key?("RQAPI_USER")
  RQAPI_USER = ENV['RQAPI_USER']
else
  RQAPI_USER = "guest"
end
if ENV.has_key?("RQAPI_PASS")
  RQAPI_PASS = ENV['RQAPI_PASS']
else
  RQAPI_PASS = "guest"
end

## possible operations as args
OPERATION_SETUP = "setup"
OPERATION_DELETE = "delete"
OPERATIONS = [OPERATION_SETUP, OPERATION_DELETE]

# The RQConfig class
class RQConfig
  attr_reader :node, :appname, :password, :queues, :dlexname, :dlqname, :opts
  
  def initialize(filepath)
    File.open(filepath) { |f|
      json = JSON.load(f)
      @node = json["node"] ## String
      @appname = json["appname"] ## String
      @password = json["password"] ## String
      @queues = json["queues"] ## Array
      @dlexname = @appname + ".dlx" ## Dead Letter Exchange Name
      @opts = [:user, :vhost, :perm, :dlexchange, :exchange, :dlqueue, :queue, :dlbinding, :binding]
    }
  end
  
  # Returns the dead letter queue name
  def dlqname(q)
    q + ".dl" 
  end

  def requrl(type, queue = nil)
    case type
    when :user
      return RQAPI_URLBASE + "/users/" + @appname
    when :vhost
      return RQAPI_URLBASE + "/vhosts/" + "%2f" + @appname
    when :perm
      return RQAPI_URLBASE + "/permissions/" + "%2f" + @appname + "/" + @appname
    when :exchange
      return RQAPI_URLBASE + "/exchanges/" + "%2f" + @appname + "/" + @appname
    when :dlexchange
      return RQAPI_URLBASE + "/exchanges/" + "%2f" + @appname + "/" + @dlexname
    when :dlqueue
      return RQAPI_URLBASE + "/queues/" + "%2f" + @appname + "/" + dlqname(queue)
    when :queue
      return RQAPI_URLBASE + "/queues/" + "%2f" + @appname + "/" + queue
    when :dlbinding
      return RQAPI_URLBASE + "/bindings/" + "%2f" + @appname + "/e/" + @dlexname + "/q/" + dlqname(queue)
    when :binding
      return RQAPI_URLBASE + "/bindings/" + "%2f" + @appname + "/e/" + @appname + "/q/" + queue
    end
  end
  
  # Returns the json object of the request body.
  # type - one of @opts (:user,:vhost,:perm,:dlexchange,:exchange,:dlqueue,:queue,:dlbinding,:binding)
  def reqopt(type, queue = nil)
    raise unless @opts.include?(type)
    case type
    when :user
      return { :password => @password, :tags => "administrator" }
    when :vhost
      return {}
    when :perm
      return { :configure => ".*", :write => ".*", :read => ".*" }
    when :exchange, :dlexchange
      return {"type":"direct","auto_delete":false,"durable":true,"internal":false,"arguments":{}}
    when :dlqueue
      return {"auto_delete":false,"durable":true,"arguments":{"x-queue-type":"quorum"},"node":@node}
    when :queue
      return {"auto_delete":false,
              "durable":true,
              "arguments":{"x-dead-letter-exchange": @dlexname,
                           "x-dead-letter-routing-key": dlqname(queue),
                           "x-queue-type": "quorum"},
              "node":@node}
    when :dlbinding
      return {
        :routing_key => dlqname(queue),
        :arguments => {}
      }
    when :binding
      return {
        :routing_key => queue,
        :arguments => {}
      }
    end
  end
end

HTTP_CONTENT_TYPE = { "Content-Type" => "application/json" }
def request(operation, httpclient, url, req)
  o = { :request => operation, :url => url }.to_json
  httpclient.set_auth(url, RQAPI_USER, RQAPI_PASS)
  ret = httpclient.delete(url, req.to_json, HTTP_CONTENT_TYPE) if operation == :delete
  ret = httpclient.post(url, req.to_json, HTTP_CONTENT_TYPE) if operation == :post
  ret = httpclient.put(url, req.to_json, HTTP_CONTENT_TYPE) if operation == :put
end

## check operation
operation = nil
if ARGV.length > 0 and OPERATIONS.include?(ARGV[0])
  operation = ARGV.shift
end

unless operation
  usage()
  exit 1
end

if operation == OPERATION_DELETE
  ARGV.each { |f|
    config = RQConfig.new(f)
    client = HTTPClient.new(:force_basic_auth => true)
    for queue in config.queues
      request(:delete, client, config.requrl(:dlqueue, queue), {})
      request(:delete, client, config.requrl(:queue, queue), {})
    end
    request(:delete, client, config.requrl(:dlexchange), {})
    request(:delete, client, config.requrl(:exchange), {})
    request(:delete, client, config.requrl(:vhost), {})
    request(:delete, client, config.requrl(:user), {})
  }
  exit 0
end

## if operation == OPERATION_SETUP ##
ARGV.each { |f|
  config = RQConfig.new(f)
  client = HTTPClient.new(:force_basic_auth => true)

  request(:put, client, config.requrl(:user), config.reqopt(:user))
  request(:put, client, config.requrl(:vhost), config.reqopt(:vhost))
  request(:put, client, config.requrl(:perm), config.reqopt(:perm))
  request(:put, client, config.requrl(:exchange), config.reqopt(:exchange))
  request(:put, client, config.requrl(:dlexchange), config.reqopt(:exchange))
  
  for queue in config.queues
    request(:put, client, config.requrl(:dlqueue, queue), config.reqopt(:dlqueue, queue))
    request(:put, client, config.requrl(:queue, queue), config.reqopt(:queue, queue))
    request(:post, client, config.requrl(:dlbinding, queue), config.reqopt(:dlbinding, queue))
    request(:post, client, config.requrl(:binding, queue), config.reqopt(:binding, queue))
  end
}
