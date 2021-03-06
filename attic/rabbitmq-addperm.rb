#!/usr/bin/ruby
# coding: utf-8

$: << "./lib"
require 'bundler/setup'
require 'json'
require 'httpclient'

RQ_USER = "guest"
RQ_PASS = "guest"
RQAPI_URLBASE = "http://127.0.0.1:15672/api"

client = HTTPClient.new(:force_basic_auth => true)
rqapi_url = RQAPI_URLBASE + "/permissions/%2fuser01/user01"
client.set_auth(rqapi_url, RQ_USER, RQ_PASS)

ret = { :configure => ".*", :write => ".*", :read => ".*" }
resp = client.put(rqapi_url, ret.to_json, "Content-Type" => "application/json")
