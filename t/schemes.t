#!/usr/bin/perl

################################################################
# Runs tests focused on authorization schemes of Bearer and DPoP
################################################################

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";
use Test::Nginx::Socket 'no_plan';

SKIP: {
      our $token = &get_token_from_idsvr();
      if ($token) {
          run_tests();
      }
      else {
          fail("Could not get token from idsvr");
      }
}

sub get_token_from_idsvr {
    use LWP::UserAgent;
 
    my $ua = LWP::UserAgent->new();

    my $response = $ua->post("http://localhost:8443/oauth/v2/oauth-token", {
        "client_id" => "test-client",
        "client_secret" => "secret1",
        "grant_type" => "client_credentials",
        "scope" => "read"
    });
    my $content = $response->decoded_content();

    my ($result) = $content =~ /access_token":"([^"]+)/;

    return $result;
}

__DATA__

=== TEST_SCHEME_1: An opaque bearer token can be introspected for a phantom token
########################################################
# The happy case works as expected when you set a scheme
########################################################

--- http_config
lua_shared_dict phantom-token 10m;

--- config
location /t {

    access_by_lua_block {

        local config = {
            introspection_endpoint = 'http://127.0.0.1:8443/oauth/v2/oauth-introspect',
            client_id = 'introspection-client',
            client_secret = 'secret2',
            token_cache_seconds = 900,
            scheme = 'Bearer'
        }

        local phantomToken = require 'phantom-token'
        phantomToken.run(config)
    }

    proxy_pass http://127.0.0.1:1984/target;
}
location /target {
    add_header 'authorization' $http_authorization;
    return 200;
}

--- error_code: 200

--- request
GET /t

--- more_headers eval
"Authorization: bearer " . $main::token;

--- response_headers_like
authorization: Bearer ey.*

=== TEST_SCHEME_2: Sending an invalid bearer token that fails introspection results in an access denied error
#########################################################
# An unrecognised token is rejected when you set a scheme
#########################################################

--- http_config
lua_shared_dict phantom-token 10m;

--- config
location /t {

    access_by_lua_block {

        local config = {
            introspection_endpoint = 'http://127.0.0.1:8443/oauth/v2/oauth-introspect',
            client_id = 'introspection-client',
            client_secret = 'secret2',
            token_cache_seconds = 900,
            scheme = 'Bearer'
        }

        local phantomToken = require 'phantom-token'
        phantomToken.run(config)
    }
}

--- more_headers 
Authorization: bearer zort

--- request
GET /t

--- error_code: 401

--- response_headers
content-type: application/json

--- response_headers_like
WWW-Authenticate: ^Bearer

--- response_body_like chomp
{"code":"invalid_token","message":"Missing, invalid or expired access token"}

=== TEST_SCHEME_3: An opaque DPoP token can be introspected for a JWT
#############################################################
# The happy case works as expected when you set a DPoP scheme
#############################################################

--- http_config
lua_shared_dict phantom-token 10m;

--- config
location /t {

    access_by_lua_block {

        local config = {
            introspection_endpoint = 'http://127.0.0.1:8443/oauth/v2/oauth-introspect',
            client_id = 'introspection-client',
            client_secret = 'secret2',
            token_cache_seconds = 900,
            scheme = 'DPoP'
        }

        local phantomToken = require 'phantom-token'
        phantomToken.run(config)
    }

    proxy_pass http://127.0.0.1:1984/target;
}
location /target {
    add_header 'authorization' $http_authorization;
    return 200;
}

--- error_code: 200

--- request
GET /t

--- more_headers eval
"Authorization: dpop " . $main::token;

--- response_headers_like
authorization: DPoP ey.*

=== TEST_SCHEME_4: Sending an invalid DPoP token that fails introspection results in an access denied error
##############################################################
# An unrecognised token is rejected when you set a DPoP scheme
##############################################################

--- http_config
lua_shared_dict phantom-token 10m;

--- config
location /t {

    access_by_lua_block {

        local config = {
            introspection_endpoint = 'http://127.0.0.1:8443/oauth/v2/oauth-introspect',
            client_id = 'introspection-client',
            client_secret = 'secret2',
            token_cache_seconds = 900,
            scheme = 'DPoP'
        }

        local phantomToken = require 'phantom-token'
        phantomToken.run(config)
    }
}

--- more_headers 
Authorization: dpop zort

--- request
GET /t

--- error_code: 401

--- response_headers
content-type: application/json

--- response_headers_like
WWW-Authenticate: ^DPoP

--- response_body_like chomp
{"code":"invalid_token","message":"Missing, invalid or expired access token"}
