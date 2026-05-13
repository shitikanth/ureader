#include "StateStore.h"
#include <filesystem>
#include <fstream>
#include <cstdlib>

namespace fs = std::filesystem;

static fs::path dataDir() {
    const char* home = std::getenv("HOME");
    if (!home) return fs::temp_directory_path() / "ureader";
#if defined(__APPLE__)
    fs::path dir = fs::path(home) / "Library/Application Support/ureader";
#elif defined(__linux__)
    const char* xdg = std::getenv("XDG_DATA_HOME");
    fs::path dir = xdg ? fs::path(xdg) / "ureader"
                       : fs::path(home) / ".local/share/ureader";
#else
    fs::path dir = fs::path(home) / ".ureader";
#endif
    fs::create_directories(dir);
    return dir;
}

StateStore& StateStore::shared() {
    static StateStore instance;
    return instance;
}

StateStore::StateStore() {
    path_ = (dataDir() / "state.json").string();
    load();
}

int StateStore::positionForUID(const std::string& uid) const {
    auto it = positions_.find(uid);
    return it != positions_.end() ? it->second : 0;
}

void StateStore::setPosition(int spineIndex, const std::string& uid) {
    positions_[uid] = spineIndex;
    save();
}

void StateStore::save() const {
    std::ofstream f(path_);
    if (!f) return;
    f << "{\"positions\":{";
    bool first = true;
    for (auto& [uid, idx] : positions_) {
        if (!first) f << ",";
        std::string escaped;
        for (char c : uid) {
            if (c == '"' || c == '\\') escaped += '\\';
            escaped += c;
        }
        f << '"' << escaped << "\":" << idx;
        first = false;
    }
    f << "}}";
}

void StateStore::load() {
    std::ifstream f(path_);
    if (!f) return;
    std::string content((std::istreambuf_iterator<char>(f)),
                         std::istreambuf_iterator<char>());

    auto pos = content.find("\"positions\"");
    if (pos == std::string::npos) return;
    auto open = content.find('{', pos + 11);
    if (open == std::string::npos) return;
    auto close = content.find('}', open + 1);
    if (close == std::string::npos) return;

    std::string body = content.substr(open + 1, close - open - 1);
    size_t i = 0;
    while (i < body.size()) {
        auto qs = body.find('"', i);
        if (qs == std::string::npos) break;
        auto qe = body.find('"', qs + 1);
        if (qe == std::string::npos) break;
        std::string key = body.substr(qs + 1, qe - qs - 1);

        auto colon = body.find(':', qe + 1);
        if (colon == std::string::npos) break;
        size_t ns = colon + 1;
        while (ns < body.size() && std::isspace((unsigned char)body[ns])) ns++;
        size_t ne = ns;
        while (ne < body.size() && std::isdigit((unsigned char)body[ne])) ne++;
        if (ne > ns)
            positions_[key] = std::stoi(body.substr(ns, ne - ns));
        i = ne + 1;
    }
}
