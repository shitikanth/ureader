#pragma once
#include <string>
#include <vector>
#include <cstdint>

struct SpineItem {
    std::string id;
    std::string path;       // path relative to opfDir (e.g., "chapter1.xhtml")
    std::string mediaType;
};

struct TocEntry {
    std::string title;
    int spineIndex;
    int depth;              // 0 = top-level
};

struct EpubMetadata {
    std::string title;
    std::string author;
    std::string uid;        // dc:identifier value
};

class EpubBook {
public:
    ~EpubBook();

    EpubMetadata metadata;
    std::vector<SpineItem> spine;
    std::vector<TocEntry> toc;
    std::string opfDir;     // directory containing the OPF file, e.g. "OEBPS"

    // Read a file by its full ZIP path (opfDir + "/" + relative path).
    // Returns empty vector if path not found.
    std::vector<uint8_t> readFile(const std::string& zipPath) const;

    // Full ZIP path for a spine item: opfDir + "/" + item.path
    std::string fullPath(const SpineItem& item) const;

private:
    struct ZipHandle;
    ZipHandle* zip = nullptr;
    friend class EpubParser;
};
