#!/usr/bin/perl

##############################################################################
# Runs tests focused on detecting invalid configuration or defaulting settings
##############################################################################

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

=== TEST_CONFIG_1: Missing required properties return a 500 error
###################################################################
# When no introspection endpoint is configured there is a 500 error
###################################################################

--- http_config
lua_shared_dict phantom-token 10m;

--- config
location /t {

    rewrite_by_lua_block {

        local config = {
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
"Authorization: bearer " . $main::token;

--- error_log
The phantom token configuration is invalid and must be corrected

--- response_body_like chomp
{"code":"server_error","message":"Problem encountered processing the request"}

=== TEST_CONFIG_2: Missing required properties return a 500 error
###################################################################
# When no introspection endpoint is configured there is a 500 error
###################################################################

--- config
location /t {

    rewrite_by_lua_block {

        local config = {
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
"Authorization: bearer " . $main::token;

--- error_log
The phantom token configuration is invalid and must be corrected

--- response_body_like chomp
{"code":"server_error","message":"Problem encountered processing the request"}

=== TEST CONFIG_2: A deployment with missing data does not crash NGINX
#######################################################################################################
# Verify that empty configuration is handled in a controlled manner rather than causing server problems
#######################################################################################################

--- config
location /t {

    rewrite_by_lua_block {

        local config = {
        }

        local phantomToken = require 'phantom-token'
        phantomToken.run(config)
    }
}

--- error_code: 500

--- request
GET /t

--- more_headers eval
"Authorization: bearer " . $main::token;

--- error_log
The phantom token configuration is invalid and must be corrected

--- response_body_like chomp
{"code":"server_error","message":"Problem encountered processing the request"}

=== TEST CONFIG_3: A deployment with null data does not crash NGINX
#######################################################################################################
# Verify that null configuration is handled in a controlled manner rather than causing server problems
#######################################################################################################

--- config
location /t {

    rewrite_by_lua_block {

        local phantomToken = require 'phantom-token'
        phantomToken.run()
    }
}

--- error_code: 500

--- request
GET /t

--- more_headers eval
"Authorization: bearer " . $main::token;

--- error_log
The phantom token configuration is invalid and must be corrected

--- response_body_like chomp
{"code":"server_error","message":"Problem encountered processing the request"}

=== TEST CONFIG_4: A deployment with a misspelt field does not crash NGINX
#####################################################################################################
# Verify that bad configuration is handled in a controlled manner rather than causing server problems
#####################################################################################################

--- config
location /t {

    rewrite_by_lua_block {

        local config = {
            introspectionn_endpoint = 'http://127.0.0.1:8443/oauth/v2/oauth-introspect',
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
"Authorization: bearer " . $main::token;

--- error_log
The phantom token configuration is invalid and must be corrected

--- response_body_like chomp
{"code":"server_error","message":"Problem encountered processing the request"}

=== TEST_CONFIG_5: A deployment with all optional fields are omitted successfully introspects tokens
#######################################################################
# The happy case works as expected when all optional fields are omitted
#######################################################################

--- http_config
lua_shared_dict phantom-token 10m;

--- config
location /t {

    rewrite_by_lua_block {

        local config = {
            introspection_endpoint = 'http://127.0.0.1:8443/oauth/v2/oauth-introspect',
            client_id = 'introspection-client',
            client_secret = 'secret2'
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