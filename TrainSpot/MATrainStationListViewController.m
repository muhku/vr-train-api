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

#import "MATrainStationListViewController.h"

#import "MATrainStationViewController.h"
#import "MATrainStation.h"
#import "MATrainInformationService.h"

typedef enum {
    kMATrainStationListViewSectionNearest,
    kMATrainStationListViewSectionAll,
} MATrainStationListViewSection;

@interface MATrainStationListViewController (PrivateMethods)

@property (readonly) MATrainInformationService *service;
@property (readonly) NSMutableArray *trainStations;
@property (readonly) CLLocationManager *locationManager;

@end

@implementation MATrainStationListViewController

@synthesize navigationController=_navigationController;
@synthesize trainStationController=_trainStationController;
@synthesize searchBar=_searchBar;

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
    
    if ([CLLocationManager locationServicesEnabled]) {
        [self.locationManager startUpdatingLocation];
    }
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    
    _service = nil;
    _trainStations = nil;
    
    [_locationManager stopUpdatingLocation];
    _locationManager = nil;
    _currentLocation = nil;
    _nearestTrainStations = nil;
    
    self.navigationController = nil;
    self.trainStationController = nil;
    self.searchBar = nil;
}

/*
 * =======================================
 * Search bar delegate
 * =======================================
 */

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar
{
    [self.searchBar setShowsCancelButton:YES animated:YES];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    [self.searchBar setShowsCancelButton:NO animated:YES];
	self.searchBar.text = @"";
	[self.searchBar resignFirstResponder];
	
    _trainStations = self.service.trainStations;
    [self.tableView reloadData];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{	
	[self.searchBar setShowsCancelButton:NO animated:YES];
    [self.searchBar resignFirstResponder];
	
    _trainStations = [self.service searchTrainStationsByKeyword:self.searchBar.text];
    [self.tableView reloadData];
}

/*
 * =======================================
 * Location handling
 * =======================================
 */

-(void)locationManager:(CLLocationManager *)manager
   didUpdateToLocation:(CLLocation *)newLocation
          fromLocation:(CLLocation *)oldLocation
{
    [self.locationManager stopUpdatingLocation];
    
    _currentLocation = newLocation;
    _nearestTrainStations = [self.service nearestTrainStationFromLocation:_currentLocation];
    [self.tableView reloadData];
} 

-(void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    [self.locationManager stopUpdatingLocation];
}

/*
 * =======================================
 * Table view
 * =======================================
 */

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	if (section == kMATrainStationListViewSectionNearest) {
		return @"Nearest stations";
	} else if (section == kMATrainStationListViewSectionAll) {
        return @"All stations";
    }
	return nil;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == kMATrainStationListViewSectionNearest) {
        return [_nearestTrainStations count];
    } else if (section == kMATrainStationListViewSectionAll) {
        return [self.trainStations count];
    }
    return 0;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    if (indexPath.section == kMATrainStationListViewSectionNearest) {
        static NSString *CellIdentifier = @"MATrainStationListViewCellNearest";
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        }
        
        MATrainStation *station = [_nearestTrainStations objectAtIndex:indexPath.row];
        cell.textLabel.text = station.name;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%f km", station.distanceFromUserGivenPoint];
    } else if (indexPath.section == kMATrainStationListViewSectionAll) {
        static NSString *CellIdentifier = @"MATrainStationListViewCellAll";
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        }
    
        MATrainStation *station = [self.trainStations objectAtIndex:indexPath.row];
        cell.textLabel.text = station.name;
    }
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == kMATrainStationListViewSectionNearest) {
        MATrainStation *trainStation = [_nearestTrainStations objectAtIndex:indexPath.row];
        self.trainStationController.trainStation = trainStation;
        self.trainStationController.resetDataWhenViewWillAppear = YES;
        [self.navigationController pushViewController:self.trainStationController animated:YES];
    } else if (indexPath.section == kMATrainStationListViewSectionAll) {
        MATrainStation *trainStation = [self.trainStations objectAtIndex:indexPath.row];
        self.trainStationController.trainStation = trainStation;
        self.trainStationController.resetDataWhenViewWillAppear = YES;
        [self.navigationController pushViewController:self.trainStationController animated:YES];
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

- (NSMutableArray *)trainStations
{
    if (!_trainStations) {
        _trainStations = self.service.trainStations;
    }
    return _trainStations;
}

- (CLLocationManager *)locationManager
{
    if (!_locationManager) {
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation;
        _locationManager.delegate = self;
    }
    return _locationManager;
}

@end
