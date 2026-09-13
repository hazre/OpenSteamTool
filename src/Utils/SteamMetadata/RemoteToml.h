#pragma once
#include <string>

namespace RemoteToml {

    struct Request {
        std::string channel;    // "pattern" or "ipc"
        std::string component;  // "steamclient" or "steamui"
        std::string dllPath;
    };

    struct Result {
        bool        ok        = false;
        bool        fromCache = false;
        std::string body;
        std::string sha256;
        std::string lastUrl;   // final remote URL attempted ("" if none)
    };

    // Fetch remote TOML first, then fall back to the exact local cache entry.
    Result Fetch(const Request& request);

    // Browsable repo URL for channel/component derived from the configured
    // [remote] url_template (or the upstream default when unconfigured).
    // "" when the template host is not recognized.
    std::string UpstreamTreeUrl(const std::string& channel,
                                const std::string& component);

} // namespace RemoteToml
