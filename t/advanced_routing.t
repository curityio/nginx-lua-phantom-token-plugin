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

=== TEST_ADVANCED_ROUTING_1: The plugin can be bypassed for special token patterns
##########################################################################################################
# The plugin can be bypassed when there is special JWT configuration and the access token is already a JWT
##########################################################################################################

--- http_config
lua_shared_dict phantom-token 10m;
map $http_authorization $loc {
    ~^[Bb]earer\s*[A-Za-z0-9-_]*\.[A-Za-z0-9-_]*\.[A-Za-z0-9-_]* loc_bypass;
    default                                                      loc_phantom_token;
}

--- config
location /t {
    try_files $uri @$loc;
}
location @loc_bypass {
    add_header 'x-custom' 'bypass';
    return 200;
}
location @loc_phantom_token {
    
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

    add_header 'x-custom' 'phantom-token';
    return 200;
}

--- error_code: 200

--- request
GET /t

--- more_headers eval
"Authorization: bearer eyJraWQiOiItMjAyMDIxMjM3MyIsIng1dCI6IktwdlhqdEJQeWx3RHNENWtWLTN1bkVzQXozRSIsImFsZyI6IlJTMjU2In0.eyJqdGkiOiI2Y2U0ZGE1Mi1hMTE3LTQ3MGQtYWQ5Yi0wNmVjZTcyZDA5ZGIiLCJkZWxlZ2F0aW9uSWQiOiJlMGMwYTY5MS0zZmJmLTRmN2QtYWU3Mi0zYzk2NTU3ZDI0YTAiLCJleHAiOjE2NjYwOTM0MDAsIm5iZiI6MTY2NjA5MzEwMCwic2NvcGUiOiJyZWFkIiwiaXNzIjoiaHR0cDovL2N1cml0eXNlcnZlcjo4NDQzL29hdXRoL3YyL29hdXRoLWFub255bW91cyIsInN1YiI6InRlc3QtY2xpZW50IiwiYXVkIjoidGVzdC1jbGllbnQiLCJpYXQiOjE2NjYwOTMxMDAsInB1cnBvc2UiOiJhY2Nlc3NfdG9rZW4ifQ.Iaug4CDO3T9xirPU0pmq1YVdf9CR_6iCtxDpW7BRMCFW9jO4HCdsAj9kE-Ncbk26b5_l4QdD5g0nd36iXNoPIaHPO6TYb9T-PBcuSqc7WkgK_RT-BNeNmE8RRWU47dd8JFmMLgmgnWMYeEhi8kyKFScJ4hj6-H-KqDwjszWSPH_YTYPHp69C8mu_qNWLfaP8KBPizdYO8_6vxfOkDMDEbK6KbfaLAuWjfh9MzAD7j6POQz2NXy8F3KT79X49_nIjkjjE5Nq7vzTS910XlSMRvG0kQ0-LhEYH__GqxDMC4musv6th5s929dc7FyA4zRrR8njomwk166ItmO2Y_sEZeA"

--- response_headers eval
"x-custom: bypass"

=== TEST_ADVANCED_ROUTING_2: The plugin is run when special token patterns do not result in a match
##################################################################################################################
# The plugin falls back to introspection when there is special JWT configuration and the access token is not a JWT
##################################################################################################################

--- http_config
lua_shared_dict phantom-token 10m;
map $http_authorization $loc {
    ~^[Bb]earer\s*[A-Za-z0-9-_]*\.[A-Za-z0-9-_]*\.[A-Za-z0-9-_]* loc_bypass;
    default                                                      loc_phantom_token;
}

--- config
location /t {
    try_files $uri @$loc;
}
location @loc_bypass {
    add_header 'x-custom' 'bypass';
    return 200;
}
location @loc_phantom_token {
    
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

    add_header 'x-custom' 'phantom-token';
    return 200;
}

--- error_code: 200

--- request
GET /t

--- more_headers eval
"Authorization: bearer " . $main::token;

--- response_headers eval
"x-custom: phantom-token"
