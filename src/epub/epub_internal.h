#pragma once
#include "EpubBook.h"
#include "miniz.h"

struct EpubBook::ZipHandle {
    mz_zip_archive archive;
};
