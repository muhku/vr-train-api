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

#import "MATrain.h"
#import "MATrainStation.h"

static NSDateFormatter *timeFormatter;

@implementation MATrainWaypoint

@synthesize trainStation=_trainStation;
@synthesize scheduledArrivalTime=_scheduledArrivalTime;
@synthesize scheduledDepartureTime=_scheduledDepartureTime;
@synthesize completed=_completed;

- (id)init
{
    self = [super init];
    if (self) {
        _completed = NO;
    }
    return self;
}

- (void)dealloc
{
    _completed = NO;
}

@end

@implementation MATrain

@synthesize identifier=_identifier;
@synthesize name=_name;
@synthesize type=_type;
@synthesize status=_status;
@synthesize from=_from;
@synthesize to=_to;
@synthesize timeDifferenceToScheduledTimeInSeconds=_timeDifferenceToScheduledTimeInSeconds;
@synthesize location=_location;
@synthesize speed=_speed;

- (id)init
{
    self = [super init];
    if (self) {
        _waypoints = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc
{
    _waypoints = nil;
}

- (NSMutableArray *)waypoints
{
    return _waypoints;
}

- (CLLocationCoordinate2D)coordinate
{
    return self.location.coordinate;
}

- (NSString *)title
{
    return [NSString stringWithFormat:@"Speed: %i km/h", self.speed];
}

-  (NSString *)subtitle
{
    if (!([self.waypoints count] > 0)) {
        return nil;
    }
    if (!timeFormatter) {
        timeFormatter = [[NSDateFormatter alloc] init];
        [timeFormatter setDateFormat:@"HH:mm"];
    }
    for (MATrainWaypoint *waypoint in self.waypoints) {
        if (!waypoint.completed) {
            return [NSString stringWithFormat:@"Next stop: %@ %@",
                    [timeFormatter stringFromDate:waypoint.scheduledArrivalTime],
                    waypoint.trainStation.name];
        }
    }
    return nil;
}

@end
