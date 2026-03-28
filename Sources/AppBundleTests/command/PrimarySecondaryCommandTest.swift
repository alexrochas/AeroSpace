@testable import AppBundle
import Common
import XCTest

@MainActor
final class PrimarySecondaryCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testPrimarySecondary_parse() {
        testParseCommandSucc("primary-secondary", PrimarySecondaryCmdArgs(rawArgs: []))
    }

    func testPrimarySecondary_arrangesFocusedWindowAsPrimary() async throws {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
                TestWindow.new(id: 3, parent: $0)
            }
            TestWindow.new(id: 4, parent: $0)
        }

        assertEquals(try await PrimarySecondaryCommand(args: PrimarySecondaryCmdArgs(rawArgs: [])).run(.defaultEnv, .emptyStdin).exitCode, 0)

        assertEquals(
            workspace.rootTilingContainer.layoutDescription,
            .h_tiles([
                .window(2),
                .v_tiles([
                    .window(1),
                    .window(3),
                    .window(4),
                ]),
            ]),
        )
        assertEquals(workspace.rootTilingContainer.primarySecondaryPrimaryRatio, defaultPrimarySecondaryPrimaryRatio)

        let availableWidth = workspace.workspaceMonitor.visibleRectPaddedByOuterGaps.width
        let availableHeight = workspace.workspaceMonitor.visibleRectPaddedByOuterGaps.height - 1
        assertCGFloatNear(workspace.rootTilingContainer.children[0].hWeight, availableWidth * defaultPrimarySecondaryPrimaryRatio)
        assertCGFloatNear(workspace.rootTilingContainer.children[1].hWeight, availableWidth * (1 - defaultPrimarySecondaryPrimaryRatio))

        let stack = workspace.rootTilingContainer.children[1] as! TilingContainer
        for child in stack.children {
            assertCGFloatNear(child.vWeight, availableHeight / 3)
        }
    }

    func testPrimarySecondary_promotesAnotherWindowInsideExistingPrimarySecondaryLayout() async throws {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
            TestWindow.new(id: 3, parent: $0)
            TestWindow.new(id: 4, parent: $0)
        }

        assertEquals(try await PrimarySecondaryCommand(args: PrimarySecondaryCmdArgs(rawArgs: [])).run(.defaultEnv, .emptyStdin).exitCode, 0)

        let stack = workspace.rootTilingContainer.children[1] as! TilingContainer
        assertEquals((stack.children[1] as! Window).focusWindow(), true)

        assertEquals(try await PrimarySecondaryCommand(args: PrimarySecondaryCmdArgs(rawArgs: [])).run(.defaultEnv, .emptyStdin).exitCode, 0)

        assertEquals(
            workspace.rootTilingContainer.layoutDescription,
            .h_tiles([
                .window(3),
                .v_tiles([
                    .window(2),
                    .window(1),
                    .window(4),
                ]),
            ]),
        )
        assertEquals(workspace.rootTilingContainer.primarySecondaryPrimaryRatio, defaultPrimarySecondaryPrimaryRatio)
    }
}

private func assertCGFloatNear(
    _ actual: CGFloat,
    _ expected: CGFloat,
    accuracy: CGFloat = 0.001,
    file: String = #filePath,
    line: Int = #line
) {
    if abs(actual - expected) > accuracy {
        XCTFail(
            """

            \(file):\(line): Assertion failed
                Expected:
                    \(expected)
                Actual:
                    \(actual)
            """,
        )
    }
}
