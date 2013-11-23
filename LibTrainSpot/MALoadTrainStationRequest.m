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

#import "MALoadTrainStationRequest.h"
#import "MATrain.h"
#import "MATrainStation.h"
#import "MATrainInformationService.h"

static NSString *const kXPathQueryTrainStation = @"/rss/channel";
static NSString *const kXPathQueryTrains = @"/rss/channel/item";

@interface MALoadTrainStationRequest (PrivateMethods)
- (void)parseTrains:(xmlNodePtr)node;
- (void)parseTrainStation:(xmlNodePtr)node;
@end

@implementation MALoadTrainStationRequest

@synthesize trainStation=_trainStation;
@synthesize trains=_trains;

- (id)init
{
    self = [super init];
    if (self) {
        _service = [[MATrainInformationService alloc] init];
    }
    return self;
}

- (void)dealloc
{
    _service = nil;
    
    _trains = nil;
    _trainsByIdentifier = nil;
    
    self.onCompletion = nil;
    self.onFailure = nil;
    
}

- (void)parseTrains:(xmlNodePtr)node
{
    MATrain *train = [[MATrain alloc] init];
    MATrainWaypoint *waypoint = [[MATrainWaypoint alloc] init];
    waypoint.trainStation = self.trainStation;
    [train.waypoints addObject:waypoint];
    
    for (xmlNodePtr n = node->children; n != NULL; n = n->next) {        
        NSString *nodeName = [NSString stringWithCString:(const char *)n->name
                                                encoding:NSUTF8StringEncoding];
        if ([nodeName isEqualToString:@"title"]) {
            train.name = [self contentForNode:n];
        } else if ([nodeName isEqualToString:@"category"]) {
            int trainType = [[self contentForNode:n] intValue];
            
            if (trainType == 1) {
                train.type = MATrainTypeLongDistanceTrain;
            } else if (trainType == 2) {
                train.type = MATrainTypeLocalTrain;
            } else {
                train.type = MATrainTypeUnknown;
            }
        } else if ([nodeName isEqualToString:@"status"]) {
            int trainStatus = [[self contentForNode:n] intValue];
            
            if (trainStatus == 1) {
                train.status = MATrainStatusOnTime;
            } else if (trainStatus == 2) {
                train.status = MATrainStatusLate;
            } else if (trainStatus == 3) {
                train.status = MATrainStatusSeverelyLate;
            } else if (trainStatus == 5) {
                train.status = MATrainStatusCanceled;
            } else {
                train.status = MATrainStatusUnknown;
            }
        } else if ([nodeName isEqualToString:@"fromStation"]) {
            train.from = [_service trainStationByIdentifier:[self contentForNode:n]];
        } else if ([nodeName isEqualToString:@"toStation"]) {
            train.to = [_service trainStationByIdentifier:[self contentForNode:n]];
        } else if ([nodeName isEqualToString:@"scheduledTime"]) {
            waypoint.scheduledArrivalTime = [self dateFromNode:n];
        } else if ([nodeName isEqualToString:@"scheduledDepartTime"]) {
            waypoint.scheduledDepartureTime = [self dateFromNode:n];
        } else if ([nodeName isEqualToString:@"lateness"]) {
            train.timeDifferenceToScheduledTimeInSeconds = [[self contentForNode:n] integerValue];
        } else if ([nodeName isEqualToString:@"guid"]) {
            train.identifier = [self contentForNode:n];
        } else if ([nodeName isEqualToString:@"point"]) {
            NSArray *locationComponents = [[self contentForNode:n] componentsSeparatedByString:@" "];
            train.location = [[CLLocation alloc] initWithLatitude:[[locationComponents objectAtIndex:0] doubleValue]
                                                         longitude:[[locationComponents objectAtIndex:1] doubleValue]];
        }
    }
    
    if (![_trainsByIdentifier objectForKey:train.identifier]) {
        /*
         * Seems the feed is sometimes a bit buggy - it can return
         * the same train twice with identical information.
         * So let's make sure we don't return the same train twice.
         */
        [_trainsByIdentifier setObject:train forKey:train.identifier];
        [_trains addObject:train];
    }
}

- (void)parseTrainStation:(xmlNodePtr)node
{
    for (xmlNodePtr n = node->children; n != NULL; n = n->next) {        
        NSString *nodeName = [NSString stringWithCString:(const char *)n->name
                                                encoding:NSUTF8StringEncoding];
        if ([nodeName isEqualToString:@"point"]) {
            NSArray *locationComponents = [[self contentForNode:n] componentsSeparatedByString:@" "];
            self.trainStation.location = [[CLLocation alloc] initWithLatitude:[[locationComponents objectAtIndex:0] doubleValue]
                                                                     longitude:[[locationComponents objectAtIndex:1] doubleValue]];
        }
    }
}

- (void)parseResponseData
{
    _trains = [[NSMutableArray alloc] init];
    _trainsByIdentifier = [[NSMutableDictionary alloc] init];
    
    [self performXPathQuery:kXPathQueryTrainStation];
    [self performXPathQuery:kXPathQueryTrains];
}

- (void)parseXMLNode:(xmlNodePtr)node xPathQuery:(NSString *)xPathQuery
{
    if ([xPathQuery isEqualToString:kXPathQueryTrainStation]) {
        [self parseTrainStation:node];
    } else if ([xPathQuery isEqualToString:kXPathQueryTrains]) {
        [self parseTrains:node];
    }
}

@end
