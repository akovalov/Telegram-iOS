import Foundation
import UIKit
import SwiftSignalKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramVoip
import AccountContext
import AppBundle

private final class CallRatingAlertContentNode: AlertContentNode {
    private let strings: PresentationStrings
    private let apply: (Int) -> Void
    
    var rating: Int?
    
    private let titleNode: ASTextNode
    private let textNode: ASTextNode
    private var starContainerNode: ASDisplayNode
    private let starNodes: [ASButtonNode]

    private let actionNodesSeparator: ASDisplayNode
    private let actionNodes: [TextAlertContentActionNode]
    private let actionVerticalSeparators: [ASDisplayNode]
    
    private let disposable = MetaDisposable()
    
    private var validLayout: CGSize?

    private let effectView: UIVisualEffectView

    override var dismissOnOutsideTap: Bool {
        return self.isUserInteractionEnabled
    }
    
    init(theme: AlertControllerTheme, ptheme: PresentationTheme, strings: PresentationStrings, actions: [TextAlertAction], dismiss: @escaping () -> Void, apply: @escaping (Int) -> Void) {
        self.strings = strings
        self.apply = apply
        
        self.titleNode = ASTextNode()
        self.titleNode.maximumNumberOfLines = 3
        self.textNode = ASTextNode()

        self.starContainerNode = ASDisplayNode()
        
        var starNodes: [ASButtonNode] = []
        for _ in 0 ..< 5 {
            starNodes.append(ASButtonNode())
        }
        self.starNodes = starNodes
        
        self.actionNodesSeparator = ASDisplayNode()
        self.actionNodesSeparator.isLayerBacked = true
        
//        self.actionNodes = actions.map { action -> TextAlertContentActionNode in
//            return TextAlertContentActionNode(theme: theme, action: action)
//        }
        self.actionNodes = []
        
        var actionVerticalSeparators: [ASDisplayNode] = []
        if actions.count > 1 {
            for _ in 0 ..< actions.count - 1 {
                let separatorNode = ASDisplayNode()
                separatorNode.isLayerBacked = true
                actionVerticalSeparators.append(separatorNode)
            }
        }
        self.actionVerticalSeparators = actionVerticalSeparators

        self.effectView = UIVisualEffectView()
        self.effectView.effect = UIBlurEffect(style: .light)
        self.effectView.clipsToBounds = true
        self.effectView.layer.cornerRadius = 20.0
        self.effectView.alpha = 0.8

        super.init()

        self.view.addSubview(self.effectView)

        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        
        self.addSubnode(self.starContainerNode)
        
        for node in self.starNodes {
            node.addTarget(self, action: #selector(self.starPressed(_:)), forControlEvents: .touchDown)
            node.addTarget(self, action: #selector(self.starReleased(_:)), forControlEvents: .touchUpInside)
            self.starContainerNode.addSubnode(node)
        }
        
//        self.addSubnode(self.actionNodesSeparator)
        
        for actionNode in self.actionNodes {
            self.addSubnode(actionNode)
        }
        
        for separatorNode in self.actionVerticalSeparators {
            self.addSubnode(separatorNode)
        }
        
        self.updateTheme(theme)
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.starContainerNode.view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:))))
    }
    
    @objc func panGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
        let location = gestureRecognizer.location(in: self.starContainerNode.view)
        var selectedNode: ASButtonNode?
        for node in self.starNodes {
            if node.frame.contains(location) {
                selectedNode = node
                break
            }
        }
        if let selectedNode = selectedNode {
            switch gestureRecognizer.state {
                case .began, .changed:
                    self.starPressed(selectedNode)
                case .ended:
                    self.starReleased(selectedNode)
                case .cancelled:
                    self.resetStars()
                default:
                    break
            }
        } else {
            self.resetStars()
        }
    }
    
    private func resetStars() {
        for i in 0 ..< self.starNodes.count {
            let node = self.starNodes[i]
            node.isSelected = false
        }
    }
    
    @objc func starPressed(_ sender: ASButtonNode) {
        if let index = self.starNodes.firstIndex(of: sender) {
            self.rating = index + 1
            for i in 0 ..< self.starNodes.count {
                let node = self.starNodes[i]
                node.isSelected = i <= index
            }
        }
    }
    
    @objc func starReleased(_ sender: ASButtonNode) {
        if let index = self.starNodes.firstIndex(of: sender) {
            self.rating = index + 1
            for i in 0 ..< self.starNodes.count {
                let node = self.starNodes[i]
                node.isSelected = i <= index
            }
            if let rating = self.rating {
                self.apply(rating)
            }
        }
    }
    
    override func updateTheme(_ theme: AlertControllerTheme) {
        self.titleNode.attributedText = NSAttributedString(string: self.strings.Calls_RatingTitle2, font: Font.semibold(16.0), textColor: .white, paragraphAlignment: .center)
        self.textNode.attributedText = NSAttributedString(string: self.strings.Calls_RatingText, font: Font.regular(16.0), textColor: .white, paragraphAlignment: .center)
        
        for node in self.starNodes {
            node.setImage(generateTintedImage(image: UIImage(bundleImageName: "Call/Star"), color: .white), for: [])
            let highlighted = generateTintedImage(image: UIImage(bundleImageName: "Call/StarHighlighted"), color: .white)
            node.setImage(highlighted, for: [.selected])
            node.setImage(highlighted, for: [.selected, .highlighted])
        }
        
        self.actionNodesSeparator.backgroundColor = theme.separatorColor
        for actionNode in self.actionNodes {
            actionNode.updateTheme(theme)
        }
        for separatorNode in self.actionVerticalSeparators {
            separatorNode.backgroundColor = theme.separatorColor
        }
        
        if let size = self.validLayout {
            _ = self.updateLayout(size: size, transition: .immediate)
        }
    }
    
    override func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        self.effectView.frame = CGRect(origin: CGPoint(), size: size)
        
        self.validLayout = size
                
        let actionButtonHeight: CGFloat = 44.0
        var minActionsWidth: CGFloat = 0.0
        let maxActionWidth: CGFloat = floor(size.width / CGFloat(self.actionNodes.count))
        let actionTitleInsets: CGFloat = 8.0
        
        var effectiveActionLayout = TextAlertContentActionLayout.horizontal
        for actionNode in self.actionNodes {
            let actionTitleSize = actionNode.titleNode.updateLayout(CGSize(width: maxActionWidth, height: actionButtonHeight))
            if case .horizontal = effectiveActionLayout, actionTitleSize.height > actionButtonHeight * 0.6667 {
                effectiveActionLayout = .vertical
            }
            switch effectiveActionLayout {
                case .horizontal:
                    minActionsWidth += actionTitleSize.width + actionTitleInsets
                case .vertical:
                    minActionsWidth = max(minActionsWidth, actionTitleSize.width + actionTitleInsets)
            }
        }
        
        var origin: CGPoint = CGPoint(x: 0.0, y: 20.0)

        let titleSize = self.titleNode.measure(CGSize(width: size.width - 32.0, height: size.height))
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: size.width / 2.0 - titleSize.width / 2.0, y: origin.y), size: titleSize))
        origin.y += titleSize.height + 10.0

        let textSize = self.textNode.measure(CGSize(width: size.width - 32.0, height: size.height))
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: size.width / 2.0 - textSize.width / 2.0, y: origin.y), size: textSize))
        origin.y += textSize.height + 10.0

        let starSize = CGSize(width: 42.0, height: 42.0)
        let starsOrigin = size.width / 2.0 - (starSize.width * 5.0) / 2.0
        self.starContainerNode.frame = CGRect(origin: CGPoint(x: starsOrigin, y: origin.y), size: CGSize(width: starSize.width * CGFloat(self.starNodes.count), height: starSize.height))
        for i in 0 ..< self.starNodes.count {
            let node = self.starNodes[i]
            transition.updateFrame(node: node, frame: CGRect(x: starSize.width * CGFloat(i), y: 0.0, width: starSize.width, height: starSize.height))
        }
        origin.y += titleSize.height
        
        let resultSize = CGSize(width: size.width, height: titleSize.height + textSize.height + starSize.height + 40.0)
        
        return resultSize
    }
}

func rateCallAndSendLogs(engine: TelegramEngine, callId: CallId, starsCount: Int, comment: String, userInitiated: Bool, includeLogs: Bool) -> Signal<Void, NoError> {
    let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(4244000))

    let rate = engine.calls.rateCall(callId: callId, starsCount: Int32(starsCount), comment: comment, userInitiated: userInitiated)
    if includeLogs {
        let id = Int64.random(in: Int64.min ... Int64.max)
        let name = "\(callId.id)_\(callId.accessHash).log.json"
        let path = callLogsPath(account: engine.account) + "/" + name
        let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: LocalFileReferenceMediaResource(localFilePath: path, randomId: id), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/text", size: nil, attributes: [.FileName(fileName: name)])
        let message = EnqueueMessage.message(text: comment, attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), replyToMessageId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
        return rate
        |> then(enqueueMessages(account: engine.account, peerId: peerId, messages: [message])
        |> mapToSignal({ _ -> Signal<Void, NoError> in
            return .single(Void())
        }))
    } else if !comment.isEmpty {
        return rate
        |> then(enqueueMessages(account: engine.account, peerId: peerId, messages: [.message(text: comment, attributes: [], inlineStickers: [:], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])])
        |> mapToSignal({ _ -> Signal<Void, NoError> in
            return .single(Void())
        }))
    } else {
        return rate
    }
}

public func callRatingController(sharedContext: SharedAccountContext, account: Account, callId: CallId, userInitiated: Bool, isVideo: Bool, present: @escaping (ViewController, Any) -> Void, push: @escaping (ViewController) -> Void) -> AlertController {
    let presentationData = sharedContext.currentPresentationData.with { $0 }
    let theme = presentationData.theme
    let strings = presentationData.strings
    
    var dismissImpl: ((Bool) -> Void)?
    var contentNode: CallRatingAlertContentNode?
    let actions: [TextAlertAction] = [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_NotNow, action: {
        dismissImpl?(true)
    })]
    
    contentNode = CallRatingAlertContentNode(theme: AlertControllerTheme(presentationData: presentationData), ptheme: theme, strings: strings, actions: actions, dismiss: {
        dismissImpl?(true)
    }, apply: { rating in
        dismissImpl?(true)
        if rating < 4 {
            push(callFeedbackController(sharedContext: sharedContext, account: account, callId: callId, rating: rating, userInitiated: userInitiated, isVideo: isVideo))
        } else {
            let _ = rateCallAndSendLogs(engine: TelegramEngine(account: account), callId: callId, starsCount: rating, comment: "", userInitiated: userInitiated, includeLogs: false).start()
        }
    })
    
    let controller = AlertController(theme: AlertControllerTheme(presentationData: presentationData), contentNode: contentNode!)
    dismissImpl = { [weak controller] animated in
        if animated {
            controller?.dismissAnimated()
        } else {
            controller?.dismiss()
        }
    }
    return controller
}

public func callRatingNode(sharedContext: SharedAccountContext, account: Account, callId: CallId, userInitiated: Bool, isVideo: Bool, push: @escaping (ViewController) -> Void) -> AlertContentNode {
    let presentationData = sharedContext.currentPresentationData.with { $0 }
    let theme = presentationData.theme
    let strings = presentationData.strings

    var contentNode: CallRatingAlertContentNode

    contentNode = CallRatingAlertContentNode(theme: AlertControllerTheme(presentationData: presentationData), ptheme: theme, strings: strings, actions: [], dismiss: {
    }, apply: { rating in
        if rating < 4 {
            push(callFeedbackController(sharedContext: sharedContext, account: account, callId: callId, rating: rating, userInitiated: userInitiated, isVideo: isVideo))
        } else {
            let _ = rateCallAndSendLogs(engine: TelegramEngine(account: account), callId: callId, starsCount: rating, comment: "", userInitiated: userInitiated, includeLogs: false).start()
        }
    })

    return contentNode
}

