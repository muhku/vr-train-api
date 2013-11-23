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

#ifdef __APPLE__
#include "TargetConditionals.h"
#endif

#import <Foundation/Foundation.h>
#import <CoreLocation/CLLocation.h>

#if TARGET_OS_IPHONE
#import <MapKit/MKAnnotation.h>
#else
#import "MKAnnotation_Mock.h"
#endif

@class MATrainStation;

@interface MATrainWaypoint : NSObject {
    MATrainStation *_trainStation;
    NSDate *_scheduledArrivalTime;
    NSDate *_scheduledDepartureTime;
    BOOL _completed;
}

@property (strong,nonatomic) MATrainStation *trainStation;
@property (nonatomic,copy) NSDate *scheduledArrivalTime;
@property (nonatomic,copy) NSDate *scheduledDepartureTime;
@property (nonatomic,assign) BOOL completed;

@end

typedef enum {
    MATrainTypeUnknown = 0,
    MATrainTypeLongDistanceTrain = 1,
    MATrainTypeLocalTrain = 2
} MATrainType;

typedef enum {
    MATrainStatusUnknown = 0,
    MATrainStatusOnTime = 1,
    MATrainStatusLate = 2,
    MATrainStatusSeverelyLate = 3,
    MATrainStatusCanceled = 5
} MATrainStatus;

@interface MATrain : NSObject<MKAnnotation> {
    NSString *_identifier;
    NSString *_name;
    MATrainType _type;
    MATrainStatus _status;
    MATrainStation *_from;
    MATrainStation *_to;
    int _timeDifferenceToScheduledTimeInSeconds;
    CLLocation *_location;
    NSMutableArray *_waypoints;
    int _speed;
}

@property (nonatomic,copy) NSString *identifier;
@property (nonatomic,copy) NSString *name;
@property (nonatomic,assign) MATrainType type;
@property (nonatomic,assign) MATrainStatus status;
@property (strong,nonatomic) MATrainStation *from;
@property (strong,nonatomic) MATrainStation *to;
@property (nonatomic,assign) int timeDifferenceToScheduledTimeInSeconds;
@property (nonatomic,copy) CLLocation *location;
@property (weak,nonatomic,readonly) NSMutableArray *waypoints;
@property (nonatomic,readonly) CLLocationCoordinate2D coordinate;
@property (nonatomic,assign) int speed;

// For MKAnnotation
@property (nonatomic, readonly, copy) NSString *title;
@property (nonatomic, readonly, copy) NSString *subtitle;

@end
