/*
 * Copyright (c) 2012 Matias Muhonen <mmu@iki.fi>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "MAXMLHttpRequest.h"

#import <libxml/xpath.h>

#define DATE_COMPONENTS (NSYearCalendarUnit| NSMonthCalendarUnit | NSDayCalendarUnit | NSWeekCalendarUnit |  NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit | NSWeekdayCalendarUnit | NSWeekdayOrdinalCalendarUnit)
#define CURRENT_CALENDAR [NSCalendar currentCalendar]

@interface MAXMLHttpRequest (PrivateMethods)
- (void)parseResponseData;
- (void)parseXMLNode:(xmlNodePtr)node xPathQuery:(NSString *)xPathQuery;
@end

@implementation MAXMLHttpRequest

@synthesize url=_url;
@synthesize onCompletion;
@synthesize onFailure;
@synthesize lastError=_lastError;

- (id)init
{
    self = [super init];
    if (self) {
    }
    return self;
}

- (void)dealloc
{
    _receivedData = nil;
}

- (void)start
{
    if (_connection) {
        return;
    }
    
    _lastError = MAXMLHttpRequestError_NoError;
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:self.url]
                                             cachePolicy:NSURLRequestUseProtocolCachePolicy
                                         timeoutInterval:60.0];
    
    @synchronized (self) {
        _receivedData = [NSMutableData data];
        _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    }
    
    if (!_connection) {
        onFailure();
        return;
    }
}

- (void)cancel
{
    if (!_connection) {
        return;
    }
    @synchronized (self) {
        [_connection cancel];
        _connection = nil;
    }
}

/*
 * =======================================
 * NSURLConnectionDelegate
 * =======================================
 */

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    _httpStatus = [httpResponse statusCode];
    
    [_receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [_receivedData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    @synchronized (self) {
        assert(_connection == connection);
        _connection = nil;
        _receivedData = nil;
    }
    
    _lastError = MAXMLHttpRequestError_Connection_Failed;
    onFailure();
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    assert(_connection == connection);
    
    @synchronized (self) {
        _connection = nil;
    }
    
    if (_httpStatus != 200) {
        _lastError = MAXMLHttpRequestError_Invalid_Http_Status;
        onFailure();
        return;
    }
    
    _xmlDocument = xmlReadMemory([_receivedData bytes],
                                 [_receivedData length],
                                 "",
                                 "UTF-8",
                                 0);
    
    if (!_xmlDocument) {
        _lastError = MAXMLHttpRequestError_XML_Parser_Failed;
        onFailure();
        return;
    }
    
    [self parseResponseData];
    
    xmlFreeDoc(_xmlDocument), _xmlDocument = nil;
    
    onCompletion();
}

/*
 * =======================================
 * XML handling
 * =======================================
 */

- (NSArray *)performXPathQuery:(NSString *)query
{
    NSMutableArray *resultNodes = [NSMutableArray array];
    xmlXPathContextPtr xpathCtx = NULL; 
    xmlXPathObjectPtr xpathObj = NULL;
    
    xpathCtx = xmlXPathNewContext(_xmlDocument);
    if (xpathCtx == NULL) {
		goto cleanup;
    }
    
    xpathObj = xmlXPathEvalExpression((xmlChar *)[query cStringUsingEncoding:NSUTF8StringEncoding], xpathCtx);
    if (xpathObj == NULL) {
		goto cleanup;
    }
	
	xmlNodeSetPtr nodes = xpathObj->nodesetval;
	if (!nodes) {
		goto cleanup;
	}
	
	for (size_t i = 0; i < nodes->nodeNr; i++) {
        [self parseXMLNode:nodes->nodeTab[i] xPathQuery:query];
	}
    
cleanup:
    if (xpathObj) {
        xmlXPathFreeObject(xpathObj);
    }
    if (xpathCtx) {
        xmlXPathFreeContext(xpathCtx);
    }
    return resultNodes;
}

- (NSString *)contentForNode:(xmlNodePtr)node
{
    NSString *stringWithContent;
    if (!node) {
        stringWithContent = [[NSString alloc] init];
    } else {
        xmlChar *content = xmlNodeGetContent(node);
        stringWithContent = [NSString stringWithCString:(const char *)content encoding:NSUTF8StringEncoding];
        xmlFree(content);
    }
    return stringWithContent;
}

/*
 * =======================================
 * Helpers
 * =======================================
 */

- (NSDate *)dateWithHour:(int)hour minute:(int)minute
{
    NSDate *today = [NSDate date];
    NSDateComponents *components = [CURRENT_CALENDAR components:DATE_COMPONENTS fromDate:today];
	[components setHour:hour];
	[components setMinute:minute];
	return [CURRENT_CALENDAR dateFromComponents:components];
}

- (NSDate *)dateFromNode:(xmlNodePtr)node
{
    NSArray *dateComponents = [[self contentForNode:node] componentsSeparatedByString:@":"];
    return ([dateComponents count] == 2 ? [self dateWithHour:[[dateComponents objectAtIndex:0] intValue]
                                                      minute:[[dateComponents objectAtIndex:1] intValue]] : nil);
}

@end
