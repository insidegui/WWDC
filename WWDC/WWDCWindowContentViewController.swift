import Cocoa

class WWDCWindowContentViewController: NSViewController {

    var topSafeAreaPadding: CGFloat { 22 }

    /// The child view controller that will have its top anchor attached to the window's content layout guide in order
    /// to keep this view controller's contents from being under the title bar.
    var childForWindowTopSafeAreaConstraint: NSViewController? { return nil }

    /// Returns ``childForWindowTopSafeAreaConstraint`` by default.
    var viewForWindowTopSafeAreaConstraint: NSView? { childForWindowTopSafeAreaConstraint?.view }

    private var activeTopConstraint: NSLayoutConstraint?

    private lazy var topConstraint: NSLayoutConstraint? = {
        guard let viewForWindowTopSafeAreaConstraint else { return nil }
        guard let layoutGuide = view.window?.contentLayoutGuide as? NSLayoutGuide else { return nil }
        return viewForWindowTopSafeAreaConstraint.topAnchor.constraint(equalTo: layoutGuide.topAnchor, constant: topSafeAreaPadding)
    }()

    override func updateViewConstraints() {
        super.updateViewConstraints()

        guard viewForWindowTopSafeAreaConstraint != nil, view.window != nil else {
            activeTopConstraint?.isActive = false
            activeTopConstraint = nil
            return
        }

        guard let topConstraint, !topConstraint.isActive else { return }

        topConstraint.isActive = true
        activeTopConstraint = topConstraint
    }

}
