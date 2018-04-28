//
//  SettingsViewController.m
//  piwigo
//
//  Created by Spencer Baker on 1/20/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "SettingsViewController.h"
#import "SessionService.h"
#import "AppDelegate.h"
#import "Model.h"
#import "SelectPrivacyViewController.h"
#import "TextFieldTableViewCell.h"
#import "ButtonTableViewCell.h"
#import "LabelTableViewCell.h"
#import "AboutViewController.h"
#import "ClearCache.h"
#import "SliderTableViewCell.h"
#import "SwitchTableViewCell.h"
#import "AlbumService.h"
#import "CategorySortViewController.h"
#import "PiwigoImageData.h"
#import "DefaultImageSizeViewController.h"
#import "DefaultThumbnailSizeViewController.h"
#import "ReleaseNotesViewController.h"
#import "ImagesCollection.h"

typedef enum {
	SettingsSectionServer,
	SettingsSectionLogout,
	SettingsSectionThumbnails,
    SettingsSectionImages,
	SettingsSectionImageUpload,
    SettingsSectionCache,
    SettingsSectionColor,
	SettingsSectionAbout,
	SettingsSectionCount
} SettingsSection;

typedef enum {
	kImageUploadSettingAuthor
} kImageUploadSetting;

@interface SettingsViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, SelectPrivacyDelegate, CategorySortDelegate>

@property (nonatomic, strong) UITableView *settingsTableView;
@property (nonatomic, strong) NSArray *headerHeights;
@property (nonatomic, strong) NSLayoutConstraint *topConstraint;
@property (nonatomic, strong) NSLayoutConstraint *tableViewBottomConstraint;

@property (nonatomic, assign) CGFloat previousContentYOffset;
@property (nonatomic, assign) CGFloat minContentYOffset;

@end

@implementation SettingsViewController

-(instancetype)init
{
	self = [super init];
	if(self)
	{
        self.headerHeights = @[
							   @44.0,
							   @14.0,
							   @44.0,
                               @44.0,
							   @44.0,
                               @44.0,
							   @44.0,
							   @44.0
							   ];
		
        self.settingsTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
		self.settingsTableView.translatesAutoresizingMaskIntoConstraints = NO;
        self.settingsTableView.backgroundColor = [UIColor clearColor];
		self.settingsTableView.delegate = self;
		self.settingsTableView.dataSource = self;
		[self.view addSubview:self.settingsTableView];
		[self.view addConstraints:[NSLayoutConstraint constraintFillWidth:self.settingsTableView]];
		[self.view addConstraint:[NSLayoutConstraint constraintViewFromTop:self.settingsTableView amount:0]];
		self.tableViewBottomConstraint = [NSLayoutConstraint constraintViewFromBottom:self.settingsTableView amount:0];
		[self.view addConstraint:self.tableViewBottomConstraint];

        // Before starting scrolling
        self.previousContentYOffset = -INFINITY;
}
	return self;
}

-(void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];

    // Background color of the view
    self.view.backgroundColor = [UIColor piwigoBackgroundColor];

    // Navigation bar appearence
    NSDictionary *attributes = @{
                                 NSForegroundColorAttributeName: [UIColor piwigoWhiteCream],
                                 NSFontAttributeName: [UIFont piwigoFontNormal],
                                 };
    self.navigationController.navigationBar.titleTextAttributes = attributes;
    [self.navigationController.navigationBar setTintColor:[UIColor piwigoOrange]];
    [self.navigationController.navigationBar setBarTintColor:[UIColor piwigoBackgroundColor]];
    self.navigationController.navigationBar.barStyle = [Model sharedInstance].isDarkPaletteActive ? UIBarStyleBlack : UIBarStyleDefault;

    // Tab bar appearance
    self.tabBarController.tabBar.barTintColor = [UIColor piwigoBackgroundColor];
    self.tabBarController.tabBar.tintColor = [UIColor piwigoOrange];
    if (@available(iOS 10, *)) {
        self.tabBarController.tabBar.unselectedItemTintColor = [UIColor piwigoTextColor];
    }
    [[UITabBarItem appearance] setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor piwigoTextColor]} forState:UIControlStateNormal];
    [[UITabBarItem appearance] setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor piwigoOrange]} forState:UIControlStateSelected];
    
    // Table view
    self.settingsTableView.separatorColor = [UIColor piwigoSeparatorColor];
    [self.settingsTableView reloadData];
}

-(void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

-(void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    //Reload the tableview on orientation change, to match the new width of the table.
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self.settingsTableView reloadData];
    } completion:nil];
}


#pragma mark - UITableView - headers

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return [self.headerHeights[section] floatValue];
}

-(UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    // Header label
    UILabel *headerLabel = [UILabel new];
    headerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    headerLabel.font = [UIFont piwigoFontBold];
    headerLabel.textColor = [UIColor piwigoHeaderColor];

    // Header text
    switch(section)
    {
        case SettingsSectionServer:
            headerLabel.text = NSLocalizedString(@"settingsHeader_server", @"Piwigo Server");
            break;
        case SettingsSectionThumbnails:
            headerLabel.text = NSLocalizedString(@"settingsHeader_thumbnails", @"Thumbnails");
            break;
        case SettingsSectionImages:
            headerLabel.text = NSLocalizedString(@"settingsHeader_images", @"Images");
            break;
        case SettingsSectionImageUpload:
            headerLabel.text = NSLocalizedString(@"settingsHeader_upload", @"Default Upload Settings");
            break;
        case SettingsSectionCache:
            headerLabel.text = NSLocalizedString(@"settingsHeader_cache", @"Cache Settings (Used/Total)");
            break;
        case SettingsSectionColor:
            headerLabel.text = NSLocalizedString(@"settingsHeader_colors", @"Colors");
            break;
        case SettingsSectionAbout:
            headerLabel.text = NSLocalizedString(@"settingsHeader_about", @"Information");
            break;
    }
    
    // Header height
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont piwigoFontBold]};
    NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
    context.minimumScaleFactor = 1.0;
    CGRect headerRect = [headerLabel.text boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                                       options:NSStringDrawingUsesLineFragmentOrigin
                                                    attributes:attributes
                                                       context:context];
    headerRect.size.height = fmax(44.0, ceil(headerRect.size.height + 10.0));

    // Header view
    UIView *header = [[UIView alloc] initWithFrame:headerRect];
    header.backgroundColor = [UIColor clearColor];
    [header addSubview:headerLabel];
    [header addConstraint:[NSLayoutConstraint constraintViewFromBottom:headerLabel amount:4]];
    if (@available(iOS 11, *)) {
        [header addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[header]-|"
                                                                   options:kNilOptions
                                                                   metrics:nil
                                                                     views:@{@"header" : headerLabel}]];
    } else {
        [header addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[header]-15-|"
                                                                       options:kNilOptions
                                                                       metrics:nil
                                                                         views:@{@"header" : headerLabel}]];
    }
    return header;
}


#pragma mark - UITableView - rows

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return SettingsSectionCount;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger nberOfRows = 0;
    switch(section)
    {
        case SettingsSectionServer:
            nberOfRows = 2;
            break;
        case SettingsSectionLogout:
            nberOfRows = 1;
            break;
        case SettingsSectionThumbnails:
            nberOfRows = 4;
            break;
        case SettingsSectionImages:
            nberOfRows = 1;
            break;
        case SettingsSectionImageUpload:
            nberOfRows = 6 + ([Model sharedInstance].resizeImageOnUpload ? 1 : 0) +
                                ([Model sharedInstance].compressImageOnUpload ? 1 : 0);
            break;
        case SettingsSectionCache:
            nberOfRows = 3;
            break;
        case SettingsSectionColor:
            nberOfRows = 1 + ([Model sharedInstance].isDarkPaletteModeActive ? 1 + ([Model sharedInstance].switchPaletteAutomatically ? 1 : 0) : 0);
            break;
        case SettingsSectionAbout:
            nberOfRows = 5;
            break;
    }
    return nberOfRows;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 44.0;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *tableViewCell = [UITableViewCell new];
	switch(indexPath.section)
	{
		case SettingsSectionServer:      // Piwigo Server
		{
			LabelTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"server"];
			if(!cell)
			{
				cell = [LabelTableViewCell new];
			}
            switch(indexPath.row)
			{
				case 0:
                    cell.leftText = NSLocalizedString(@"settings_server", @"Address");
                    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                    if(self.view.bounds.size.width > 414) {     // i.e. larger than iPhones 6, 7 screen width
                        cell.rightText = [NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName];
                    } else {
                        cell.rightText = [Model sharedInstance].serverName;
                    }
					break;
				case 1:
					cell.leftText = NSLocalizedString(@"settings_username", @"Username");
					if([Model sharedInstance].username.length > 0)
					{
						cell.rightText = [Model sharedInstance].username;
					}
					else
					{
						cell.rightText = NSLocalizedString(@"settings_notLoggedIn", @" - Not Logged In - ");
					}
					break;
			}
			tableViewCell = cell;
			break;
		}
		case SettingsSectionLogout:      // Logout Button
		{
			ButtonTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"button"];
			if(!cell)
			{
				cell = [ButtonTableViewCell new];
			}
			if([Model sharedInstance].username.length > 0)
			{
				cell.buttonText = NSLocalizedString(@"settings_logout", @"Logout");
			}
			else
			{
				cell.buttonText = NSLocalizedString(@"login", @"Login");
			}
			tableViewCell = cell;
			break;
		}

#pragma mark Thumbnails
        case SettingsSectionThumbnails:     // Thumbnails
		{
			switch(indexPath.row)
			{
				case 0:     // Default Sort
				{
					LabelTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"defaultSort"];
					if(!cell)
					{
						cell = [LabelTableViewCell new];
					}
					
                    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                    if(self.view.bounds.size.width > 414) {     // i.e. larger than iPhones 6,7 Plus screen width
                        cell.leftText = NSLocalizedString(@"defaultImageSort>414px", @"Default Sort of Images");
                    } else if(self.view.bounds.size.width > 320) {     // i.e. larger than iPhone 5 screen width
                        cell.leftText = NSLocalizedString(@"defaultImageSort>320px", @"Default Sort");
                    } else {
                        cell.leftText = NSLocalizedString(@"defaultImageSort", @"Sort");
                    }
					cell.rightText = [CategorySortViewController getNameForCategorySortType:[Model sharedInstance].defaultSort];
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

                    tableViewCell = cell;
					break;
				}
				case 1:     // Default Thumbnail File
				{
					LabelTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"defaultThumbnailFile"];
					if(!cell) {
						cell = [LabelTableViewCell new];
					}
					
                    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                    if(self.view.bounds.size.width > 375) {     // i.e. larger than iPhones 6,7 screen width
                        cell.leftText = NSLocalizedString(@"defaultThumbnailFile>414px", @"Thumbnail Image File");
                    } else if(self.view.bounds.size.width > 320) {     // i.e. larger than iPhone 5 screen width
                        cell.leftText = NSLocalizedString(@"defaultThumbnailFile>320px", @"Thumbnail File");
                    } else {
                        cell.leftText = NSLocalizedString(@"defaultThumbnailFile", @"File");
                    }
					cell.rightText = [PiwigoImageData nameForThumbnailSizeType:(kPiwigoImageSize)[Model sharedInstance].defaultThumbnailSize];
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

					tableViewCell = cell;
					break;
				}
                case 2:     // Default Thumbnail Size
                {
                    SliderTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"defaultThumbnailSize"];
                    if(!cell)
                    {
                        cell = [SliderTableViewCell new];
                    }
                    if(self.view.bounds.size.width > 375) {     // i.e. larger than iPhones 6,7 screen width
                        cell.sliderName.text = NSLocalizedString(@"defaultThumbnailSize>414px", @"Default Size of Thumbnails");
                    } else if(self.view.bounds.size.width > 320) {     // i.e. larger than iPhone 5 screen width
                        cell.sliderName.text = NSLocalizedString(@"defaultThumbnailSize>320px", @"Thumbnails Size");
                    } else {
                        cell.sliderName.text = NSLocalizedString(@"defaultThumbnailSize", @"Size");
                    }
                    
                    NSInteger minNberOfImages = [ImagesCollection numberOfImagesPerRowForViewInPortrait:self.view withMaxWidth:kThumbnailFileSize];
                    cell.slider.minimumValue = 1;
                    cell.slider.maximumValue = 1 + minNberOfImages; // Allows to double the number of thumbnails
                    cell.incrementSliderBy = 1;
                    cell.sliderCountPrefix = @"";
                    cell.sliderCountSuffix = [NSString stringWithFormat:@"/%d", (int)cell.slider.maximumValue];
                    cell.sliderValue = 2 * minNberOfImages - [Model sharedInstance].thumbnailsPerRowInPortrait + 1;
                    [cell.slider addTarget:self action:@selector(updateThumbnailSize:) forControlEvents:UIControlEventValueChanged];
                    
                    tableViewCell = cell;
                    break;
                }
                case 3:     // Display titles on thumbnails
                {
                    SwitchTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"titles"];
                    if(!cell)
                    {
                        cell = [SwitchTableViewCell new];
                    }
                    
                    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                    if(self.view.bounds.size.width > 320) {
                        cell.leftLabel.text = NSLocalizedString(@"settings_displayTitles>320px", @"Display Titles on Thumbnails");
                    } else {
                        cell.leftLabel.text = NSLocalizedString(@"settings_displayTitles", @"Titles on Thumbnails");
                    }
                    [cell.cellSwitch setOn:[Model sharedInstance].displayImageTitles];
                    cell.cellSwitchBlock = ^(BOOL switchState) {
                        [Model sharedInstance].displayImageTitles = switchState;
                        [[Model sharedInstance] saveToDisk];
                    };
                    
                    tableViewCell = cell;
                    break;
                }
			}
			break;
		}

#pragma mark Images
        case SettingsSectionImages:     // Images
        {
            switch(indexPath.row)
            {
                case 0:     // Default Size of Previewed Images
                {
                    LabelTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"defaultPreviewFile"];
                    if(!cell) {
                        cell = [LabelTableViewCell new];
                    }
                    
                    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                    if(self.view.bounds.size.width > 375) {     // i.e. larger than iPhones 6,7 screen width
                        cell.leftText = NSLocalizedString(@"defaultPreviewFile>414px", @"Preview Image File");
                    } else if(self.view.bounds.size.width > 320) {     // i.e. larger than iPhone 5 screen width
                        cell.leftText = NSLocalizedString(@"defaultPreviewFile>320px", @"Preview File");
                    } else {
                        cell.leftText = NSLocalizedString(@"defaultPreviewFile", @"Preview");
                    }
                    cell.rightText = [PiwigoImageData nameForImageSizeType:(kPiwigoImageSize)[Model sharedInstance].defaultImagePreviewSize withAdvice:NO];
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    
                    tableViewCell = cell;
                    break;
                }
            }
            break;
        }

#pragma mark Default Upload Settings
        case SettingsSectionImageUpload:     // Default Upload Settings
		{
			switch(indexPath.row)
			{
				case 0:     // Author Name
				{
					TextFieldTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"uploadSettingsField"];
					if(!cell)
					{
						cell = [TextFieldTableViewCell new];
					}
					
                    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                    if(self.view.bounds.size.width > 320) {     // i.e. larger than iPhone 5 screen width
                        cell.labelText = NSLocalizedString(@"settings_defaultAuthor>320px", @"Author Name");
                    } else {
                        cell.labelText = NSLocalizedString(@"settings_defaultAuthor", @"Author");
                    }
					cell.rightTextField.text = [Model sharedInstance].defaultAuthor;
					cell.rightTextField.placeholder = NSLocalizedString(@"settings_defaultAuthorPlaceholder", @"Author Name");
					cell.rightTextField.delegate = self;
					cell.rightTextField.tag = kImageUploadSettingAuthor;
					
					tableViewCell = cell;
					break;
				}
				case 1:     // Privacy Level
				{
					LabelTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"privacy"];
					if(!cell)
					{
						cell = [LabelTableViewCell new];
					}
					
                    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                    if(self.view.bounds.size.width > 414) {     // i.e. larger than iPhones 6,7 Plus screen width
                        cell.leftText = NSLocalizedString(@"settings_defaultPrivacy>414px", @"Who Can See the Media?");
                    } else {
                        cell.leftText = NSLocalizedString(@"settings_defaultPrivacy", @"Privacy");
                    }
					cell.rightText = [[Model sharedInstance] getNameForPrivacyLevel:[Model sharedInstance].defaultPrivacyLevel];
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

					tableViewCell = cell;
					break;
				}
                case 2:     // Strip private Metadata
                {
                    SwitchTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"gps"];
                    if(!cell) {
                        cell = [SwitchTableViewCell new];
                    }
                    
                    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                    if(self.view.bounds.size.width > 414) {     // i.e. larger than iPhones 6,7 screen width
                        cell.leftLabel.text = NSLocalizedString(@"settings_stripGPSdata>375px", @"Strip Private Metadata Before Upload");
                    } else {
                        cell.leftLabel.text = NSLocalizedString(@"settings_stripGPSdata", @"Strip Private Metadata");
                    }
                    [cell.cellSwitch setOn:[Model sharedInstance].stripGPSdataOnUpload];
                    cell.cellSwitchBlock = ^(BOOL switchState) {
                        [Model sharedInstance].stripGPSdataOnUpload = switchState;
                        [[Model sharedInstance] saveToDisk];
                    };
                   
                    tableViewCell = cell;
                    break;
                }
				case 3:     // Resize Before Upload
				{
					SwitchTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"resize"];
					if(!cell) {
						cell = [SwitchTableViewCell new];
					}
					
                    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                    if(self.view.bounds.size.width > 375) {     // i.e. larger than iPhones 6,7 screen width
                        cell.leftLabel.text = NSLocalizedString(@"settings_photoResize>375px", @"Resize Image Before Upload");
                    } else {
                        cell.leftLabel.text = NSLocalizedString(@"settings_photoResize", @"Resize Before Upload");
                    }
					[cell.cellSwitch setOn:[Model sharedInstance].resizeImageOnUpload];
					cell.cellSwitchBlock = ^(BOOL switchState) {
                        // Number of rows will change accordingly
                        [Model sharedInstance].resizeImageOnUpload = switchState;
                        // Store modified setting
                        [[Model sharedInstance] saveToDisk];
                        // Position of the row that should be added/removed
                        NSIndexPath *rowAtIndexPath = [NSIndexPath indexPathForRow:4
                                                                         inSection:SettingsSectionImageUpload];
                        if(switchState) {
                            // Insert row in existing table
                            [self.settingsTableView insertRowsAtIndexPaths:@[rowAtIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                        } else {
                           // Remove row in existing table
                            [self.settingsTableView deleteRowsAtIndexPaths:@[rowAtIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                        }
					};
					
					tableViewCell = cell;
					break;
				}
                case 4:     // Image Size slider or Compress Before Upload switch
                {
                    if ([Model sharedInstance].resizeImageOnUpload) {
                        SliderTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"photoSize"];
                        if(!cell)
                        {
                            cell = [SliderTableViewCell new];
                        }
                        cell.sliderName.text = NSLocalizedString(@"settings_photoSize", @"> Size");
                        cell.slider.minimumValue = 5;
                        cell.slider.maximumValue = 100;
                        cell.sliderCountPrefix = @"";
                        cell.sliderCountSuffix = @"%";
                        cell.incrementSliderBy = 5;
                        cell.sliderValue = [Model sharedInstance].photoResize;
                        [cell.slider addTarget:self action:@selector(updateImageSize:) forControlEvents:UIControlEventValueChanged];

                        tableViewCell = cell;
                    } else {
                        SwitchTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"compress"];
                        if(!cell) {
                            cell = [SwitchTableViewCell new];
                        }
                        
                        // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                        if(self.view.bounds.size.width > 375) {     // i.e. larger than iPhones 6,7 screen width
                            cell.leftLabel.text = NSLocalizedString(@"settings_photoCompress>375px", @"Compress Image Before Upload");
                        } else {
                            cell.leftLabel.text = NSLocalizedString(@"settings_photoCompress", @"Compress Before Upload");
                        }
                        [cell.cellSwitch setOn:[Model sharedInstance].compressImageOnUpload];
                        cell.cellSwitchBlock = ^(BOOL switchState) {
                            // Number of rows will change accordingly
                            [Model sharedInstance].compressImageOnUpload = switchState;
                            // Store modified setting
                            [[Model sharedInstance] saveToDisk];
                            // Position of the row that should be added/removed (depends on resize option)
                            NSIndexPath *rowAtIndexPath = [NSIndexPath indexPathForRow:(5 + ([Model sharedInstance].resizeImageOnUpload ? 1 : 0))
                                                                             inSection:SettingsSectionImageUpload];
                            if(switchState) {
                                // Insert row in existing table
                                [self.settingsTableView insertRowsAtIndexPaths:@[rowAtIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                            } else {
                                // Remove row in existing table
                                [self.settingsTableView deleteRowsAtIndexPaths:@[rowAtIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                            }
                        };
                        
                        tableViewCell = cell;
                    }
                    break;
                }
                case 5:     // Compress Before Upload switch or Image Quality slider or Delete Image switch
                {
                    if ([Model sharedInstance].resizeImageOnUpload) {
                        SwitchTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"compress"];
                        if(!cell) {
                            cell = [SwitchTableViewCell new];
                        }
                        
                        // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                        if(self.view.bounds.size.width > 375) {     // i.e. larger than iPhones 6,7 screen width
                            cell.leftLabel.text = NSLocalizedString(@"settings_photoCompress>375px", @"Compress Image Before Upload");
                        } else {
                            cell.leftLabel.text = NSLocalizedString(@"settings_photoCompress", @"Compress Before Upload");
                        }
                        [cell.cellSwitch setOn:[Model sharedInstance].compressImageOnUpload];
                        cell.cellSwitchBlock = ^(BOOL switchState) {
                            // Number of rows will change accordingly
                            [Model sharedInstance].compressImageOnUpload = switchState;
                            // Store modified setting
                            [[Model sharedInstance] saveToDisk];
                            // Position of the row that should be added/removed
                            NSIndexPath *rowAtIndexPath = [NSIndexPath indexPathForRow:(5 + ([Model sharedInstance].resizeImageOnUpload ? 1 : 0))
                                                                             inSection:SettingsSectionImageUpload];
                            if(switchState) {
                                // Insert row in existing table
                                [self.settingsTableView insertRowsAtIndexPaths:@[rowAtIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                            } else {
                                // Remove row in existing table
                                [self.settingsTableView deleteRowsAtIndexPaths:@[rowAtIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                            }
                        };
                        
                        tableViewCell = cell;
                    } else if ([Model sharedInstance].compressImageOnUpload) {
                        SliderTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"photoQuality"];
                        if(!cell)
                        {
                            cell = [SliderTableViewCell new];
                        }
                        cell.sliderName.text = NSLocalizedString(@"settings_photoQuality", @"> Quality");
                        cell.slider.minimumValue = 50;
                        cell.slider.maximumValue = 98;
                        cell.sliderCountPrefix = @"";
                        cell.sliderCountSuffix = @"%";
                        cell.incrementSliderBy = 2;
                        cell.sliderValue = [Model sharedInstance].photoQuality;
                        [cell.slider addTarget:self action:@selector(updateImageQuality:) forControlEvents:UIControlEventValueChanged];
                        
                        tableViewCell = cell;
                    } else {
                        SwitchTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"delete"];
                        if(!cell) {
                            cell = [SwitchTableViewCell new];
                        }
                        
                        // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                        if(self.view.bounds.size.width > 414) {     // i.e. larger than iPhones 6,7 screen width
                            cell.leftLabel.text = NSLocalizedString(@"settings_deleteImage>375px", @"Delete Image After Upload");
                        } else {
                            cell.leftLabel.text = NSLocalizedString(@"settings_deleteImage", @"Delete After Upload");
                        }
                        [cell.cellSwitch setOn:[Model sharedInstance].deleteImageAfterUpload];
                        cell.cellSwitchBlock = ^(BOOL switchState) {
                            [Model sharedInstance].deleteImageAfterUpload = switchState;
                            [[Model sharedInstance] saveToDisk];
                        };
                        
                        tableViewCell = cell;
                    }
                    break;
                }
				case 6:     // Image Quality slider or Delete Image switch
				{
                    if ([Model sharedInstance].resizeImageOnUpload && [Model sharedInstance].compressImageOnUpload) {
                        SliderTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"photoQuality"];
                        if(!cell)
                        {
                            cell = [SliderTableViewCell new];
                        }
                        cell.sliderName.text = NSLocalizedString(@"settings_photoQuality", @"> Quality");
                        cell.slider.minimumValue = 50;
                        cell.slider.maximumValue = 98;
                        cell.sliderCountPrefix = @"";
                        cell.sliderCountSuffix = @"%";
                        cell.incrementSliderBy = 2;
                        cell.sliderValue = [Model sharedInstance].photoQuality;
                        [cell.slider addTarget:self action:@selector(updateImageQuality:) forControlEvents:UIControlEventValueChanged];
                        
                        tableViewCell = cell;
                    } else {
                        SwitchTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"delete"];
                        if(!cell) {
                            cell = [SwitchTableViewCell new];
                        }
                        
                        // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                        if(self.view.bounds.size.width > 414) {     // i.e. larger than iPhones 6,7 screen width
                            cell.leftLabel.text = NSLocalizedString(@"settings_deleteImage>375px", @"Delete Image After Upload");
                        } else {
                            cell.leftLabel.text = NSLocalizedString(@"settings_deleteImage", @"Delete After Upload");
                        }
                        [cell.cellSwitch setOn:[Model sharedInstance].deleteImageAfterUpload];
                        cell.cellSwitchBlock = ^(BOOL switchState) {
                            [Model sharedInstance].deleteImageAfterUpload = switchState;
                            [[Model sharedInstance] saveToDisk];
                        };
                        
                        tableViewCell = cell;
                    }
					break;
				}
                case 7:     // Delete image after upload
                {
                    SwitchTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"delete"];
                    if(!cell) {
                        cell = [SwitchTableViewCell new];
                    }
                    
                    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                    if(self.view.bounds.size.width > 414) {     // i.e. larger than iPhones 6,7 screen width
                        cell.leftLabel.text = NSLocalizedString(@"settings_deleteImage>375px", @"Delete Image After Upload");
                    } else {
                        cell.leftLabel.text = NSLocalizedString(@"settings_deleteImage", @"Delete After Upload");
                    }
                    [cell.cellSwitch setOn:[Model sharedInstance].deleteImageAfterUpload];
                    cell.cellSwitchBlock = ^(BOOL switchState) {
                        [Model sharedInstance].deleteImageAfterUpload = switchState;
                        [[Model sharedInstance] saveToDisk];
                    };
                    
                    tableViewCell = cell;
                    break;
                }
			}
			break;
		}

#pragma mark Cache Settings
        case SettingsSectionCache:       // Cache Settings
        {
            switch(indexPath.row)
            {
                case 0:     // Download all Albums at Start
                {
                    SwitchTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"switchCell"];
                    if(!cell)
                    {
                        cell = [SwitchTableViewCell new];
                    }
                    
                    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                    if(self.view.bounds.size.width > 414) {     // i.e. larger than iPhones 6, 7 screen width
                        cell.leftLabel.text = NSLocalizedString(@"settings_loadAllCategories>320px", @"Download all Albums at Start (uncheck if troubles)");
                    } else {
                        cell.leftLabel.text = NSLocalizedString(@"settings_loadAllCategories", @"Download all Albums at Start");
                    }
                    [cell.cellSwitch setOn:[Model sharedInstance].loadAllCategoryInfo];
                    cell.cellSwitchBlock = ^(BOOL switchState) {
                        if(![Model sharedInstance].loadAllCategoryInfo && switchState)
                        {
                            [AlbumService getAlbumListForCategory:-1 OnCompletion:nil onFailure:nil];
                        }
                        
                        [Model sharedInstance].loadAllCategoryInfo = switchState;
                        [[Model sharedInstance] saveToDisk];
                    };
                    
                    tableViewCell = cell;
                    break;
                }
                case 1:     // Disk
                {
                    NSInteger currentDiskSize = [[NSURLCache sharedURLCache] currentDiskUsage];
                    float currentDiskSizeInMB = currentDiskSize / (1024.0f * 1024.0f);
                    SliderTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"sliderSettingsDisk"];
                    if(!cell)
                    {
                        cell = [SliderTableViewCell new];
                    }
                    cell.sliderName.text = NSLocalizedString(@"settings_cacheDisk", @"Disk");
                    cell.slider.minimumValue = 10;
                    cell.slider.maximumValue = 500;
                    
                    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                    if(self.view.bounds.size.width > 375) {     // i.e. larger than iPhones 6,7 screen width
                        cell.sliderCountPrefix = [NSString stringWithFormat:@"%.1f/", currentDiskSizeInMB];
                    } else {
                        cell.sliderCountPrefix = [NSString stringWithFormat:@"%ld/", lroundf(currentDiskSizeInMB)];
                    }
                    cell.sliderCountSuffix = NSLocalizedString(@"settings_cacheMegabytes", @"MB");
                    cell.incrementSliderBy = 10;
                    cell.sliderValue = [Model sharedInstance].diskCache;
                    [cell.slider addTarget:self action:@selector(updateDiskCacheSize:) forControlEvents:UIControlEventValueChanged];
                    
                    tableViewCell = cell;
                    break;
                }
                case 2:     // Memory
                {
                    NSInteger currentMemSize = [[NSURLCache sharedURLCache] currentMemoryUsage];
                    float currentMemSizeInMB = currentMemSize / (1024.0f * 1024.0f);
                    SliderTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"sliderSettingsMem"];
                    if(!cell)
                    {
                        cell = [SliderTableViewCell new];
                    }
                    cell.sliderName.text = NSLocalizedString(@"settings_cacheMemory", @"Memory");
                    cell.slider.minimumValue = 10;
                    cell.slider.maximumValue = 200;
                    
                    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                    if(self.view.bounds.size.width > 375) {     // i.e. larger than iPhone 6,7 screen width
                        cell.sliderCountPrefix = [NSString stringWithFormat:@"%.1f/", currentMemSizeInMB];
                    } else {
                        cell.sliderCountPrefix = [NSString stringWithFormat:@"%ld/", lroundf(currentMemSizeInMB)];
                    }
                    cell.sliderCountSuffix = NSLocalizedString(@"settings_cacheMegabytes", @"MB");
                    cell.incrementSliderBy = 10;
                    cell.sliderValue = [Model sharedInstance].memoryCache;
                    [cell.slider addTarget:self action:@selector(updateMemoryCacheSize:) forControlEvents:UIControlEventValueChanged];
                    
                    tableViewCell = cell;
                    break;
                }
            }
            break;
        }

#pragma mark Colors
        case SettingsSectionColor:      // Colors
        {
            switch (indexPath.row)
            {
                case 0:     // Dark Palette Mode
                {
                    SwitchTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"darkPalette"];
                    if(!cell) {
                        cell = [SwitchTableViewCell new];
                    }
                    
                    cell.leftLabel.text = NSLocalizedString(@"settings_darkPalette", @"Dark Palette");
                    [cell.cellSwitch setOn:[Model sharedInstance].isDarkPaletteModeActive];
                    cell.cellSwitchBlock = ^(BOOL switchState) {
                        // Number of rows will change accordingly
                        [Model sharedInstance].isDarkPaletteModeActive = switchState;
                        // Position of the row(s) that should be added/removed
                        NSIndexPath *rowAtIndexPath = [NSIndexPath indexPathForRow:1
                                                                         inSection:SettingsSectionColor];
                        NSIndexPath *row2AtIndexPath = [NSIndexPath indexPathForRow:2
                                                                         inSection:SettingsSectionColor];
                        if(switchState) {
                            // Insert row in existing table
                            if ([Model sharedInstance].switchPaletteAutomatically)
                                [self.settingsTableView insertRowsAtIndexPaths:@[rowAtIndexPath,row2AtIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                            else
                                [self.settingsTableView insertRowsAtIndexPaths:@[rowAtIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                        } else {
                            // Remove row in existing table
                            if ([Model sharedInstance].switchPaletteAutomatically)
                                [self.settingsTableView deleteRowsAtIndexPaths:@[rowAtIndexPath,row2AtIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                            else
                                [self.settingsTableView deleteRowsAtIndexPaths:@[rowAtIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                        }
                        // Switch off auto mode if dark palette mode disabled
                        if (!switchState) [Model sharedInstance].switchPaletteAutomatically = NO;
                        // Store modified setting
                        [[Model sharedInstance] saveToDisk];
                        // Refresh table
                        [self.settingsTableView reloadData];
                        // Redraw views in windows
                        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                        [appDelegate screenBrightnessChanged:nil];
                    };
                    
                    tableViewCell = cell;
                    break;
                }
                case 1:     // Switch automatically ?
                {
                    SwitchTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"switchPalette"];
                    if(!cell) {
                        cell = [SwitchTableViewCell new];
                    }
                    
                    cell.leftLabel.text = NSLocalizedString(@"settings_switchPalette", @"Switch Automatically");
                    [cell.cellSwitch setOn:[Model sharedInstance].switchPaletteAutomatically];
                    cell.cellSwitchBlock = ^(BOOL switchState) {
                        // Number of rows will change accordingly
                        [Model sharedInstance].switchPaletteAutomatically = switchState;
                        // Store modified setting
                        [[Model sharedInstance] saveToDisk];
                        // Position of the row that should be added/removed
                        NSIndexPath *rowAtIndexPath = [NSIndexPath indexPathForRow:2
                                                                         inSection:SettingsSectionColor];
                        if(switchState) {
                            // Insert row in existing table
                            [self.settingsTableView insertRowsAtIndexPaths:@[rowAtIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                        } else {
                            // Remove row in existing table
                            [self.settingsTableView deleteRowsAtIndexPaths:@[rowAtIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                        }
                        // Refresh table
                        [self.settingsTableView reloadData];
                        // Redraw views in windows
                        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                        [appDelegate screenBrightnessChanged:nil];
                    };
                    
                    tableViewCell = cell;
                    break;
                }
                case 2:     // Switch at Brightness ?
                {
                    CGFloat currentBrightness = [[UIScreen mainScreen] brightness] * 100;
                    SliderTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"sliderPalette"];
                    if(!cell)
                    {
                        cell = [SliderTableViewCell new];
                    }
                    cell.sliderName.text = NSLocalizedString(@"settings_brightness", @"Brightness");
                    cell.slider.minimumValue = 0;
                    cell.slider.maximumValue = 100;
                    cell.sliderCountPrefix = [NSString stringWithFormat:@"%ld/", lroundf(currentBrightness)];
                    cell.sliderCountSuffix = @"";
                    cell.incrementSliderBy = 1;
                    cell.sliderValue = [Model sharedInstance].switchPaletteThreshold;
                    [cell.slider addTarget:self action:@selector(updatePaletteBrightnessThreshold:) forControlEvents:UIControlEventValueChanged];
                    
                    tableViewCell = cell;
                    break;
                }
            }
            break;
        }

#pragma mark Information
        case SettingsSectionAbout:      // Information
		{
            switch(indexPath.row)
            {
                case 0:     // Support Forum
                {
                    LabelTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"support"];
                    if(!cell)
                    {
                        cell = [LabelTableViewCell new];
                    }
                    
                    cell.leftText = NSLocalizedString(@"settings_supportForum", @"Support Forum");
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
//                    if ([Model sharedInstance].isAppLanguageRTL) {
//                        cell.rightText = @"<";
//                    } else {
//                        cell.rightText = @">";
//                    }
                    
                    tableViewCell = cell;
                    break;
                }
                case 1:     // Rate Piwigo Mobile
                {
                    LabelTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"rate"];
                    if(!cell)
                    {
                        cell = [LabelTableViewCell new];
                    }
                    
                    cell.leftText = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"settings_rateInAppStore", @"Rate Piwigo Mobile"), [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
//                    if ([Model sharedInstance].isAppLanguageRTL) {
//                        cell.rightText = @"<";
//                    } else {
//                        cell.rightText = @">";
//                    }

                    tableViewCell = cell;
                    break;
                }
                case 2:     // Translate Piwigo Mobile
                {
                    LabelTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"translate"];
                    if(!cell)
                    {
                        cell = [LabelTableViewCell new];
                    }
                    
                    cell.leftText = NSLocalizedString(@"settings_translateWithCrowdin", @"Translate Piwigo Mobile");
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
//                    if ([Model sharedInstance].isAppLanguageRTL) {
//                        cell.rightText = @"<";
//                    } else {
//                        cell.rightText = @">";
//                    }

                    tableViewCell = cell;
                    break;
                }
                case 3:     // Release Notes
                {
                    LabelTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"release"];
                    if(!cell)
                    {
                        cell = [LabelTableViewCell new];
                    }
                    
                    cell.leftText = NSLocalizedString(@"settings_releaseNotes", @"Release Notes");
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
//                    if ([Model sharedInstance].isAppLanguageRTL) {
//                        cell.rightText = @"<";
//                    } else {
//                        cell.rightText = @">";
//                    }

                    tableViewCell = cell;
                    break;
                }
                case 4:     // Acknowledgements
                {
                    LabelTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"thanks"];
                    if(!cell)
                    {
                        cell = [LabelTableViewCell new];
                    }
                    
                    cell.leftText = NSLocalizedString(@"settings_acknowledgements", @"Acknowledgements");
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
//                    if ([Model sharedInstance].isAppLanguageRTL) {
//                        cell.rightText = @"<";
//                    } else {
//                        cell.rightText = @">";
//                    }

                    tableViewCell = cell;
                    break;
                }
            }
		}
	}
	
	return tableViewCell;
}


#pragma mark - UITableView - footers

-(CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    // No footer by default (nil => 0 point)
    NSString *footer;
    
    // Any footer text?
    switch(section)
    {
        case SettingsSectionLogout:
            if (([Model sharedInstance].uploadFileTypes != nil) && ([[Model sharedInstance].uploadFileTypes length] > 0)) {
                footer = [NSString stringWithFormat:@"%@: %@.", NSLocalizedString(@"settingsFooter_formats", @"The server accepts the following file formats"), [[Model sharedInstance].uploadFileTypes stringByReplacingOccurrencesOfString:@"," withString:@", "]];
            }
            break;
    }
    
    // Footer height?
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont piwigoFontSmall]};
    NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
    context.minimumScaleFactor = 1.0;
    CGRect footerRect = [footer boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                             options:NSStringDrawingUsesLineFragmentOrigin
                                          attributes:attributes
                                             context:context];
    
    return ceil(footerRect.size.height + 10.0);
}

-(UIView*)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    // Footer label
    UILabel *footerLabel = [UILabel new];
    footerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    footerLabel.font = [UIFont piwigoFontSmall];
    footerLabel.textColor = [UIColor piwigoHeaderColor];
    footerLabel.textAlignment = NSTextAlignmentCenter;
    footerLabel.numberOfLines = 0;
    footerLabel.adjustsFontSizeToFitWidth = NO;
    footerLabel.lineBreakMode = NSLineBreakByWordWrapping;
    
    // Footer text
    switch(section)
    {
        case SettingsSectionLogout:
            if (([Model sharedInstance].uploadFileTypes != nil) && ([[Model sharedInstance].uploadFileTypes length] > 0)) {
                footerLabel.text = [NSString stringWithFormat:@"%@: %@.", NSLocalizedString(@"settingsFooter_formats", @"The server accepts the following file formats"), [[Model sharedInstance].uploadFileTypes stringByReplacingOccurrencesOfString:@"," withString:@", "]];
            }
            break;
    }
    
    // Footer height
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont piwigoFontSmall]};
    NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
    context.minimumScaleFactor = 1.0;
    CGRect footerRect = [footerLabel.text boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                                       options:NSStringDrawingUsesLineFragmentOrigin
                                                    attributes:attributes
                                                       context:context];
    
    // Footer view
    UIView *footer = [[UIView alloc] initWithFrame:footerRect];
    footer.backgroundColor = [UIColor clearColor];
    [footer addSubview:footerLabel];
    [footer addConstraint:[NSLayoutConstraint constraintViewFromTop:footerLabel amount:4]];
    if (@available(iOS 11, *)) {
        [footer addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[footer]-|"
                                                                       options:kNilOptions
                                                                       metrics:nil
                                                                         views:@{@"footer" : footerLabel}]];
    } else {
        [footer addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[footer]-15-|"
                                                                       options:kNilOptions
                                                                       metrics:nil
                                                                         views:@{@"footer" : footerLabel}]];
    }
    
    return footer;
}


#pragma mark - UITableViewDelegate Methods

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	switch(indexPath.section)
	{
		case SettingsSectionServer:         // Piwigo Server
			break;
		case SettingsSectionLogout:         // Logout
			[self logout];
			break;
		case SettingsSectionThumbnails:     // General Settings
		{
			switch(indexPath.row)
			{
				case 0:                     // Sort method selection
				{
					CategorySortViewController *categoryVC = [CategorySortViewController new];
					categoryVC.currentCategorySortType = [Model sharedInstance].defaultSort;
					categoryVC.sortDelegate = self;
					[self.navigationController pushViewController:categoryVC animated:YES];
					break;
				}
				case 1:                     // Thumbnail file selection
				{
					DefaultThumbnailSizeViewController *defaultThumbnailSizeVC = [DefaultThumbnailSizeViewController new];
					[self.navigationController pushViewController:defaultThumbnailSizeVC animated:YES];
					break;
				}
			}
			break;
		}
        case SettingsSectionImages:         // Images
        {
            switch(indexPath.row)
            {
                case 0:                     // Image file selection
                {
                    DefaultImageSizeViewController *defaultImageSizeVC = [DefaultImageSizeViewController new];
                    [self.navigationController pushViewController:defaultImageSizeVC animated:YES];
                    break;
                }
            }
            break;
        }
		case SettingsSectionImageUpload:     // Default upload Settings
			switch(indexPath.row)
			{
				case 1:                      // Default privacy selection
				{
					SelectPrivacyViewController *selectPrivacy = [SelectPrivacyViewController new];
					selectPrivacy.delegate = self;
					[selectPrivacy setPrivacy:[Model sharedInstance].defaultPrivacyLevel];
					[self.navigationController pushViewController:selectPrivacy animated:YES];
					break;
				}
			}
			break;
//        case SettingsSectionCache:       // Cache Settings
//        {
//            switch(indexPath.row)
//            {
//			if(indexPath.row == 2)
//			{
//				[UIAlertView showWithTitle:@"DELETE IMAGE CACHE"
//								   message:@"Are you sure you want to clear your image cache?\nThis will make images take a while to load again."
//						 cancelButtonTitle:@"No"
//						 otherButtonTitles:@[@"Yes"]
//								  tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
//									  if(buttonIndex == 1)
//									  {
//										  // set it to 0 to clear it
//										  NSURLCache *URLCache = [[NSURLCache alloc] initWithMemoryCapacity:0
//																							   diskCapacity:0
//																								   diskPath:nil];
//										  [NSURLCache setSharedURLCache:URLCache];
//										  
//										  // set it back
//										  URLCache = [[NSURLCache alloc] initWithMemoryCapacity:500 * 1024 * 1024
//																				   diskCapacity:500 * 1024 * 1024
//																					   diskPath:nil];
//										  [NSURLCache setSharedURLCache:URLCache];
//									  }
//								  }];
//            }
//            break;
//        }
		case SettingsSectionAbout:       // About — Informations
		{
            switch(indexPath.row)
            {
                case 0:     // Open Piwigo support forum webpage with default browser
                {
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:NSLocalizedString(@"settings_pwgForumURL", @"http://piwigo.org/forum")]];
                    break;
                }
                case 1:     // Open Piwigo App Store page for rating
                {
                    // See https://itunes.apple.com/us/app/piwigo/id472225196?ls=1&mt=8
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"itms-apps://itunes.apple.com/app/piwigo/id472225196?action=write-review"]];
                    break;
                }
                case 2:     // Open Piwigo Crowdin page for translating
                {
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://crowdin.com/project/piwigo-mobile"]];
                    break;
                }
                case 3:     // Open Release Notes page
                {
                    ReleaseNotesViewController *releaseNotesVC = [ReleaseNotesViewController new];
                    [self.navigationController pushViewController:releaseNotesVC animated:YES];
                    break;
                }
                case 4:     // Open Acknowledgements page
                {
                    AboutViewController *aboutVC = [AboutViewController new];
                    [self.navigationController pushViewController:aboutVC animated:YES];
                    break;
                }
            }
		}
	}
}


#pragma mark - Option Methods

-(void)logout
{
	if([Model sharedInstance].username.length > 0)
	{
        // Ask user for confirmation
        UIAlertController* alert = [UIAlertController
                    alertControllerWithTitle:NSLocalizedString(@"logoutConfirmation_title", @"Logout")
                    message:NSLocalizedString(@"logoutConfirmation_message", @"Are you sure you want to logout?")
                    preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* cancelAction = [UIAlertAction
                    actionWithTitle:NSLocalizedString(@"alertNoButton", @"No")
                    style:UIAlertActionStyleCancel
                    handler:^(UIAlertAction * action) {}];
        
        UIAlertAction* logoutAction = [UIAlertAction
                    actionWithTitle:NSLocalizedString(@"alertYesButton", @"Yes")
                    style:UIAlertActionStyleDestructive
                    handler:^(UIAlertAction * action) {
                       [SessionService sessionLogoutOnCompletion:^(NSURLSessionTask *task, BOOL sucessfulLogout) {
                           if(sucessfulLogout)
                           {
                               // Session closed
                               [[Model sharedInstance].sessionManager invalidateSessionCancelingTasks:YES];
                               [Model sharedInstance].imageDownloader = nil;
                               [[Model sharedInstance].imagesSessionManager invalidateSessionCancelingTasks:YES];
                               [Model sharedInstance].hadOpenedSession = NO;
                               
                               // Back to default values
                               [Model sharedInstance].usesCommunityPluginV29 = NO;
                               [Model sharedInstance].hasAdminRights = NO;
                               
                               // Erase cache
                               [ClearCache clearAllCache];
                               AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                               [appDelegate loadLoginView];
                           }
                           else
                           {
                               // Failed, retry ?
                               UIAlertController* alert = [UIAlertController
                                                           alertControllerWithTitle:NSLocalizedString(@"logoutFail_title", @"Logout Failed")
                                                           message:NSLocalizedString(@"logoutFail_message", @"Failed to logout\nTry again?")
                                                           preferredStyle:UIAlertControllerStyleAlert];
                               
                               UIAlertAction* dismissAction = [UIAlertAction
                                                               actionWithTitle:NSLocalizedString(@"alertNoButton", @"No")
                                                               style:UIAlertActionStyleCancel
                                                               handler:^(UIAlertAction * action) {}];
                               
                               UIAlertAction* retryAction = [UIAlertAction
                                                               actionWithTitle:NSLocalizedString(@"alertYesButton", @"Yes")
                                                               style:UIAlertActionStyleDestructive
                                                               handler:^(UIAlertAction * action) {
                                                                   [self logout];
                                                               }];
                               
                               [alert addAction:dismissAction];
                               [alert addAction:retryAction];
                               [self presentViewController:alert animated:YES completion:nil];
                           }
                       } onFailure:^(NSURLSessionTask *task, NSError *error) {
                           // Error message already presented
                       }];
                    }];
        
        [alert addAction:cancelAction];
        [alert addAction:logoutAction];
        [self presentViewController:alert animated:YES completion:nil];
	}
	else
	{
		[ClearCache clearAllCache];
		AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
		[appDelegate loadLoginView];
	}
}


//#pragma mark - UITextFieldDelegate Methods
//
//-(void)keyboardWillChange:(NSNotification*)notification
//{
//    CGRect keyboardRect = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
//    keyboardRect = [self.view convertRect:keyboardRect fromView:nil];
//
//    self.tableViewBottomConstraint.constant = -keyboardRect.size.height;
//}
//
//-(void)keyboardWillDismiss:(NSNotification*)notification
//{
//    self.tableViewBottomConstraint.constant = 0;
//}
//
//-(void)textFieldDidEndEditing:(UITextField *)textField
//{
//    switch(textField.tag)
//    {
//        case kImageUploadSettingAuthor:
//        {
//            [Model sharedInstance].defaultAuthor = textField.text;
//            [[Model sharedInstance] saveToDisk];
//            break;
//        }
//    }
//}


#pragma mark - SelectedPrivacyDelegate Methods

-(void)selectedPrivacy:(kPiwigoPrivacy)privacy
{
	[Model sharedInstance].defaultPrivacyLevel = privacy;
	[[Model sharedInstance] saveToDisk];
}


#pragma mark - CategorySortDelegate Methods

-(void)didSelectCategorySortType:(kPiwigoSortCategory)sortType
{
	[Model sharedInstance].defaultSort = sortType;
	[[Model sharedInstance] saveToDisk];
	[self.settingsTableView reloadData];
}


#pragma mark - Sliders changed value Methods

- (IBAction)updateThumbnailSize:(id)sender
{
    SliderTableViewCell *thumbnailsSizeCell = (SliderTableViewCell*)[self.settingsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:2 inSection:SettingsSectionThumbnails]];
    NSInteger minNberOfImages = [ImagesCollection numberOfImagesPerRowForViewInPortrait:self.view withMaxWidth:kThumbnailFileSize];
    [Model sharedInstance].thumbnailsPerRowInPortrait = 2 * minNberOfImages - ([thumbnailsSizeCell getCurrentSliderValue] - 1);
    [[Model sharedInstance] saveToDisk];
}

- (IBAction)updateImageSize:(id)sender
{
    SliderTableViewCell *photoSizeCell = (SliderTableViewCell*)[self.settingsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:4 inSection:SettingsSectionImageUpload]];
    [Model sharedInstance].photoResize = [photoSizeCell getCurrentSliderValue];
    [[Model sharedInstance] saveToDisk];
}

- (IBAction)updateImageQuality:(id)sender
{
    NSInteger row = 5 + ([Model sharedInstance].resizeImageOnUpload ? 1 : 0);
    SliderTableViewCell *photoQualityCell = (SliderTableViewCell*)[self.settingsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:SettingsSectionImageUpload]];
    [Model sharedInstance].photoQuality = [photoQualityCell getCurrentSliderValue];
    [[Model sharedInstance] saveToDisk];
}

- (IBAction)updatePaletteBrightnessThreshold:(id)sender
{
    SliderTableViewCell *sliderSettingPalette = (SliderTableViewCell*)[self.settingsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:2 inSection:SettingsSectionColor]];
    [Model sharedInstance].switchPaletteThreshold = [sliderSettingPalette getCurrentSliderValue];
    [[Model sharedInstance] saveToDisk];

    // Update palette if needed
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate screenBrightnessChanged:nil];
}

- (IBAction)updateDiskCacheSize:(id)sender
{
    SliderTableViewCell *sliderSettingsDisk = (SliderTableViewCell*)[self.settingsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:SettingsSectionCache]];
    [Model sharedInstance].diskCache = [sliderSettingsDisk getCurrentSliderValue];
    [[Model sharedInstance] saveToDisk];
    
    [NSURLCache sharedURLCache].diskCapacity = [Model sharedInstance].diskCache * 1024*1024;
}

- (IBAction)updateMemoryCacheSize:(id)sender
{
    SliderTableViewCell *sliderSettingsMem = (SliderTableViewCell*)[self.settingsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:2 inSection:SettingsSectionCache]];
    [Model sharedInstance].memoryCache = [sliderSettingsMem getCurrentSliderValue];
    [[Model sharedInstance] saveToDisk];
    
    [NSURLCache sharedURLCache].memoryCapacity = [Model sharedInstance].memoryCache * 1024*1024;
}

#pragma mark - UIScrollViewDelegate Methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    // NOP if content not yet complete
    if (scrollView.contentSize.height == 0) return;
    
    // First time ever, set parameters
    if (self.previousContentYOffset == -INFINITY) {
        self.minContentYOffset = scrollView.contentOffset.y;
    }
    
    // Initialisation
    CGFloat y = scrollView.contentOffset.y - self.minContentYOffset;
    CGFloat yMax = fmaxf(scrollView.contentSize.height - scrollView.frame.size.height + self.tabBarController.tabBar.bounds.size.height - self.minContentYOffset, self.minContentYOffset);
    //    NSLog(@"contentSize:%g, frameSize:%g", scrollView.contentSize.height, scrollView.frame.size.height);
    //    NSLog(@"offset=%3.0f, y=%3.0f, yMax=%3.0f", self.minContentYOffset, y, yMax);
    
    // Depends on current tab bar visibility
    if ([self tabBarIsVisible]) {
        // Hide the tab bar when scrolling down
        if ((y > self.previousContentYOffset) &&        // Scrolling down
            (y > 44) && (y < yMax - 44))                // from the top
        {
            // User scrolls content to the bootm, starting from the top
            [self setTabBarVisible:NO animated:YES completion:nil];
        }
    } else {
        // Decide whether tab bar should be shown
        if ((y < self.previousContentYOffset) &&        // Scrolling up
            (y < yMax - 44))                            // above the bottom
        {
            // User scrolls content near the top or bottom
            [self setTabBarVisible:YES animated:YES completion:nil];
        }
        else if ((y > self.previousContentYOffset) &&   // Scrolling down
                 (y > yMax - 44))                       // near the bottom
        {
            // User scrolls content to the bootm, starting from the top
            [self setTabBarVisible:YES animated:YES completion:nil];
        }
    }
    
    // Store actual position for next time
    self.previousContentYOffset = y;
}

- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView
{
    // User tapped the status bar
    __weak typeof(self) weakSelf = self;
    [self setTabBarVisible:YES animated:YES completion:^(BOOL finished) {
        weakSelf.previousContentYOffset = scrollView.contentOffset.y;
    }];
    
    return YES;
}

// Pass a param to describe the state change, an animated flag and a completion block matching UIView animations completion
- (void)setTabBarVisible:(BOOL)visible animated:(BOOL)animated completion:(void (^)(BOOL))completion {
    
    // bail if the current state matches the desired state
    if ([self tabBarIsVisible] == visible) return (completion)? completion(YES) : nil;
    
    // get a frame calculation ready
    CGRect frame = self.tabBarController.tabBar.frame;
    CGFloat height = frame.size.height;
    CGFloat offsetY = (visible)? -height : height;
    
    // zero duration means no animation
    CGFloat duration = (animated)? 0.3 : 0.0;
    
    [UIView animateWithDuration:duration animations:^{
        self.tabBarController.tabBar.frame = CGRectOffset(frame, 0, offsetY);
    } completion:completion];
}

// Getter to know the current state
- (BOOL)tabBarIsVisible {
    return self.tabBarController.tabBar.frame.origin.y < CGRectGetMaxY(self.view.frame);
}

@end


