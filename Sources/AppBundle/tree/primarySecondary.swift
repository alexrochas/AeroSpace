import AppKit

private let primarySecondaryPrimaryRatioKey = TreeNodeUserDataKey<CGFloat>(key: "primarySecondaryPrimaryRatioKey")
let defaultPrimarySecondaryPrimaryRatio = CGFloat(0.7)

extension TilingContainer {
    var primarySecondaryPrimaryRatio: CGFloat? {
        get { getUserData(key: primarySecondaryPrimaryRatioKey) }
        set {
            if let newValue {
                putUserData(key: primarySecondaryPrimaryRatioKey, data: newValue)
            } else {
                cleanUserData(key: primarySecondaryPrimaryRatioKey)
            }
        }
    }

    @MainActor
    func applyPrimarySecondarySizingIfNeeded(availableWidth: CGFloat, availableHeight: CGFloat) {
        guard let ratio = primarySecondaryPrimaryRatio else { return }
        guard layout == .tiles, orientation == .h else { return }
        guard let primary = children.first, children.count <= 2 else { return }

        if children.count == 1 {
            primary.hWeight = availableWidth
            return
        }

        primary.hWeight = availableWidth * ratio
        children[1].hWeight = availableWidth - primary.hWeight

        guard let stack = children[1] as? TilingContainer,
              stack.layout == .tiles,
              stack.orientation == .v,
              !stack.children.isEmpty
        else { return }

        let stackChildHeight = availableHeight / CGFloat(stack.children.count)
        for child in stack.children {
            child.vWeight = stackChildHeight
        }
    }

    @MainActor
    func bindingDataForNewPrimarySecondaryWindow(on workspace: Workspace) -> BindingData? {
        guard primarySecondaryPrimaryRatio != nil, layout == .tiles, orientation == .h else { return nil }
        switch children.count {
            case 0:
                return BindingData(parent: self, adaptiveWeight: WEIGHT_AUTO, index: 0)
            case 1:
                guard children[0] is Window else { return nil }
                return BindingData(parent: self, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
            case 2:
                guard children[0] is Window else { return nil }
                if let stack = children[1] as? TilingContainer,
                   stack.layout == .tiles,
                   stack.orientation == .v
                {
                    return BindingData(parent: stack, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
                }
                if let stackWindow = children[1] as? Window {
                    let binding = stackWindow.unbindFromParent()
                    let stack = TilingContainer.newVTiles(
                        parent: self,
                        adaptiveWeight: binding.adaptiveWeight,
                        index: binding.index,
                    )
                    stackWindow.bind(to: stack, adaptiveWeight: WEIGHT_AUTO, index: 0)
                    applyPrimarySecondarySizingIfNeeded(
                        availableWidth: workspace.workspaceMonitor.visibleRectPaddedByOuterGaps.width,
                        availableHeight: workspace.workspaceMonitor.visibleRectPaddedByOuterGaps.height - 1,
                    )
                    return BindingData(parent: stack, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
                }
                return nil
            default:
                return nil
        }
    }
}
