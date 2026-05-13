#include "EpubBook.h"
#include "miniz.h"

struct EpubBook::ZipHandle {
    mz_zip_archive archive;
};

EpubBook::~EpubBook() {
    if (zip) {
        mz_zip_reader_end(&zip->archive);
        delete zip;
    }
}

std::vector<uint8_t> EpubBook::readFile(const std::string& zipPath) const {
    if (!zip) return {};
    size_t size = 0;
    void* data = mz_zip_reader_extract_file_to_heap(&zip->archive, zipPath.c_str(), &size, 0);
    if (!data) return {};
    std::vector<uint8_t> result(static_cast<uint8_t*>(data),
                                static_cast<uint8_t*>(data) + size);
    mz_free(data);
    return result;
}

std::string EpubBook::fullPath(const SpineItem& item) const {
    if (opfDir.empty()) return item.path;
    return opfDir + "/" + item.path;
}
