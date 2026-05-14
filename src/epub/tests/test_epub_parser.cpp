#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
#include "EpubParser.h"
#include <stdexcept>

static std::string fixture(const std::string& name) {
    return std::string(FIXTURES_DIR) + "/" + name;
}

TEST_CASE("EpubParser — nonexistent file throws") {
    CHECK_THROWS_AS(EpubParser::parse("/no/such/file.epub"),
                    std::runtime_error);
}

TEST_CASE("EpubParser — valid epub2") {
    auto book = EpubParser::parse(fixture("minimal.epub"));
    REQUIRE(book != nullptr);

    SUBCASE("metadata title") {
        CHECK(book->metadata.title == "Test Book");
    }
    SUBCASE("metadata author") {
        CHECK(book->metadata.author == "Test Author");
    }
    SUBCASE("metadata uid") {
        CHECK(book->metadata.uid == "test-epub-001");
    }
    SUBCASE("spine count") {
        REQUIRE(book->spine.size() == 2);
    }
    SUBCASE("spine paths") {
        CHECK(book->spine[0].path == "chapter1.xhtml");
        CHECK(book->spine[1].path == "chapter2.xhtml");
    }
    SUBCASE("spine media type") {
        CHECK(book->spine[0].mediaType == "application/xhtml+xml");
    }
    SUBCASE("opfDir") {
        CHECK(book->opfDir == "OEBPS");
    }
    SUBCASE("fullPath") {
        CHECK(book->fullPath(book->spine[0]) == "OEBPS/chapter1.xhtml");
    }
    SUBCASE("readFile returns content") {
        auto bytes = book->readFile("OEBPS/chapter1.xhtml");
        REQUIRE(!bytes.empty());
        std::string s(bytes.begin(), bytes.end());
        CHECK(s.find("Hello from chapter one") != std::string::npos);
    }
    SUBCASE("readFile missing path returns empty") {
        auto bytes = book->readFile("OEBPS/nonexistent.xhtml");
        CHECK(bytes.empty());
    }
    SUBCASE("toc count") {
        REQUIRE(book->toc.size() == 4);
    }
    SUBCASE("toc chapter entries") {
        CHECK(book->toc[0].title == "Chapter 1");
        CHECK(book->toc[0].spineIndex == 0);
        CHECK(book->toc[0].depth == 0);
        CHECK(book->toc[3].title == "Chapter 2");
        CHECK(book->toc[3].spineIndex == 1);
        CHECK(book->toc[3].depth == 0);
    }
    SUBCASE("toc subsection entries") {
        CHECK(book->toc[1].title == "Section 1.1");
        CHECK(book->toc[1].spineIndex == 0);
        CHECK(book->toc[1].depth == 1);
        CHECK(book->toc[2].title == "Section 1.2");
        CHECK(book->toc[2].spineIndex == 0);
        CHECK(book->toc[2].depth == 1);
    }
    SUBCASE("toc fragment preserved") {
        CHECK(book->toc[0].fragment == "");
        CHECK(book->toc[1].fragment == "section-1-1");
        CHECK(book->toc[2].fragment == "section-1-2");
        CHECK(book->toc[3].fragment == "");
    }
}
