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

#import "MATrainStationViewController.h"

#import "MATrainInformationService.h"
#import "MATrainViewController.h"
#import "MALoadTrainStationRequest.h"
#import "MATrain.h"
#import "MATrainStation.h"

typedef enum {
    kTrainStationViewSectionTrains,
    kTrainStationViewSectionTrainStation,
} MATrainStationViewSection;

@interface MATrainStationViewController (PrivateMethods)
- (void)populateTrainList;

@property (readonly) MATrainInformationService *service;
@property (readonly) UIActivityIndicatorView *activityIndicator;
@property (readonly) NSDateFormatter *timeFormatter;
@property (readonly) MALoadTrainStationRequest *request;
@property (readonly) NSMutableArray *trains;
@end

@implementation MATrainStationViewController

@synthesize navigationController=_navigationController;
@synthesize trainController=_trainController;
@synthesize tableView=_tableView;
@synthesize trainStation=_trainStation;
@synthesize trainTypeControl=_trainTypeControl;
@synthesize resetDataWhenViewWillAppear=_resetDataWhenViewWillAppear;

/*
 * =======================================
 * View controller
 * =======================================
 */

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    _trains = [[NSMutableArray alloc] init];
    
    _trainTypeSelection = kTrainTypeSelectionAll;
    self.tableView.tableFooterView = self.activityIndicator;
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    self.navigationController = nil;
    self.trainController = nil;
    self.trainStation = nil;
    self.tableView = nil;
    self.trainTypeControl = nil;
    
    _service = nil;
    
    [_request cancel];
    _request = nil;
    _trains = nil;
    _filteredTrainList = nil;
    
    _activityIndicator = nil;
    
    _timeFormatter = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    self.navigationItem.title = self.trainStation.name;
    
    if (self.resetDataWhenViewWillAppear) {
        self.resetDataWhenViewWillAppear = NO;
        
        [_trains removeAllObjects];
        [_filteredTrainList removeAllObjects];
    }
    [self.tableView reloadData];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    if (_request) {
        [_request cancel];
        _request = nil;
        
        [self.activityIndicator stopAnimating];
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    __weak MATrainStationViewController *weakSelf = self;
    _request = [self.service loadTrainStationWithIdentifier:self.trainStation.identifier];
    _request.onCompletion = ^(void) {
        [weakSelf.activityIndicator stopAnimating];
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        
        NSDate *now = [[NSDate alloc] init];
        
        [weakSelf.trains removeAllObjects];
        
        BOOL foundEnd = NO;
        
        for (NSInteger i=[weakSelf.request.trains count] - 1; i >= 0; i--) {
            MATrain *train = [weakSelf.request.trains objectAtIndex:i];
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
            if (![train.to.identifier isEqualToString:weakSelf.trainStation.identifier]) {
                [weakSelf.trains insertObject:train atIndex:0];
            }
        }
        
        [weakSelf populateTrainList];
        [weakSelf.tableView reloadData];
    };
    _request.onFailure = ^(void) {
        [weakSelf.activityIndicator stopAnimating];
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                        message:@"Error loading the train station."
                                                       delegate:nil
                                              cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
        [alert show];
    };
    [_request start];
    [_activityIndicator startAnimating];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
}

/*
 * =======================================
 * Handling the train types
 * =======================================
 */

- (IBAction)chooseTrainType:(id)sender
{
    switch (self.trainTypeControl.selectedSegmentIndex) {
        case kTrainTypeSelectionAll:
            _trainTypeSelection = kTrainTypeSelectionAll;
            break;
            
        case kTrainTypeSelectionLocal:
            _trainTypeSelection = kTrainTypeSelectionLocal;
            break;
            
        case kTrainTypeSelectionLongDistance:
            _trainTypeSelection = kTrainTypeSelectionLongDistance;
            break;
            
        default:
            break;
    }
    
    [self populateTrainList];
    [self.tableView reloadData];
}

- (void)populateTrainList
{
    _filteredTrainList = [[NSMutableArray alloc] init];
    
    for (id t in _trains) {
        MATrain *train = (MATrain *)t;
        
        if (_trainTypeSelection == kTrainTypeSelectionAll) {
            [_filteredTrainList addObject:train];
        } else if (_trainTypeSelection == kTrainTypeSelectionLocal &&
                   train.type == MATrainTypeLocalTrain) {
            [_filteredTrainList addObject:train];
        } else if (_trainTypeSelection == kTrainTypeSelectionLongDistance &&
                   train.type == MATrainTypeLongDistanceTrain) {
            [_filteredTrainList addObject:train];
        }
    }
}

/*
 * =======================================
 * Table view
 * =======================================
 */

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == kTrainStationViewSectionTrainStation) {
        return 1;
    } else if (section == kTrainStationViewSectionTrains) {
        return [_filteredTrainList count];
    }
    return 0;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	if (section == kTrainStationViewSectionTrains) {
		return @"Departures";
	}
	return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    if (indexPath.section == kTrainStationViewSectionTrainStation) {
        static NSString *CellIdentifier = @"MATrainStationViewCell";
        
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        }
        
        cell.textLabel.text = @"Show station on a Map...";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if (indexPath.section == kTrainStationViewSectionTrains) {
        static NSString *CellIdentifier = @"MATrainStationTrainsViewCell";
        
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        }
        
        MATrain *train = [_filteredTrainList objectAtIndex:indexPath.row];
        MATrainWaypoint *waypoint = [train.waypoints lastObject];
        cell.textLabel.text = [NSString stringWithFormat:@"%@: %@",
                               train.identifier, train.to.name];
        
        NSMutableString *detailTextLabelText = [[NSMutableString alloc] init];
        [detailTextLabelText appendString:[NSString stringWithFormat:@"%@",
                                           [self.timeFormatter stringFromDate:waypoint.scheduledDepartureTime]]];
        
        int minutesLate = train.timeDifferenceToScheduledTimeInSeconds / 60;
        if (minutesLate > 0) {
            [detailTextLabelText appendString:[NSString stringWithFormat:@"      Late: %i minute%@",
                                               minutesLate, (minutesLate > 1 ? @"s" : @"")]];
        }
        
        cell.detailTextLabel.text = detailTextLabelText;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == kTrainStationViewSectionTrainStation) {
        CLLocationCoordinate2D coordinate = _request.trainStation.location.coordinate;
        if (coordinate.latitude > 0 && coordinate.longitude > 0) {
            NSString *urlString = [NSString stringWithFormat:@"http://maps.google.com/maps?q=%f,%f", 
                                   coordinate.latitude, coordinate.longitude];
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlString]];
        } else {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Location not available"
                                                            message:@"Train station location is unknown."
                                                           delegate:nil
                                                  cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
            [alert show];
        }
    } else if (indexPath.section == kTrainStationViewSectionTrains) {
        self.trainController.train = [_filteredTrainList objectAtIndex:indexPath.row];
        [self.navigationController pushViewController:self.trainController animated:YES];
    }
}

/*
 * =======================================
 * Properties
 * =======================================
 */

- (MATrainInformationService *)service
{
    if (!_service) {
        _service = [[MATrainInformationService alloc] init];
    }
    return _service;
}

- (UIActivityIndicatorView *)activityIndicator
{
    if (!_activityIndicator) {
        _activityIndicator = [UIActivityIndicatorView new];
        _activityIndicator.frame = CGRectMake(0.0, 0.0, 40.0, 40.0);
        _activityIndicator.hidesWhenStopped = YES;
    }
    return _activityIndicator;
}

- (NSDateFormatter *)timeFormatter
{
    if (!_timeFormatter) {
        _timeFormatter = [[NSDateFormatter alloc] init];
        [_timeFormatter setDateFormat:@"HH:mm"];
    }
    return _timeFormatter;
}

- (MALoadTrainStationRequest *)request
{
    return _request;
}

- (NSMutableArray *)trains
{
    return _trains;
}

@end
