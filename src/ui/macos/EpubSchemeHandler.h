#pragma once
#import <WebKit/WebKit.h>
#include "EpubBook.h"

@interface EpubSchemeHandler : NSObject <WKURLSchemeHandler>
- (instancetype)initWithBook:(EpubBook*)book;
@end
