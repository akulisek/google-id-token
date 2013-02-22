# encoding: utf-8
# Copyright 2012 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#  
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# @author Tim Bray, adapted from code by Bob Aman

$:.unshift("#{File.expand_path(File.dirname(__FILE__))}/../lib")
require 'google-id-token'
require 'fakeweb'

CERTS_URI = 'https://www.googleapis.com/oauth2/v1/certs'

describe GoogleIDToken::Validator do

  it 'should complain if unable to fetch Google tokens' do
    FakeWeb::register_uri(:get, CERTS_URI,
                          :status => ["404", "Not found"],
                          :body => 'Ouch!')
    t = GoogleIDToken::Validator.new
    t.check('whatever', 'whatever').should == nil
    t.problem.should =~ /Unable to retrieve.*keys/
  end

  it 'should successfully validate a good token against good certs' do
    FakeWeb::register_uri(:get, CERTS_URI,
                          :status => ["200", "Success"],
                          :body => @certs_body)
    jwt = @validator.check(@good_token, @token_aud, @token_cid)
    jwt.should_not == nil
    jwt['aud'].should == @token_aud
    jwt['cid'].should == @token_cid
    jwt['azp'].should == @token_cid
  end

  it 'should fail to validate a mangled token' do
    FakeWeb::register_uri(:get, CERTS_URI,
                          :status => ["200", "Success"],
                          :body => @certs_body)
    bad_token = @good_token.gsub('x', 'y')
    jwt = @validator.check(bad_token, @token_aud, @token_cid)
    jwt.should == nil
    @validator.problem.should =~ /not verified/
  end
  
  it 'should fail to validate a good token with wrong aud field' do
    FakeWeb::register_uri(:get, CERTS_URI,
                          :status => ["200", "Success"],
                          :body => @certs_body)
    jwt = @validator.check(@good_token, @token_aud + 'x', @token_cid)
    jwt.should == nil
    @validator.problem.should =~ /audience mismatch/
  end

  it 'should fail to validate a good token with wrong cid field' do
    FakeWeb::register_uri(:get, CERTS_URI,
                          :status => ["200", "Success"],
                          :body => @certs_body)
    jwt = @validator.check(@good_token, @token_aud, @token_cid + 'x')
    jwt.should == nil
    @validator.problem.should =~ /client-id mismatch/
  end

  it 'should validate a good token with the new azp instead of cid field' do
    FakeWeb::register_uri(:get, CERTS_URI,
                          :status => ["200", "Success"],
                          :body => @nf_token_certs_body)
    jwt = @validator.check(@new_fields_token, @nf_token_aud, @nf_token_azp)
    jwt.should_not == nil
    jwt['aud'].should == @nf_token_aud
    jwt['cid'].should == @nf_token_azp
    jwt['azp'].should == @nf_token_azp
  end

  # put 'before' after, so you can actually read the tests
  before do
    @good_token = 'eyJhbGciOiJSUzI1NiIsImtpZCI6IjI3ODRhNjU0ZTUxNzI4ODQ0Yzk5NDcyZjJhODBjYjJjYzcxNDg4MGEifQ.eyJpc3MiOiJhY2NvdW50cy5nb29nbGUuY29tIiwiZW1haWwiOiJ0aW1icmF5QGdtYWlsLmNvbSIsImNpZCI6IjQyNDg2MTM2NDEyMS1hcnI1NDhtcXIyOWp2OXBma2dzdXQ2MHVmYnJwZmc1Mi5hcHBzLmdvb2dsZXVzZXJjb250ZW50LmNvbSIsInZlcmlmaWVkX2VtYWlsIjoidHJ1ZSIsInRva2VuX2hhc2giOiJxWTktaE01aHIwQnNJUVNXN0Vzdl9nIiwiYXVkIjoic2VydmVyOjQyNDg2MTM2NDEyMS5hcHBzLmdvb2dsZXVzZXJjb250ZW50LmNvbSIsImlhdCI6MTM1MzExMjUwMCwiZXhwIjoxMzUzMTE2NDAwfQ.CdDz-88kXUeABTnPlzV5f2c9CjGAjHz1xtFip2UtpBaZX0Mj84v-evCPv9oBXMeBXsVsrW0vsvNlclYld9booUhGz3Kv5O45zNTeyH1psrxsUMTya6FSMAWjHVdj8RKwXTM32TJ5dJpY0DBWaumz9Y8BWSfGb5ShDrVIMkYdE0s'

    @token_aud = "server:424861364121.apps.googleusercontent.com"
    @token_cid = "424861364121-arr548mqr29jv9pfkgsut60ufbrpfg52.apps.googleusercontent.com"

    @certs_body = '{
 "2784a654e51728844c99472f2a80cb2cc714880a": "-----BEGIN CERTIFICATE-----\nMIICITCCAYqgAwIBAgIIROG99i5sVikwDQYJKoZIhvcNAQEFBQAwNjE0MDIGA1UE\nAxMrZmVkZXJhdGVkLXNpZ25vbi5zeXN0ZW0uZ3NlcnZpY2VhY2NvdW50LmNvbTAe\nFw0xMjExMTYwNzEzMzRaFw0xMjExMTcyMDEzMzRaMDYxNDAyBgNVBAMTK2ZlZGVy\nYXRlZC1zaWdub24uc3lzdGVtLmdzZXJ2aWNlYWNjb3VudC5jb20wgZ8wDQYJKoZI\nhvcNAQEBBQADgY0AMIGJAoGBAKEWdkX1EyoQEcO4ercNqCeltb1f1+NlmN3G6nSl\nq3rL8hqxU1r3OrtWBMErr+P40lx36BRHrH8PK/A70UaRNyWMPnfGnkfCPc/YMS4S\nUlz/poO1PHjSMiF+ThGaVz3GhDIEZ7q4oOIQmgjh7drwUxjxgD8TXgUs9ZR/MRgq\nXzi9AgMBAAGjODA2MAwGA1UdEwEB/wQCMAAwDgYDVR0PAQH/BAQDAgeAMBYGA1Ud\nJQEB/wQMMAoGCCsGAQUFBwMCMA0GCSqGSIb3DQEBBQUAA4GBACaaoUNMPSfsGACw\nd05FploHeaRKRmR8F7s+mBpv+NzNV1mTDognAawTqYSHp4Mcs1GbqibsSNHGFEmq\ncWoDfwGXEeg7/FXmuWnFN6B2GXsRED/JSA2C6oNqmSTIs7Km/7KB3e0xbnXfucPe\nFx7N5BCvD5tTy1NAgJqeNii7ovM4\n-----END CERTIFICATE-----\n",
 "370d478a1ab578b7e9c1d1ed32922495e60e3b45": "-----BEGIN CERTIFICATE-----\nMIICITCCAYqgAwIBAgIIUNxFMFAZ5EswDQYJKoZIhvcNAQEFBQAwNjE0MDIGA1UE\nAxMrZmVkZXJhdGVkLXNpZ25vbi5zeXN0ZW0uZ3NlcnZpY2VhY2NvdW50LmNvbTAe\nFw0xMjExMTcwNjU4MzRaFw0xMjExMTgxOTU4MzRaMDYxNDAyBgNVBAMTK2ZlZGVy\nYXRlZC1zaWdub24uc3lzdGVtLmdzZXJ2aWNlYWNjb3VudC5jb20wgZ8wDQYJKoZI\nhvcNAQEBBQADgY0AMIGJAoGBAK1RWqOkhx6nbU7dyYprTJmDdQHkjlBqDEzYZleI\nYdX/dFwPAwmCNQqMPxQQGLFLSQSVQH55VNgIZphRoh9A+m40EUb+kNglWVgAnKv9\nDCtXKHByavWRKOE0394HKLYki9HIb9BdQDJzhiuBLa2wAvsDIA+Jc9jZlK4mF0hb\nKpGDAgMBAAGjODA2MAwGA1UdEwEB/wQCMAAwDgYDVR0PAQH/BAQDAgeAMBYGA1Ud\nJQEB/wQMMAoGCCsGAQUFBwMCMA0GCSqGSIb3DQEBBQUAA4GBADw8Q7Zenn4qtKx5\niWFs5hBqEiMrKbWOAFsgx9GqsSNEQZOx7JQOz9YAxMVqEJbfxe7+T6jknA5ww2v4\n73DiNmHfwYwHIlB75BTh69fI4+Y3rGCMLEy2A9tvX/e0VkRy03/CBAX+P0vxT1rX\nCiJwlLpKXgOOJ5BLxrU8SrVoCzCg\n-----END CERTIFICATE-----\n"
}'

    @new_fields_token = 'eyJhbGciOiJSUzI1NiIsImtpZCI6IjU1YzE1ODI1ZWEyOGI5ZTVkYTE1YzdhYTg4N2UxNGViMzU1YjI4YWQifQ.eyJpc3MiOiJhY2NvdW50cy5nb29nbGUuY29tIiwiYXRfaGFzaCI6IkdORUFEQmg4LUE0NUhPTGNFOXZXOWciLCJhdWQiOiI0MDc0MDg3MTgxOTIuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJlbWFpbF92ZXJpZmllZCI6InRydWUiLCJzdWIiOiIxMDc2MDY3MDM1NTgxNjE1MDc5NDYiLCJhenAiOiI0MDc0MDg3MTgxOTIuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJlbWFpbCI6InRpbWJyYXlAZ21haWwuY29tIiwiaWF0IjoxMzYxNTcyODA0LCJleHAiOjEzNjE1NzY3MDR9.GXOKxOz8ERDNrAGLvSDBJwZpATOPgsAN8jf0mp12SBse4eBajODY1LfmrmEu7hm27UJc6aKKPvgyyic_h4bOnxwZsa2fT9XQ4U2YepPfoN3IC7a4gFIGKsz7sOF9FeZBeIuille_BuoFVOYZlQ1CSGIeVG5GGneuUEZA1f6TL9Y'
    @nf_token_aud = "407408718192.apps.googleusercontent.com"
    @nf_token_azp = "407408718192.apps.googleusercontent.com"

    @nf_token_certs_body = '{
 "3f450955c07de2eaa4059856c38afaf591f1e1a7": "-----BEGIN CERTIFICATE-----\nMIICITCCAYqgAwIBAgIIV6xthUjA80owDQYJKoZIhvcNAQEFBQAwNjE0MDIGA1UE\nAxMrZmVkZXJhdGVkLXNpZ25vbi5zeXN0ZW0uZ3NlcnZpY2VhY2NvdW50LmNvbTAe\nFw0xMzAyMjEwNjQzMzRaFw0xMzAyMjIxOTQzMzRaMDYxNDAyBgNVBAMTK2ZlZGVy\nYXRlZC1zaWdub24uc3lzdGVtLmdzZXJ2aWNlYWNjb3VudC5jb20wgZ8wDQYJKoZI\nhvcNAQEBBQADgY0AMIGJAoGBAMT9CDAm4D9e6isJ3VrctpwNpyQlxucNic8FNEaT\nGd4OFkj2pG60Op6od2bzIi5dGY60/RqyupVThqNhvfqlNBqq4E12DbA8s9JUEolD\nffvM02NOu1f/Y/MZQEr/ETlylDZ+Ju14Tq4sZoRAq6CPgP88ZhYr41v41e4H1QKE\nmWyLAgMBAAGjODA2MAwGA1UdEwEB/wQCMAAwDgYDVR0PAQH/BAQDAgeAMBYGA1Ud\nJQEB/wQMMAoGCCsGAQUFBwMCMA0GCSqGSIb3DQEBBQUAA4GBAIi8FESCpkqhFv6r\nWcjB8cWRaJ2zluSnAK44+OajexZplwmYw+ryAv4eg7jOc6TgD+7NvLHcGsTDcD+R\nMzfQIh5InDpMPyfU0urKEPpOK1gQwpVgm5nhZFisOAGIxVKzZqE4BCEFrA45gFZi\naVgtJh43SdG0F3NRQCFo6WLMc4Sl\n-----END CERTIFICATE-----\n",
 "55c15825ea28b9e5da15c7aa887e14eb355b28ad": "-----BEGIN CERTIFICATE-----\nMIICITCCAYqgAwIBAgIIJqqvU8CBfqIwDQYJKoZIhvcNAQEFBQAwNjE0MDIGA1UE\nAxMrZmVkZXJhdGVkLXNpZ25vbi5zeXN0ZW0uZ3NlcnZpY2VhY2NvdW50LmNvbTAe\nFw0xMzAyMjIwNjI4MzRaFw0xMzAyMjMxOTI4MzRaMDYxNDAyBgNVBAMTK2ZlZGVy\nYXRlZC1zaWdub24uc3lzdGVtLmdzZXJ2aWNlYWNjb3VudC5jb20wgZ8wDQYJKoZI\nhvcNAQEBBQADgY0AMIGJAoGBAK7o+lOca1/3R6YXX5FSVuZeWockCH450WmT7RKM\n8y1UM7zTxW5gbxDWA607UqRPQJF+JBHHqvNj3sjxloJmeEmAYhcNRqshr81Xi6fG\nVqqCq/MxBABOqLPwGjx3dNo9Q6DOsM2y1jvwjnHEs2cxoQ0VE9g1wEes7tgzzZI/\nlWcnAgMBAAGjODA2MAwGA1UdEwEB/wQCMAAwDgYDVR0PAQH/BAQDAgeAMBYGA1Ud\nJQEB/wQMMAoGCCsGAQUFBwMCMA0GCSqGSIb3DQEBBQUAA4GBAB8bKSiG3Va27WLH\nvvFbiBaQMgCeNqpTOBCAZWMzrBKH4ixJnBFHKXHdJoVLCKqMp/chfEKxZ3fgZdkC\nFuFpYAnKxd7dPouLkd+7eyZDd/ORfmqVhfR7pvKC9FcwuNBvwj8iJzNHXxsrvZY+\nDuL8ZvGwdj7HTsIUASsb6/WIbh5m\n-----END CERTIFICATE-----\n"
}'

    @validator = GoogleIDToken::Validator.new
  end
end
