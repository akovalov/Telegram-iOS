import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import LegacyComponents
import AccountContext
import AnimatedStickerNode
import TelegramCore
import StickerResources
import TelegramAnimatedStickerNode
import Postbox

private let emojiFont = Font.regular(28.0)
private let textFont = Font.regular(15.0)

final class CallControllerKeyPreviewNode: ASDisplayNode {
    private let keyTextNode: ASTextNode
    private let infoTextNode: ASTextNode
    private let titleTextNode: ASTextNode
    private let okTextNode: ASTextNode

    private let effectView: UIVisualEffectView
    
    private let dismiss: () -> Void

    private var disposable = MetaDisposable()

    private var accountContext: AccountContext?
    private let keyContainerNode: ASDisplayNode
    private let animatedKeyNode: ASDisplayNode
    private let separatorNode: ASDisplayNode

    init(keyText: String, titleText: String, infoText: String, accountContext: AccountContext? = nil, dismiss: @escaping () -> Void) {
        self.keyTextNode = ASTextNode()
        self.keyTextNode.displaysAsynchronously = false
        self.infoTextNode = ASTextNode()
        self.infoTextNode.displaysAsynchronously = false
        self.titleTextNode = ASTextNode()
        self.titleTextNode.displaysAsynchronously = false
        self.okTextNode = ASTextNode()
        self.okTextNode.displaysAsynchronously = false
        self.dismiss = dismiss
        self.accountContext = accountContext

        self.effectView = UIVisualEffectView()
        if #available(iOS 9.0, *) {
        } else {
            self.effectView.effect = UIBlurEffect(style: .light)
            self.effectView.alpha = 0.0
        }
        self.effectView.clipsToBounds = true
        self.effectView.layer.cornerRadius = 20.0

        self.animatedKeyNode = ASDisplayNode()
        self.separatorNode = ASDisplayNode()
        self.keyContainerNode = ASDisplayNode()

        super.init()
        
        self.keyTextNode.attributedText = NSAttributedString(string: keyText, attributes: [NSAttributedString.Key.font: Font.regular(41.0), NSAttributedString.Key.kern: 6.0 as NSNumber])
        
        self.infoTextNode.attributedText = NSAttributedString(string: infoText, font: Font.regular(16.0), textColor: UIColor.white, paragraphAlignment: .center)
        self.titleTextNode.attributedText = NSAttributedString(string: titleText, font: Font.semibold(16.0), textColor: UIColor.white, paragraphAlignment: .center)
        self.okTextNode.attributedText = NSAttributedString(string: "OK", font: Font.regular(20.0), textColor: UIColor.white, paragraphAlignment: .center)

        self.view.addSubview(self.effectView)
        self.addSubnode(self.keyContainerNode)
        self.keyContainerNode.addSubnode(self.keyTextNode)
        self.keyContainerNode.addSubnode(self.animatedKeyNode)
        self.addSubnode(self.infoTextNode)
        self.addSubnode(self.titleTextNode)
        self.addSubnode(self.okTextNode)
        self.effectView.contentView.addSubview(self.separatorNode.view)

        self.loadAnimatedEmoji(key: keyText)
    }

    deinit {
        self.disposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))

        self.separatorNode.backgroundColor = .white.withAlphaComponent(0.2)
        self.separatorNode.layer.compositingFilter = "sourceInCompositing"
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.effectView.frame = CGRect(origin: CGPoint(), size: size)
        
        let keyTextSize = self.keyTextNode.measure(CGSize(width: 210.0, height: 48.0))
        transition.updateFrame(node: self.keyContainerNode, frame: CGRect(origin: CGPoint(x: floor((size.width - keyTextSize.width) / 2) + 6.0, y: 20.0), size: keyTextSize))
        transition.updateFrame(node: self.keyTextNode, frame: self.keyContainerNode.bounds)
        transition.updateFrame(node: self.animatedKeyNode, frame: self.keyContainerNode.bounds)

        let titleTextSize = self.titleTextNode.measure(CGSize(width: size.width - 32.0, height: CGFloat.greatestFiniteMagnitude))
        transition.updateFrame(node: self.titleTextNode, frame: CGRect(origin: CGPoint(x: floor((size.width - titleTextSize.width) / 2.0), y: 78.0), size: titleTextSize))

        let infoTextSize = self.infoTextNode.measure(CGSize(width: size.width - 32.0, height: CGFloat.greatestFiniteMagnitude))
        transition.updateFrame(node: self.infoTextNode, frame: CGRect(origin: CGPoint(x: floor((size.width - infoTextSize.width) / 2.0), y: self.titleTextNode.frame.maxY + 10.0), size: infoTextSize))

        let okTextSize = self.okTextNode.measure(CGSize(width: size.width - 32.0, height: CGFloat.greatestFiniteMagnitude))
        transition.updateFrame(node: self.okTextNode, frame: CGRect(origin: CGPoint(x: floor((size.width - okTextSize.width) / 2.0), y: size.height - 58.0 / 2 - okTextSize.height / 2.0), size: okTextSize))

        transition.updateFrame(node: self.separatorNode, frame: CGRect(x: 0, y: size.height - 56.0, width: size.width, height: 1))
    }
    
    func animateIn(from rect: CGRect, fromNode: ASDisplayNode, callState: PresentationCallState?) {
        self.animatedKeyNode.alpha = 0.0

        if let transitionView = fromNode.view.snapshotView(afterScreenUpdates: false) {
            fromNode.view.superview?.addSubview(transitionView)
            transitionView.layer.animatePosition(from: CGPoint(x: rect.midX, y: rect.midY), to: self.view.convert(self.keyContainerNode.layer.position, to: fromNode.view.superview), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { [weak transitionView] _ in
                self.keyContainerNode.alpha = 1
                transitionView?.removeFromSuperview()
            })
            transitionView.layer.animateScale(from: 1.0, to: self.keyContainerNode.frame.size.width / rect.size.width, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        }
        self.effectView.layer.animateScale(from: 0, to: 1, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
        self.infoTextNode.layer.animateScale(from: 0, to: 1, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
        self.titleTextNode.layer.animateScale(from: 0, to: 1, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
        self.okTextNode.layer.animateScale(from: 0, to: 1, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)

        self.keyContainerNode.alpha = 0
        self.infoTextNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        self.titleTextNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        self.okTextNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        
        UIView.animate(withDuration: 0.3, animations: {
            if #available(iOS 9.0, *) {
                var style: UIBlurEffect.Style = .regular
                if case .active = callState?.videoState {
                    style = .dark
                }
                if case .active = callState?.remoteVideoState {
                    style = .dark
                }
                self.effectView.effect = UIBlurEffect(style: style)
                self.effectView.alpha = style == .dark ? 1.0 : 0.5
            } else {
                self.effectView.alpha = 1.0
            }
        }) { _ in
            self.animatedKeyNode.alpha = 1.0
        }
    }
    
    func animateOut(to rect: CGRect, toNode: ASDisplayNode, completion: @escaping () -> Void) {
        self.animatedKeyNode.subnodes?.forEach {
            ($0 as? AnimatedStickerNode)?.stop()
        }

        self.effectView.layer.animateScale(from: 1.0, to: 0.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
        self.effectView.layer.animateAlpha(from: self.effectView.alpha, to: 0.0, duration: 0.1, removeOnCompletion: false)
        self.infoTextNode.layer.animateScale(from: 1, to: 0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
        self.infoTextNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
        self.titleTextNode.layer.animateScale(from: 1, to: 0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
        self.titleTextNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
        self.okTextNode.layer.animateScale(from: 1, to: 0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
        self.okTextNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)

        if let transitionView = self.keyContainerNode.view.snapshotView(afterScreenUpdates: false) {
            transitionView.center = self.keyContainerNode.view.superview?.convert(self.keyContainerNode.view.center, to: toNode.view.superview) ?? .zero
            toNode.view.superview?.addSubview(transitionView)
            self.keyContainerNode.alpha = 0
            transitionView.layer.animatePosition(from: transitionView.layer.position, to: CGPoint(x: rect.midX, y: rect.midY), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { [weak transitionView] _ in
                self.keyContainerNode.alpha = 1
                transitionView?.removeFromSuperview()
                completion()
            })
            transitionView.layer.animateScale(from: 1.0, to: rect.size.width / transitionView.frame.size.width, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        }
        UIView.animate(withDuration: 0.3, animations: {
            if #available(iOS 9.0, *) {
                self.effectView.effect = nil
            } else {
                self.effectView.alpha = 0.0
            }
        })
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.dismiss()
        }
    }
}

extension CallControllerKeyPreviewNode {

    private func loadAnimatedEmoji(key: String) {

        guard let context = accountContext else {
            return
        }

        let emojis = key.emojis

        let animatedEmojiStickers = context.engine.stickers.loadedStickerPack(reference: .animatedEmoji, forceActualized: false)
        |> map { animatedEmoji -> [String: [StickerPackItem]] in
            var animatedEmojiStickers: [String: [StickerPackItem]] = [:]
            switch animatedEmoji {
            case let .result(_, items, _):
                for item in items {
                    if let emoji = item.getStringRepresentationsOfIndexKeys().first {
                        animatedEmojiStickers[emoji.basicEmoji.0] = [item]
                        let strippedEmoji = emoji.basicEmoji.0.strippedEmoji
                        if animatedEmojiStickers[strippedEmoji] == nil {
                            animatedEmojiStickers[strippedEmoji] = [item]
                        }
                    }
                }
            default:
                break
            }
            return animatedEmojiStickers
        }

        self.disposable.set(combineLatest(queue: Queue.mainQueue(), animatedEmojiStickers, context.engine.themes.getChatThemes(accountManager: context.sharedContext.accountManager)).start(next: { [weak self] animatedEmojiStickers, themes in
            guard let self else {
                return
            }
            let stickerFiles = emojis.compactMap { animatedEmojiStickers[$0]?.first?.file }
            guard stickerFiles.count == emojis.count else {
                return
            }

            self.fetchEmojiFiles(stickerFiles, account: context.account)
        }))
    }

    private func fetchEmojiFiles(_ files: [TelegramMediaFile], account: Account) {

        var dataSignals: [Signal<Never, NoError>] = []

        for file in files {
            let dimensions = file.dimensions ?? PixelDimensions(width: 512, height: 512)
            let signal = chatMessageAnimatedSticker(postbox: account.postbox, userLocation: .other, file: file, small: false, size: dimensions.cgSize, fetched: true)
            |> ignoreValues

            dataSignals.append(signal)
        }

        self.disposable.set((combineLatest(dataSignals)
        |> deliverOnMainQueue).start(error: { _ in
        }, completed: { [weak self] in
            self?.showEmojiFiles(files)
        }))
    }

    private func showEmojiFiles(_ files: [TelegramMediaFile]) {

        guard let account = accountContext?.account else {
            return
        }

        var frameOriginX: CGFloat = 0
        let frameOriginY: CGFloat = 0
        for file in files {
            let animationNode: AnimatedStickerNode = DefaultAnimatedStickerNodeImpl()
            self.animatedKeyNode.addSubnode(animationNode)

            let animationSize = CGSize(width: 48.0, height: 48.0)
            let fittedSize = file.dimensions?.cgSize.aspectFitted(animationSize) ?? animationSize

            animationNode.setup(source: AnimatedStickerResourceSource(account: account, resource: file.resource, isVideo: file.isVideoSticker), width: Int(fittedSize.width), height: Int(fittedSize.height), playbackMode: .loop, mode: .cached)

            animationNode.visibility = true
            animationNode.frame = CGRect(origin: CGPoint(x: frameOriginX, y: frameOriginY), size: fittedSize)
            animationNode.updateLayout(size: fittedSize)

            frameOriginX = animationNode.frame.maxX + 3.0

            animationNode.started = { [weak self] in
                self?.keyTextNode.alpha = 0.0
            }
        }
    }
}
