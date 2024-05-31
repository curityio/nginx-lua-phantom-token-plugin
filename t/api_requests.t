#!/usr/bin/perl

###################################################################################################
# Runs tests focused on sending an access token and receiving the expected success or error results
###################################################################################################

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

=== TEST_API_REQUEST_1: An opaque token can be introspected for a phantom token
##################################
# The happy case works as expected
##################################

--- http_config
lua_shared_dict phantom-token 10m;

--- config
location /t {

    rewrite_by_lua_block {

        local config = {
            introspection_endpoint = 'http://127.0.0.1:8443/oauth/v2/oauth-introspect',
            client_id = 'introspection-client',
            client_secret = 'secret2',
            token_cache_seconds = 900
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

=== TEST_API_REQUEST_2: Sending an invalid token that fails introspection results in an access denied error
###########################################################################
# An unrecognised token is rejected when the Authorization Server is called
###########################################################################

--- http_config
lua_shared_dict phantom-token 10m;

--- config
location /t {

    rewrite_by_lua_block {

        local config = {
            introspection_endpoint = 'http://127.0.0.1:8443/oauth/v2/oauth-introspect',
            client_id = 'introspection-client',
            client_secret = 'secret2',
            token_cache_seconds = 900
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
WWW-Authenticate: Bearer

--- response_body_like chomp
{"code":"unauthorized","message":"Missing, invalid or expired access token"}

=== TEST_API_REQUEST_3: Sending no authorization header results in an access denied error
#################################################
# A missing token is rejected by the plugin logic
#################################################

--- http_config
lua_shared_dict phantom-token 10m;

--- config
location /t {

    rewrite_by_lua_block {

        local config = {
            introspection_endpoint = 'http://127.0.0.1:8443/oauth/v2/oauth-introspect',
            client_id = 'introspection-client',
            client_secret = 'secret2',
            token_cache_seconds = 900
        }

        local phantomToken = require 'phantom-token'
        phantomToken.run(config)
    }
}

--- request
GET /t

--- error_code: 401

--- response_headers
content-type: application/json
WWW-Authenticate: Bearer

--- response_body_like chomp
{"code":"unauthorized","message":"Missing, invalid or expired access token"}

=== TEST_API_REQUEST_4: The wrong authorization scheme results in an access denied error
##############################################################
# A token supplied incorrectly is not read by the plugin logic
##############################################################

--- http_config
lua_shared_dict phantom-token 10m;

--- config
location /t {

    rewrite_by_lua_block {

        local config = {
            introspection_endpoint = 'http://127.0.0.1:8443/oauth/v2/oauth-introspect',
            client_id = 'introspection-client',
            client_secret = 'secret2',
            token_cache_seconds = 900
        }

        local phantomToken = require 'phantom-token'
        phantomToken.run(config)
    }
}

--- more_headers eval
"Authorization: basic " . $main::token;

--- request
GET /t

--- error_code: 401

--- response_headers
content-type: application/json
WWW-Authenticate: Bearer

--- response_body_like chomp
{"code":"unauthorized","message":"Missing, invalid or expired access token"}

=== TEST_API_REQUEST_5: A valid token with trash after results in an access denied error
######################################################################################
# A valid token appended with other characters is rejected by the Authorization Server
######################################################################################

--- http_config
lua_shared_dict phantom-token 10m;

--- config
location /t {

    rewrite_by_lua_block {

        local config = {
            introspection_endpoint = 'http://127.0.0.1:8443/oauth/v2/oauth-introspect',
            client_id = 'introspection-client',
            client_secret = 'secret2',
            token_cache_seconds = 900
        }

        local phantomToken = require 'phantom-token'
        phantomToken.run(config)
    }
}

--- more_headers eval
"Authorization: bearer " . $main::token . "z";

--- request
GET /t

--- error_code: 401

--- response_headers
content-type: application/json
WWW-Authenticate: Bearer

--- response_body_like chomp
{"code":"unauthorized","message":"Missing, invalid or expired access token"}

=== TEST_API_REQUEST_6: The bearer HTTP method can be in upper case
#####################################################
# The plugin logic correctly handles case differences
#####################################################

--- http_config
lua_shared_dict phantom-token 10m;

--- config
location /t {

    rewrite_by_lua_block {

        local config = {
            introspection_endpoint = 'http://127.0.0.1:8443/oauth/v2/oauth-introspect',
            client_id = 'introspection-client',
            client_secret = 'secret2',
            token_cache_seconds = 900
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
"Authorization: BEARER " . $main::token;

--- response_headers_like
authorization: Bearer ey.*

=== TEST_API_REQUEST_7: The bearer HTTP method can be in mixed case
#####################################################
# The plugin logic correctly handles case differences
#####################################################

--- http_config
lua_shared_dict phantom-token 10m;

--- config
location /t {

    rewrite_by_lua_block {

        local config = {
            introspection_endpoint = 'http://127.0.0.1:8443/oauth/v2/oauth-introspect',
            client_id = 'introspection-client',
            client_secret = 'secret2',
            token_cache_seconds = 900
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
"Authorization: bEaReR " . $main::token;

--- response_headers_like
authorization: Bearer ey.*

=== TEST_API_REQUEST_8: The bearer HTTP method can have > 1 space before it
################################################
# The plugin logic correctly handles white space
################################################

--- http_config
lua_shared_dict phantom-token 10m;

--- config
location /t {

    rewrite_by_lua_block {

        local config = {
            introspection_endpoint = 'http://127.0.0.1:8443/oauth/v2/oauth-introspect',
            client_id = 'introspection-client',
            client_secret = 'secret2',
            token_cache_seconds = 900
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
"Authorization: bearer               " . $main::token

--- response_headers_like
authorization: Bearer ey.*
