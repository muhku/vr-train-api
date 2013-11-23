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

#import "MAAppDelegate.h"
#import "MATrainInformationService.h"
#import "MALoadTrainStationRequest.h"
#import "MAApplicationSettings.h"
#import "MATrain.h"
#import "MATrainStation.h"

@interface MAAppDelegate (PrivateMethods)
- (void)terminateForReal;
@end

@implementation MAAppDelegate

@synthesize window = _window;
@synthesize preferencesWindow;
@synthesize feedLastRetrievalTime;
@synthesize trainStationListController;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    _service = [[MATrainInformationService alloc] init];
    
    NSMutableArray *trainStations = [[NSMutableArray alloc] init];
    for (MATrainStation *station in _service.trainStations) {
        [trainStations addObject:station.name];
    }
    [self.trainStationListController setContent:trainStations];
    
    // Update the feed automatically every 15 minutes
    _feedUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:60 * 15
                                                        target:self
                                                      selector:@selector(updateTrainMenu:)
                                                      userInfo:nil
                                                       repeats:YES];
    [_feedUpdateTimer fire];
    
    _statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    
    [_statusItem setTitle:[NSString stringWithFormat:@"From %@", self.selectedTrainStation.name]];
    [_statusItem setHighlightMode:YES];
    [_statusItem setAction:@selector(updateTrainMenu:)];
}

/*
 * =======================================
 * Actions
 * =======================================
 */

- (IBAction)updateTrainMenu:(id)sender
{
    NSDate *now = [[NSDate alloc] init];
    
    if (!_forceUpdate) {
        if (!([now timeIntervalSince1970] - self.feedLastRetrievalTime >= 60)) {
            // If less than 60 seconds from the last retrieval, do not retrieve the feed.
            return;
        }
    }
    
    _forceUpdate = NO;
    self.feedLastRetrievalTime = [now timeIntervalSince1970];
    
    __weak MAAppDelegate *weakSelf = self;
    [_loadTrainStationRequest cancel];
    _loadTrainStationRequest = [_service loadTrainStationWithIdentifier:self.selectedTrainStation.identifier];
    _loadTrainStationRequest.onCompletion = ^() {
        NSDate *now = [[NSDate alloc] init];
        
        [weakSelf.trains removeAllObjects];
        
        BOOL foundEnd = NO;
        
        for (NSInteger i=[_loadTrainStationRequest.trains count] - 1; i >= 0; i--) {
            MATrain *train = [_loadTrainStationRequest.trains objectAtIndex:i];
            MATrainWaypoint *waypoint = [train.waypoints lastObject];
            if (foundEnd && [waypoint.scheduledDepartureTime compare:now] != NSOrderedDescending) {
                break;
            } else {
                if ([waypoint.scheduledDepartureTime compare:now] != NSOrderedDescending) {
                    goto next;
                } else {
                    foundEnd = YES;
                }
            }
        next:
            if (![train.to.identifier isEqualToString:weakSelf.selectedTrainStation.identifier]) {
                [weakSelf.trains insertObject:train atIndex:0];
            }
        }
        
        [weakSelf.statusItem setMenu:self.departingTrainsMenu];
    };
    _loadTrainStationRequest.onFailure = ^() {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Error"];
        [alert setInformativeText:@"Unable to retrieve train information."];
        [alert runModal];
    };
    [_loadTrainStationRequest start];
}

- (IBAction)openPreferences:(id)sender
{
    [self.preferencesWindow center];
    [self.preferencesWindow makeKeyAndOrderFront:nil];
}

- (IBAction)showTrain:(id)sender
{
    NSMenuItem *menuItem = sender;
    MATrain *train = [_trains objectAtIndex:menuItem.tag];
    
    int trainNumber = 0;
    
    if ([train.name length] == 1) {
        trainNumber = [[train.identifier substringFromIndex:1] intValue];
    } else if ([train.name hasPrefix:@"IC "] ||
               [train.name hasPrefix:@"AE "]) {
        trainNumber = [[train.name substringFromIndex:2] intValue];
    } else if ([train.name hasPrefix:@"IC2 "]) {
        trainNumber = [[train.name substringFromIndex:3] intValue];
    } else if ([train.name hasPrefix:@"S "] ||
               [train.name hasPrefix:@"P "] ||
               [train.name hasPrefix:@"H "]) {
        trainNumber = [[train.name substringFromIndex:1] intValue];
    }
    
    NSString *trainURL = [NSString stringWithFormat:[MAApplicationSettings sharedApplicationSettings].trainInformationServiceURL, trainNumber];
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:trainURL]];
}

- (IBAction)terminate:(id)sender
{
    // Don't terminate before the event loop has finished running
    [NSApp performSelector:@selector(terminateForReal:) withObject:nil afterDelay:0.0];
}

/*
 * =======================================
 * NSMenuDelegate
 * =======================================
 */

- (void)menuWillOpen:(NSMenu *)menu
{
    [self updateTrainMenu:menu];
}

/*
 * =======================================
 * Properties
 * =======================================
 */

- (NSUInteger)selectedTrainStationIndex
{
    MATrainStation *selectedTrainStation = self.selectedTrainStation;
    NSUInteger index = 0;
    for (MATrainStation *station in _service.trainStations) {
        if ([selectedTrainStation.identifier isEqualToString:station.identifier]) {
            return index;
        }
        index++;
    }
    return 0;
}

- (void)setSelectedTrainStationIndex:(NSUInteger)selectedTrainStationIndex
{
    MAApplicationSettings *settings = [MAApplicationSettings sharedApplicationSettings];
    MATrainStation *newTrainStation = [_service.trainStations objectAtIndex:selectedTrainStationIndex];
    settings.selectedTrainStationIdentifier = newTrainStation.identifier;
    [settings storeSettings];
    
    [_statusItem setTitle:[NSString stringWithFormat:@"From %@", self.selectedTrainStation.name]];
    
    _forceUpdate = YES;
    [self updateTrainMenu:self];
}

- (NSMutableArray *)trains
{
    if (!_trains) {
        _trains = [[NSMutableArray alloc] init];
    }
    return _trains;
}

- (MATrainStation *)selectedTrainStation
{
    return [_service trainStationByIdentifier:[MAApplicationSettings sharedApplicationSettings].selectedTrainStationIdentifier];
}

- (NSMenu *)departingTrainsMenu
{
    NSMenu *departingTrainsMenu = [[NSMenu alloc] initWithTitle:@"Trains"];
    departingTrainsMenu.delegate = self;
    
    NSInteger i = 0;
    for (MATrain *train in _trains) {
        MATrainWaypoint *waypoint = [train.waypoints lastObject];
        
        NSMenuItem *departingTrain = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%@  %@ %@",
                                                                        [self.timeFormatter stringFromDate:waypoint.scheduledDepartureTime],
                                                                        train.name,
                                                                        train.to.name]
                                                                action:@selector(showTrain:)
                                                         keyEquivalent:@""];
        departingTrain.tag = i++;
        [departingTrainsMenu addItem:departingTrain];
    }
    
    [departingTrainsMenu insertItem:[NSMenuItem separatorItem] atIndex:0];
    
    NSMenuItem *quit = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Quit", @"")
                                                  action:@selector(terminate:)
                                           keyEquivalent:@"q"];
    [departingTrainsMenu insertItem:quit atIndex:0];
    
    NSMenuItem *preferences = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Preferences%C", (unichar)0x2026]
                                                  action:@selector(openPreferences:)
                                           keyEquivalent:@""];
    [departingTrainsMenu insertItem:preferences atIndex:0];
    
    return departingTrainsMenu;
}

- (NSStatusItem *)statusItem
{
    return _statusItem;
}

- (NSDateFormatter *)timeFormatter
{
    if (!_timeFormatter) {
        _timeFormatter = [[NSDateFormatter alloc] init];
        [_timeFormatter setDateFormat:@"HH:mm"];
    }
    return _timeFormatter;
}

/*
 * =======================================
 * Private
 * =======================================
 */

- (void)terminateForReal
{
    [NSApp terminate: nil];
}

@end