//
//  ViewController.swift
//  RxMarbles
//
//  Created by Roman Tutubalin on 06.01.16.
//  Copyright © 2016 AnjLab. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import SafariServices
import Device

class OperatorViewController: UIViewController, UISplitViewControllerDelegate {
    private var _currentActivity: NSUserActivity?
    private var _disposeBag = DisposeBag()
    
    private let _scrollView = UIScrollView()
    private let _sceneView: SceneView
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("unimplemented")
    }
    
    init(rxOperator: Operator) {
        _sceneView = SceneView(rxOperator: rxOperator, frame: CGRectZero)
        
        super.init(nibName: nil, bundle: nil)
        
        title = rxOperator.description
    }
    
    override func setEditing(editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        _sceneView.editing = editing
        
        navigationItem.setHidesBackButton(editing, animated: animated)
        navigationItem.rightBarButtonItems = _rightButtonItems()
    }
    
    override func didMoveToParentViewController(parent: UIViewController?) {
        super.didMoveToParentViewController(parent)
        
        navigationItem.leftItemsSupplementBackButton = true
        navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem()
        navigationItem.rightBarButtonItems = _rightButtonItems()
        
        guard
            let requireRecognizerToFail = navigationController?
                .interactivePopGestureRecognizer?
                .requireGestureRecognizerToFail
        else { return }
        
        [
            _sceneView.sourceTimeline?.longPressGestureRecorgnizer,
            _sceneView.secondSourceTimeline?.longPressGestureRecorgnizer
        ]
        .flatMap { $0 }
        .forEach(requireRecognizerToFail)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .whiteColor()
        
        view.addSubview(_scrollView)
        _scrollView.addSubview(_sceneView)
        
        _currentActivity = _sceneView.rxOperator.userActivity()
        
        let nc = NSNotificationCenter.defaultCenter()
        
        nc.rx_notification(NotificationName.setEventView).subscribeNext {
            [unowned self] in self._setEventView($0)
        }.addDisposableTo(_disposeBag)
        
        nc.rx_notification(NotificationName.addEvent).subscribeNext {
            [unowned self] in self._addEventToTimeline($0)
        }.addDisposableTo(_disposeBag)
        
        nc.rx_notification(NotificationName.openOperatorDescription).subscribeNext {
            [unowned self] in self._openOperatorDocumentation($0)
        }.addDisposableTo(_disposeBag)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        _scrollView.frame = view.bounds
        
        var height: CGFloat = 70.0
        height += _sceneView.resultTimeline.bounds.height
        if !_sceneView.rxOperator.withoutTimelines {
            height += _sceneView.sourceTimeline.bounds.height
            if _sceneView.rxOperator.multiTimelines {
                height += _sceneView.secondSourceTimeline.bounds.height
            }
        }
        height += _sceneView.rxOperatorText.bounds.height
        _sceneView.frame = CGRectMake(20, 0, _scrollView.bounds.size.width - 40, height)
        _scrollView.contentSize.height = _sceneView.bounds.height
    }
    
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        _currentActivity?.becomeCurrent()
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        _currentActivity?.resignCurrent()
    }
    
//    MARK: Button Items
    
    private func _rightButtonItems() -> [UIBarButtonItem] {
        let shareButtonItem = UIBarButtonItem(barButtonSystemItem: .Action, target: self, action: "_share:")
        
        if _sceneView.rxOperator.withoutTimelines {
            return [shareButtonItem]
        }
        return editing ? [editButtonItem()] : [editButtonItem(), shareButtonItem]
    }
    
//    MARK: Navigation
    
    private func _openOperatorDocumentation(notification: NSNotification) {
        let safariViewController = SFSafariViewController(URL: _sceneView.rxOperator.url)
        presentViewController(safariViewController, animated: true, completion: nil)
    }
    
//    MARK: Snapshot
    
    private func _makeSnapshot() -> UIImage {
        let size = CGSizeMake(_scrollView.bounds.width, _sceneView.bounds.size.height - _sceneView.rxOperatorText.bounds.height)
        
        UIGraphicsBeginImageContextWithOptions(size, true, UIScreen.mainScreen().scale)
        let c = UIGraphicsGetCurrentContext()!
        
        UIColor.whiteColor().setFill()
        UIRectFill(CGRectMake(0, 0, size.width, size.height))
        
        _scrollView.layer.renderInContext(c)
        
        let snapshot = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return snapshot
    }
    
    private dynamic func _share(sender: AnyObject?) {
       
        let activity = UIActivityViewController(activityItems: [_makeSnapshot()], applicationActivities: nil)
        
        activity.excludedActivityTypes = [
            UIActivityTypeAssignToContact,
            UIActivityTypePrint,
        ]
        if let delegate = UIApplication.sharedApplication().delegate as? AppDelegate,
            let rootViewController = delegate.window?.rootViewController {
                if Device.type() == .iPad || Device.type() == .Simulator {
                    activity.popoverPresentationController?.sourceView = view
                    if let shareButtonItem = sender {
                        activity.popoverPresentationController?.barButtonItem = shareButtonItem as? UIBarButtonItem
                    }
                }
                rootViewController.presentViewController(activity, animated: true, completion: nil)
            }
    }
    
//    MARK: Alert controllers
    
    private func _addEventToTimeline(notification: NSNotification) {
        guard
            let sender = notification.object as? UIButton,
            let timeline = sender.superview as? SourceTimelineView
        else { return }
        
        var time = Int(timeline.bounds.size.width / 2.0)
        
        let elementSelector = UIAlertController(title: "Add event", message: nil, preferredStyle: .ActionSheet)
       
        let sceneView = _sceneView
        let nextAction = UIAlertAction(title: "Next", style: .Default) { _ in
            let e = next(time, String(random() % 9 + 1), Color.nextRandom, (timeline == sceneView.sourceTimeline) ? .Circle : .Rect)
            timeline.addEventToTimeline(e, animator: timeline.animator)
            sceneView.resultTimeline.subject.onNext()
        }
        let completedAction = UIAlertAction(title: "Completed", style: .Default) { _ in
            time = timeline.maxEventTime() > 850 ? timeline.maxEventTime() + 30 : 850
            let e = completed(time)
            timeline.addEventToTimeline(e, animator: timeline.animator)
            sceneView.resultTimeline.subject.onNext()
        }
        let errorAction = UIAlertAction(title: "Error", style: .Default) { _ in
            let e = error(500)
            timeline.addEventToTimeline(e, animator: timeline.animator)
            sceneView.resultTimeline.subject.onNext()
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel) { _ in }
        
        elementSelector.addAction(nextAction)
        let sourceEvents: [EventView] = timeline.sourceEvents
        if sourceEvents.indexOf({ $0.isCompleted }) == nil {
            elementSelector.addAction(completedAction)
        }
        elementSelector.addAction(errorAction)
        elementSelector.addAction(cancelAction)
        
        elementSelector.popoverPresentationController?.sourceRect = sender.frame
        elementSelector.popoverPresentationController?.sourceView = sender.superview
        
        presentViewController(elementSelector, animated: true, completion: nil)
    }

    private func _setEventView(notification: NSNotification) {
        guard let eventView = notification.object as? EventView else { return }
        
        let settingsAlertController = UIAlertController(title: nil, message: nil, preferredStyle: .Alert)
        
        if eventView.isNext {
            let contentViewController = UIViewController()
            contentViewController.preferredContentSize = CGSizeMake(200.0, 90.0)
            
            let preview = EventView(recorded: eventView.recorded)
            preview.center = CGPointMake(100.0, 25.0)
            contentViewController.view.addSubview(preview)
            
            let colorsSegmentedControl = _contentViewColorsSegmentedControl(eventView)
            contentViewController.view.addSubview(colorsSegmentedControl)
            
            settingsAlertController.setValue(contentViewController, forKey: "contentViewController")
            settingsAlertController.addTextFieldWithConfigurationHandler { textField in
                if let text = eventView.recorded.value.element?.value {
                    textField.text = text
                }
            }
            settingsAlertController.addAction(_saveAction(preview, oldEventView: eventView))
            
            Observable
                .combineLatest(settingsAlertController.textFields!.first!.rx_text, colorsSegmentedControl.rx_value, resultSelector: { text, segment in
                    return (text, segment)
                })
                .subscribeNext({ text, segment in
                    self._updatePreviewEventView(preview, params: (color: Color.nextAll[segment], value: text))
                })
                .addDisposableTo(_disposeBag)
        } else {
            settingsAlertController.message = "Delete event?"
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel) { _ in }
        settingsAlertController.addAction(_deleteAction(eventView))
        settingsAlertController.addAction(cancelAction)
        presentViewController(settingsAlertController, animated: true, completion: nil)
    }
    
    private func _contentViewColorsSegmentedControl(eventView: EventView) -> UISegmentedControl {
        let colors = Color.nextAll
        let currentColor = eventView.recorded.value.element?.color
        let colorsSegment = UISegmentedControl(items: colors.map { _ in "" } )
        colorsSegment.tintColor = .clearColor()
        colorsSegment.frame = CGRectMake(0.0, 50.0, 200.0, 30.0)
        
        zip(colorsSegment.subviews, colors).forEach { v, color in v.backgroundColor = color }
        
        colorsSegment.selectedSegmentIndex = colors.indexOf(currentColor!)!
        return colorsSegment
    }
    
    private func _saveAction(newEventView: EventView, oldEventView: EventView) -> UIAlertAction {
        return UIAlertAction(title: "Save", style: .Default) { _ in
            guard let index = oldEventView.timeLine?.sourceEvents.indexOf(oldEventView)
            else { return }
            
            oldEventView.timeLine?.sourceEvents.removeAtIndex(index)
            oldEventView.timeLine?.addEventToTimeline(newEventView.recorded, animator: oldEventView.timeLine?.animator)
            oldEventView.removeFromSuperview()
            self._sceneView.resultTimeline.subject.onNext()
        }
    }
    
    private func _deleteAction(eventView: EventView) -> UIAlertAction {
        return UIAlertAction(title: "Delete", style: .Destructive) { _ in
            eventView.animator!.removeAllBehaviors()
            eventView.animator!.addBehavior(eventView.gravity!)
            eventView.animator!.addBehavior(eventView.removeBehavior!)
        }
    }
    
    private func _updatePreviewEventView(preview: EventView, params: (color: UIColor, value: String)) {
        let time = preview.recorded.time
        let shape = preview.recorded.value.element?.shape
        let event = Event.Next(ColoredType(value: params.value, color: params.color, shape: shape!))
        
        preview.recorded = RecordedType(time: time, event: event)
        preview.label.text = params.value
        preview.setColorOnPreview(params.color)
    }
    
//    MARK: Preview Actions
    
    override func previewActionItems() -> [UIPreviewActionItem] {
        let shareAction = UIPreviewAction(title: "Share", style: .Default) { _, _ in
            self._share(nil)
        }
        return [shareAction]
    }
}