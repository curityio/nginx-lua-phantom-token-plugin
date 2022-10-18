#!/usr/bin/perl

###########################################################
# Runs tests related to configuration and defaulting values
###########################################################

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

=== TEST 1: A REF token can be introspected for a phantom token

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

    proxy_pass http://localhost:1984/target;
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
