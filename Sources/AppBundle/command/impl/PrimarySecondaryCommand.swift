import AppKit
import Common

struct PrimarySecondaryCommand: Command {
    let args: PrimarySecondaryCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    @MainActor
    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        guard let primaryWindow = target.windowOrNil else {
            return .fail(io.err(noWindowIsFocused))
        }
        guard primaryWindow.parent is TilingContainer else {
            return .fail(io.err("The window is non-tiling"))
        }

        let workspace = target.workspace
        let root = workspace.rootTilingContainer
        if root.primarySecondaryPrimaryRatio != nil,
           root.layout == .tiles,
           root.orientation == .h,
           root.children.count <= 2,
           let currentPrimary = root.children.first as? Window,
           isSupportedPrimarySecondaryChild(root.children.dropFirst().first)
        {
            if currentPrimary != primaryWindow {
                swapWindows(primaryWindow, currentPrimary)
            }
            root.applyPrimarySecondarySizingIfNeeded(
                availableWidth: workspace.workspaceMonitor.visibleRectPaddedByOuterGaps.width,
                availableHeight: workspace.workspaceMonitor.visibleRectPaddedByOuterGaps.height - 1,
            )
            focus.windowOrNil?.markAsMostRecentChild()
            return .succ
        }

        let tilingWindows = root.allLeafWindowsRecursive
        guard tilingWindows.contains(primaryWindow) else {
            return .fail(io.err("The window is non-tiling"))
        }

        let orderedWindows = [primaryWindow] + tilingWindows.filter { $0 != primaryWindow }
        let previousRootBinding = root.unbindFromParent()
        let newRoot = TilingContainer(
            parent: workspace,
            adaptiveWeight: previousRootBinding.adaptiveWeight,
            .h,
            .tiles,
            index: previousRootBinding.index,
        )
        newRoot.primarySecondaryPrimaryRatio = defaultPrimarySecondaryPrimaryRatio

        primaryWindow.bind(to: newRoot, adaptiveWeight: WEIGHT_AUTO, index: 0)
        let otherWindows = Array(orderedWindows.dropFirst())
        if otherWindows.count == 1 {
            otherWindows[0].bind(to: newRoot, adaptiveWeight: WEIGHT_AUTO, index: 1)
        } else if !otherWindows.isEmpty {
            let stack = TilingContainer.newVTiles(parent: newRoot, adaptiveWeight: WEIGHT_AUTO, index: 1)
            for (index, window) in otherWindows.enumerated() {
                window.bind(to: stack, adaptiveWeight: WEIGHT_AUTO, index: index)
            }
        }

        newRoot.applyPrimarySecondarySizingIfNeeded(
            availableWidth: workspace.workspaceMonitor.visibleRectPaddedByOuterGaps.width,
            availableHeight: workspace.workspaceMonitor.visibleRectPaddedByOuterGaps.height - 1,
        )
        focus.windowOrNil?.markAsMostRecentChild()
        return .succ
    }
}

private func isSupportedPrimarySecondaryChild(_ child: TreeNode?) -> Bool {
    switch child {
        case nil:
            true
        case is Window:
            true
        case let stack as TilingContainer:
            stack.layout == .tiles &&
                stack.orientation == .v &&
                !stack.children.isEmpty &&
                stack.children.allSatisfy { $0 is Window }
        default:
            false
    }
}
