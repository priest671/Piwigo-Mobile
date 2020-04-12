//
//  AlbumImagesViewController.m
//  piwigo
//
//  Created by Spencer Baker on 1/27/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Photos/Photos.h>
//#import <StoreKit/StoreKit.h>

#import "AlbumData.h"
#import "AlbumImagesViewController.h"
#import "AlbumService.h"
#import "AsyncImageActivityItemProvider.h"
#import "AsyncVideoActivityItemProvider.h"
#import "AppDelegate.h"
#import "CategoriesData.h"
#import "CategoryCollectionViewCell.h"
#import "CategoryHeaderReusableView.h"
#import "DiscoverImagesViewController.h"
#import "EditImageParamsViewController.h"
#import "FavoritesImagesViewController.h"
#import "ImageCollectionViewCell.h"
#import "ImageDetailViewController.h"
#import "ImageService.h"
#import "ImagesCollection.h"
#import "LocalAlbumsViewController.h"
#import "MBProgressHUD.h"
#import "Model.h"
#import "MoveCategoryViewController.h"
#import "MoveImageViewController.h"
#import "NetworkHandler.h"
#import "NberImagesFooterCollectionReusableView.h"
#import "PhotosFetch.h"
#import "SAMKeychain.h"
#import "SearchImagesViewController.h"

//#ifndef DEBUG_LIFECYCLE
//#define DEBUG_LIFECYCLE
//#endif

CGFloat const kRadius = 25.0;
CGFloat const kDeg2Rad = 3.141592654 / 180.0;
NSString * const kPiwigoNotificationBackToDefaultAlbum = @"kPiwigoNotificationBackToDefaultAlbum";

@interface AlbumImagesViewController () <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate, UIToolbarDelegate, UISearchControllerDelegate, UISearchResultsUpdating, UISearchBarDelegate, UITextFieldDelegate, ImageDetailDelegate, EditImageParamsDelegate, MoveImagesDelegate, CategorySortDelegate, CategoryCollectionViewCellDelegate, AsyncImageActivityItemProviderDelegate, TagSelectorViewDelegate, ChangedSettingsDelegate>

@property (nonatomic, strong) UICollectionView *imagesCollection;
@property (nonatomic, strong) AlbumData *albumData;
@property (nonatomic, strong) NSIndexPath *imageOfInterest;
@property (nonatomic, assign) BOOL isCachedAtInit;
@property (nonatomic, strong) NSString *currentSort;
@property (nonatomic, assign) BOOL loadingImages;
@property (nonatomic, assign) BOOL displayImageTitles;
@property (nonatomic, strong) UIViewController *hudViewController;

@property (nonatomic, strong) UIBarButtonItem *settingsBarButton;
@property (nonatomic, strong) UIBarButtonItem *discoverBarButton;
@property (nonatomic, strong) UIBarButtonItem *selectBarButton;
@property (nonatomic, strong) UIBarButtonItem *cancelBarButton;
@property (nonatomic, strong) UIBarButtonItem *spaceBetweenButtons;
@property (nonatomic, strong) UIBarButtonItem *editBarButton;
@property (nonatomic, strong) UIBarButtonItem *deleteBarButton;
@property (nonatomic, strong) UIBarButtonItem *shareBarButton;
@property (nonatomic, strong) UIBarButtonItem *moveBarButton;
@property (nonatomic, strong) UIButton *addButton;
@property (nonatomic, strong) UIButton *createAlbumButton;
@property (nonatomic, strong) UIButton *uploadImagesButton;
@property (nonatomic, strong) UIAlertAction *createAlbumAction;
@property (nonatomic, strong) UIButton *homeAlbumButton;

@property (nonatomic, assign) BOOL isSelect;
@property (nonatomic, assign) NSInteger totalNumberOfImages;
@property (nonatomic, strong) NSMutableArray *selectedImageIds;
@property (nonatomic, strong) NSMutableArray *touchedImageIds;

@property (nonatomic, strong) NSMutableArray *selectedImageIdsToEdit;
@property (nonatomic, strong) NSMutableArray *selectedImagesToEdit;
@property (nonatomic, strong) NSMutableArray *selectedImageIdsToDelete;
@property (nonatomic, strong) NSMutableArray *selectedImagesToDelete;
@property (nonatomic, strong) NSMutableArray *selectedImagesToRemove;
@property (nonatomic, strong) NSMutableArray *selectedImageIdsToShare;
@property (nonatomic, strong) NSMutableArray *selectedImagesToShare;
@property (nonatomic, strong) PiwigoImageData *selectedImage;

@property (nonatomic, strong) UIRefreshControl *refreshControl;

@property (nonatomic, assign) kPiwigoSortCategory currentSortCategory;
@property (nonatomic, strong) ImageDetailViewController *imageDetailView;

@end

@implementation AlbumImagesViewController

-(instancetype)initWithAlbumId:(NSInteger)albumId inCache:(BOOL)isCached
{
    self = [super init];
	if(self)
	{
		self.categoryId = albumId;
        self.loadingImages = NO;
        self.isCachedAtInit = isCached;
        self.imageOfInterest = [NSIndexPath indexPathForItem:0 inSection:1];
        
		self.albumData = [[AlbumData alloc] initWithCategoryId:self.categoryId andQuery:@""];
		self.currentSortCategory = [Model sharedInstance].defaultSort;
        self.displayImageTitles = [Model sharedInstance].displayImageTitles;
		
        // Initialise selection mode
        self.isSelect = NO;
        self.touchedImageIds = [NSMutableArray new];
        self.selectedImageIds = [NSMutableArray new];

        // Collection of images
		self.imagesCollection = [[UICollectionView alloc] initWithFrame:self.view.frame collectionViewLayout:[UICollectionViewFlowLayout new]];
		self.imagesCollection.translatesAutoresizingMaskIntoConstraints = NO;
		self.imagesCollection.alwaysBounceVertical = YES;
        self.imagesCollection.showsVerticalScrollIndicator = YES;
		self.imagesCollection.dataSource = self;
		self.imagesCollection.delegate = self;

        [self.imagesCollection registerClass:[ImageCollectionViewCell class] forCellWithReuseIdentifier:@"ImageCollectionViewCell"];
		[self.imagesCollection registerClass:[CategoryCollectionViewCell class] forCellWithReuseIdentifier:@"CategoryCollectionViewCell"];
        [self.imagesCollection registerClass:[CategoryHeaderReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"CategoryHeader"];
        [self.imagesCollection registerClass:[NberImagesFooterCollectionReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:@"NberImagesFooterCollection"];

		[self.view addSubview:self.imagesCollection];
        [self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.imagesCollection]];
        if (@available(iOS 11.0, *)) {
            [self.imagesCollection setContentInsetAdjustmentBehavior:UIScrollViewContentInsetAdjustmentAlways];
        } else {
            // Fallback on earlier versions
        }

        // Refresh view
        self.refreshControl = [[UIRefreshControl alloc] init];

        // Navigation bar and toolbar buttons
        self.settingsBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"preferences"] landscapeImagePhone:[UIImage imageNamed:@"preferencesCompact"] style:UIBarButtonItemStylePlain target:self action:@selector(didTapPreferencesButton)];
        [self.settingsBarButton setAccessibilityIdentifier:@"preferences"];
        self.discoverBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"list"] landscapeImagePhone:[UIImage imageNamed:@"listCompact"] style:UIBarButtonItemStylePlain target:self action:@selector(discoverImages)];
        [self.discoverBarButton setAccessibilityIdentifier:@"discover"];

        self.selectBarButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"categoryImageList_selectButton", @"Select") style:UIBarButtonItemStylePlain target:self action:@selector(didTapSelect)];
        [self.selectBarButton setAccessibilityIdentifier:@"Select"];
        self.cancelBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelSelect)];
        [self.cancelBarButton setAccessibilityIdentifier:@"Cancel"];
        self.spaceBetweenButtons = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
        self.editBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(editSelection)];
        [self.editBarButton setAccessibilityIdentifier:@"edit"];
        self.deleteBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"imageTrash"] landscapeImagePhone:[UIImage imageNamed:@"imageTrashCompact"] style:UIBarButtonItemStylePlain target:self action:@selector(deleteSelection)];
        self.deleteBarButton.tintColor = [UIColor redColor];
        self.shareBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"imageShare"] landscapeImagePhone:[UIImage imageNamed:@"imageShareCompact"] style:UIBarButtonItemStylePlain target:self action:@selector(shareSelection)];
        self.shareBarButton.tintColor = [UIColor piwigoColorOrange];
        self.moveBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"imageMove"] landscapeImagePhone:[UIImage imageNamed:@"imageMoveCompact"] style:UIBarButtonItemStylePlain target:self action:@selector(addImagesToCategory)];
        self.moveBarButton.tintColor = [UIColor piwigoColorOrange];
        self.navigationController.toolbarHidden = YES;

        // "Add" button above collection view and other buttons
        self.addButton = [UIButton buttonWithType:UIButtonTypeSystem];
        CGFloat xPos = [UIScreen mainScreen].bounds.size.width - 3*kRadius;
        CGFloat yPos = [UIScreen mainScreen].bounds.size.height - 3*kRadius;
        self.addButton.frame = CGRectMake(xPos, yPos, 2*kRadius, 2*kRadius);
        self.addButton.layer.cornerRadius = kRadius;
        self.addButton.layer.masksToBounds = NO;
        [self.addButton.layer setOpacity:0.0];
        [self.addButton.layer setShadowColor:[UIColor piwigoColorGray].CGColor];
        [self.addButton.layer setShadowOpacity:1.0];
        [self.addButton.layer setShadowRadius:5.0];
        [self.addButton.layer setShadowOffset:CGSizeMake(0.0, 2.0)];
        self.addButton.backgroundColor = [UIColor piwigoColorOrange];
        self.addButton.tintColor = [UIColor whiteColor];
        self.addButton.showsTouchWhenHighlighted = YES;
        if (self.categoryId == 0) {
            [self.addButton setImage:[UIImage imageNamed:@"createLarge"] forState:UIControlStateNormal];
        } else {
            [self.addButton setImage:[UIImage imageNamed:@"add"] forState:UIControlStateNormal];
        }
        [self.addButton addTarget:self action:@selector(didTapAddButton)
               forControlEvents:UIControlEventTouchUpInside];
        self.addButton.hidden = YES;
        [self.view addSubview:self.addButton];

        // "Home" album button above collection view
        self.homeAlbumButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.homeAlbumButton.frame = self.addButton.frame;
        self.homeAlbumButton.layer.cornerRadius = kRadius;
        self.homeAlbumButton.layer.masksToBounds = NO;
        [self.homeAlbumButton.layer setOpacity:0.0];
        [self.homeAlbumButton.layer setShadowColor:[UIColor piwigoColorGray].CGColor];
        [self.homeAlbumButton.layer setShadowOpacity:1.0];
        [self.homeAlbumButton.layer setShadowRadius:5.0];
        [self.homeAlbumButton.layer setShadowOffset:CGSizeMake(0.0, 2.0)];
        self.homeAlbumButton.showsTouchWhenHighlighted = YES;
        [self.homeAlbumButton setImage:[UIImage imageNamed:@"rootAlbum"] forState:UIControlStateNormal];
        [self.homeAlbumButton addTarget:self action:@selector(returnToDefaultCategory)
                    forControlEvents:UIControlEventTouchUpInside];
        self.homeAlbumButton.hidden = YES;
        [self.view insertSubview:self.homeAlbumButton belowSubview:self.addButton];

        // "Create Album" button above collection view
        self.createAlbumButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.createAlbumButton.frame = self.addButton.frame;
        self.createAlbumButton.layer.cornerRadius = 0.86*kRadius;
        self.createAlbumButton.layer.masksToBounds = NO;
        [self.createAlbumButton.layer setOpacity:0.0];
        [self.createAlbumButton.layer setShadowColor:[UIColor piwigoColorGray].CGColor];
        [self.createAlbumButton.layer setShadowOpacity:1.0];
        [self.createAlbumButton.layer setShadowRadius:5.0];
        [self.createAlbumButton.layer setShadowOffset:CGSizeMake(0.0, 2.0)];
        self.createAlbumButton.backgroundColor = [UIColor piwigoColorOrange];
        self.createAlbumButton.tintColor = [UIColor whiteColor];
        self.createAlbumButton.showsTouchWhenHighlighted = YES;
        [self.createAlbumButton setImage:[UIImage imageNamed:@"create"] forState:UIControlStateNormal];
        [self.createAlbumButton addTarget:self action:@selector(didTapCreateAlbumButton)
               forControlEvents:UIControlEventTouchUpInside];
        self.createAlbumButton.hidden = YES;
        [self.view insertSubview:self.createAlbumButton belowSubview:self.addButton];

        // "Upload Images" button above collection view
        self.uploadImagesButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.uploadImagesButton.frame = self.addButton.frame;
        self.uploadImagesButton.layer.cornerRadius = 0.86*kRadius;
        self.uploadImagesButton.layer.masksToBounds = NO;
        [self.uploadImagesButton.layer setOpacity:0.0];
        [self.uploadImagesButton.layer setShadowColor:[UIColor piwigoColorGray].CGColor];
        [self.uploadImagesButton.layer setShadowOpacity:1.0];
        [self.uploadImagesButton.layer setShadowRadius:5.0];
        [self.uploadImagesButton.layer setShadowOffset:CGSizeMake(0.0, 2.0)];
        self.uploadImagesButton.backgroundColor = [UIColor piwigoColorOrange];
        self.uploadImagesButton.tintColor = [UIColor whiteColor];
        self.uploadImagesButton.showsTouchWhenHighlighted = YES;
        [self.uploadImagesButton setImage:[UIImage imageNamed:@"imageUpload"] forState:UIControlStateNormal];
        [self.uploadImagesButton addTarget:self action:@selector(didTapUploadImagesButton)
               forControlEvents:UIControlEventTouchUpInside];
        self.uploadImagesButton.hidden = YES;
        [self.view insertSubview:self.uploadImagesButton belowSubview:self.addButton];

        // Register category data updates
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getCategoryData:) name:kPiwigoNotificationGetCategoryData object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(categoriesUpdated) name:kPiwigoNotificationCategoryDataUpdated object:nil];
		
        // Register palette changes
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyColorPalette) name:kPiwigoNotificationPaletteChanged object:nil];

        // Register root album changes
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(returnToDefaultCategory) name:kPiwigoNotificationBackToDefaultAlbum object:nil];
    }
	return self;
}

#pragma mark - View Lifecycle

-(void)viewDidLoad
{
    [super viewDidLoad];
    
    // Reload category data
#if defined(DEBUG_LIFECYCLE)
    NSLog(@"viewDidLoad => ID:%ld", (long)self.categoryId);
#endif
    [self getCategoryData:nil];

    // Navigation bar
    [self.navigationController.navigationBar setAccessibilityIdentifier:@"AlbumImagesNav"];

    // For iOS 11 and later: place search bar in navigation bar or root album
    if (@available(iOS 11.0, *)) {
        // Initialise search controller when displaying root album
        if (self.categoryId == 0) {
            SearchImagesViewController *resultsCollectionController = [[SearchImagesViewController alloc] init];
            UISearchController *searchController = [[UISearchController alloc] initWithSearchResultsController:resultsCollectionController];
            searchController.delegate = self;
            searchController.hidesNavigationBarDuringPresentation = YES;
            searchController.searchResultsUpdater = self;
            
            searchController.searchBar.tintColor = [UIColor piwigoColorOrange];
            searchController.searchBar.searchBarStyle = UISearchBarStyleMinimal;
            searchController.searchBar.translucent = NO;
            searchController.searchBar.showsCancelButton = NO;
            searchController.searchBar.showsSearchResultsButton = NO;
            searchController.searchBar.delegate = self;        // Monitor when the search button is tapped.
            self.definesPresentationContext = YES;
            
            // Place the search bar in the navigation bar.
            self.navigationItem.searchController = searchController;
        }
    }
}

-(void)applyColorPalette
{
    // Background color of the view
    self.view.backgroundColor = [UIColor piwigoColorBackground];

    // Refresh controller
    self.refreshControl.backgroundColor = [UIColor piwigoColorBackground];
    self.refreshControl.tintColor = [UIColor piwigoColorOrange];
    NSDictionary *attributesRefresh = @{
                                 NSForegroundColorAttributeName: [UIColor piwigoColorOrange],
                                 NSFontAttributeName: [UIFont piwigoFontNormal],
                                 };
    self.refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:NSLocalizedString(@"pullToRefresh", @"Reload Images") attributes:attributesRefresh];
    
    // Buttons
    self.homeAlbumButton.backgroundColor = [UIColor piwigoColorRightLabel];
    self.homeAlbumButton.tintColor = [UIColor piwigoColorBackground];

    // Navigation bar appearence
    NSDictionary *attributes = @{
                                 NSForegroundColorAttributeName: [UIColor piwigoColorWhiteCream],
                                 NSFontAttributeName: [UIFont piwigoFontNormal],
                                 };
    self.navigationController.navigationBar.titleTextAttributes = attributes;
    if (@available(iOS 11.0, *)) {
        if (self.categoryId == [Model sharedInstance].defaultCategory) {
            // Title
            NSDictionary *attributesLarge = @{
                                              NSForegroundColorAttributeName: [UIColor piwigoColorWhiteCream],
                                              NSFontAttributeName: [UIFont piwigoFontLargeTitle],
                                              };
            self.navigationController.navigationBar.largeTitleTextAttributes = attributesLarge;
            self.navigationController.navigationBar.prefersLargeTitles = YES;

            // Search bar
            self.navigationItem.searchController.searchBar.barStyle = [Model sharedInstance].isDarkPaletteActive ? UIBarStyleBlack : UIBarStyleDefault;
            if (@available(iOS 13.0, *)) {
                self.navigationItem.searchController.searchBar.searchTextField.textColor = [UIColor piwigoColorLeftLabel];
                self.navigationItem.searchController.searchBar.searchTextField.keyboardAppearance = [Model sharedInstance].isDarkPaletteActive ? UIKeyboardAppearanceDark : UIKeyboardAppearanceLight;
            }
        }
        else {
            self.navigationController.navigationBar.prefersLargeTitles = NO;
        }
    }
    self.navigationController.navigationBar.barStyle = [Model sharedInstance].isDarkPaletteActive ? UIBarStyleBlack : UIBarStyleDefault;
    self.navigationController.navigationBar.tintColor = [UIColor piwigoColorOrange];
    self.navigationController.navigationBar.barTintColor = [UIColor piwigoColorBackground];
    self.navigationController.navigationBar.backgroundColor = [UIColor piwigoColorBackground];
    [self.navigationController.navigationBar setAccessibilityIdentifier:@"AlbumImagesNav"];

    // Toolbar
    self.navigationController.toolbar.barTintColor =[UIColor piwigoColorBackground];
    self.navigationController.toolbar.barStyle = [Model sharedInstance].isDarkPaletteActive ? UIBarStyleBlack : UIBarStyleDefault;
    
    // Collection view
    self.imagesCollection.backgroundColor = [UIColor piwigoColorBackground];
    self.imagesCollection.indicatorStyle = [Model sharedInstance].isDarkPaletteActive ? UIScrollViewIndicatorStyleWhite : UIScrollViewIndicatorStyleBlack;
    [self.imagesCollection reloadData];
}

-(void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
#if defined(DEBUG_LIFECYCLE)
    NSLog(@"viewWillAppear  => ID:%ld", (long)self.categoryId);
#endif
    
    // Set colors, fonts, etc.
    [self applyColorPalette];

    // Called before displaying SearchImagesViewController?
    UIViewController *presentedViewController = [self presentedViewController];
    if ([presentedViewController isKindOfClass:[UISearchController class]]) {
        // Hide toolbar
        [self.navigationController setToolbarHidden:YES animated:YES];
        return;
    }
    
    // Inform Upload view controllers that user selected this category
    NSDictionary *userInfo = @{@"currentCategoryId" : @(self.categoryId)};
    [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationChangedCurrentCategory object:nil userInfo:userInfo];
    
    // Load, sort images and reload collection
    if (self.categoryId != 0) {
#if defined(DEBUG_LIFECYCLE)
        NSLog(@"viewWillAppear  => load images");
#endif
        self.loadingImages = YES;
        [self.albumData updateImageSort:self.currentSortCategory OnCompletion:^{

            // Set navigation bar buttons
            [self updateButtonsInPreviewMode];

            self.loadingImages = NO;
            [self.imagesCollection reloadData];
        }];
    }
    else {
#if defined(DEBUG_LIFECYCLE)
        NSLog(@"viewWillAppear  => reload albums table");
#endif
        if([[CategoriesData sharedInstance] getCategoriesForParentCategory:self.categoryId].count > 0) {
            [self.imagesCollection reloadData];
        }
    }
    
    // Refresh image collection if displayImageTitles option changed in Settings
    if (self.displayImageTitles != [Model sharedInstance].displayImageTitles) {
        self.displayImageTitles = [Model sharedInstance].displayImageTitles;
        if (self.categoryId != 0) {
            [self.albumData reloadAlbumOnCompletion:^{
                self.loadingImages = NO;
                [self.imagesCollection reloadSections:[NSIndexSet indexSetWithIndex:1]];
            }];
        }
    }

    // Always open this view with a navigation bar and the search bar
    // (might have been hidden during Image Previewing)
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    if (@available(iOS 11.0, *)) {
        self.navigationItem.hidesSearchBarWhenScrolling = false;
    }

    // Set navigation bar buttons
    [self updateButtonsInPreviewMode];
}

-(void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
    // Called after displaying SearchImagesViewController?
    if (@available(iOS 11.0, *)) {
        UIViewController *presentedViewController = [self presentedViewController];
        if ([presentedViewController isKindOfClass:[UISearchController class]]) {
            // Scroll to image of interest if needed
            if ([self.navigationItem.searchController.searchResultsController isKindOfClass:[SearchImagesViewController class]]) {
                SearchImagesViewController *resultsController = (SearchImagesViewController *)self.navigationItem.searchController.searchResultsController;
                [resultsController scrollToHighlightedCell];
            }
            return;
        }
    }
    
    // Refresh controller
	[self.refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
    [self.imagesCollection addSubview:self.refreshControl];
    self.imagesCollection.alwaysBounceVertical = YES;
    
    // Allows hiding search bar when scrolling
    if (@available(iOS 11.0, *)) {
        self.navigationItem.hidesSearchBarWhenScrolling = true;
    }

    // Should we scroll to image of interest?
//        NSLog(@"••• Starting with %ld images", (long)[self.imagesCollection numberOfItemsInSection:1]);
    if ((self.categoryId != 0) && ([self.albumData.images count] > 0) && (self.imageOfInterest.item != 0)) {
        
        // Not the root album, album contains images and thumbnail of interest is not the first one
        // => Scroll and highlight cell of interest
//        NSLog(@"=> Try to scroll to item=%ld in section=%ld", (long)self.imageOfInterest.item, (long)self.imageOfInterest.section);

        // Thumbnail of interest already visible?
        NSArray<NSIndexPath *> *indexPathsForVisibleItems = [self.imagesCollection indexPathsForVisibleItems];
        if ([indexPathsForVisibleItems containsObject:self.imageOfInterest]) {
            // Thumbnail is already visible and is highlighted
            UICollectionViewCell *cell = [self.imagesCollection cellForItemAtIndexPath:self.imageOfInterest];
            if ([cell isKindOfClass:[ImageCollectionViewCell class]]) {
                ImageCollectionViewCell *imageCell = (ImageCollectionViewCell *)cell;
                [imageCell highlightOnCompletion:^{
                    // Apply effect when returning from image preview mode
                    self.imageOfInterest = [NSIndexPath indexPathForItem:0 inSection:1];
                }];
            } else {
                self.imageOfInterest = [NSIndexPath indexPathForItem:0 inSection:1];
            }
        }
        else {
            // Search for the first visible thumbnail
            NSIndexPath *indexPathOfFirstVisibleThumbnail = nil;
            for (NSInteger index = 0; index < [indexPathsForVisibleItems count]; index++) {
                if ([indexPathsForVisibleItems objectAtIndex:index].section == 1) {
                    indexPathOfFirstVisibleThumbnail = [indexPathsForVisibleItems objectAtIndex:index];
                    break;
                }
            }
            
            // Thumbnail of interest above visible items?
            if (self.imageOfInterest.item < indexPathOfFirstVisibleThumbnail.item) {
                // Scroll up collection and highlight cell
//                NSLog(@"=> Scroll to item #%ld in section #%ld", (long)self.imageOfInterest.item, (long)self.imageOfInterest.section);
                [self.imagesCollection scrollToItemAtIndexPath:self.imageOfInterest atScrollPosition:UICollectionViewScrollPositionCenteredVertically animated:YES];
            }
            
            // Thumbnail is below visible items
            // Get number of already loaded items
            NSInteger nberOfItems = [self.imagesCollection numberOfItemsInSection:1];
            if (self.imageOfInterest.item < nberOfItems) {
                // Already loaded => scroll to it
//                NSLog(@"=> Scroll to item #%ld in section #%ld", (long)self.imageOfInterest.item, (long)self.imageOfInterest.section);
                [self.imagesCollection scrollToItemAtIndexPath:self.imageOfInterest atScrollPosition:UICollectionViewScrollPositionCenteredVertically animated:YES];
                
                // Calculate the number of thumbnails displayed per page
                NSInteger imagesPerPage = [ImagesCollection numberOfImagesPerPageForView:self.imagesCollection imagesPerRowInPortrait:[Model sharedInstance].thumbnailsPerRowInPortrait];

                // Load more images if seems to be a good idea
                if ((self.imageOfInterest.item > (nberOfItems - roundf(imagesPerPage / 3.0))) &&
                    (self.albumData.images.count != [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] numberOfImages])) {
//                    NSLog(@"=> Load more images…");
                    [self.albumData loadMoreImagesOnCompletion:^{
                        [self.imagesCollection reloadSections:[NSIndexSet indexSetWithIndex:1]];
                    }];
                }
            } else {
                // No yet loaded => load more images
                // Should not happen as needToLoadMoreImages() should be called when previewing images
                if (self.albumData.images.count != [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] numberOfImages]) {
//                    NSLog(@"=> Load more images…");
                    [self.albumData loadMoreImagesOnCompletion:^{
                        [self.imagesCollection reloadSections:[NSIndexSet indexSetWithIndex:1]];
                    }];
                }
            }
        }
    }

    // Replace iRate as from v2.1.5 (75) — See https://github.com/nicklockwood/iRate
    // Tells StoreKit to ask the user to rate or review the app, if appropriate.
//#if !defined(DEBUG)
//    if (NSClassFromString(@"SKStoreReviewController")) {
//        [SKStoreReviewController requestReview];
//    }
//#endif
}

-(void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {

    // Highlight image which is now visible
    if ((self.categoryId != 0) && ([self.albumData.images count] > 0) && (self.imageOfInterest.item != 0)) {
//        NSLog(@"=> Did end scrolling with %ld images", (long)[self.imagesCollection numberOfItemsInSection:1]);
        UICollectionViewCell *cell = [self.imagesCollection cellForItemAtIndexPath:self.imageOfInterest];
        if ([cell isKindOfClass:[ImageCollectionViewCell class]]) {
            ImageCollectionViewCell *imageCell = (ImageCollectionViewCell *)cell;
            [imageCell highlightOnCompletion:^{
                // Apply effect when returning from image preview mode
                self.imageOfInterest = [NSIndexPath indexPathForItem:0 inSection:1];
            }];
        } else {
           self.imageOfInterest = [NSIndexPath indexPathForItem:0 inSection:1];
        }
    }
}

-(void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    // Update the navigation bar on orientation change, to match the new width of the table.
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        if (self.isSelect) {
            [self updateButtonsInSelectionMode];
        } else {
            // Update position of buttons (recalculated after device rotation)
            CGFloat xPos = [UIScreen mainScreen].bounds.size.width - 3*kRadius;
            CGFloat yPos = [UIScreen mainScreen].bounds.size.height - 3*kRadius;
            self.addButton.frame = CGRectMake(xPos, yPos, 2*kRadius, 2*kRadius);
            if (self.addButton.isHidden) {
                self.homeAlbumButton.frame = self.addButton.frame;
            } else {
                self.homeAlbumButton.frame = CGRectMake(xPos - 3*kRadius, yPos, 2*kRadius, 2*kRadius);
            }
            if (self.createAlbumButton.isHidden) {
                self.createAlbumButton.frame = self.addButton.frame;
                self.uploadImagesButton.frame = self.addButton.frame;
            } else {
                self.createAlbumButton.frame = CGRectMake(xPos - 3*kRadius*cos(15*kDeg2Rad), yPos - 3*kRadius*sin(15*kDeg2Rad), 1.72*kRadius, 1.72*kRadius);
                self.uploadImagesButton.frame = CGRectMake(xPos - 3*kRadius*cos(75*kDeg2Rad), yPos - 3*kRadius*sin(75*kDeg2Rad), 1.72*kRadius, 1.72*kRadius);
            }
        }
        [self.imagesCollection reloadData];
    } completion:nil];
}

-(void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    
    // Should we update user interface based on the appearance?
    if (@available(iOS 13.0, *)) {
        BOOL hasUserInterfaceStyleChanged = (previousTraitCollection.userInterfaceStyle != self.traitCollection.userInterfaceStyle);
        if (hasUserInterfaceStyleChanged) {
            [Model sharedInstance].isSystemDarkModeActive = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
            AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
            [appDelegate screenBrightnessChanged];
        }
    } else {
        // Fallback on earlier versions
    }
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    // Do not show album title in backButtonItem of child view to provide enough space for image title
    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
    if(self.view.bounds.size.width <= 414) {     // i.e. smaller than iPhones 6,7 Plus screen width
        self.title = @"";
    }

    // Hide upload button during transition
    [self.addButton setHidden:YES];
}

-(void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    //Make sure buttons are back to initial state
    [self didCancelTapAddButton];
}


#pragma mark - Buttons in Preview mode

-(void)updateButtonsInPreviewMode
{
    // Hide toolbar
    [self.navigationController setToolbarHidden:YES animated:YES];

    // Title is name of category
    if (self.categoryId == 0) {
        self.title = NSLocalizedString(@"tabBar_albums", @"Albums");
    } else {
        self.title = [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] name];
    }

    // User can upload images/videos if he/she has:
    // — admin rights
    // — upload access to the current category
    if ([Model sharedInstance].hasAdminRights ||
        [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] hasUploadRights])
    {
        // Show Upload button if needed
        if (self.addButton.isHidden)
        {
            // Unhide transparent Add button
            [self.addButton setHidden:NO];

            // Animate appearance of Add button
            [UIView animateWithDuration:0.3 animations:^{
                [self.addButton.layer setOpacity:0.9];
            } completion:^(BOOL finished) {
                // Show Home button if not in root or default album
                [self showHomeAlbumButtonIfNeeded];
            }];
        } else {
            // Present Home button if needed and if not in root or default album
            [self showHomeAlbumButtonIfNeeded];
        }
    }
    else    // No upload rights => No Upload button
    {
        // Show Home button if not in root or default album
        [self.addButton setHidden:YES];
        [self showHomeAlbumButtonIfNeeded];
    }
    
    // Left side of navigation bar
    if ((self.categoryId == 0) ||
        (self.categoryId == [Model sharedInstance].defaultCategory)){
        // Button for accessing settings
        [self.navigationItem setLeftBarButtonItems:@[self.settingsBarButton] animated:YES];
        [self.navigationItem setHidesBackButton:YES];
    }
    else {
        // Back button to parent album
        [self.navigationItem setLeftBarButtonItems:@[] animated:YES];
        [self.navigationItem setHidesBackButton:NO];
    }
    
    // Right side of navigation bar
    if (self.categoryId == 0) {
        // Root album => Discover menu button
        [self.navigationItem setRightBarButtonItems:@[self.discoverBarButton] animated:YES];
    }
    else if (self.albumData.images.count > 0) {
        // Button for activating the selection mode
        [self.navigationItem setRightBarButtonItems:@[self.selectBarButton] animated:YES];
    } else {
        // No button
        [self.navigationItem setRightBarButtonItems:@[] animated:YES];
    }
}

-(void)didTapPreferencesButton
{
    UIStoryboard *settingsSB = [UIStoryboard storyboardWithName:@"SettingsViewController" bundle:nil];
    SettingsViewController *settingsVC = [settingsSB instantiateViewControllerWithIdentifier:@"SettingsViewController"];
    settingsVC.settingsDelegate = self;
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    navController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    navController.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:navController animated:YES completion:nil];
}

-(void)didTapAddButton
{
    // Create album if root album shown
    if (self.categoryId == 0) {
        // User in root album => Create album
        [self showCreateCategoryDialog];
        return;
    }
    
    // Hide Home button behind Add button if needed
    if (self.homeAlbumButton.isHidden)
    {
        // Show CreateAlbum and UploadImages albums
        [self showOptionalButtonsCompletion:^{
            
            // Change appearance and action of Add button
            [self.addButton addTarget:self action:@selector(didCancelTapAddButton)
                   forControlEvents:UIControlEventTouchUpInside];
            [UIView animateWithDuration:0.2 animations:^{
                self.addButton.backgroundColor = [UIColor grayColor];
            }];
        }];
    } else {
        // Hide Home Album button
        [self hideHomeAlbumButtonCompletion:^{
            
            // Show CreateAlbum and UploadImages albums
            [self showOptionalButtonsCompletion:^{
                
                // Change appearance and action of Add button
                [self.addButton addTarget:self action:@selector(didCancelTapAddButton)
                       forControlEvents:UIControlEventTouchUpInside];
                [UIView animateWithDuration:0.2 animations:^{
                    self.addButton.backgroundColor = [UIColor grayColor];
                }];
            }];
        }];
    }
}

-(void)didCancelTapAddButton
{
    // User changed mind or finished job
    // First hide optional buttons
    [self hideOptionalButtonsCompletion:^{
        // Reset appearance and action of Add button
        [self.addButton addTarget:self action:@selector(didTapAddButton)
               forControlEvents:UIControlEventTouchUpInside];
        [UIView animateWithDuration:0.2 animations:^{
            self.addButton.backgroundColor = [UIColor piwigoColorOrange];
        } completion:^(BOOL finished) {
            // Present Home button if needed and if not in root or default album
            [self showHomeAlbumButtonIfNeeded];
        }];
    }];
}

-(void)showHomeAlbumButtonIfNeeded
{
    // Present Home Album button if needed
    // and if not in root or default album
    if (self.homeAlbumButton.isHidden && (self.categoryId != 0) &&
        (self.categoryId != [Model sharedInstance].defaultCategory))
    {
        // Unhide transparent Home Album button
        [self.homeAlbumButton setHidden:NO];
                
        // Animate appearance of Home Album button
        [UIView animateWithDuration:0.3 animations:^{
            // Progressive appearance
            [self.homeAlbumButton.layer setOpacity:0.9];
            
            // Position of Home Album button depends on user's rights
            if (([Model sharedInstance].hasAdminRights ||
                 [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] hasUploadRights]))
            {
                CGFloat xPos = self.addButton.frame.origin.x;
                CGFloat yPos = self.addButton.frame.origin.y;
                self.homeAlbumButton.frame = CGRectMake(xPos - 3*kRadius, yPos, 2*kRadius, 2*kRadius);
            }
            else {
                self.homeAlbumButton.frame = self.addButton.frame;
            }
        }];
    }
}

-(void)hideHomeAlbumButtonCompletion:(void (^ __nullable)(void))completion
{
    // Hide Home Album button behind Add button
    [UIView animateWithDuration:0.2 animations:^{
        // Progressive disappearance
        [self.homeAlbumButton.layer setOpacity:0.0];

        // Animate displacement towards the Add button if needed
        self.homeAlbumButton.frame = self.addButton.frame;
    
    } completion:^(BOOL finished) {
        // Hide Home Album button
        [self.homeAlbumButton setHidden:YES];

        // Execute block
        if (completion) {
            completion();
        }
    }];
}

-(void)showOptionalButtonsCompletion:(void (^ __nullable)(void))completion
{
    // For positioning the buttons
    CGFloat xPos = self.addButton.frame.origin.x;
    CGFloat yPos = self.addButton.frame.origin.y;

    // Unhide transparent CreateAlbum and UploadImages buttons
    [self.createAlbumButton setHidden:NO];
    [self.uploadImagesButton setHidden:NO];
    
    // Show CreateAlbum and UploadImages buttons
    [UIView animateWithDuration:0.3 animations:^{
        // Progressive appearance
        [self.createAlbumButton.layer setOpacity:0.9];
        [self.uploadImagesButton.layer setOpacity:0.9];
        
        // Move buttons together
        self.createAlbumButton.frame = CGRectMake(xPos - 3*kRadius*cos(15*kDeg2Rad), yPos - 3*kRadius*sin(15*kDeg2Rad), 1.72*kRadius, 1.72*kRadius);
        self.uploadImagesButton.frame = CGRectMake(xPos - 3*kRadius*cos(75*kDeg2Rad), yPos - 3*kRadius*sin(75*kDeg2Rad), 1.72*kRadius, 1.72*kRadius);
    
    } completion:^(BOOL finished) {
        // Execute block
        if (completion) {
            completion();
        }
    }];
}

-(void)hideOptionalButtonsCompletion:(void (^ __nullable)(void))completion
{
    // For positioning the buttons
    CGFloat xPos = self.addButton.frame.origin.x;
    CGFloat yPos = self.addButton.frame.origin.y;

    // Show CreateAlbum and UploadImages buttons
    [UIView animateWithDuration:0.3 animations:^{
        // Progressive disappearance
        [self.createAlbumButton.layer setOpacity:0.0];
        [self.uploadImagesButton.layer setOpacity:0.0];
        
        // Move buttons together
        self.createAlbumButton.frame = CGRectMake(xPos, yPos, 1.72*kRadius, 1.72*kRadius);
        self.uploadImagesButton.frame = CGRectMake(xPos, yPos, 1.72*kRadius, 1.72*kRadius);

    } completion:^(BOOL finished) {
        // Hide transparent CreateAlbum and UploadImages buttons
        [self.createAlbumButton setHidden:YES];
        [self.uploadImagesButton setHidden:YES];
        
        // Reset background colours
        [self.createAlbumButton setBackgroundColor:[UIColor piwigoColorOrange]];
        [self.uploadImagesButton setBackgroundColor:[UIColor piwigoColorOrange]];
        
        // Execute block
        if (completion) {
            completion();
        }
    }];
}


#pragma mark - Buttons in Selection mode

-(void)updateButtonsInSelectionMode
{
    // Update title
    switch (self.selectedImageIds.count) {
        case 0:
            self.title = NSLocalizedString(@"selectImages", @"Select Photos");
            break;
            
        case 1:
            self.title = NSLocalizedString(@"selectImageSelected", @"1 Photo Selected");
            break;
            
        default:
            self.title = [NSString stringWithFormat:NSLocalizedString(@"selectImagesSelected", @"%@ Photos Selected"), @(self.selectedImageIds.count)];
            break;
    }
    
    // Hide back, Settings, Upload and Home buttons
    [self.navigationItem setHidesBackButton:YES];
    [self.addButton setHidden:YES];
    [self.homeAlbumButton setHidden:YES];

    // User can delete images/videos if he/she has:
    // — admin rights
    if ([Model sharedInstance].hasAdminRights)
    {
        // Interface depends on device and orientation
        if (([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) &&
            (([[UIDevice currentDevice] orientation] != UIDeviceOrientationLandscapeLeft) &&
             ([[UIDevice currentDevice] orientation] != UIDeviceOrientationLandscapeRight))) {
    
            // iPhone in portrait mode
            // Redefine bar buttons (definition lost after rotation of device)
            self.spaceBetweenButtons = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
            self.deleteBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"imageTrash"] landscapeImagePhone:[UIImage imageNamed:@"imageTrashCompact"] style:UIBarButtonItemStylePlain target:self action:@selector(deleteSelection)];
            self.deleteBarButton.tintColor = [UIColor redColor];
            self.shareBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"imageShare"] landscapeImagePhone:[UIImage imageNamed:@"imageShareCompact"] style:UIBarButtonItemStylePlain target:self action:@selector(shareSelection)];
            self.shareBarButton.tintColor = [UIColor piwigoColorOrange];
            self.moveBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"imageMove"] landscapeImagePhone:[UIImage imageNamed:@"imageMoveCompact"] style:UIBarButtonItemStylePlain target:self action:@selector(addImagesToCategory)];
            self.moveBarButton.tintColor = [UIColor piwigoColorOrange];

            // Left side of navigation bar
            [self.navigationItem setLeftBarButtonItems:@[self.cancelBarButton] animated:YES];
            self.cancelBarButton.enabled = YES;

            // Right side of navigation bar
            [self.navigationItem setRightBarButtonItems:@[self.editBarButton] animated:YES];
            self.editBarButton.enabled = (self.selectedImageIds.count > 0);

            // Toolbar
            [self.navigationController setToolbarHidden:NO animated:YES];
            self.toolbarItems = @[self.shareBarButton, self.spaceBetweenButtons, self.moveBarButton, self.spaceBetweenButtons, self.deleteBarButton];
            self.shareBarButton.enabled = (self.selectedImageIds.count > 0);
            self.moveBarButton.enabled = (self.selectedImageIds.count > 0);
            self.deleteBarButton.enabled = (self.selectedImageIds.count > 0);
        }
        else    // iPhone in landscape mode, iPad in any orientation
        {
            // Hide toolbar
            [self.navigationController setToolbarHidden:YES animated:YES];

            // Left side of navigation bar
            [self.navigationItem setLeftBarButtonItems:@[self.cancelBarButton, self.deleteBarButton] animated:YES];
            self.cancelBarButton.enabled = YES;
            self.deleteBarButton.enabled = (self.selectedImageIds.count > 0);

            // Right side of navigation bar
            [self.navigationItem setRightBarButtonItems:@[self.editBarButton, self.moveBarButton, self.shareBarButton] animated:YES];
            self.shareBarButton.enabled = (self.selectedImageIds.count > 0);
            self.moveBarButton.enabled = (self.selectedImageIds.count > 0);
            self.editBarButton.enabled = (self.selectedImageIds.count > 0);
      }
    }
    // WRONG =====> 'normal' user with upload access to the current category can edit images
    // SHOULD BE => 'normal' user having uploaded images can edit them. This requires 'user_id' and 'added_by' values of images for checking rights
    else if ([Model sharedInstance].hasNormalRights && [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] hasUploadRights])
    {
        // Interface depends on device and orientation
        if (([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) &&
            (([[UIDevice currentDevice] orientation] != UIDeviceOrientationLandscapeLeft) &&
             ([[UIDevice currentDevice] orientation] != UIDeviceOrientationLandscapeRight))) {
                
                // iPhone in portrait mode
                // Redefine bar buttons (definition lost after rotation of device)
                self.spaceBetweenButtons = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
                self.shareBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"imageShare"] landscapeImagePhone:[UIImage imageNamed:@"imageShareCompact"] style:UIBarButtonItemStylePlain target:self action:@selector(shareSelection)];
                self.shareBarButton.tintColor = [UIColor piwigoColorOrange];
                self.moveBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"imageMove"] landscapeImagePhone:[UIImage imageNamed:@"imageMoveCompact"] style:UIBarButtonItemStylePlain target:self action:@selector(addImagesToCategory)];
                self.moveBarButton.tintColor = [UIColor piwigoColorOrange];
                
                // Left side of navigation bar
                [self.navigationItem setLeftBarButtonItems:@[self.cancelBarButton] animated:YES];
                self.cancelBarButton.enabled = YES;

                // Right side of navigation bar
                [self.navigationItem setRightBarButtonItems:@[self.editBarButton] animated:YES];
                self.editBarButton.enabled = (self.selectedImageIds.count > 0);

                // Present toolbar
                [self.navigationController setToolbarHidden:NO animated:YES];
                self.toolbarItems = @[self.shareBarButton, self.spaceBetweenButtons, self.moveBarButton];
                self.shareBarButton.enabled = (self.selectedImageIds.count > 0);
                self.moveBarButton.enabled = (self.selectedImageIds.count > 0);
            }
        else    // iPhone in landscape mode, iPad in any orientation
        {
            // Hide toolbar
            [self.navigationController setToolbarHidden:YES animated:YES];
            
            // Left side of navigation bar
            [self.navigationItem setLeftBarButtonItems:@[self.cancelBarButton] animated:YES];
            self.cancelBarButton.enabled = YES;

            // Right side of navigation bar
            [self.navigationItem setRightBarButtonItems:@[self.editBarButton, self.moveBarButton, self.shareBarButton] animated:YES];
            self.editBarButton.enabled = (self.selectedImageIds.count > 0);
            self.shareBarButton.enabled = (self.selectedImageIds.count > 0);
            self.moveBarButton.enabled = (self.selectedImageIds.count > 0);
        }
    }
    else    // No rights => No toolbar, only download button
    {
        // Hide toolbar
        [self.navigationController setToolbarHidden:YES animated:YES];

        // Left side of navigation bar
        [self.navigationItem setLeftBarButtonItems:@[self.cancelBarButton] animated:YES];
        self.cancelBarButton.enabled = YES;

        // Right side of navigation bar
        [self.navigationItem setRightBarButtonItems:@[self.shareBarButton] animated:YES];
        self.shareBarButton.enabled = (self.selectedImageIds.count > 0);
    }
}

-(void)disableBarButtons
{
    self.cancelBarButton.enabled = NO;
    self.editBarButton.enabled = NO;
    self.deleteBarButton.enabled = NO;
    self.moveBarButton.enabled = NO;
    self.shareBarButton.enabled = NO;
}



#pragma mark - Category Data

-(void)getCategoryData:(NSNotification *)notification
{
    // Extract notification user info
    BOOL noHUD = NO;
    if (notification != nil) {
        NSDictionary *userInfo = notification.userInfo;

        // Right category Id?
        NSInteger catId = [[userInfo objectForKey:@"albumId"] integerValue];
        if (catId != self.categoryId) return;
        
        // Display HUD?
        noHUD = [[userInfo objectForKey:@"NoHUD"] boolValue];

        // Disable cache?
        self.isCachedAtInit = [[userInfo objectForKey:@"fromCache"] boolValue];
    }

    // Display HUD if requested
    if (!([Model sharedInstance].loadAllCategoryInfo && self.isCachedAtInit) && !noHUD) {
        // Show loading HD
        [self showHUDwithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…") inMode:MBProgressHUDModeIndeterminate withDetailLabel:NO];
    }
    
    // Reload category data
#if defined(DEBUG_LIFECYCLE)
    NSLog(@"getCategoryData => getAlbumListForCategory(ID:%ld, cache:%@, recursive:%@)", (long)self.categoryId,([Model sharedInstance].loadAllCategoryInfo && self.isCachedAtInit) ? @"Yes" : @"No",[Model sharedInstance].loadAllCategoryInfo ? @"Yes" : @"No");
#endif
    
    // Load category data
    [AlbumService getAlbumListForCategory:self.categoryId
                               usingCache:([Model sharedInstance].loadAllCategoryInfo && self.isCachedAtInit)
                          inRecursiveMode:[Model sharedInstance].loadAllCategoryInfo
                             OnCompletion:^(NSURLSessionTask *task, NSArray *albums) {
                                 self.isCachedAtInit = YES;
                                 [self.imagesCollection reloadData];

                                 // Hide loading HUD
                                 [self hideHUD];
                            }
                                onFailure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
                                    NSLog(@"getAlbumListForCategory error %ld: %@", (long)error.code, error.localizedDescription);
#endif
                                    // Hide loading HUD
                                    [self hideHUD];
                                }
     ];
}

-(void)refresh:(UIRefreshControl*)refreshControl
{
    // Show loading HD
    [self showHUDwithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…") inMode:MBProgressHUDModeIndeterminate withDetailLabel:NO];

    [AlbumService getAlbumListForCategory:[Model sharedInstance].loadAllCategoryInfo ? 0 : self.categoryId
                               usingCache:NO
                          inRecursiveMode:[Model sharedInstance].loadAllCategoryInfo
                             OnCompletion:^(NSURLSessionTask *task, NSArray *albums) {
                                 [self.imagesCollection reloadData];

                                 if (refreshControl) [refreshControl endRefreshing];

                                 // Hide loading HUD
                                 [self hideHUD];
                             
                             }  onFailure:^(NSURLSessionTask *task, NSError *error) {
                                 if (refreshControl) [refreshControl endRefreshing];

                                 // Hide loading HUD
                                 [self hideHUD];
                             }
     ];
}

-(void)categoriesUpdated
{
#if defined(DEBUG_LIFECYCLE)
    NSLog(@"                => categoriesUpdated… %ld", (long)self.categoryId);
#endif
    
    // Images ?
    if (self.categoryId != 0) {
        [self.albumData loadAllImagesOnCompletion:^{

             // Sort images
             [self.albumData updateImageSort:self.currentSortCategory OnCompletion:^{

                 // The album title is not shown in backButtonItem to provide enough space
                 // for image title on devices of screen width <= 414 ==> Restore album title
                 self.title = [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] name];
                
                 // Set navigation bar buttons
                 [self updateButtonsInPreviewMode];

                 // Reload collection view
                 [self.imagesCollection reloadData];
//                 [self.imagesCollection reloadSections:[NSIndexSet indexSetWithIndex:1]];
            }];
        }];
    }
     else {
         // The album title is not shown in backButtonItem to provide enough space
         // for image title on devices of screen width <= 414 ==> Restore album title
         self.title = NSLocalizedString(@"tabBar_albums", @"Albums");

         // Set navigation bar buttons
         [self updateButtonsInPreviewMode];

         // Reload collection view
         [self.imagesCollection reloadData];
     }
}

#pragma mark - Default Category Management

-(void)returnToDefaultCategory
{
    // Does the default album view controller already exists?
    NSInteger cur = 0, index = 0;
    AlbumImagesViewController *rootAlbumViewController = nil;
    for (UIViewController *viewController in self.navigationController.viewControllers) {
        
        // Look for AlbumImagesViewControllers
        if ([viewController isKindOfClass:[AlbumImagesViewController class]]) {
            AlbumImagesViewController *thisViewController = (AlbumImagesViewController *) viewController;
            
            // Is this the view controller of the default album?
            if (thisViewController.categoryId == [Model sharedInstance].defaultCategory) {
                // The view controller of the parent category already exist
                rootAlbumViewController = thisViewController;
            }
            
            // Is this the current view controller?
            if (thisViewController.categoryId == self.categoryId) {
                // This current view controller will become the child view controller
                index = cur;
            }
        }
        cur++;
    }
    
    // The view controller of the default album does not exist yet
    if (!rootAlbumViewController) {
        rootAlbumViewController = [[AlbumImagesViewController alloc] initWithAlbumId:[Model sharedInstance].defaultCategory inCache:NO];
        NSMutableArray *arrayOfVC = [[NSMutableArray alloc] initWithArray:self.navigationController.viewControllers];
        [arrayOfVC insertObject:rootAlbumViewController atIndex:index];
        self.navigationController.viewControllers = arrayOfVC;
    }
    
    // Present the root album
    [self.navigationController popToViewController:rootAlbumViewController animated:YES];
}


#pragma mark - Upload images

-(void)didTapUploadImagesButton
{
    // Check autorisation to access Photo Library before uploading
    [[PhotosFetch sharedInstance] checkPhotoLibraryAccessForViewController:self
            onAuthorizedAccess:^{
                // Open local albums view controller in new navigation controlelr
                LocalAlbumsViewController *localAlbums = [[LocalAlbumsViewController alloc] initWithCategoryId:self.categoryId];
                UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:localAlbums];
                navController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
                navController.modalPresentationStyle = UIModalPresentationFormSheet;
                [self presentViewController:navController animated:YES completion:nil];
            }
            onDeniedAccess:nil
     ];

    // Hide CreateAlbum and UploadImages buttons
    [self didCancelTapAddButton];
}


#pragma mark - Create Sub-Album

-(void)didTapCreateAlbumButton
{
    // Change colour of Upload Images button
    [self.createAlbumButton setBackgroundColor:[UIColor grayColor]];
    
    // Start creating album
    [self showCreateCategoryDialog];
}

-(void)showCreateCategoryDialog
{
    UIAlertController* alert = [UIAlertController
                                alertControllerWithTitle:NSLocalizedString(@"createNewAlbum_title", @"New Album")
                                message:NSLocalizedString(@"createNewAlbum_message", @"Enter a name for this album:")
                                preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = NSLocalizedString(@"createNewAlbum_placeholder", @"Album Name");
        textField.clearButtonMode = UITextFieldViewModeAlways;
        textField.keyboardType = UIKeyboardTypeDefault;
        textField.keyboardAppearance = [Model sharedInstance].isDarkPaletteActive ? UIKeyboardAppearanceDark : UIKeyboardAppearanceDefault;
        textField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
        textField.autocorrectionType = UITextAutocorrectionTypeYes;
        textField.returnKeyType = UIReturnKeyContinue;
        textField.delegate = self;
    }];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = NSLocalizedString(@"createNewAlbumDescription_placeholder", @"Description");
        textField.clearButtonMode = UITextFieldViewModeAlways;
        textField.keyboardType = UIKeyboardTypeDefault;
        textField.keyboardAppearance = [Model sharedInstance].isDarkPaletteActive ? UIKeyboardAppearanceDark : UIKeyboardAppearanceDefault;
        textField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
        textField.autocorrectionType = UITextAutocorrectionTypeYes;
        textField.returnKeyType = UIReturnKeyContinue;
        textField.delegate = self;
    }];
    
    UIAlertAction* cancelAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
        style:UIAlertActionStyleCancel
        handler:^(UIAlertAction * action) {
            // Cancel action, reset buttons
            [self didCancelTapAddButton];
    }];
    
    self.createAlbumAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"alertAddButton", @"Add")
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction * action) {
            // Create album
            [self addCategoryWithName:alert.textFields.firstObject.text
                           andComment:alert.textFields.lastObject.text
                             inParent:self.categoryId];
        }];
    
    [alert addAction:cancelAction];
    [alert addAction:self.createAlbumAction];
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    [self presentViewController:alert animated:YES completion:nil];
}

-(void)addCategoryWithName:(NSString *)albumName andComment:(NSString *)albumComment
                  inParent:(NSInteger)parentId
{
    // Display HUD during the update
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showHUDwithTitle:NSLocalizedString(@"createNewAlbumHUD_label", @"Creating Album…") inMode:MBProgressHUDModeIndeterminate withDetailLabel:NO];
    });
    
    // Create album
    [AlbumService createCategoryWithName:albumName
                  withStatus:@"public"
                  andComment:albumComment
                    inParent:parentId
                OnCompletion:^(NSURLSessionTask *task, BOOL createdSuccessfully) {
                    if(createdSuccessfully)
                    {
                        // Reload data
                        [self.imagesCollection reloadData];

                        // Hide HUD
                        [self hideHUDwithSuccess:YES completion:nil];
                        
                        // Reset buttons
                        [self didCancelTapAddButton];
                    }
                    else
                    {
                        // Hide HUD and inform user
                        [self hideHUDwithSuccess:NO completion:^{
                            [self showCreateCategoryErrorWithMessage:nil];
                        }];
                    }
                } onFailure:^(NSURLSessionTask *task, NSError *error) {
                    // Hide HUD and inform user
                    [self hideHUDwithSuccess:NO completion:^{
                        [self showCreateCategoryErrorWithMessage:[error localizedDescription]];
                    }];
                }];
}

-(void)showCreateCategoryErrorWithMessage:(NSString*)message
{
    NSString *errorMessage = NSLocalizedString(@"createAlbumError_message", @"Failed to create a new album");
    if(message)
    {
        errorMessage = [NSString stringWithFormat:@"%@\n%@", errorMessage, message];
    }
    UIAlertController* alert = [UIAlertController
            alertControllerWithTitle:NSLocalizedString(@"createAlbumError_title", @"Create Album Error")
            message:errorMessage
            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* dismissAction = [UIAlertAction
            actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
            style:UIAlertActionStyleCancel
            handler:^(UIAlertAction * action) {
                // Reset buttons
                [self didCancelTapAddButton];
    }];
    
    // Add actions
    [alert addAction:dismissAction];

    // Present list of actions
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    [self presentViewController:alert animated:YES completion:nil];
}


#pragma mark - Select Images

-(void)didTapSelect
{
    // Activate Images Selection mode
    self.isSelect = YES;
    
    // Disable interaction with category cells and scroll to first image cell if needed
    NSInteger numberOfImageCells = 0;
    for (UICollectionViewCell *cell in self.imagesCollection.visibleCells) {

        // Disable user interaction with category cell
        if ([cell isKindOfClass:[CategoryCollectionViewCell class]]) {
            CategoryCollectionViewCell *categoryCell = (CategoryCollectionViewCell *)cell;
            [categoryCell setAlpha:0.5];
            [categoryCell setUserInteractionEnabled:NO];
        }

        // Will scroll to position if no visible image cell
        if ([cell isKindOfClass:[ImageCollectionViewCell class]]) {
            numberOfImageCells++;
        }
    }

    // Scroll to position of images if needed
    if (!numberOfImageCells)
        [self.imagesCollection scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:1] atScrollPosition:UICollectionViewScrollPositionTop animated:YES];
    
    // Refresh collection view
    [self.imagesCollection reloadData];
    
    // Update navigation bar and toolbar
    [self updateButtonsInSelectionMode];
}

-(void)cancelSelect
{
	// Disable Images Selection mode
    self.isSelect = NO;
    
    // Update navigation bar and toolbar
	[self updateButtonsInPreviewMode];
    
    // Enable interaction with category cells and deselect image cells
    for (UICollectionViewCell *cell in self.imagesCollection.visibleCells) {
        
        // Enable user interaction with category cell
        if ([cell isKindOfClass:[CategoryCollectionViewCell class]]) {
            CategoryCollectionViewCell *categoryCell = (CategoryCollectionViewCell *)cell;
            [categoryCell setAlpha:1.0];
            [categoryCell setUserInteractionEnabled:YES];
        }
        
        // Deselect image cell and disable interaction
        if ([cell isKindOfClass:[ImageCollectionViewCell class]]) {
            ImageCollectionViewCell *imageCell = (ImageCollectionViewCell *)cell;
            if(imageCell.isSelected) imageCell.isSelected = NO;
        }
    }

    // Clear array of selected images and allow iOS device to sleep
    self.touchedImageIds = [NSMutableArray new];
    self.selectedImageIds = [NSMutableArray new];
	[UIApplication sharedApplication].idleTimerDisabled = NO;
    
    // Refresh collection view
    [self.imagesCollection reloadData];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    // Will examine touchs only in select mode
    if (self.isSelect) {
       return YES;
    }
    return NO;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer;
{
    // Will interpret touches only in horizontal direction
    if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        UIPanGestureRecognizer *gPR = (UIPanGestureRecognizer *)gestureRecognizer;
        CGPoint translation = [gPR translationInView:self.imagesCollection];
        if (fabs(translation.x) > fabs(translation.y))
            return YES;
    }
    return NO;
}

-(void)touchedImages:(UIPanGestureRecognizer *)gestureRecognizer
{
    // Just in case…
    if (gestureRecognizer.view == nil) return;
    
    // Select/deselect cells
    if ((gestureRecognizer.state == UIGestureRecognizerStateBegan) ||
        (gestureRecognizer.state == UIGestureRecognizerStateChanged)) {
        
        // Point and direction
        CGPoint point = [gestureRecognizer locationInView:self.imagesCollection];
        
        // Get cell at touch position
        NSIndexPath *indexPath = [self.imagesCollection indexPathForItemAtPoint:point];
        if ((indexPath.section != 1) || (indexPath.row == NSNotFound)) return;
        UICollectionViewCell *cell = [self.imagesCollection cellForItemAtIndexPath:indexPath];
        if (cell == nil) return;
        
        // Only consider image cells
        if ([cell isKindOfClass:[ImageCollectionViewCell class]])
        {
            ImageCollectionViewCell *imageCell = (ImageCollectionViewCell *)cell;
            
            // Update the selection if not already done
            NSString *imageIdObject = [NSString stringWithFormat:@"%ld", (long)imageCell.imageData.imageId];
            if (![self.touchedImageIds containsObject:imageIdObject]) {
                
                // Store that the user touched this cell during this gesture
                [self.touchedImageIds addObject:imageIdObject];
                
                // Update the selection state
                if(![self.selectedImageIds containsObject:imageIdObject]) {
                    [self.selectedImageIds addObject:imageIdObject];
                    imageCell.isSelected = YES;
                } else {
                    imageCell.isSelected = NO;
                    [self.selectedImageIds removeObject:imageIdObject];
                }
                
                // Reload the cell and update the navigation bar
                [self.imagesCollection reloadItemsAtIndexPaths:@[indexPath]];
                [self updateButtonsInSelectionMode];
            }
        }
    }
    
    // Is this the end of the gesture?
    if ([gestureRecognizer state] == UIGestureRecognizerStateEnded) {
        self.touchedImageIds = [NSMutableArray new];
    }
}


#pragma mark - Edit images

-(void)editSelection
{
    if (self.selectedImageIds.count <= 0) return;

    // Disable buttons
    [self disableBarButtons];
    
    // Display HUD
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showHUDwithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…") inMode:MBProgressHUDModeIndeterminate withDetailLabel:NO];
    });
    
    // Retrieve image data
    self.selectedImagesToEdit = [NSMutableArray new];
    self.selectedImageIdsToEdit = [NSMutableArray arrayWithArray:[self.selectedImageIds mutableCopy]];
    [self retrieveImageDataBeforeEdit];
}

-(void)retrieveImageDataBeforeEdit
{
    if (self.selectedImageIdsToEdit.count <= 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideHUDwithSuccess:NO completion:^{
                [self editImages];
            }];
        });
        return;
    }
    
    // Image data are not complete when retrieved using pwg.categories.getImages
    [ImageService getImageInfoById:[[self.selectedImageIdsToEdit lastObject] integerValue]
                andAddImageToCache:NO
                  ListOnCompletion:^(NSURLSessionTask *task, PiwigoImageData *imageData) {
                      
                      if (imageData != nil) {
                          // Store image data
                          [self.selectedImagesToEdit insertObject:imageData atIndex:0];
                          
                          // Next image
                          [self.selectedImageIdsToEdit removeLastObject];
                          [self retrieveImageDataBeforeEdit];
                      }
                      else {
                          // Could not retrieve image data
                          [self couldNotRetrieveImageDataOnRetry:^{
                              [self retrieveImageDataBeforeEdit];
                          }];
                      }
                  }
                         onFailure:^(NSURLSessionTask *task, NSError *error) {
                             // Failed — Ask user if he/she wishes to retry
                             [self couldNotRetrieveImageDataOnRetry:^{
                                 [self retrieveImageDataBeforeEdit];
                             }];
                         }];
}

-(void)couldNotRetrieveImageDataOnRetry:(void (^)(void))completion
{
    // Failed — Ask user if he/she wishes to retry
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"imageDetailsFetchError_title", @"Image Details Fetch Failed")
        message:NSLocalizedString(@"imageDetailsFetchError_retryMessage", @"Fetching the image data failed\nTry again?")
        preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* dismissAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
        style:UIAlertActionStyleCancel
        handler:^(UIAlertAction * action) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updateButtonsInSelectionMode];
                [self hideHUD];
            });
        }];
    
    UIAlertAction* retryAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"alertRetryButton", @"Retry")
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction * action) {
            if (completion) completion();
        }];
    
    [alert addAction:dismissAction];
    [alert addAction:retryAction];
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    [self presentViewController:alert animated:YES completion:nil];
}

-(void)editImages
{
    switch (self.selectedImagesToEdit.count) {
        case 0:     // No image => End (should never happened)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideHUDwithSuccess:YES completion:^{
                    [self cancelSelect];
                }];
            });
            break;
        }
            
        default:    // Several images
        {
            // Present EditImageParams view
            UIStoryboard *editImageSB = [UIStoryboard storyboardWithName:@"EditImageParams" bundle:nil];
            EditImageParamsViewController *editImageVC = [editImageSB instantiateViewControllerWithIdentifier:@"EditImageParams"];
            editImageVC.images = [self.selectedImagesToEdit copy];
            editImageVC.delegate = self;
            [self pushView:editImageVC];
            break;
        }
    }
}


#pragma mark - Delete images

-(void)deleteSelection
{
    if(self.selectedImageIds.count <= 0) return;
    
    // Disable buttons
    [self disableBarButtons];
    
    // Display HUD
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showHUDwithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…") inMode:MBProgressHUDModeIndeterminate withDetailLabel:NO];
    });
    
    // Retrieve image data
    self.selectedImagesToDelete = [NSMutableArray new];
    self.selectedImagesToRemove = [NSMutableArray new];
    self.selectedImageIdsToDelete = [NSMutableArray arrayWithArray:[self.selectedImageIds mutableCopy]];
    [self retrieveImageDataBeforeDelete];
}

-(void)retrieveImageDataBeforeDelete
{
    if (self.selectedImageIdsToDelete.count <= 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideHUDwithSuccess:NO completion:^{
                [self askDeleteConfirmation];
            }];
        });
        return;
    }
    
    // Image data are not complete when retrieved with pwg.categories.getImages
    [ImageService getImageInfoById:[[self.selectedImageIdsToDelete lastObject] integerValue]
                andAddImageToCache:NO
          ListOnCompletion:^(NSURLSessionTask *task, PiwigoImageData *imageData) {

              if (imageData != nil) {
                  // Split orphaned and non-orphaned images
                  if (imageData.categoryIds.count > 1) {
                      [self.selectedImagesToRemove insertObject:imageData atIndex:0];
                  }
                  else {
                      [self.selectedImagesToDelete insertObject:imageData atIndex:0];
                  }
              
                  // Next image
                  [self.selectedImageIdsToDelete removeLastObject];
                  [self retrieveImageDataBeforeDelete];
              }
              else {
                  // Could not retrieve image data
                  [self couldNotRetrieveImageDataOnRetry:^{
                      [self retrieveImageDataBeforeDelete];
                  }];
              }
          }
                 onFailure:^(NSURLSessionTask *task, NSError *error) {
                     // Failed — Ask user if he/she wishes to retry
                     [self couldNotRetrieveImageDataOnRetry:^{
                         [self retrieveImageDataBeforeDelete];
                     }];
                 }];
}

-(void)askDeleteConfirmation
{
    NSString *messageString;
    NSInteger totalNberToDelete = self.selectedImagesToDelete.count + self.selectedImagesToRemove.count;
    // Alert message
    if (totalNberToDelete > 1) {
        messageString = [NSString stringWithFormat:NSLocalizedString(@"deleteSeveralImages_message", @"Are you sure you want to delete the selected %@ images?"), @(totalNberToDelete)];
    } else {
        messageString = NSLocalizedString(@"deleteSingleImage_message", @"Are you sure you want to delete this image?");
    }

    // Do we really want to delete these images?
    UIAlertController* alert = [UIAlertController
        alertControllerWithTitle:nil
        message:messageString
        preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction* cancelAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
        style:UIAlertActionStyleCancel
        handler:^(UIAlertAction * action) {
            [self updateButtonsInSelectionMode];
        }];
    
    UIAlertAction* removeImagesAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"deleteCategory_orphanedImages", @"Delete Orphans")
        style:UIAlertActionStyleDestructive
        handler:^(UIAlertAction * action) {

            // Display HUD during server update
            self.totalNumberOfImages = self.selectedImagesToRemove.count
                                     + (self.selectedImagesToDelete.count > 0);
            if (self.totalNumberOfImages > 1) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self showHUDwithTitle:NSLocalizedString(@"deleteSeveralImagesHUD_deleting", @"Deleting Images…") inMode:MBProgressHUDModeAnnularDeterminate withDetailLabel:NO];
                });
            }
            else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self showHUDwithTitle:NSLocalizedString(@"deleteSingleImageHUD_deleting", @"Deleting Image…") inMode:MBProgressHUDModeIndeterminate withDetailLabel:NO];
                });
            }

            // Start removing images
            [self removeImages];
        }];

    UIAlertAction* deleteImagesAction = [UIAlertAction
        actionWithTitle:totalNberToDelete > 1 ? [NSString stringWithFormat:NSLocalizedString(@"deleteSeveralImages_title", @"Delete %@ Images"), @(totalNberToDelete)] : NSLocalizedString(@"deleteSingleImage_title", @"Delete Image")
        style:UIAlertActionStyleDestructive
        handler:^(UIAlertAction * action) {
            
            [self.selectedImagesToDelete addObjectsFromArray:self.selectedImagesToRemove];

            // Display HUD during server update
            self.totalNumberOfImages = self.selectedImagesToDelete.count;
            if (self.selectedImagesToDelete.count > 1) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self showHUDwithTitle:NSLocalizedString(@"deleteSeveralImagesHUD_deleting", @"Deleting Images…") inMode:MBProgressHUDModeAnnularDeterminate withDetailLabel:NO];
                });
            }
            else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self showHUDwithTitle:NSLocalizedString(@"deleteSingleImageHUD_deleting", @"Deleting Image…") inMode:MBProgressHUDModeIndeterminate withDetailLabel:NO];
                });
            }

            // Start deleting images
            [self deleteImages];
       }];
    
    // Add actions
    [alert addAction:cancelAction];
    [alert addAction:deleteImagesAction];
    if (self.selectedImagesToRemove.count > 0) { [alert addAction:removeImagesAction]; }

    // Present list of actions
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    alert.popoverPresentationController.barButtonItem = self.deleteBarButton;
    [self presentViewController:alert animated:YES completion:nil];
}

-(void)removeImages
{
    if (self.selectedImagesToRemove.count <= 0)
    {
        if (self.selectedImagesToDelete.count <= 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideHUDwithSuccess:YES completion:^{
                    [self cancelSelect];
                }];
            });
        }
        else {
            [self deleteImages];
        }
        return;
    }
    
    // Update image category list
    self.selectedImage = [self.selectedImagesToRemove lastObject];
    NSMutableArray *categoryIds = [self.selectedImage.categoryIds mutableCopy];
    [categoryIds removeObject:@(self.categoryId)];
    
    // Let's remove the image from current category
    [ImageService setCategoriesForImage:self.selectedImage
         withCategories:categoryIds
             onProgress:nil
           OnCompletion:^(NSURLSessionTask *task, BOOL updatedSuccessfully) {
               if (updatedSuccessfully)
               {
                   // Remove image from current category
                   [self.albumData removeImageWithId:self.selectedImage.imageId];
                   [self.selectedImageIds removeObject:[NSString stringWithFormat:@"%ld", (long)self.selectedImage.imageId]];
                   [self.imagesCollection reloadData];

                   // Update cache
                   [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] removeImages:@[self.selectedImage]];
                   [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] deincrementImageSizeByOne];

                   // Next image
                   [self.selectedImagesToRemove removeLastObject];
                   dispatch_async(dispatch_get_main_queue(), ^{
                       [MBProgressHUD HUDForView:self.hudViewController.view].progress = 1.0 - (double)(self.selectedImagesToRemove.count + self.selectedImagesToDelete.count) / self.totalNumberOfImages;
                   });
                   [self removeImages];
               }
                else {
                    // Update album view if image moved
                    // Error — Try again ?
                    UIAlertController* alert = [UIAlertController
                        alertControllerWithTitle:NSLocalizedString(@"deleteImageFail_title", @"Delete Failed")
                        message:[NSString stringWithFormat:NSLocalizedString(@"deleteImageFail_message", @"Image could not be deleted\n%@"), NSLocalizedString(@"internetErrorGeneral_title", @"Connection Error")]
                        preferredStyle:UIAlertControllerStyleAlert];
                    
                    UIAlertAction* dismissAction = [UIAlertAction
                        actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                        style:UIAlertActionStyleCancel
                        handler:^(UIAlertAction * action) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self hideHUDwithSuccess:NO completion:^{
                                    [self updateButtonsInSelectionMode];
                                }];
                            });
                        }];
                    
                    UIAlertAction* retryAction = [UIAlertAction
                       actionWithTitle:NSLocalizedString(@"alertRetryButton", @"Retry")
                       style:UIAlertActionStyleDestructive
                       handler:^(UIAlertAction * action) {
                           [self removeImages];
                       }];
                    
                    // Add actions
                    [alert addAction:dismissAction];
                    [alert addAction:retryAction];
                    
                    // Present list of actions
                    if (@available(iOS 13.0, *)) {
                        alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
                    } else {
                        // Fallback on earlier versions
                    }
                    [self presentViewController:alert animated:YES completion:nil];
                }
           }
              onFailure:^(NSURLSessionTask *task, NSError *error) {
                  // Error — Try again ?
                  UIAlertController* alert = [UIAlertController
                      alertControllerWithTitle:NSLocalizedString(@"deleteImageFail_title", @"Delete Failed")
                      message:[NSString stringWithFormat:NSLocalizedString(@"deleteImageFail_message", @"Image could not be deleted\n%@"), [error localizedDescription]]
                      preferredStyle:UIAlertControllerStyleAlert];
                  
                  UIAlertAction* dismissAction = [UIAlertAction
                      actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                      style:UIAlertActionStyleCancel
                      handler:^(UIAlertAction * action) {
                          dispatch_async(dispatch_get_main_queue(), ^{
                              [self hideHUDwithSuccess:NO completion:^{
                                  [self updateButtonsInSelectionMode];
                              }];
                          });
                      }];
                  
                  UIAlertAction* retryAction = [UIAlertAction
                     actionWithTitle:NSLocalizedString(@"alertRetryButton", @"Retry")
                     style:UIAlertActionStyleDestructive
                     handler:^(UIAlertAction * action) {
                         [self removeImages];
                     }];
                  
                  // Add actions
                  [alert addAction:dismissAction];
                  [alert addAction:retryAction];
                  
                  // Present list of actions
                  if (@available(iOS 13.0, *)) {
                      alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
                  } else {
                      // Fallback on earlier versions
                  }
                  [self presentViewController:alert animated:YES completion:nil];
              }];
}

-(void)deleteImages
{
    if (self.selectedImagesToDelete.count <= 0)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideHUDwithSuccess:YES completion:^{
                [self cancelSelect];
            }];
        });
        return;
    }
    
    // Let's delete all images at once
    [ImageService deleteImages:self.selectedImagesToDelete
              ListOnCompletion:^(NSURLSessionTask *task) {
                  
                  // Images deleted
                  for (PiwigoImageData *selectedImage in self.selectedImagesToDelete) {
                      [self.albumData removeImageWithId:selectedImage.imageId];
                      [self.selectedImageIds removeObject:[NSString stringWithFormat:@"%ld", (long)selectedImage.imageId]];
                  }
                  
                  // Reload collection
                  [self.imagesCollection reloadData];

                  // Hide HUD
                  dispatch_async(dispatch_get_main_queue(), ^{
                      [self hideHUDwithSuccess:YES completion:^{
                          [self cancelSelect];
                      }];
                  });
              }
                    onFailure:^(NSURLSessionTask *task, NSError *error) {
                        // Error — Try again ?
                        UIAlertController* alert = [UIAlertController
                            alertControllerWithTitle:NSLocalizedString(@"deleteImageFail_title", @"Delete Failed")
                            message:[NSString stringWithFormat:NSLocalizedString(@"deleteImageFail_message", @"Image could not be deleted\n%@"), [error localizedDescription]]
                            preferredStyle:UIAlertControllerStyleAlert];
                        
                        UIAlertAction* dismissAction = [UIAlertAction
                            actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                            style:UIAlertActionStyleCancel
                            handler:^(UIAlertAction * action) {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [self hideHUDwithSuccess:NO completion:^{
                                        [self updateButtonsInSelectionMode];
                                    }];
                                });
                            }];
                        
                        UIAlertAction* retryAction = [UIAlertAction
                            actionWithTitle:NSLocalizedString(@"alertRetryButton", @"Retry")
                            style:UIAlertActionStyleDestructive
                            handler:^(UIAlertAction * action) {
                              [self deleteImages];
                            }];
                        
                        // Add actions
                        [alert addAction:dismissAction];
                        [alert addAction:retryAction];
                        
                        // Present list of actions
                        if (@available(iOS 13.0, *)) {
                            alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
                        } else {
                            // Fallback on earlier versions
                        }
                        [self presentViewController:alert animated:YES completion:nil];
                    }];
}


#pragma mark - Share images

-(void)shareSelection
{
    if (self.selectedImageIds.count <= 0) return;

    // Disable buttons
    [self disableBarButtons];
    
    // Display HUD
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showHUDwithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…") inMode:MBProgressHUDModeIndeterminate withDetailLabel:NO];
    });
    
    // Retrieve image data
    self.selectedImagesToShare = [NSMutableArray new];
    self.selectedImageIdsToShare = [NSMutableArray arrayWithArray:[self.selectedImageIds mutableCopy]];
    [self retrieveImageDataBeforeShare];
}

-(void)retrieveImageDataBeforeShare
{
    if (self.selectedImageIdsToShare.count <= 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideHUDwithSuccess:NO completion:^{
                [self checkPhotoLibraryAccessBeforeShare];
            }];
        });
        return;
    }
    
    // Image data are not complete when retrieved using pwg.categories.getImages
    [ImageService getImageInfoById:[[self.selectedImageIdsToShare lastObject] integerValue]
                andAddImageToCache:NO
                  ListOnCompletion:^(NSURLSessionTask *task, PiwigoImageData *imageData) {
                      
                      if (imageData != nil) {
                          // Store image data
                          [self.selectedImagesToShare insertObject:imageData atIndex:0];
                          
                          // Next image
                          [self.selectedImageIdsToShare removeLastObject];
                          [self retrieveImageDataBeforeShare];
                      }
                      else {
                          // Could not retrieve image data
                          [self couldNotRetrieveImageDataOnRetry:^{
                              [self retrieveImageDataBeforeShare];
                          }];
                      }
                  }
                         onFailure:^(NSURLSessionTask *task, NSError *error) {
                             // Failed — Ask user if he/she wishes to retry
                             [self couldNotRetrieveImageDataOnRetry:^{
                                 [self retrieveImageDataBeforeShare];
                             }];
                         }];
}

-(void)checkPhotoLibraryAccessBeforeShare
{
    // Check autorisation to access Photo Library (camera roll)
    [[PhotosFetch sharedInstance] checkPhotoLibraryAccessForViewController:nil
                onAuthorizedAccess:^{
                    // User allowed to save image in camera roll
                    [self presentShareImageViewControllerWithCameraRollAccess:YES];
                }
                    onDeniedAccess:^{
                        // User not allowed to save image in camera roll
                        if ([NSThread isMainThread]) {
                            [self presentShareImageViewControllerWithCameraRollAccess:NO];
                        }
                        else{
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self presentShareImageViewControllerWithCameraRollAccess:NO];
                            });
                        }
                    }];
}

-(void)presentShareImageViewControllerWithCameraRollAccess:(BOOL)hasCameraRollAccess
{
    // Create new activity provider items to pass to the activity view controller
    self.totalNumberOfImages = self.selectedImagesToShare.count;
    NSMutableArray *itemsToShare = [NSMutableArray new];
    for (PiwigoImageData *imageData in self.selectedImagesToShare) {
        if (imageData.isVideo) {
            // Case of a video
            AsyncVideoActivityItemProvider *videoItemProvider = [[AsyncVideoActivityItemProvider alloc]  initWithPlaceholderImage:imageData];
            
            // Use delegation to monitor the progress of the item method
            videoItemProvider.delegate = self;
            
            // Add to list of items to share
            [itemsToShare addObject:videoItemProvider];
        }
        else {
            // Case of an image
            AsyncImageActivityItemProvider *imageItemProvider = [[AsyncImageActivityItemProvider alloc]  initWithPlaceholderImage:imageData];
            
            // Use delegation to monitor the progress of the item method
            imageItemProvider.delegate = self;
            
            // Add to list of items to share
            [itemsToShare addObject:imageItemProvider];
        }
    }

    // Create an activity view controller with the activity provider item.
    // AsyncImageActivityItemProvider's superclass conforms to the UIActivityItemSource protocol
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:itemsToShare applicationActivities:nil];
    
    // Set HUD view controller for displaying progress
    self.hudViewController = activityViewController;
    
    // Exclude camera roll activity if needed
    if (!hasCameraRollAccess) {
        activityViewController.excludedActivityTypes = @[UIActivityTypeSaveToCameraRoll];
    }

    // Delete image/video files and remove observers after dismissing activity view controller
    [activityViewController setCompletionWithItemsHandler:^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError){
//        NSLog(@"Activity Type selected: %@", activityType);
        if (completed) {
//            NSLog(@"Selected activity was performed and returned error:%ld", (long)activityError.code);
            [self hideHUDwithSuccess:YES completion:nil];
            [self cancelSelect];
            for (PiwigoImageData *imageData in self.selectedImagesToShare) {
                if (imageData.isVideo) {
                    // Delete shared video file & remove observers
                    [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationDidShareVideo object:nil];
                }
                else {
                    // Delete shared image file & remove observers
                    [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationDidShareImage object:nil];
                }
            }
        } else {
            if (activityType == NULL) {
//                NSLog(@"User dismissed the view controller without making a selection.");
                [self updateButtonsInSelectionMode];
            }
            else {
//                NSLog(@"Activity was not performed.");
                [self cancelSelect];
                for (PiwigoImageData *imageData in self.selectedImagesToShare) {
                    if (imageData.isVideo)
                    {
                        // Cancel download task
                        [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationCancelDownloadVideo object:nil];
                        
                        // Delete shared video file & remove observers
                        [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationDidShareVideo object:nil];
                    }
                    else {
                        // Cancel download task
                        [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationCancelDownloadImage object:nil];
                        
                        // Delete shared image file & remove observers
                        [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationDidShareImage object:nil];
                    }
                }
            }
        }
    }];
    
    // Present share image activity view controller
    activityViewController.popoverPresentationController.barButtonItem = self.shareBarButton;
    [self presentViewController:activityViewController animated:YES completion:nil];
}

-(void)cancelShareImages
{
    // Cancel video file donwload
    [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationCancelDownloadVideo object:nil];
    // Cancel image file download
    [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationCancelDownloadImage object:nil];
}


#pragma mark - Move/Copy images to Category

-(void)addImagesToCategory
{
    // Disable buttons
    [self disableBarButtons];
    
    // Determine index of first selected cell
    NSInteger indexOfFirstSelectedImage = LONG_MAX;
    PiwigoImageData *firstImageData;
    for (NSNumber *imageId in self.selectedImageIds) {
        NSInteger obj1 = [imageId integerValue];
        NSInteger index = 0;
        for (PiwigoImageData *image in self.albumData.images) {
            NSInteger obj2 = image.imageId;
            if (obj1 == obj2) break;
            index++;
        }
        indexOfFirstSelectedImage = MIN(index, indexOfFirstSelectedImage);
        firstImageData = [self.albumData.images objectAtIndex:indexOfFirstSelectedImage];
    }

    // Present alert to user
    UIAlertController* alert = [UIAlertController
                                alertControllerWithTitle:nil message:nil
                                preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction* cancelAction = [UIAlertAction
                                   actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
                                   style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction * action) {
                                       [self updateButtonsInSelectionMode];
                                   }];
    
    UIAlertAction* copyAction = [UIAlertAction
                                 actionWithTitle:NSLocalizedString(@"copyImage_title", @"Copy to Album")
                                 style:UIAlertActionStyleDefault
                                 handler:^(UIAlertAction * action) {
                                     MoveImageViewController *moveImageVC = [[MoveImageViewController alloc] initWithSelectedImageIds:self.selectedImageIds orSingleImageData:firstImageData inCategoryId:self.categoryId atIndex:indexOfFirstSelectedImage andCopyOption:YES];
                                     moveImageVC.moveImagesDelegate = self;
                                     [self pushView:moveImageVC];
                                 }];
    
    UIAlertAction* moveAction = [UIAlertAction
                                 actionWithTitle:NSLocalizedString(@"moveImage_title", @"Move to Album")
                                 style:UIAlertActionStyleDefault
                                 handler:^(UIAlertAction * action) {
                                     MoveImageViewController *moveImageVC = [[MoveImageViewController alloc] initWithSelectedImageIds:self.selectedImageIds orSingleImageData:firstImageData inCategoryId:self.categoryId atIndex:indexOfFirstSelectedImage andCopyOption:NO];
                                     moveImageVC.moveImagesDelegate = self;
                                     [self pushView:moveImageVC];
                                 }];
    
    // Add actions
    [alert addAction:cancelAction];
    [alert addAction:copyAction];
    [alert addAction:moveAction];
    
    // Present list of actions
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    alert.popoverPresentationController.barButtonItem = self.moveBarButton;
    [self presentViewController:alert animated:YES completion:nil];
}


#pragma mark - UICollectionView Headers & Footers

-(UICollectionReusableView*)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case 0:     // Section 0 — Album collection
        {
            CategoryHeaderReusableView *header = nil;
            
            if (kind == UICollectionElementKindSectionHeader) {
                header = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"CategoryHeader" forIndexPath:indexPath];
                PiwigoAlbumData *albumData = [[CategoriesData sharedInstance] getCategoryById:self.categoryId];
                if ([albumData.comment length] > 0) {
                    header.commentLabel.text = albumData.comment;
                }
                header.commentLabel.textColor = [UIColor piwigoColorHeader];
                return header;
            }
            break;
        }
            
        case 1:    // Section 1 — Image collection
        {
            if(kind == UICollectionElementKindSectionFooter)
            {
                NberImagesFooterCollectionReusableView *footer = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:@"NberImagesFooterCollection" forIndexPath:indexPath];
                footer.noImagesLabel.textColor = [UIColor piwigoColorHeader];

                if (self.loadingImages) {
                    // Currently trying to load images…
                    footer.noImagesLabel.text = NSLocalizedString(@"categoryMainEmtpy", @"No albums in your Piwigo yet.\rYou may pull down to refresh or re-login.");
                } else {
                    // Get number of images
                    NSInteger totalImageCount = 0;
                    if (self.categoryId == 0) {
                        // Only albums in Root Album => total number of images
                        for (PiwigoAlbumData *albumData in [[CategoriesData sharedInstance] getCategoriesForParentCategory:self.categoryId]) {
                            totalImageCount += albumData.totalNumberOfImages;
                        }
                    } else {
                        // Number of images in current album
                        totalImageCount = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].totalNumberOfImages;
                    }

                    if (totalImageCount == 0) {
                        // Not loading and no images
                        footer.noImagesLabel.text = NSLocalizedString(@"noImages", @"No Images");
                    }
                    else {
                        // Display number of images…
                        NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
                        [numberFormatter setPositiveFormat:@"#,##0"];
                        footer.noImagesLabel.text = [NSString stringWithFormat:@"%@ %@", [numberFormatter stringFromNumber:[NSNumber numberWithInteger:totalImageCount]], totalImageCount > 1 ? NSLocalizedString(@"categoryTableView_photosCount", @"photos") : NSLocalizedString(@"categoryTableView_photoCount", @"photo")];
                    }
                }
                return footer;
            }
            break;
        }
    }

	UICollectionReusableView *view = [[UICollectionReusableView alloc] initWithFrame:CGRectZero];
	return view;
}

- (void)collectionView:(UICollectionView *)collectionView willDisplaySupplementaryView:(UICollectionReusableView *)view forElementKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath
{
    if (([elementKind isEqualToString:UICollectionElementKindSectionHeader]) ||
        ([elementKind isEqualToString:UICollectionElementKindSectionFooter])) {
        view.layer.zPosition = 0;       // Below scroll indicator
        view.backgroundColor = [[UIColor piwigoColorBackground] colorWithAlphaComponent:0.75];
    }
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case 0:     // Section 0 — Album collection
        {
            // Header height?
            PiwigoAlbumData *albumData = [[CategoriesData sharedInstance] getCategoryById:self.categoryId];
            if ([albumData.comment length] > 0) {
                NSString *header = albumData.comment;
                NSDictionary *attributes = @{NSFontAttributeName: [UIFont piwigoFontNormal]};
                NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
                context.minimumScaleFactor = 1.0;
                CGRect headerRect = [header boundingRectWithSize:CGSizeMake(collectionView.frame.size.width - 30.0, CGFLOAT_MAX)
                                                         options:NSStringDrawingUsesLineFragmentOrigin
                                                      attributes:attributes
                                                         context:context];
                return CGSizeMake(collectionView.frame.size.width - 30.0, ceil(headerRect.size.height));
            }
            break;
        }
    }

    return CGSizeZero;
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForFooterInSection:(NSInteger)section
{
    switch (section) {
        case 1:    // Section 1 — Image collection
        {
            NSString *footer = @"";
            if (self.loadingImages) {
                // Currently trying to load images…
                footer = NSLocalizedString(@"categoryMainEmtpy", @"No albums in your Piwigo yet.\rYou may pull down to refresh or re-login.");
            } else {
                // Get number of images
                NSInteger totalImageCount = 0;
                if (self.categoryId == 0) {
                    // Only albums in Root Album => total number of images
                    for (PiwigoAlbumData *albumData in [[CategoriesData sharedInstance] getCategoriesForParentCategory:self.categoryId]) {
                        totalImageCount += albumData.totalNumberOfImages;
                    }
                } else {
                    // Number of images in current album
                    totalImageCount = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].totalNumberOfImages;
                }

                if (totalImageCount == 0) {
                    // Not loading and no images
                    footer = NSLocalizedString(@"noImages", @"No Images");
                }
                else {
                    // Display number of images…
                    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
                    [numberFormatter setPositiveFormat:@"#,##0"];
                    footer = [NSString stringWithFormat:@"%@ %@", [numberFormatter stringFromNumber:[NSNumber numberWithInteger:totalImageCount]], totalImageCount > 1 ? NSLocalizedString(@"categoryTableView_photosCount", @"photos") : NSLocalizedString(@"categoryTableView_photoCount", @"photo")];
                }
            }
 
            if ([footer length] > 0) {
                NSDictionary *attributes = @{NSFontAttributeName: [UIFont piwigoFontLight]};
                NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
                context.minimumScaleFactor = 1.0;
                CGRect footerRect = [footer boundingRectWithSize:CGSizeMake(collectionView.frame.size.width - 30.0, CGFLOAT_MAX)
                                                         options:NSStringDrawingUsesLineFragmentOrigin
                                                      attributes:attributes
                                                         context:context];
                return CGSizeMake(collectionView.frame.size.width - 30.0, ceil(footerRect.size.height + 10.0));
            }
            break;
        }
    }

    return CGSizeZero;
}


#pragma mark - UICollectionView - Rows

-(NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
	return 2;
}

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    // Returns number of images or albums
    NSInteger numberOfItems;
    switch (section) {
        case 0:             // Albums
            numberOfItems = [[CategoriesData sharedInstance] getCategoriesForParentCategory:self.categoryId].count;
            break;
            
        default:            // Images
            numberOfItems = self.albumData.images.count;
            break;
    }
    return numberOfItems;
}

-(UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
    // Avoid unwanted spaces
    switch (section) {
        case 0:             // Albums
        {
            if ([collectionView numberOfItemsInSection:section] == 0) {
                return UIEdgeInsetsMake(0, kAlbumMarginsSpacing, 0, kAlbumMarginsSpacing);
            }
            else if (self.categoryId == 0) {
                if (@available(iOS 13.0, *)) {
                    return UIEdgeInsetsMake(0, kAlbumMarginsSpacing, 0, kAlbumMarginsSpacing);
                } else {
                    return UIEdgeInsetsMake(10, kAlbumMarginsSpacing, 0, kAlbumMarginsSpacing);
                }
            }
            else {
                return UIEdgeInsetsMake(10, kAlbumMarginsSpacing, 0, kAlbumMarginsSpacing);
            }
            break;
        }
            
        default:            // Images
        {
            PiwigoAlbumData *albumData = [[CategoriesData sharedInstance] getCategoryById:self.categoryId];
            if ([collectionView numberOfItemsInSection:section] == 0) {
                return UIEdgeInsetsMake(0, kImageMarginsSpacing, 0, kImageMarginsSpacing);
            }
            else if ([albumData.comment length] == 0) {
                return UIEdgeInsetsMake(4, kImageMarginsSpacing, 4, kImageMarginsSpacing);
            }
            else {
                return UIEdgeInsetsMake(10, kImageMarginsSpacing, 4, kImageMarginsSpacing);
            }
            break;
        }
    }
}

-(CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section;
{
    switch (section) {
        case 0:             // Albums
            return 0.0;
            break;
            
        default:            // Images
            return (CGFloat)[ImagesCollection imageCellVerticalSpacingForCollectionType:kImageCollectionFull];
    }
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section;
{
    switch (section) {
        case 0:             // Albums
            return (CGFloat)kAlbumCellSpacing;
            break;
            
        default:            // Images
            return (CGFloat)[ImagesCollection imageCellHorizontalSpacingForCollectionType:kImageCollectionFull];
    }
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case 0:             // Albums (see XIB file)
        {
            float nberAlbumsPerRow = [ImagesCollection numberOfAlbumsPerRowForViewInPortrait:collectionView withMaxWidth:384.0];
            CGFloat size = (CGFloat)[ImagesCollection albumSizeForView:collectionView andNberOfAlbumsPerRowInPortrait:nberAlbumsPerRow];
            return CGSizeMake(size, 156.5);
            break;
        }
            
        default:            // Images
        {
            // Calculate the optimum image size
            CGFloat size = (CGFloat)[ImagesCollection imageSizeForView:collectionView imagesPerRowInPortrait:[Model sharedInstance].thumbnailsPerRowInPortrait];
            return CGSizeMake(size, size);
        }
    }
}

-(UICollectionViewCell*)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case 0:             // Albums (see XIB file)
        {
            CategoryCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"CategoryCollectionViewCell" forIndexPath:indexPath];
            cell.categoryDelegate = self;
            
            PiwigoAlbumData *albumData = [[[CategoriesData sharedInstance] getCategoriesForParentCategory:self.categoryId] objectAtIndex:indexPath.row];
            [cell setupWithAlbumData:albumData];
            
            // Disable category cells in Image selection mode
            if (self.isSelect) {
                [cell setAlpha:0.5];
                [cell setUserInteractionEnabled:NO];
            } else {
                [cell setAlpha:1.0];
                [cell setUserInteractionEnabled:YES];
            }
            
            return cell;
            break;
        }
            
        default:            // Images
        {
            ImageCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"ImageCollectionViewCell" forIndexPath:indexPath];
            
            if (self.albumData.images.count > indexPath.row) {
                // Create cell from Piwigo data
                PiwigoImageData *imageData = [self.albumData.images objectAtIndex:indexPath.row];
//                NSLog(@"Index:%ld => image ID:%@ - %@", indexPath.row, imageData.imageId, imageData.name);
                [cell setupWithImageData:imageData forCategoryId:self.categoryId];
                cell.isSelected = [self.selectedImageIds containsObject:[NSString stringWithFormat:@"%ld", (long)imageData.imageId]];
                
                // Add pan gesture recognition
                UIPanGestureRecognizer *imageSeriesRocognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(touchedImages:)];
                imageSeriesRocognizer.minimumNumberOfTouches = 1;
                imageSeriesRocognizer.maximumNumberOfTouches = 1;
                imageSeriesRocognizer.cancelsTouchesInView = NO;
                imageSeriesRocognizer.delegate = self;
                [cell addGestureRecognizer:imageSeriesRocognizer];
                cell.userInteractionEnabled = YES;
            }
            
            // Calculate the number of thumbnails displayed per page
            NSInteger imagesPerPage = [ImagesCollection numberOfImagesPerPageForView:collectionView imagesPerRowInPortrait:[Model sharedInstance].thumbnailsPerRowInPortrait];
            
            // Load image data in advance if possible (page after page…)
            if ((indexPath.row > fmaxf(roundf(2 * imagesPerPage / 3.0), [collectionView numberOfItemsInSection:1] - roundf(imagesPerPage / 3.0))) &&
                (self.albumData.images.count != [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] numberOfImages]))
            {
                [self.albumData loadMoreImagesOnCompletion:^{
                    [self.imagesCollection reloadData];
                }];
            }
            
            return cell;
        }
    }
}


#pragma mark - UICollectionViewDelegate Methods

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case 0:             // Albums
            break;
            
        default:            // Images
        {
            ImageCollectionViewCell *selectedCell = (ImageCollectionViewCell*)[collectionView cellForItemAtIndexPath:indexPath];
            
            // Avoid rare crashes…
            if ((indexPath.row < 0) || (indexPath.row >= [self.albumData.images count])) {
                // forget this call!
                return;
            }
            
            // Action depends on mode
            if(!self.isSelect)
            {
                // Add category to list of recent albums
                NSDictionary *userInfo = @{@"categoryId" : [NSString stringWithFormat:@"%ld", (long)self.categoryId]};
                [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationAddRecentAlbum object:nil userInfo:userInfo];

                // Selection mode not active => display full screen image
                self.imageDetailView = [[ImageDetailViewController alloc] initWithCategoryId:self.categoryId atImageIndex:indexPath.row withArray:[self.albumData.images copy]];
                self.imageDetailView.hidesBottomBarWhenPushed = YES;
                self.imageDetailView.imgDetailDelegate = self;
                [self.navigationController pushViewController:self.imageDetailView animated:YES];
            }
            else
            {
                // Selection mode active => add/remove image from selection
                NSString *imageIdObject = [NSString stringWithFormat:@"%ld", (long)selectedCell.imageData.imageId];
                if(![self.selectedImageIds containsObject:imageIdObject]) {
                    [self.selectedImageIds addObject:imageIdObject];
                    selectedCell.isSelected = YES;
                } else {
                    selectedCell.isSelected = NO;
                    [self.selectedImageIds removeObject:imageIdObject];
                }
                [collectionView reloadItemsAtIndexPaths:@[indexPath]];
                
                // and display nav buttons
                [self updateButtonsInSelectionMode];
            }
        }
    }
}


#pragma mark - HUD methods

-(void)showHUDwithTitle:(NSString *)title inMode:(MBProgressHUDMode)mode withDetailLabel:(BOOL)isDownloading
{
    // Determine the present view controller if needed (not necessarily self.view)
    if (!self.hudViewController) {
        self.hudViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (self.hudViewController.presentedViewController) {
            self.hudViewController = self.hudViewController.presentedViewController;
        }
    }
    
    // Create the login HUD if needed
    MBProgressHUD *hud = [self.hudViewController.view viewWithTag:loadingViewTag];
    if (!hud) {
        // Create the HUD
        hud = [MBProgressHUD showHUDAddedTo:self.hudViewController.view animated:YES];
        [hud setTag:loadingViewTag];
        
        // Change the background view shape, style and color.
        hud.square = NO;
        hud.animationType = MBProgressHUDAnimationFade;
        hud.backgroundView.style = MBProgressHUDBackgroundStyleSolidColor;
        hud.backgroundView.color = [UIColor colorWithWhite:0.f alpha:0.5f];
        hud.contentColor = [UIColor piwigoColorHudContent];
        hud.bezelView.color = [UIColor piwigoColorHudBezelView];
        
        // Will look best, if we set a minimum size.
        hud.minSize = CGSizeMake(200.f, 100.f);
    }
    
    // Set title
    hud.label.text = title;
    hud.label.font = [UIFont piwigoFontNormal];
    
    // Image download or other action?
    switch (mode) {
        case MBProgressHUDModeAnnularDeterminate:
            // Downloading or deleting images
            hud.mode = MBProgressHUDModeAnnularDeterminate;
            if (isDownloading) {
                hud.detailsLabel.text = [NSString stringWithFormat:@"%ld / %ld", (long)(self.totalNumberOfImages - self.selectedImageIds.count + 1), (long)self.totalNumberOfImages];
                [hud.button setTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
                            forState:UIControlStateNormal];
                [hud.button addTarget:self action:@selector(cancelShareImages) forControlEvents:UIControlEventTouchUpInside];
            } else {
                hud.detailsLabel.text = @"";
            }
            break;
            
        default:
            // Other actions
            hud.mode = MBProgressHUDModeIndeterminate;
            hud.detailsLabel.text = @"";
            break;
    }
}

-(void)hideHUDwithSuccess:(BOOL)success completion:(void (^)(void))completion
{
    dispatch_async(dispatch_get_main_queue(), ^{
        // Hide and remove the HUD
        MBProgressHUD *hud = [self.hudViewController.view viewWithTag:loadingViewTag];
        if (hud) {
            if (success) {
                UIImage *image = [[UIImage imageNamed:@"completed"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
                hud.customView = imageView;
                hud.mode = MBProgressHUDModeCustomView;
                hud.label.text = NSLocalizedString(@"completeHUD_label", @"Complete");
                [hud hideAnimated:YES afterDelay:1.f];
            } else {
                [hud hideAnimated:YES];
            }
        }
        if (completion) {
            completion();
        }
    });
}

-(void)hideHUD
{
    // Hide and remove the HUD
    MBProgressHUD *hud = [self.hudViewController.view viewWithTag:loadingViewTag];
    if (hud) {
        [hud hideAnimated:YES];
        self.hudViewController = nil;
    }
}


#pragma mark - UITextField Delegate Methods

-(BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    // Disable Add Category action
    if ([textField.placeholder isEqualToString:NSLocalizedString(@"createNewAlbum_placeholder", @"Album Name")])
    {
        [self.createAlbumAction setEnabled:(textField.text.length >= 1)];
    }
    return YES;
}

-(BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    // Enable Add Category action if album name is non null
    if ([textField.placeholder isEqualToString:NSLocalizedString(@"createNewAlbum_placeholder", @"Album Name")])
    {
        NSString *finalString = [textField.text stringByReplacingCharactersInRange:range withString:string];
        [self.createAlbumAction setEnabled:(finalString.length >= 1)];
    }
    return YES;
}

-(BOOL)textFieldShouldClear:(UITextField *)textField
{
    // Disable Add Category action
    if ([textField.placeholder isEqualToString:NSLocalizedString(@"createNewAlbum_placeholder", @"Album Name")])
    {
        [self.createAlbumAction setEnabled:NO];
    }
    return YES;
}

-(BOOL)textFieldShouldEndEditing:(UITextField *)textField
{
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    return YES;
}


#pragma mark - ImageDetailDelegate Methods

-(void)didFinishPreviewOfImageWithId:(NSInteger)imageId
{
    NSInteger index = 0;
    for (PiwigoImageData *image in self.albumData.images) {
        if (image.imageId == imageId) break;
        index++;
    }
    if (index < [self.albumData.images count])
        self.imageOfInterest = [NSIndexPath indexPathForItem:index inSection:1];
}

-(void)didDeleteImage:(PiwigoImageData *)image atIndex:(NSInteger)index
{
    [self.albumData removeImage:image];
    index = MAX(0, index-1);                                    // index must be > 0
    index = MIN(index, [self.albumData.images count] - 1);      // index must be < nber images
    self.imageOfInterest = [NSIndexPath indexPathForItem:index inSection:1];
    [self.imagesCollection reloadData];
}

-(void)needToLoadMoreImages
{
    [self.albumData loadMoreImagesOnCompletion:^{
        if(self.imageDetailView != nil)
        {
            self.imageDetailView.images = [self.albumData.images mutableCopy];
        }
        [self.imagesCollection reloadData];
    }];
}


#pragma mark - EditImageParamsDelegate Methods

-(void)didDeselectImageWithId:(NSInteger)imageId
{
    // Deselect image
    [self.selectedImageIds removeObject:[NSString stringWithFormat:@"%ld", (long)imageId]];
    [self.imagesCollection reloadData];
}

-(void)didRenameFileOfImage:(PiwigoImageData *)imageData
{
    // Update image data
    [self.albumData updateImage:imageData];
}

-(void)didFinishEditingParams:(PiwigoImageData *)params
{
    // Update image data
    [self.albumData updateImage:params];

    // Deselect images and leave select mode
    [self cancelSelect];
}


#pragma mark - MoveImagesDelegate methods

-(void)cancelMoveImages
{
    // Re-enable buttons
    [self updateButtonsInSelectionMode];
}

-(void)didRemoveImage:(PiwigoImageData *)image atIndex:(NSInteger)index
{
    [self.albumData removeImage:image];
    index = MAX(0, index-1);                                    // index must be >= 0
    index = MIN(index, [self.albumData.images count] - 1);      // index must be < nber images
    self.imageOfInterest = [NSIndexPath indexPathForItem:index inSection:1];
    [self.imagesCollection reloadData];
}

-(void)deselectImages
{
    // Deselect images and leave select mode
    [self cancelSelect];
}


#pragma mark - ChangedSettingsDelegate Methods

-(void)didChangeDefaultAlbum
{
    // Change default album
    self.categoryId = [Model sharedInstance].defaultCategory;
    self.albumData = [[AlbumData alloc] initWithCategoryId:self.categoryId andQuery:@""];

    // For iOS 11 and later: place search bar in navigation bar or root album
    if (@available(iOS 11.0, *)) {
        // Initialise search controller when displaying root album
        if (self.categoryId == 0) {
            SearchImagesViewController *resultsCollectionController = [[SearchImagesViewController alloc] init];
            UISearchController *searchController = [[UISearchController alloc] initWithSearchResultsController:resultsCollectionController];
            searchController.delegate = self;
            searchController.hidesNavigationBarDuringPresentation = YES;
            searchController.searchResultsUpdater = self;
            
            searchController.searchBar.tintColor = [UIColor piwigoColorOrange];
            searchController.searchBar.searchBarStyle = UISearchBarStyleMinimal;
            searchController.searchBar.translucent = NO;
            searchController.searchBar.showsCancelButton = NO;
            searchController.searchBar.showsSearchResultsButton = NO;
            searchController.searchBar.delegate = self;        // Monitor when the search button is tapped.
            self.definesPresentationContext = YES;
            
            // Place the search bar in the navigation bar.
            self.navigationItem.searchController = searchController;
        } else {
            self.navigationItem.searchController = nil;
        }
    }

    // Load, sort images and reload collection
    [self refresh:nil];
}


#pragma mark - CategorySortDelegate Methods

-(void)didSelectCategorySortType:(kPiwigoSortCategory)sortType
{
	self.currentSortCategory = sortType;
    [self.albumData updateImageSort:sortType OnCompletion:^{
//        NSLog(@"didSelectCategorySortType:Sorting images…");
        [self.imagesCollection reloadData];
    }];
}


#pragma mark - CategoryCollectionViewCellDelegate Methods

-(void)pushView:(UIViewController *)viewController
{
    // Push sub-album or Discover album
    if (([viewController isKindOfClass:[AlbumImagesViewController class]])    ||
        ([viewController isKindOfClass:[DiscoverImagesViewController class]]) ||
        ([viewController isKindOfClass:[FavoritesImagesViewController class]]) ) {
        // Push sub-album view
        [self.navigationController pushViewController:viewController animated:YES];
    }
    else {
        // Push album list or tag list
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
        {
            viewController.modalPresentationStyle = UIModalPresentationPopover;
            viewController.popoverPresentationController.sourceView = self.imagesCollection;
            if ([viewController isKindOfClass:[MoveCategoryViewController class]]) {
                viewController.popoverPresentationController.permittedArrowDirections = 0;
                [self.navigationController presentViewController:viewController animated:YES completion:nil];
            }
            else if ([viewController isKindOfClass:[MoveImageViewController class]]) {
                viewController.popoverPresentationController.barButtonItem = self.moveBarButton;
                viewController.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionUp;
                [self.navigationController presentViewController:viewController animated:YES completion:nil];
            }
            else if ([viewController isKindOfClass:[TagSelectorViewController class]]) {
                viewController.popoverPresentationController.barButtonItem = self.discoverBarButton;
                viewController.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionUp;
                [self.navigationController presentViewController:viewController animated:YES completion:nil];
            }
            else if ([viewController isKindOfClass:[EditImageParamsViewController class]]) {
                // Push Edit view embedded in navigation controller
                UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:viewController];
                navController.modalPresentationStyle = UIModalPresentationPopover;
                navController.popoverPresentationController.sourceView = self.view;
                navController.popoverPresentationController.barButtonItem = self.editBarButton;
                navController.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionUp;
                [self.navigationController presentViewController:navController animated:YES completion:nil];
            }
        }
        else {
            UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:viewController];
            navController.modalPresentationStyle = UIModalPresentationPopover;
            navController.popoverPresentationController.sourceView = self.view;
            navController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
            [self.navigationController presentViewController:navController animated:YES completion:nil];
        }
    }
}


#pragma mark - AsyncImageActivityItemProviderDelegate

-(void)imageActivityItemProviderPreprocessingDidBegin:(UIActivityItemProvider *)imageActivityItemProvider withTitle:(NSString *)title
{
    // Show HUD to let the user know the image is being downloaded in the background.
    dispatch_async(dispatch_get_main_queue(),
                   ^(void){
                       [self showHUDwithTitle:title inMode:MBProgressHUDModeAnnularDeterminate withDetailLabel:YES];
                   });
}

-(void)imageActivityItemProvider:(UIActivityItemProvider *)imageActivityItemProvider preprocessingProgressDidUpdate:(float)progress
{
    // Update HUD
    dispatch_async(dispatch_get_main_queue(),
                   ^(void){
                       [MBProgressHUD HUDForView:self.hudViewController.view].progress = progress;
                   });
}

-(void)imageActivityItemProviderPreprocessingDidEnd:(UIActivityItemProvider *)imageActivityItemProvider withImageId:(NSInteger)imageId
{
    // Close HUD
    NSString *imageIdObject = [NSString stringWithFormat:@"%ld", (long)imageId];
    dispatch_async(dispatch_get_main_queue(),
                   ^(void){
                       if ([imageActivityItemProvider isCancelled]) {
                           [self hideHUDwithSuccess:NO completion:^{
                               self.hudViewController = nil;
                           }];
                       } else {
                           if ([self.selectedImageIds containsObject:imageIdObject]) {
                               // Remove image from selection
                               [self.selectedImageIds removeObject:imageIdObject];
                               // Close HUD if last image
                               if ([self.selectedImageIds count] == 0) {
                                   [self hideHUDwithSuccess:NO completion:^{
                                       self.hudViewController = nil;
                                   }];
                               }
                           }
                       }
                   });
}

-(void)showErrorWithTitle:(NSString *)title andMessage:(NSString *)message
{
    // Close HUD if needed
    if (self.hudViewController) {
        [self hideHUDwithSuccess:NO completion:nil];
    }
    
    // Display error alert after trying to share image
    dispatch_async(dispatch_get_main_queue(),
                   ^(void){
                       // Determine present view controller
                       UIViewController *topViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
                       while (topViewController.presentedViewController) {
                           topViewController = topViewController.presentedViewController;
                       }
                       
                       // Present alert
                       UIAlertController* alert = [UIAlertController
                                                   alertControllerWithTitle:title
                                                   message:message
                                                   preferredStyle:UIAlertControllerStyleAlert];
                       
                       UIAlertAction* dismissAction = [UIAlertAction
                                                       actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                                                       style:UIAlertActionStyleCancel
                                                       handler:^(UIAlertAction * action) {
                           // Closes ActivityView
                           [topViewController dismissViewControllerAnimated:YES completion:nil];
                       }];
                       
                       [alert addAction:dismissAction];
                       if (@available(iOS 13.0, *)) {
                           alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
                       } else {
                           // Fallback on earlier versions
                       }
                       [topViewController presentViewController:alert animated:YES completion:nil];
                   });
}


#pragma mark - UISearchControllerDelegate

- (void)willPresentSearchController:(UISearchController *)searchController
{
    // Unregister category data updates
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPiwigoNotificationCategoryDataUpdated object:nil];
}

- (void)didDismissSearchController:(UISearchController *)searchController
{
    // Register category data updates
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(categoriesUpdated) name:kPiwigoNotificationCategoryDataUpdated object:nil];
}


#pragma mark - UISearchResultsUpdating

-(void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    
    // Query string
    NSString *searchString = [searchController.searchBar text];
    
    // Resfresh image collection for new query only
    if ([searchController.searchResultsController isKindOfClass:[SearchImagesViewController class]]) {
        SearchImagesViewController *resultsController = (SearchImagesViewController *)searchController.searchResultsController;
        
        if (![resultsController.searchQuery isEqualToString:searchString] || !searchString.length) {
            
            // Initialise search cache
            PiwigoAlbumData *searchAlbum = [[PiwigoAlbumData alloc] initSearchAlbumForQuery:searchString];
            [[CategoriesData sharedInstance] updateCategories:@[searchAlbum]];
            
            // Resfresh image collection
            resultsController.searchQuery = searchString;
            [resultsController searchAndLoadImages];
        }
    }
}


#pragma mark - Discover images

// Create Discover images view i.e. Most visited, Best rated, etc.
-(void)discoverImages
{
    // Do we really want to delete these images?
    UIAlertController* alert = [UIAlertController
        alertControllerWithTitle:nil
        message:NSLocalizedString(@"categoryDiscover_title", @"Discover")
        preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction* cancelAction = [UIAlertAction
       actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
       style:UIAlertActionStyleCancel
       handler:^(UIAlertAction * action) {}];

    UIAlertAction* favoritesSelectorAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"categoryDiscoverFavorites_title", @"Your favorites")
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction * action) {
            // Show tags for selecting images
            [self discoverFavoritesImages];
         }];
    
    UIAlertAction* tagSelectorAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"tags", @"Tags")
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction * action) {
            // Show tags for selecting images
            [self discoverImagesByTag];
         }];
    
    UIAlertAction* mostVisitedAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"categoryDiscoverVisits_title", @"Most visited")
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction * action) {
            // Show most visited images
            [self discoverImagesInCategoryId:kPiwigoVisitsCategoryId];
         }];
    
    UIAlertAction* bestRatedAction = [UIAlertAction
          actionWithTitle:NSLocalizedString(@"categoryDiscoverBest_title", @"Best rated")
          style:UIAlertActionStyleDefault
          handler:^(UIAlertAction * action) {
              // Show best rated images
              [self discoverImagesInCategoryId:kPiwigoBestCategoryId];
          }];

    UIAlertAction* recentAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"categoryDiscoverRecent_title", @"Recent photos")
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction * action) {
          // Show best rated images
          [self discoverImagesInCategoryId:kPiwigoRecentCategoryId];
        }];
    
    // Add actions
    [alert addAction:cancelAction];
    if ([@"2.10.0" compare:[Model sharedInstance].version options:NSNumericSearch] != NSOrderedDescending)
    {
        [alert addAction:favoritesSelectorAction];
    }
    [alert addAction:tagSelectorAction];
    [alert addAction:mostVisitedAction];
    [alert addAction:bestRatedAction];
    [alert addAction:recentAction];
    
    // Present list of Discover views
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    alert.popoverPresentationController.barButtonItem = self.discoverBarButton;
    [self presentViewController:alert animated:YES completion:nil];
}

-(void)discoverImagesInCategoryId:(NSInteger)categoryId
{
    // Create Discover view
    DiscoverImagesViewController *discoverController = [[DiscoverImagesViewController alloc] initWithCategoryId:categoryId];
    [self pushView:discoverController];
}

-(void)discoverImagesByTag
{
    // Push tag select view
    UIStoryboard *tagSelectorSB = [UIStoryboard storyboardWithName:@"TagSelectorViewController" bundle:nil];
    TagSelectorViewController *tagSelectorVC = [tagSelectorSB instantiateViewControllerWithIdentifier:@"TagSelectorViewController"];
    tagSelectorVC.tagSelectedDelegate = self;
    [self pushView:tagSelectorVC];
}

-(void)discoverFavoritesImages
{
    // Create Discover view
    FavoritesImagesViewController *discoverController = [[FavoritesImagesViewController alloc] initWithCategoryId:kPiwigoFavoritesCategoryId];
    [self pushView:discoverController];
}

#pragma mark - TagSelectViewDelegate Methods

-(void)pushTaggedImagesView:(UIViewController *)viewController
{
    // Push sub-album view
    [self.navigationController pushViewController:viewController animated:YES];
}

@end
