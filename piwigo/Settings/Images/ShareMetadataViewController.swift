//
//  ShareMetadataViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 22/01/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//
//  Converted to Swift 5 by Eddy Lelièvre-Berna on 04/04/2019.
//

import UIKit

let kPiwigoActivityTypeMessenger = UIActivity.ActivityType(rawValue: "com.facebook.Messenger.ShareExtension")
let kPiwigoActivityTypePostInstagram = UIActivity.ActivityType(rawValue: "com.burbn.instagram.shareextension")
let kPiwigoActivityTypePostToSignal = UIActivity.ActivityType(rawValue: "org.whispersystems.signal.shareextension")
let kPiwigoActivityTypePostToSnapchat = UIActivity.ActivityType(rawValue: "com.toyopagroup.picaboo.share")
let kPiwigoActivityTypePostToWhatsApp = UIActivity.ActivityType(rawValue: "net.whatsapp.WhatsApp.ShareExtension")
let kPiwigoActivityTypeOther = UIActivity.ActivityType(rawValue: "undefined.ShareExtension")

@objc
class ShareMetadataViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet var shareMetadataTableView: UITableView!
    
    private var activitiesSharingMetadata = [UIActivity.ActivityType]()
    private var activitiesNotSharingMetadata = [UIActivity.ActivityType]()

    private var editBarButton: UIBarButtonItem?
    private var doneBarButton: UIBarButtonItem?


// MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("tabBar_upload", comment: "Upload")
        
        // Buttons
        doneBarButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(stopEditingOptions))
    }

    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = UIColor.piwigoColorBackground()

        // Navigation bar appearence
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.piwigoFontNormal()
        ]
        navigationController?.navigationBar.titleTextAttributes = attributes as [NSAttributedString.Key : Any]
        if #available(iOS 11.0, *) {
            navigationController?.navigationBar.prefersLargeTitles = false
        }
        navigationController?.navigationBar.barStyle = Model.sharedInstance().isDarkPaletteActive ? .black : .default
        navigationController?.navigationBar.tintColor = UIColor.piwigoColorOrange()
        navigationController?.navigationBar.barTintColor = UIColor.piwigoColorBackground()
        navigationController?.navigationBar.backgroundColor = UIColor.piwigoColorBackground()

        // Table view
        shareMetadataTableView.separatorColor = UIColor.piwigoColorSeparator()
        shareMetadataTableView.indicatorStyle = Model.sharedInstance().isDarkPaletteActive ? .white : .black
        shareMetadataTableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Add Edit button
        navigationItem.setRightBarButton(editBarButton, animated: false)

        // Prepare data source
        setDataSourceFromSettings()

        // Set colors, fonts, etc.
        applyColorPalette()

        // Register palette changes
        let name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette), name: name, object: nil)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        //Reload the tableview on orientation change, to match the new width of the table.
        coordinator.animate(alongsideTransition: { context in

            // Reload table view
            self.shareMetadataTableView.reloadData()
        })
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Unregister palette changes
        let name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.removeObserver(self, name: name, object: nil)
    }

    
// MARK: - Editing mode
    
    @objc func stopEditingOptions() {
        // Replace "Done" button with "Edit" button
        navigationItem.setRightBarButton(editBarButton, animated: true)

        // Refresh table to remove [+] and [-] buttons
        shareMetadataTableView.reloadData()

        // Show back button
        navigationItem.setHidesBackButton(false, animated: true)
    }

    
// MARK: - UITableView - Header
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        var heightForHeader: CGFloat = 0.0
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0

        switch section {
            case 0:
                // Title
                let titleString = "\(NSLocalizedString("shareImageMetadata_Title", comment: "Share Metadata"))\n"
                let titleAttributes = [
                    NSAttributedString.Key.font: UIFont.piwigoFontBold()
                ]
                let titleRect = titleString.boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: titleAttributes, context: context)

                // Text
                let textString = NSLocalizedString("shareImageMetadata_subTitle1", comment: "Actions sharing images with private metadata")
                let textAttributes = [
                    NSAttributedString.Key.font: UIFont.piwigoFontSmall()
                ]
                let textRect = textString.boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: textAttributes, context: context)

                heightForHeader = CGFloat(fmax(44.0, ceil(titleRect.size.height + textRect.size.height)))
            case 1:
                // Text
                let textString = NSLocalizedString("shareImageMetadata_subTitle2", comment: "Actions sharing images without private metadata")
                let textAttributes = [
                    NSAttributedString.Key.font: UIFont.piwigoFontSmall()
                ]
                let textRect = textString.boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: textAttributes, context: context)
                heightForHeader = CGFloat(fmax(44.0, ceil(textRect.size.height)))
            default:
                break
        }
        return heightForHeader
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerAttributedString = NSMutableAttributedString(string: "")

        switch section {
            case 0:
                // Title
                let titleString = "\(NSLocalizedString("shareImageMetadata_Title", comment: "Share Metadata"))\n"
                let titleAttributedString = NSMutableAttributedString(string: titleString)
                titleAttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: NSRange(location: 0, length: titleString.count))
                headerAttributedString.append(titleAttributedString)

                // Text
                let textString = NSLocalizedString("shareImageMetadata_subTitle1", comment: "Actions sharing images with private metadata")
                let textAttributedString = NSMutableAttributedString(string: textString)
                textAttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: NSRange(location: 0, length: textString.count))
                headerAttributedString.append(textAttributedString)
            case 1:
                // Text
                let textString = NSLocalizedString("shareImageMetadata_subTitle2", comment: "Actions sharing images without private metadata")
                let textAttributedString = NSMutableAttributedString(string: textString)
                textAttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: NSRange(location: 0, length: textString.count))
                headerAttributedString.append(textAttributedString)
            default:
                break
        }

        // Header label
        let headerLabel = UILabel()
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.textColor = UIColor.piwigoColorHeader()
        headerLabel.numberOfLines = 0
        headerLabel.adjustsFontSizeToFitWidth = false
        headerLabel.lineBreakMode = .byWordWrapping
        headerLabel.attributedText = headerAttributedString

        // Header view
        let header = UIView()
        header.backgroundColor = UIColor.clear
        header.addSubview(headerLabel)
        header.addConstraint(NSLayoutConstraint.constraintView(fromBottom: headerLabel, amount: 4)!)
        if #available(iOS 11, *) {
            header.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-[header]-|", options: [], metrics: nil, views: [
            "header": headerLabel
            ]))
        } else {
            header.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-15-[header]-15-|", options: [], metrics: nil, views: [
            "header": headerLabel
            ]))
        }
        return header
    }

    
// MARK: - UITableView - Rows
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var nberOfRows = 0
        switch section {
            case 0:
                nberOfRows = activitiesSharingMetadata.count
            case 1:
                nberOfRows = activitiesNotSharingMetadata.count
            default:
                break
        }
        return nberOfRows
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44.0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        guard let cell = tableView.dequeueReusableCell(withIdentifier: "ShareMetadataCell", for: indexPath) as? ShareMetadataCell else {
            print("Error: tableView.dequeueReusableCell does not return a ShareMetadataCell!")
            return ShareMetadataCell()
        }

        let width = view.bounds.size.width
        switch indexPath.section {
            case 0:
                let activity = activitiesSharingMetadata[indexPath.row]
                let activityName = getName(forActivity: activity, forWidth: width)
                cell.configure(with: activityName, andEditOption: cellIconType.remove)
            case 1:
                let activity = activitiesNotSharingMetadata[indexPath.row]
                let activityName = getName(forActivity: activity, forWidth: width)
                cell.configure(with: activityName, andEditOption: cellIconType.add)
            default:
                break
        }

        cell.accessibilityIdentifier = "shareMetadata"
        cell.isAccessibilityElement = true
        return cell
    }

    
// MARK: - UITableViewDelegate Methods
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        var activitiesSharing = self.activitiesSharingMetadata
        var activitiesNotSharing = self.activitiesNotSharingMetadata

        switch indexPath.section {
        case 0: // Actions sharing photos with private metadata
            // Get tapped activity
            let activity = activitiesSharingMetadata[indexPath.row]
            
            // Update icon of tapped cell
            let cell = tableView.cellForRow(at: indexPath) as! ShareMetadataCell
            let width = view.bounds.size.width
            let activityName = getName(forActivity: activity, forWidth: width)
            cell.configure(with: activityName, andEditOption: cellIconType.add)

            // Switch activity state
            switchActivity(activity, toState: false)

            // Transfer activity to other section
            activitiesSharing = activitiesSharing.filter({ ($0) as AnyObject !== (activity) as AnyObject })
            activitiesNotSharing.append(activity)

            // Sort list of activities
            activitiesSharingMetadata = activitiesSharing.sorted()
            activitiesNotSharingMetadata = activitiesNotSharing.sorted()

            // Determine new indexPath of tapped activity
            let index = activitiesNotSharingMetadata.firstIndex(of: activity)
            let newIndexPath = IndexPath(row: index!, section: 1)

            // Move cell of tapped activity
            tableView.moveRow(at: indexPath, to: newIndexPath)

        case 1:     // Actions sharing photos without private metadata
            // Get tapped activity
            let activity = activitiesNotSharingMetadata[indexPath.row]

            // Update icon of tapped cell
            let cell = tableView.cellForRow(at: indexPath) as! ShareMetadataCell
            let width = view.bounds.size.width
            let activityName = getName(forActivity: activity, forWidth: width)
            cell.configure(with: activityName, andEditOption: cellIconType.remove)

            // Switch activity setting
            switchActivity(activity, toState: true)

            // Transfer activity to other section
            activitiesNotSharing = activitiesNotSharing.filter({ ($0) as AnyObject !== (activity) as AnyObject })
            activitiesSharing.append(activity)

            // Sort list of activities
            activitiesSharingMetadata = activitiesSharing.sorted()
            activitiesNotSharingMetadata = activitiesNotSharing.sorted()

            // Determine new indexPath of tapped activity
            let index = activitiesSharingMetadata.firstIndex(of: activity)
            let newIndexPath = IndexPath(row: index!, section: 0)

            // Move cell of tapped activity
            tableView.moveRow(at: indexPath, to: newIndexPath)

        default:
            return
        }
    }

    
// MARK: - Utilities
    
    private func setDataSourceFromSettings() {
        
        // Empty lists
        var activitiesSharing = [UIActivity.ActivityType]()
        var activitiesNotSharing = [UIActivity.ActivityType]()
        
        // Prepare data source from actual settings
        if Model.sharedInstance().shareMetadataTypeAirDrop {
            activitiesSharing.append(.airDrop)
        } else {
            activitiesNotSharing.append(.airDrop)
        }
        if Model.sharedInstance().shareMetadataTypeAssignToContact {
            activitiesSharing.append(.assignToContact)
        } else {
            activitiesNotSharing.append(.assignToContact)
        }
        if Model.sharedInstance().shareMetadataTypeCopyToPasteboard {
            activitiesSharing.append(.copyToPasteboard)
        } else {
            activitiesNotSharing.append(.copyToPasteboard)
        }
        if Model.sharedInstance().shareMetadataTypeMail {
            activitiesSharing.append(.mail)
        } else {
            activitiesNotSharing.append(.mail)
        }
        if Model.sharedInstance().shareMetadataTypeMessage {
            activitiesSharing.append(.message)
        } else {
            activitiesNotSharing.append(.message)
        }
        if Model.sharedInstance().shareMetadataTypePostToFacebook {
            activitiesSharing.append(.postToFacebook)
        } else {
            activitiesNotSharing.append(.postToFacebook)
        }
        if Model.sharedInstance().shareMetadataTypeMessenger {
            activitiesSharing.append(kPiwigoActivityTypeMessenger)
        } else {
            activitiesNotSharing.append(kPiwigoActivityTypeMessenger)
        }
        if Model.sharedInstance().shareMetadataTypePostToFlickr {
            activitiesSharing.append(.postToFlickr)
        } else {
            activitiesNotSharing.append(.postToFlickr)
        }
        if Model.sharedInstance().shareMetadataTypePostInstagram {
            activitiesSharing.append(kPiwigoActivityTypePostInstagram)
        } else {
            activitiesNotSharing.append(kPiwigoActivityTypePostInstagram)
        }
        if Model.sharedInstance().shareMetadataTypePostToSignal {
            activitiesSharing.append(kPiwigoActivityTypePostToSignal)
        } else {
            activitiesNotSharing.append(kPiwigoActivityTypePostToSignal)
        }
        if Model.sharedInstance().shareMetadataTypePostToSnapchat {
            activitiesSharing.append(kPiwigoActivityTypePostToSnapchat)
        } else {
            activitiesNotSharing.append(kPiwigoActivityTypePostToSnapchat)
        }
        if Model.sharedInstance().shareMetadataTypePostToTencentWeibo {
            activitiesSharing.append(.postToTencentWeibo)
        } else {
            activitiesNotSharing.append(.postToTencentWeibo)
        }
        if Model.sharedInstance().shareMetadataTypePostToTwitter {
            activitiesSharing.append(.postToTwitter)
        } else {
            activitiesNotSharing.append(.postToTwitter)
        }
        if Model.sharedInstance().shareMetadataTypePostToVimeo {
            activitiesSharing.append(.postToVimeo)
        } else {
            activitiesNotSharing.append(.postToVimeo)
        }
        if Model.sharedInstance().shareMetadataTypePostToWeibo {
            activitiesSharing.append(.postToWeibo)
        } else {
            activitiesNotSharing.append(.postToWeibo)
        }
        if Model.sharedInstance().shareMetadataTypePostToWhatsApp {
            activitiesSharing.append(kPiwigoActivityTypePostToWhatsApp)
        } else {
            activitiesNotSharing.append(kPiwigoActivityTypePostToWhatsApp)
        }
        if Model.sharedInstance().shareMetadataTypeSaveToCameraRoll {
            activitiesSharing.append(.saveToCameraRoll)
        } else {
            activitiesNotSharing.append(.saveToCameraRoll)
        }
        if Model.sharedInstance().shareMetadataTypeOther {
            activitiesSharing.append(kPiwigoActivityTypeOther)
        } else {
            activitiesNotSharing.append(kPiwigoActivityTypeOther)
        }
        
        activitiesSharingMetadata = activitiesSharing.sorted()
        activitiesNotSharingMetadata = activitiesNotSharing.sorted()
    }
    
    private func switchActivity(_ activity: UIActivity.ActivityType, toState newState: Bool) {
        // Change the boolean status of the selected activity
        switch activity {
        case .airDrop:
            Model.sharedInstance().shareMetadataTypeAirDrop = newState
        case .assignToContact:
            Model.sharedInstance().shareMetadataTypeAssignToContact = newState
        case .copyToPasteboard:
            Model.sharedInstance().shareMetadataTypeCopyToPasteboard = newState
        case .mail:
            Model.sharedInstance().shareMetadataTypeMail = newState
        case .message:
            Model.sharedInstance().shareMetadataTypeMessage = newState
        case .postToFacebook:
            Model.sharedInstance().shareMetadataTypePostToFacebook = newState
        case kPiwigoActivityTypeMessenger:
            Model.sharedInstance().shareMetadataTypeMessenger = newState
        case .postToFlickr:
            Model.sharedInstance().shareMetadataTypePostToFlickr = newState
        case kPiwigoActivityTypePostInstagram:
            Model.sharedInstance().shareMetadataTypePostInstagram = newState
        case kPiwigoActivityTypePostToSignal:
            Model.sharedInstance().shareMetadataTypePostToSignal = newState
        case kPiwigoActivityTypePostToSnapchat:
            Model.sharedInstance().shareMetadataTypePostToSnapchat = newState
        case .postToTencentWeibo:
            Model.sharedInstance().shareMetadataTypePostToTencentWeibo = newState
        case .postToTwitter:
            Model.sharedInstance().shareMetadataTypePostToTwitter = newState
        case .postToVimeo:
            Model.sharedInstance().shareMetadataTypePostToVimeo = newState
        case .postToWeibo:
            Model.sharedInstance().shareMetadataTypePostToWeibo = newState
        case kPiwigoActivityTypePostToWhatsApp:
            Model.sharedInstance().shareMetadataTypePostToWhatsApp = newState
        case .saveToCameraRoll:
            Model.sharedInstance().shareMetadataTypeSaveToCameraRoll = newState
        case kPiwigoActivityTypeOther:
            Model.sharedInstance().shareMetadataTypeOther = newState
            default:
                print("Error: Unknown activity \(String(describing: activity))")
        }

        // Save modified settings
        Model.sharedInstance().saveToDisk()
        
        // Clear URL requests to force reload images before sharing
        Model.sharedInstance()?.imageCache.removeAllCachedResponses()

        // Clean up /tmp directory where shared files are temporarily stored
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        appDelegate?.cleanUpTemporaryDirectoryImmediately(true)
    }

    private func getName(forActivity activity: UIActivity.ActivityType, forWidth width: CGFloat) -> String? {
        var name = ""
        // Return activity name of appropriate lentgh
        switch activity {
        case .airDrop:
            name = width > 375 ? NSLocalizedString("shareActivityCode_AirDrop>375px", comment: "Transfer images with AirDrop")
                               : NSLocalizedString("shareActivityCode_AirDrop", comment: "Transfer with AirDrop")
        case .assignToContact:
            name = width > 375 ? NSLocalizedString("shareActivityCode_AssignToContact>375px", comment: "Assign image to contact")
                               : NSLocalizedString("shareActivityCode_AssignToContact", comment: "Assign to contact")
        case .copyToPasteboard:
            name = width > 375 ? NSLocalizedString("shareActivityCode_CopyToPasteboard>375px", comment: "Copy images to Pasteboard")
                               : NSLocalizedString("shareActivityCode_CopyToPasteboard", comment: "Copy to Pasteboard")
        case .mail:
            name = width > 375 ? NSLocalizedString("shareActivityCode_Mail>375px", comment: "Post images by email")
                               : NSLocalizedString("shareActivityCode_Mail", comment: "Post by email")
        case .message:
            name = width > 375 ? NSLocalizedString("shareActivityCode_Message>375px", comment: "Post images with the Message app")
                               : NSLocalizedString("shareActivityCode_Message", comment: "Post with Message")
        case .postToFacebook:
            name = width > 375 ? NSLocalizedString("shareActivityCode_Facebook>375px", comment: "Post images to Facebook")
                               : NSLocalizedString("shareActivityCode_Facebook", comment: "Post to Facebook")
        case kPiwigoActivityTypeMessenger:
            name = width > 375 ? NSLocalizedString("shareActivityCode_Messenger>375px", comment: "Post images with the Messenger app")
                               : NSLocalizedString("shareActivityCode_Messenger", comment: "Post with Messenger")
        case .postToFlickr:
            name = width > 375 ? NSLocalizedString("shareActivityCode_Flickr>375px", comment: "Post images to Flickr")
                               : NSLocalizedString("shareActivityCode_Flickr", comment: "Post to Flickr")
        case kPiwigoActivityTypePostInstagram:
            name = width > 375 ? NSLocalizedString("shareActivityCode_Instagram>375px", comment: "Post images to Instagram")
                               : NSLocalizedString("shareActivityCode_Instagram", comment: "Post to Instagram")
        case kPiwigoActivityTypePostToSignal:
            name = width > 375 ? NSLocalizedString("shareActivityCode_Signal>375px", comment: "Post images with the Signal app")
                               : NSLocalizedString("shareActivityCode_Signal", comment: "Post with Signal")
        case kPiwigoActivityTypePostToSnapchat:
            name = width > 375 ? NSLocalizedString("shareActivityCode_Snapchat>375px", comment: "Post images to Snapchat app")
                               : NSLocalizedString("shareActivityCode_Snapchat", comment: "Post to Snapchat")
        case .postToTencentWeibo:
            name = width > 375 ? NSLocalizedString("shareActivityCode_TencentWeibo>375px", comment: "Post images to TencentWeibo")
                               : NSLocalizedString("shareActivityCode_TencentWeibo", comment: "Post to TencentWeibo")
        case .postToTwitter:
            name = width > 375 ? NSLocalizedString("shareActivityCode_Twitter>375px", comment: "Post images to Twitter")
                               : NSLocalizedString("shareActivityCode_Twitter", comment: "Post to Twitter")
        case .postToVimeo:
            name = width > 375 ? NSLocalizedString("shareActivityCode_Vimeo>375px", comment: "Post videos to Vimeo")
                               : NSLocalizedString("shareActivityCode_Vimeo", comment: "Post to Vimeo")
        case .postToWeibo:
            name = width > 375 ? NSLocalizedString("shareActivityCode_Weibo>375px", comment: "Post images to Weibo")
                               : NSLocalizedString("shareActivityCode_Weibo", comment: "Post to Weibo")
        case kPiwigoActivityTypePostToWhatsApp:
            name = width > 375 ? NSLocalizedString("shareActivityCode_WhatsApp>375px", comment: "Post images with the WhatsApp app")
                               : NSLocalizedString("shareActivityCode_WhatsApp", comment: "Post with WhatsApp")
        case .saveToCameraRoll:
            name = width > 375 ? NSLocalizedString("shareActivityCode_CameraRoll>375px", comment: "Save images to Camera Roll")
                               : NSLocalizedString("shareActivityCode_CameraRoll", comment: "Save to Camera Roll")
        case kPiwigoActivityTypeOther:
            name = width > 375 ? NSLocalizedString("shareActivityCode_Other>375px", comment: "Share images with other apps")
                               : NSLocalizedString("shareActivityCode_Other", comment: "Share with other apps")
            default:
                print("Error: Unknown activity \(String(describing: activity))")
        }

        return name
    }
}
