{ lib, vars }:
let

  mkService = { subdomain, port, dashboard ? null, extraConfig }:
    lib.mkMerge [
      {
        services.nginx = {
          virtualHosts."${subdomain}.${vars.domainName}" = {
            forceSSL = true;
            enableACME = true;

            extraConfig =
              ''
                set $upstream_authelia http://localhost:8081/api/verify;

                location /authelia {
                  internal;
                  proxy_pass $upstream_authelia;

                  proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
                  proxy_set_header X-Original-Method $request_method;
                  proxy_set_header X-Forwarded-Method $request_method;
                  proxy_set_header X-Forwarded-Proto $scheme;
                  proxy_set_header X-Forwarded-Host $http_host;
                  proxy_set_header X-Forwarded-Uri $request_uri;
                  proxy_set_header X-Forwarded-For $remote_addr;
                  proxy_set_header Content-Length "";
                  proxy_set_header Connection "";

                  proxy_pass_request_body off;
                  proxy_next_upstream error timeout invalid_header http_500 http_502 http_503; # Timeout if the real server is dead
                  proxy_redirect http:// $scheme://;
                  proxy_http_version 1.1;
                  proxy_cache_bypass $cookie_session;
                  proxy_no_cache $cookie_session;
                  proxy_buffers 4 32k;
                  client_body_buffer_size 128k;

                  send_timeout 5m;
                  proxy_read_timeout 240;
                  proxy_send_timeout 240;
                  proxy_connect_timeout 240;
                }
              '';

            locations."/" = {
              proxyPass = "http://localhost:${toString port}";

              extraConfig =
                ''
                  auth_request /authelia;

                  set $target_url $scheme://$http_host$request_uri;

                  auth_request_set $user $upstream_http_remote_user;
                  auth_request_set $groups $upstream_http_remote_groups;
                  auth_request_set $name $upstream_http_remote_name;
                  auth_request_set $email $upstream_http_remote_email;

                  proxy_set_header Remote-User $user;
                  proxy_set_header Remote-Groups $groups;
                  proxy_set_header Remote-Name $name;
                  proxy_set_header Remote-Email $email;

                  error_page 401 =302 https://authelia.${vars.domainName}/?rd=$target_url;
                '';
            };
          };
        };
      }

      {
        modules.homer.services = lib.mkIf (builtins.isAttrs dashboard) {
          "${dashboard.category}"."${dashboard.name}" = {
            logo = dashboard.logo;
            url = "https://${subdomain}.${vars.domainName}";
          };
        };
      }

      extraConfig
    ];

in
{ inherit mkService; }
