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

#import "MATrainInformationService.h"

#import "MATrainStation.h"
#import "MATrain.h"

#import "MALoadTrainStationRequest.h"
#import "MALoadTrainRequest.h"

static NSInteger sortTrainStationsByDistance(id st1, id st2, void *keyForSorting) {
	MATrainStation *station1 = (MATrainStation *)st1;
	MATrainStation *station2 = (MATrainStation *)st2;
    
	int d1 = station1.distanceFromUserGivenPoint;
	int d2 = station2.distanceFromUserGivenPoint;
	
	if (d1 < d2) {
		return NSOrderedAscending;
	} else if (d1 > d2) {
		return NSOrderedDescending;
	} else {
		/* Station distance the same, compare by name.
		 */
        return [station1.name compare:station2.name];
	}
}

static NSString *const kFinnishRailwayTrainRssURL = @"http://188.117.35.14/TrainRSS/TrainService.svc";

@interface MATrainInformationService (PrivateMethods)
- (void)parseData;
@end

@implementation MATrainInformationService

- (id)init
{
    self = [super init];
    if (self) {
        NSString *sourcePath = [[NSBundle mainBundle] pathForResource:@"stations" ofType:@"txt"];
        _stationData = [[NSString alloc] initWithContentsOfFile:sourcePath
                                                       encoding:NSUTF8StringEncoding
                                                          error:nil];
        _trainStations = [[NSMutableArray alloc] init];
        _trainStationsByIdentifier = [[NSMutableDictionary alloc] init];
        [self parseData];
    }
    return self;
}

- (void)dealloc
{
    _stationData = nil;
    _trainStations = nil;
    _trainStationsByIdentifier = nil;
}

- (MALoadTrainStationRequest *)loadTrainStationWithIdentifier:(NSString *)identifier
{
    MALoadTrainStationRequest *request = [[MALoadTrainStationRequest alloc] init];
    request.url = [NSString stringWithFormat:@"%@/StationInfo?station=%@",
                   kFinnishRailwayTrainRssURL,
                   [identifier stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    
    request.trainStation = [self trainStationByIdentifier:identifier];
    return request;
}

- (MALoadTrainRequest *)loadTrainWithIdentifier:(NSString *)identifier
{    
    MALoadTrainRequest *request = [[MALoadTrainRequest alloc] init];
    request.url = [NSString stringWithFormat:@"%@/TrainInfo?train=%@",
                   kFinnishRailwayTrainRssURL,
                   [identifier stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    
    MATrain *train = [[MATrain alloc] init];
    train.identifier = identifier;
    request.train = train;
    
    return request;
}

- (MATrainStation *)trainStationByIdentifier:(NSString *)identifier
{
    MATrainStation *t = [_trainStationsByIdentifier objectForKey:identifier];
    
    if (t) {
        MATrainStation *trainStation = [[MATrainStation alloc] init];
        trainStation.identifier = t.identifier;
        trainStation.name = t.name;
        trainStation.location = t.location;
        return trainStation;
    }
    return nil;
}

- (NSMutableArray *)trainStations
{
    NSMutableArray *stationList = [[NSMutableArray alloc] init];
    
    for (id trainStation in _trainStations) {
        MATrainStation *t = (MATrainStation *)trainStation;
        
        MATrainStation *trainStation = [[MATrainStation alloc] init];
        trainStation.identifier = t.identifier;
        trainStation.name = t.name;
        trainStation.location = t.location;
        
        [stationList addObject:trainStation];
    }
    return stationList;
}

- (NSMutableArray *)nearestTrainStationFromLocation:(CLLocation *)location
{
    NSMutableArray *stationList = [[NSMutableArray alloc] init];
    
    for (id t in _trainStations) {
        MATrainStation *trainStation = (MATrainStation *)t;
        CLLocationDistance distance = [location distanceFromLocation:trainStation.location];
        
        if (distance > -1) {
            MATrainStation *newTrainStation = [[MATrainStation alloc] init];
            newTrainStation.identifier = trainStation.identifier;
            newTrainStation.name = trainStation.name;
            newTrainStation.location = trainStation.location;
            newTrainStation.distanceFromUserGivenPoint = distance / 1000.;
            
            [stationList addObject:newTrainStation];
        }
    }
    
    [stationList sortUsingFunction:sortTrainStationsByDistance context:NULL];
    
    NSMutableArray *finalSortedArray = [[NSMutableArray alloc] init];
    
    size_t i = 0;
    for (id t in stationList) {
        [finalSortedArray addObject:t];
        if (i++ == 1) {
            break;
        }
    }
    
    return finalSortedArray;
}

- (NSMutableArray *)searchTrainStationsByKeyword:(NSString *)keyword
{
    NSMutableArray *stationList = [[NSMutableArray alloc] init];
    
    for (id trainStation in _trainStations) {
        MATrainStation *t = (MATrainStation *)trainStation;
        
        if ([t.name rangeOfString:keyword options:NSCaseInsensitiveSearch].length > 0) {
            MATrainStation *trainStation = [[MATrainStation alloc] init];
            trainStation.identifier = t.identifier;
            trainStation.name = t.name;
            trainStation.location = t.location;
            
            [stationList addObject:trainStation];
        }
    }
    return stationList;
}

/* private */

- (void)parseData
{
    MATrainStation *station = nil;
    
    [_trainStations removeAllObjects];
    
    int offset = 0;
    
    for (NSString *line in [_stationData componentsSeparatedByString:@"\n"]) {
        NSString *data = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        if (!([data length] > 0)) {
            if (station) {
                station = nil;
            }
            goto done;
        }
        
        if (offset == 0) {
            station = [[MATrainStation alloc] init];
            station.identifier = data;
        } else if (offset == 1) {
            station.name = data;
        } else if (offset == 2) {
            NSArray *locationComponents = [data componentsSeparatedByString:@" "];
            station.location = [[CLLocation alloc] initWithLatitude:[[locationComponents objectAtIndex:0] doubleValue]
                                                           longitude:[[locationComponents objectAtIndex:1] doubleValue]];
            [_trainStations addObject:station];
            [_trainStationsByIdentifier setObject:station forKey:station.identifier];
            station = nil;
        }
        
        offset = (offset + 1) % 3;
    }
    
done:
    if (station) {
        [_trainStations addObject:station];
        station = nil;        
    }
}

@end
