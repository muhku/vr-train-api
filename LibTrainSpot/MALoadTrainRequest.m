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

#import "MALoadTrainRequest.h"
#import "MATrain.h"
#import "MATrainInformationService.h"

static NSString *const kXPathQueryTrain = @"/rss/channel";
static NSString *const kXPathQueryTrainWaypoints = @"/rss/channel/item";

@interface MALoadTrainRequest (PrivateMethods)
- (void)parseTrain:(xmlNodePtr)node;
- (void)parseWaypoints:(xmlNodePtr)node;
@end

@implementation MALoadTrainRequest

@synthesize train=_train;

- (id)init
{
    self = [super init];
    if (self) {
        _service = [[MATrainInformationService alloc] init];
    }
    return self;
}

- (void)parseTrain:(xmlNodePtr)node
{
    for (xmlNodePtr n = node->children; n != NULL; n = n->next) {        
        NSString *nodeName = [NSString stringWithCString:(const char *)n->name
                                                encoding:NSUTF8StringEncoding];
        if ([nodeName isEqualToString:@"point"]) {
            NSArray *locationComponents = [[self contentForNode:n] componentsSeparatedByString:@" "];
            self.train.location = [[CLLocation alloc] initWithLatitude:[[locationComponents objectAtIndex:0] doubleValue]
                                                              longitude:[[locationComponents objectAtIndex:1] doubleValue]];
        } else if ([nodeName isEqualToString:@"fromStation"]) {
            self.train.from = [_service trainStationByIdentifier:[self contentForNode:n]];
        } else if ([nodeName isEqualToString:@"toStation"]) {
            self.train.to = [_service trainStationByIdentifier:[self contentForNode:n]];
        } else if ([nodeName isEqualToString:@"speed"]) {
            self.train.speed = [[self contentForNode:n] intValue];
        }
    }
}

- (void)parseWaypoints:(xmlNodePtr)node
{
    MATrainWaypoint *waypoint = [[MATrainWaypoint alloc] init];
    
    for (xmlNodePtr n = node->children; n != NULL; n = n->next) {      
        NSString *nodeName = [NSString stringWithCString:(const char *)n->name
                                                encoding:NSUTF8StringEncoding];
        if ([nodeName isEqualToString:@"scheduledTime"]) {
            waypoint.scheduledArrivalTime = [self dateFromNode:n];
        } else if ([nodeName isEqualToString:@"scheduledDepartTime"]) {
            waypoint.scheduledDepartureTime = [self dateFromNode:n];
        } else if ([nodeName isEqualToString:@"stationCode"]) {
            waypoint.trainStation = [_service trainStationByIdentifier:[self contentForNode:n]];
        } else if ([nodeName isEqualToString:@"completed"]) {
            waypoint.completed = [[self contentForNode:n] isEqualToString:@"1"];
        }
    }
    
    [self.train.waypoints addObject:waypoint];
}

- (void)parseResponseData
{
    [self.train.waypoints removeAllObjects];
    
    [self performXPathQuery:kXPathQueryTrain];
    [self performXPathQuery:kXPathQueryTrainWaypoints];
    
    // Hack: sometimes the returned data has already completed waypoints uncompleted.
    // Attempt to fix this.
    BOOL completed = NO;
    for (NSInteger i=[self.train.waypoints count]-1; i >= 0; i--) {
        MATrainWaypoint *waypoint = [self.train.waypoints objectAtIndex:i];
        if (completed) {
            waypoint.completed = YES;
            continue;
        }
        if (waypoint.completed) {
            completed = YES;
        }
    }
}

- (void)parseXMLNode:(xmlNodePtr)node xPathQuery:(NSString *)xPathQuery
{
    if ([xPathQuery isEqualToString:kXPathQueryTrain]) {
        [self parseTrain:node];
    } else if ([xPathQuery isEqualToString:kXPathQueryTrainWaypoints]) {
        [self parseWaypoints:node];
    }
}

@end