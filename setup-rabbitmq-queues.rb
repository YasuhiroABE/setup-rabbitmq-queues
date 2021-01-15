#!/usr/bin/ruby
# coding: utf-8

def usage
  puts <<EOF
  usage: $ #{$0} <set|remove> file ...

  EXAMPLE - file format
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

$: << "./lib"
require 'bundler/setup'
require 'json'
require 'httpclient'

## possible operations as args
OPERATION_SETUP = "set"
OPERATION_DELETE = "remove"
OPERATIONS = [OPERATION_SETUP, OPERATION_DELETE]

# The RQConfig class
class RQConfig
  attr_reader :node, :appname, :password, :queues
  def initialize(filepath)
    open(filepath) { |data|
      json = JSON.load(data)
      @node = json["node"]
      @appname = json["appname"]
      @password = json["password"]
      @queues = json["queues"]
    }
  end
end

## Setup the RQAPI_URLBASE variable
if ENV.has_key?("RQAPI_URLBASE")
  RQAPI_URLBASE = ENV['RQAPI_URLBASE']
else
  RQAPI_URLBASE = "http://127.0.0.1:15672/api"
end
## define each specific URLs
RQAPI_USER_URL = RQAPI_URLBASE + "/users/"
RQAPI_VHOST_URL = RQAPI_URLBASE + "/vhosts/"
RQAPI_PERMISSION_URL = RQAPI_URLBASE + "/permissions/"
RQAPI_EXCHANGE_URL = RQAPI_URLBASE + "/exchanges/"
RQAPI_QUEUE_URL = RQAPI_URLBASE + "/queues/"
RQAPI_BINDING_URL = RQAPI_URLBASE + "/bindings/"

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

HTTP_CONTENT_TYPE = { "Content-Type" => "application/json" }
def request(operation, httpclient, url, req)
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
      ## delete QUEUE
      rqapi_url = RQAPI_QUEUE_URL + "%2f" + config.appname + "/" + queue + ".dl"
      request(:delete, client, rqapi_url, {})

      rqapi_url = RQAPI_QUEUE_URL + "%2f" + config.appname + "/" + queue
      request(:delete, client, rqapi_url, {})
    end
    ## delete EXCHANGES
    rqapi_url = RQAPI_EXCHANGE_URL + "%2f" + config.appname + "/" + config.appname + ".dlx"
    request(:delete, client, rqapi_url, {})
    
    rqapi_url = RQAPI_EXCHANGE_URL + "%2f" + config.appname + "/" + config.appname
    request(:delete, client, rqapi_url, {})
    
    ## delete VIRTUALHOST
    rqapi_url = RQAPI_VHOST_URL + "%2f" + config.appname
    request(:delete, client, rqapi_url, {})
    
    ## delete USER
    rqapi_url = RQAPI_USER_URL + config.appname
    request(:delete, client, rqapi_url, {})
  }
  exit 0
end

## parse files
ARGV.each { |f|
  ret = {}
  config = RQConfig.new(f)

  client = HTTPClient.new(:force_basic_auth => true)
  ## setup user
  rqapi_url = RQAPI_USER_URL + config.appname
  req = { :password => config.password, :tags => "administrator" }
  request(:put, client, rqapi_url, req)
  
  ## setup virtual host
  rqapi_url = RQAPI_VHOST_URL + "%2f" + config.appname
  request(:put, client, rqapi_url, {})

  ## setup permissions
  rqapi_url = RQAPI_PERMISSION_URL + "%2f" + config.appname + "/" + config.appname
  req = { :configure => ".*", :write => ".*", :read => ".*" }
  request(:put, client, rqapi_url, req)
  
  ## set exchange
  rqapi_url = RQAPI_EXCHANGE_URL + "%2f" + config.appname + "/" + config.appname
  req = {"type":"direct","auto_delete":false,"durable":true,"internal":false,"arguments":{}}
  request(:put, client, rqapi_url, req)
  
  ## set dead letter exchange
  rqapi_url = RQAPI_EXCHANGE_URL + "%2f" + config.appname + "/" + config.appname + ".dlx"
  req = {"type":"direct","auto_delete":false,"durable":true,"internal":false,"arguments":{}}
  request(:put, client, rqapi_url, req)

  for queue in config.queues
    ## set dead letter queue
    rqapi_url = RQAPI_QUEUE_URL + "%2f" + config.appname + "/" + queue + ".dl"
    req = {"auto_delete":false,"durable":true,"arguments":{"x-queue-type":"quorum"},"node":config.node}
    request(:put, client, rqapi_url, req)
    
    ## set queues
    rqapi_url = RQAPI_QUEUE_URL + "%2f" + config.appname + "/" + queue
    req = {"auto_delete":false,
           "durable":true,
           "arguments":{"x-dead-letter-exchange":"#{config.appname}.dlx",
                        "x-dead-letter-routing-key":"#{queue}.dl",
                        "x-queue-type": "quorum"},
           "node":config.node}
    request(:put, client, rqapi_url, req)
    
    ## setup binding on exchange
    rqapi_url = RQAPI_BINDING_URL + "%2f" + config.appname + "/e/" + config.appname + ".dlx" + "/q/" + queue + ".dl"
    ret = {
      "routing_key":"#{queue}.dl",
      "arguments":{}
    }
    request(:post, client, rqapi_url, req)

    rqapi_url = RQAPI_BINDING_URL + "%2f" + config.appname + "/e/" + config.appname + "/q/" + queue
    ret = {
      :routing_key => queue,
      :arguments => {}
    }
    request(:post, client, rqapi_url, req)
  end
}
