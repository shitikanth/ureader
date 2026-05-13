#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
#include "EpubParser.h"

static std::string fixture(const std::string& name) {
    return std::string(FIXTURES_DIR) + "/" + name;
}

// Tests added in Tasks 5 and 6
