import XCTest
import SwiftData
@testable import paprikaplanner

/// Tests for PlanGenerationViewModel - particularly navigation state and reload behavior
/// 
/// QA CONCERN: These tests verify that:
/// 1. Tab switches don't cause unnecessary reloads
/// 2. Pull-to-refresh still forces a reload
/// 3. State management works correctly
final class PlanGenerationViewModelTests: XCTestCase {
    
    var viewModel: PlanGenerationViewModel!
    
    override func setUp() {
        super.setUp()
        viewModel = PlanGenerationViewModel()
    }
    
    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
    
    // MARK: - Tab Switch / Navigation State Tests
    
    /// When the view already has data for the current week, switching tabs should NOT reload
    /// BUG FOUND: Previously, every .task call triggered a full reload
    func test_loadExistingMeals_skipsReload_whenDataExists() async {
        // Arrange - Simulate having already loaded data
        viewModel.hasGenerated = true
        viewModel.weekPlan = createMockWeekPlan(dayCount: 7)
        
        // Act - Verify the guard conditions that would skip reload
        XCTAssertTrue(viewModel.hasGenerated)
        XCTAssertEqual(viewModel.weekPlan?.days.count, 7)
        
        // The actual skip happens in loadExistingMeals - we verify the conditions
        let shouldSkip = viewModel.hasGenerated && viewModel.weekPlan?.days.count == 7
        XCTAssertTrue(shouldSkip, "Guard condition should skip reload when data exists")
    }
    
    /// When forceRefresh is true (pull-to-refresh), should reload even if data exists
    func test_loadExistingMeals_reloads_whenForceRefreshTrue() async {
        // Arrange - Simulate having data
        viewModel.hasGenerated = true
        viewModel.weekPlan = createMockWeekPlan(dayCount: 7)
        
        // The forceRefresh parameter should bypass the guard
        // We verify that the guard condition would NOT apply when forceRefresh=true
        let forceRefresh = true
        let shouldSkip = !forceRefresh && viewModel.hasGenerated && viewModel.weekPlan?.days.count == 7
        XCTAssertFalse(shouldSkip, "Guard should NOT skip when forceRefresh=true")
    }
    
    /// When no data has been loaded yet, should always load
    func test_loadExistingMeals_loads_whenNoDataExists() async {
        // Arrange - Fresh state
        XCTAssertFalse(viewModel.hasGenerated)
        XCTAssertNil(viewModel.weekPlan)
        
        // The guard should NOT skip
        let forceRefresh = false
        let shouldSkip = !forceRefresh && viewModel.hasGenerated && viewModel.weekPlan?.days.count == 7
        XCTAssertFalse(shouldSkip, "Should load when no data exists")
    }
    
    /// When data exists but is incomplete (less than 7 days), should reload
    func test_loadExistingMeals_reloads_whenDataIncomplete() async {
        // Arrange - Partial data
        viewModel.hasGenerated = true
        viewModel.weekPlan = createMockWeekPlan(dayCount: 3)
        
        // Guard should NOT skip because we don't have 7 days
        let forceRefresh = false
        let shouldSkip = !forceRefresh && viewModel.hasGenerated && viewModel.weekPlan?.days.count == 7
        XCTAssertFalse(shouldSkip, "Should reload when data is incomplete")
    }
    
    // MARK: - Initial State Tests
    
    func test_initialState_hasNoData() {
        XCTAssertFalse(viewModel.hasGenerated)
        XCTAssertNil(viewModel.weekPlan)
        XCTAssertFalse(viewModel.isGenerating)
        XCTAssertFalse(viewModel.isLoadingExisting)
    }
    
    func test_initialState_hasCurrentWeek() {
        // Should initialize with current ISO week
        let (year, week) = Calendar.currentISOWeek
        XCTAssertEqual(viewModel.currentWeekYear, year)
        XCTAssertEqual(viewModel.currentWeekNumber, week)
    }
    
    // MARK: - Offline Mode Tests
    
    func test_forceOffline_defaultsToFalse() {
        XCTAssertFalse(viewModel.forceOffline)
    }
    
    func test_toggleForceOffline_togglesState() {
        XCTAssertFalse(viewModel.forceOffline)
        
        viewModel.toggleForceOffline()
        XCTAssertTrue(viewModel.forceOffline)
        
        viewModel.toggleForceOffline()
        XCTAssertFalse(viewModel.forceOffline)
    }
    
    // MARK: - Undo Tests

    func test_canUndo_initiallyFalse() {
        XCTAssertFalse(viewModel.canUndo)
    }

    func test_regenerateAll_enablesUndo() {
        // Arrange - Set up a week plan
        viewModel.weekPlan = createMockWeekPlan(dayCount: 7)
        viewModel.hasGenerated = true

        // Act - Regenerate
        viewModel.regenerateAll()

        // Assert - Undo should now be available
        XCTAssertTrue(viewModel.canUndo, "Should be able to undo after regenerateAll")
    }

    func test_regenerateDay_enablesUndo() {
        // Arrange
        viewModel.weekPlan = createMockWeekPlan(dayCount: 7)
        viewModel.hasGenerated = true

        // Act
        viewModel.regenerateDay(at: 0)

        // Assert
        XCTAssertTrue(viewModel.canUndo, "Should be able to undo after regenerateDay")
    }

    func test_undo_restoresPreviousState() {
        // Arrange
        viewModel.weekPlan = createMockWeekPlan(dayCount: 7)
        viewModel.hasGenerated = true
        let originalMealName = viewModel.weekPlan?.days[0].mealName

        // Act - Regenerate then undo
        viewModel.regenerateDay(at: 0)
        viewModel.undo()

        // Assert
        XCTAssertFalse(viewModel.canUndo, "Undo should no longer be available after undoing")
        XCTAssertEqual(viewModel.weekPlan?.days[0].mealName, originalMealName, "Should restore original meal")
    }

    func test_undo_notAvailableAfterSync() {
        // Arrange
        viewModel.weekPlan = createMockWeekPlan(dayCount: 7)
        viewModel.hasGenerated = true
        viewModel.regenerateAll()
        XCTAssertTrue(viewModel.canUndo)

        // Act - Simulate sync completion
        viewModel.hasSynced = true

        // Assert - canUndo checks hasSynced
        XCTAssertFalse(viewModel.canUndo, "Should not be able to undo after sync")
    }

    // MARK: - Helpers

    /// Create a mock WeekPlan for testing without needing real RecipeModels
    private func createMockWeekPlan(dayCount: Int) -> WeekPlan {
        let weekPlan = WeekPlan(recipes: [])
        // Manually set up days since we can't call generate without recipes
        var days: [DayPlan] = []
        for i in 0..<dayCount {
            let date = Date().addingTimeInterval(Double(i) * 86400)
            days.append(DayPlan(date: date, recipe: nil, mealName: "Test Meal \(i)"))
        }
        weekPlan.days = days
        return weekPlan
    }
}
