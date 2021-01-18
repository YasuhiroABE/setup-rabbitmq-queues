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
for url in ["/permissions/%2fuser01/user01", "/users/user01", "/vhosts/%2fuser01"]
  rqapi_url = RQAPI_URLBASE + url
  client.set_auth(rqapi_url, RQ_USER, RQ_PASS)
  resp = client.delete(rqapi_url, nil, "Content-Type" => "application/json")
end
