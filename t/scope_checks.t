#!/usr/bin/perl

#######################################################
# Runs tests related to enforcing scopes in the gateway
#######################################################

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


=== TEST SCOPE_1: Correct scope is accepted when configured
####################################################################
# The plugin correctly matches a single scope against the JWT scopes
####################################################################

--- http_config
lua_shared_dict phantom-token 10m;

--- config
location /t {

    rewrite_by_lua_block {

        local config = {
            introspection_endpoint = 'http://127.0.0.1:8443/oauth/v2/oauth-introspect',
            client_id = 'introspection-client',
            client_secret = 'secret2',
            token_cache_seconds = 900,
            scope = 'read'
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
"Authorization: bearer " . $main::token

--- response_headers_like
authorization: Bearer ey.*

=== TEST SCOPE_2: Correct scopes are accepted when configured
#####################################################################
# The plugin correctly matches multiple scopes against the JWT scopes
#####################################################################

--- http_config
lua_shared_dict phantom-token 10m;

--- config
location /t {

    rewrite_by_lua_block {

        local config = {
            introspection_endpoint = 'http://127.0.0.1:8443/oauth/v2/oauth-introspect',
            client_id = 'introspection-client',
            client_secret = 'secret2',
            token_cache_seconds = 900,
            scope = 'read write'
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
"Authorization: bearer " . $main::token

=== TEST SCOPE_3: Access token with invalid scopes is rejected
#####################################################################
# The plugin correctly detects missing scopes in the JWT access token
#####################################################################

--- http_config
lua_shared_dict phantom-token 10m;

--- config
location /t {

    rewrite_by_lua_block {

        local config = {
            introspection_endpoint = 'http://127.0.0.1:8443/oauth/v2/oauth-introspect',
            client_id = 'introspection-client',
            client_secret = 'secret2',
            token_cache_seconds = 900,
            scope = 'read execute'
        }

        local phantomToken = require 'phantom-token'
        phantomToken.run(config)
    }
}

--- error_code: 403

--- request
GET /t

--- more_headers eval
"Authorization: bearer " . $main::token

--- response_body_like chomp
{"code":"forbidden","message":"The token does not contain the required scope"}