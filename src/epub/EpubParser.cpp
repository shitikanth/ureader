#include "EpubParser.h"
#include "epub_internal.h"
#include "tinyxml2.h"
#include <map>
#include <stdexcept>
#include <cstring>

namespace {

std::string readZipFile(mz_zip_archive* zip, const std::string& path) {
    size_t size = 0;
    void* data = mz_zip_reader_extract_file_to_heap(zip, path.c_str(), &size, 0);
    if (!data) return {};
    std::string result(static_cast<char*>(data), size);
    mz_free(data);
    return result;
}

std::string dirOf(const std::string& path) {
    auto pos = path.rfind('/');
    return pos != std::string::npos ? path.substr(0, pos) : "";
}

std::string join(const std::string& dir, const std::string& name) {
    return dir.empty() ? name : dir + "/" + name;
}

std::string stripFragment(const std::string& href) {
    auto pos = href.find('#');
    return pos != std::string::npos ? href.substr(0, pos) : href;
}

int spineIndexFor(const std::vector<SpineItem>& spine, const std::string& href) {
    std::string base = stripFragment(href);
    for (int i = 0; i < static_cast<int>(spine.size()); i++)
        if (spine[i].path == base) return i;
    return -1;
}

std::string findOpfPath(mz_zip_archive* zip) {
    auto xml = readZipFile(zip, "META-INF/container.xml");
    if (xml.empty()) throw std::runtime_error("Missing META-INF/container.xml");

    tinyxml2::XMLDocument doc;
    if (doc.Parse(xml.c_str()) != tinyxml2::XML_SUCCESS)
        throw std::runtime_error("Failed to parse container.xml");

    auto root = doc.RootElement();
    auto rootfiles = root ? root->FirstChildElement("rootfiles") : nullptr;
    auto rootfile = rootfiles ? rootfiles->FirstChildElement("rootfile") : nullptr;
    if (!rootfile) throw std::runtime_error("No rootfile element in container.xml");

    const char* p = rootfile->Attribute("full-path");
    if (!p) throw std::runtime_error("No full-path attribute in container.xml");
    return p;
}

// Forward declarations — implemented in Task 6
void parseTocNcx(mz_zip_archive*, const std::string&,
                 const std::vector<SpineItem>&, std::vector<TocEntry>&);
void parseNavXhtml(mz_zip_archive*, const std::string&,
                   const std::vector<SpineItem>&, std::vector<TocEntry>&);

void parseOpf(mz_zip_archive* zip, const std::string& opfPath, EpubBook* book) {
    auto xml = readZipFile(zip, opfPath);
    if (xml.empty()) throw std::runtime_error("Cannot read OPF: " + opfPath);

    tinyxml2::XMLDocument doc;
    if (doc.Parse(xml.c_str()) != tinyxml2::XML_SUCCESS)
        throw std::runtime_error("Failed to parse OPF: " + opfPath);

    auto pkg = doc.RootElement();
    if (!pkg) throw std::runtime_error("Empty OPF document");

    // Metadata
    if (auto meta = pkg->FirstChildElement("metadata")) {
        if (auto el = meta->FirstChildElement("dc:title"); el && el->GetText())
            book->metadata.title = el->GetText();
        if (auto el = meta->FirstChildElement("dc:creator"); el && el->GetText())
            book->metadata.author = el->GetText();

        const char* uidId = pkg->Attribute("unique-identifier");
        if (uidId) {
            for (auto el = meta->FirstChildElement(); el;
                 el = el->NextSiblingElement()) {
                const char* id = el->Attribute("id");
                if (id && std::string(id) == uidId && el->GetText()) {
                    book->metadata.uid = el->GetText();
                    break;
                }
            }
        }
    }

    // Manifest: id -> {href, mediaType}
    std::map<std::string, std::pair<std::string, std::string>> manifest;
    std::string ncxHref, navHref;

    if (auto manifestEl = pkg->FirstChildElement("manifest")) {
        for (auto item = manifestEl->FirstChildElement("item"); item;
             item = item->NextSiblingElement("item")) {
            const char* id   = item->Attribute("id");
            const char* href = item->Attribute("href");
            const char* mt   = item->Attribute("media-type");
            if (!id || !href || !mt) continue;
            manifest[id] = {href, mt};
            if (std::string(mt) == "application/x-dtbncx+xml") ncxHref = href;
            const char* props = item->Attribute("properties");
            if (props && std::string(props).find("nav") != std::string::npos)
                navHref = href;
        }
    }

    // Spine
    if (auto spineEl = pkg->FirstChildElement("spine")) {
        if (ncxHref.empty()) {
            const char* toc = spineEl->Attribute("toc");
            if (toc && manifest.count(toc)) ncxHref = manifest[toc].first;
        }
        for (auto ref = spineEl->FirstChildElement("itemref"); ref;
             ref = ref->NextSiblingElement("itemref")) {
            const char* idref = ref->Attribute("idref");
            if (idref && manifest.count(idref)) {
                SpineItem si;
                si.id        = idref;
                si.path      = manifest[idref].first;
                si.mediaType = manifest[idref].second;
                book->spine.push_back(std::move(si));
            }
        }
    }

    // TOC
    std::string opfDir = dirOf(opfPath);
    if (!navHref.empty())
        parseNavXhtml(zip, join(opfDir, navHref), book->spine, book->toc);
    else if (!ncxHref.empty())
        parseTocNcx(zip, join(opfDir, ncxHref), book->spine, book->toc);
}

// Stub TOC parsers — replaced in Task 6
void parseTocNcx(mz_zip_archive*, const std::string&,
                 const std::vector<SpineItem>&, std::vector<TocEntry>&) {}
void parseNavXhtml(mz_zip_archive*, const std::string&,
                   const std::vector<SpineItem>&, std::vector<TocEntry>&) {}

} // anonymous namespace

std::unique_ptr<EpubBook> EpubParser::parse(const std::string& path) {
    auto book = std::make_unique<EpubBook>();
    book->zip = new EpubBook::ZipHandle();
    memset(&book->zip->archive, 0, sizeof(mz_zip_archive));

    if (!mz_zip_reader_init_file(&book->zip->archive, path.c_str(), 0))
        throw std::runtime_error("Cannot open epub: " + path);

    std::string opfPath = findOpfPath(&book->zip->archive);
    book->opfDir = dirOf(opfPath);
    parseOpf(&book->zip->archive, opfPath, book.get());
    return book;
}
