//
//  RNURLProtocol.m
//
//  Created by Rakuraku Jyo on 2013/10/08.
//  Copyright (c) 2013 RAKUNEW.com. All rights reserved.
//
//  This code is licensed under the MIT License:
//
//  Permission is hereby granted, free of charge, to any person obtaining a
//  copy of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
//  DEALINGS IN THE SOFTWARE.
//

#import "ISDiskCache.h"

#import "RNURLProtocol.h"

static NSString *const RNCachingURLHeader = @"X-RN-Cache";

static ISDiskCache *__diskCache = nil;
static NSMutableArray *__whiteListURLs = nil;

@implementation RNURLProtocol {
    NSURLConnection *_connection;
    NSURLResponse *_response;
    NSMutableData *_data;
}

+ (void)initialize {
    [super initialize];

    static dispatch_once_t once;
    dispatch_once(&once, ^{
        __diskCache = [ISDiskCache sharedCache];
        [__diskCache setLimitOfSize:1024 * 1024 * 100];
    });
}

#pragma mark - NSURLProtocol implementation

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    return ([request.URL.scheme isEqualToString:@"http"] || ([request.URL.scheme isEqualToString:@"https"])) // protocol check
        && [request valueForHTTPHeaderField:RNCachingURLHeader] == nil // non-recursive check
        && [self isWhiteListed:request.URL.absoluteString]; // white-list check
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void)startLoading {
    NSURLResponse *res = [__diskCache objectForKey:self.request.URL];
    NSData *data = [__diskCache objectForKey:[self dataKey]];

    if (res) {
        NSLog(@"--- Hit %@", self.request.URL);
        // we handle caching ourselves.
        [[self client] URLProtocol:self didReceiveResponse:res cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        [[self client] URLProtocol:self didLoadData:data];
        [[self client] URLProtocolDidFinishLoading:self];
    } else {
        NSLog(@"--- Loss, fetching %@", self.request.URL);
        NSMutableURLRequest *connectionRequest = [[self request] mutableCopy];
        // we need to mark this request with our header so we know not to handle it in +[NSURLProtocol canInitWithRequest:].
        [connectionRequest setValue:@"" forHTTPHeaderField:RNCachingURLHeader];
        _connection = [NSURLConnection connectionWithRequest:connectionRequest delegate:self];
    }
}

- (void)stopLoading {
    [_connection cancel];
}

#pragma mark - NSURLConnection Delegate Methods

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response {
    if (response != nil) {
        [[self client] URLProtocol:self wasRedirectedToRequest:request redirectResponse:response];
    }
    return request;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [[self client] URLProtocol:self didLoadData:data];
    [self appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [[self client] URLProtocol:self didFailWithError:error];

    _connection = nil;
    _response = nil;
    _data = nil;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    _response = response;
    [[self client] URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];  // We cache ourselves.
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [[self client] URLProtocolDidFinishLoading:self];

    [__diskCache setObject:_response forKey:self.request.URL];
    [__diskCache setObject:_data forKey:[self dataKey]];

    _connection = nil;
    _response = nil;
    _data = nil;
}

#pragma mark - Inner Logic

- (void)appendData:(NSData *)data {
    if (_data == nil) {
        _data = [data mutableCopy];
    } else {
        [_data appendData:data];
    }
}

- (NSString *)dataKey {
    return [NSString stringWithFormat:@"%@-data", self.request.URL];
}

// Only white listed items will be cached
+ (BOOL)isWhiteListed:(NSString *)URLStr {
    NSError *error = NULL;
    BOOL found = NO;
    for (NSString *pattern in __whiteListURLs) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:&error];
        NSTextCheckingResult *result = [regex firstMatchInString:URLStr options:NSMatchingAnchored range:NSMakeRange(0, URLStr.length)];
        if (result.numberOfRanges) {
            return YES;
        }
    }

    return found;
}

+ (NSMutableArray *)whiteListURLs {
    if (__whiteListURLs == nil) {
        __whiteListURLs = [NSMutableArray array];
    }

    return __whiteListURLs;
}

@end