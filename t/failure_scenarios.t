#!/usr/bin/perl

#############################################################################
# Simulates failures and checks that the correct error responses are received
#############################################################################

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
        "scope" => "read write"
    });
    my $content = $response->decoded_content();

    my ($result) = $content =~ /access_token":"([^"]+)/;

    return $result;
}

__DATA__


=== TEST FAILURE_1: Curity Identity Server not contactable returns 502
#######################################################################
# Connectivity error returns a 500 to the client with useful error data
#######################################################################

--- http_config
lua_shared_dict phantom-token 10m;

--- config
location /t {

    rewrite_by_lua_block {

        local config = {
            introspection_endpoint = 'http://127.0.0.1:8447/oauth/v2/oauth-introspect',
            client_id = 'introspection-client',
            client_secret = 'secret2',
            token_cache_seconds = 900
        }

        local phantomToken = require 'phantom-token'
        phantomToken.run(config)
    }
}

--- error_code: 500

--- request
GET /t

--- more_headers eval
"Authorization: bearer " . $main::token

--- response_body_like chomp
{"code":"server_error","message":"Problem encountered authorizing the HTTP request"}

=== TEST FAILURE_2: Misconfigured introspection client returns 401
########################################################################
# Configuration error returns a 401 to the client with useful error data
########################################################################

--- http_config
lua_shared_dict phantom-token 10m;

--- config
location /t {

    rewrite_by_lua_block {

        local config = {
            introspection_endpoint = 'http://127.0.0.1:8443/oauth/v2/oauth-introspect',
            client_id = 'introspection-client',
            client_secret = 'secret_invalid',
            token_cache_seconds = 900
        }

        local phantomToken = require 'phantom-token'
        phantomToken.run(config)
    }
}

--- error_code: 401

--- request
GET /t

--- more_headers eval
"Authorization: bearer " . $main::token

--- response_body_like chomp
{"code":"unauthorized","message":"Missing, invalid or expired access token"}