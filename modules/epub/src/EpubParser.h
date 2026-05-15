#pragma once
#include "EpubBook.h"
#include <memory>

class EpubParser {
public:
    // Throws std::runtime_error on any failure (bad ZIP, missing OPF, etc.)
    static std::unique_ptr<EpubBook> parse(const std::string& path);
};
