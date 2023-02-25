import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import LegacyComponents
import AccountContext

private let emojiFont = Font.regular(28.0)
private let textFont = Font.regular(15.0)

final class CallControllerKeyPreviewNode: ASDisplayNode {
    private let keyTextNode: ASTextNode
    private let infoTextNode: ASTextNode
    private let titleTextNode: ASTextNode
    private let okTextNode: ASTextNode

    private let effectView: UIVisualEffectView
    
    private let dismiss: () -> Void

    init(keyText: String, titleText: String, infoText: String, dismiss: @escaping () -> Void) {
        self.keyTextNode = ASTextNode()
        self.keyTextNode.displaysAsynchronously = false
        self.infoTextNode = ASTextNode()
        self.infoTextNode.displaysAsynchronously = false
        self.titleTextNode = ASTextNode()
        self.titleTextNode.displaysAsynchronously = false
        self.okTextNode = ASTextNode()
        self.okTextNode.displaysAsynchronously = false
        self.dismiss = dismiss
        
        self.effectView = UIVisualEffectView()
        if #available(iOS 9.0, *) {
        } else {
            self.effectView.effect = UIBlurEffect(style: .light)
            self.effectView.alpha = 0.0
        }
        self.effectView.clipsToBounds = true
        self.effectView.layer.cornerRadius = 20.0

        super.init()
        
        self.keyTextNode.attributedText = NSAttributedString(string: keyText, attributes: [NSAttributedString.Key.font: Font.regular(41.0), NSAttributedString.Key.kern: 6.0 as NSNumber])
        
        self.infoTextNode.attributedText = NSAttributedString(string: infoText, font: Font.regular(16.0), textColor: UIColor.white, paragraphAlignment: .center)
        self.titleTextNode.attributedText = NSAttributedString(string: titleText, font: Font.semibold(16.0), textColor: UIColor.white, paragraphAlignment: .center)
        self.okTextNode.attributedText = NSAttributedString(string: "OK", font: Font.regular(20.0), textColor: UIColor.white, paragraphAlignment: .center)

        self.view.addSubview(self.effectView)
        self.addSubnode(self.keyTextNode)
        self.addSubnode(self.infoTextNode)
        self.addSubnode(self.titleTextNode)
        self.addSubnode(self.okTextNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.effectView.frame = CGRect(origin: CGPoint(), size: size)
        
        let keyTextSize = self.keyTextNode.measure(CGSize(width: 210.0, height: 48.0))
        transition.updateFrame(node: self.keyTextNode, frame: CGRect(origin: CGPoint(x: floor((size.width - keyTextSize.width) / 2) + 6.0, y: 20.0), size: keyTextSize))

        let titleTextSize = self.titleTextNode.measure(CGSize(width: size.width - 32.0, height: CGFloat.greatestFiniteMagnitude))
        transition.updateFrame(node: self.titleTextNode, frame: CGRect(origin: CGPoint(x: floor((size.width - titleTextSize.width) / 2.0), y: 78.0), size: titleTextSize))

        let infoTextSize = self.infoTextNode.measure(CGSize(width: size.width - 32.0, height: CGFloat.greatestFiniteMagnitude))
        transition.updateFrame(node: self.infoTextNode, frame: CGRect(origin: CGPoint(x: floor((size.width - infoTextSize.width) / 2.0), y: self.titleTextNode.frame.maxY + 10.0), size: infoTextSize))

        let okTextSize = self.okTextNode.measure(CGSize(width: size.width - 32.0, height: CGFloat.greatestFiniteMagnitude))
        transition.updateFrame(node: self.okTextNode, frame: CGRect(origin: CGPoint(x: floor((size.width - okTextSize.width) / 2.0), y: size.height - 58.0 / 2 - okTextSize.height / 2.0), size: okTextSize))
    }
    
    func animateIn(from rect: CGRect, fromNode: ASDisplayNode, callState: PresentationCallState?) {
        if let transitionView = fromNode.view.snapshotView(afterScreenUpdates: false) {
            fromNode.view.superview?.addSubview(transitionView)
            transitionView.layer.animatePosition(from: CGPoint(x: rect.midX, y: rect.midY), to: self.view.convert(self.keyTextNode.layer.position, to: fromNode.view.superview), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { [weak transitionView] _ in
                self.keyTextNode.alpha = 1
                transitionView?.removeFromSuperview()
            })
            transitionView.layer.animateScale(from: 1.0, to: self.keyTextNode.frame.size.width / rect.size.width, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        }
        self.effectView.layer.animateScale(from: 0, to: 1, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
        self.infoTextNode.layer.animateScale(from: 0, to: 1, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
        self.titleTextNode.layer.animateScale(from: 0, to: 1, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
        self.okTextNode.layer.animateScale(from: 0, to: 1, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)

        self.keyTextNode.alpha = 0
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
        })
    }
    
    func animateOut(to rect: CGRect, toNode: ASDisplayNode, completion: @escaping () -> Void) {
        self.effectView.layer.animateScale(from: 1.0, to: 0.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
        self.effectView.layer.animateAlpha(from: self.effectView.alpha, to: 0.0, duration: 0.1, removeOnCompletion: false)
        self.infoTextNode.layer.animateScale(from: 1, to: 0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
        self.infoTextNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
        self.titleTextNode.layer.animateScale(from: 1, to: 0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
        self.titleTextNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
        self.okTextNode.layer.animateScale(from: 1, to: 0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
        self.okTextNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)

        if let transitionView = self.keyTextNode.view.snapshotView(afterScreenUpdates: false) {
            transitionView.center = self.keyTextNode.view.superview?.convert(self.keyTextNode.view.center, to: toNode.view.superview) ?? .zero
            toNode.view.superview?.addSubview(transitionView)
            self.keyTextNode.alpha = 0
            transitionView.layer.animatePosition(from: transitionView.layer.position, to: CGPoint(x: rect.midX, y: rect.midY), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { [weak transitionView] _ in
                self.keyTextNode.alpha = 1
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

