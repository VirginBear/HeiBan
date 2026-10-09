using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;

var checks=0;
void Check(bool condition,string message){if(!condition)throw new Exception(message);checks++;}
void Near(double actual,double expected,string message)=>Check(Math.Abs(actual-expected)<1e-6,message);
void Point(InkPoint actual,InkPoint expected,string message){Near(actual.X,expected.X,message+" X");Near(actual.Y,expected.Y,message+" Y");}

foreach(var type in new[]{"line","arrow"})
foreach(var angle in new[]{0d,37d,90d,-120d})
{
    var o=new BoardObject{Type=type};ObjectHandles.SetEndpoints(o,new(350,240),new(50,80));o.Rotation=angle;
    var a=ObjectHandles.Endpoint(o,0);var b=ObjectHandles.Endpoint(o,1);
    ObjectHandles.MoveEndpoint(o,0,new(480,25));Point(ObjectHandles.Endpoint(o,1),b,"B stays fixed when A moves");
    ObjectHandles.MoveEndpoint(o,1,new(20,450));Point(ObjectHandles.Endpoint(o,0),new(480,25),"A stays fixed when B moves");
    Near(o.Width,460,"Bounds rebuilt");Near(o.Height,425,"Bounds rebuilt");
    Check(ObjectHandles.Get(o,.2).All(h=>h.Kind=="endpoint"),"Lines have only A/B handles");
    Check(VectorMath.IsPointInObject(new(250,237.5),o,2),"Line segment hit");
    Check(!VectorMath.IsPointInObject(new(30,40),o,2),"Empty line bounding box misses");
}
var rotatedImage=new BoardObject{Type="image",X=100,Y=200,Width=400,Height=100,Rotation=90};
Check(VectorMath.IsPointInObject(new(300,420),rotatedImage,0),"Rotated image visible area hit");
Check(!VectorMath.IsPointInObject(new(110,210),rotatedImage,0),"Unrotated empty area misses");
Check(ObjectHandles.Get(rotatedImage,2).Count(h=>h.Kind=="resize")==8,"Eight image resize handles");
Check(ObjectHandles.Get(rotatedImage,2).Count(h=>h.Kind=="rotate")==1,"Image rotation handle");
foreach(var angle in new[]{0d,37d,90d,-120d})
foreach(var index in Enumerable.Range(0,8))
{
    var initial=new BoardObject{Type="image",X=100,Y=200,Width=400,Height=200,Rotation=angle};
    var target=DocumentCodec.Clone(initial);var handles=ObjectHandles.Get(initial,1);
    var anchor=handles[(index+4)%8].Point;
    var pointer=ObjectHandles.Rotate(new(handles[index].Point.X+(handles[index].Point.X-ObjectHandles.Center(initial).X)*.5,
        handles[index].Point.Y+(handles[index].Point.Y-ObjectHandles.Center(initial).Y)*.5),ObjectHandles.Center(initial),0);
    ObjectHandles.Resize(target,initial,index,pointer,index%2==0);
    Point(ObjectHandles.Get(target,1)[(index+4)%8].Point,anchor,"Opposite resize anchor stays fixed");
    if(index%2==0)Near(target.Width/target.Height,2,"Image corner keeps aspect ratio");
}
foreach(var ratio in new[]{0d,.5,1d})
foreach(var edge in new[]{"top","center","bottom"})
{
    var offset=RulerGeometry.PivotOffset(0,1000,64,ratio,edge);
    var pivot=new InkPoint(500+offset.X,350+offset.Y);
    foreach(var angle in new[]{37d,90d,-180d})
    {
        var next=RulerGeometry.PivotOffset(angle,1000,64,ratio,edge);
        var center=new InkPoint(pivot.X-next.X,pivot.Y-next.Y);
        Point(new(center.X+next.X,center.Y+next.Y),pivot,"Ruler edge/end pivot remains fixed");
    }
}
Check(RulerGeometry.PickPivot(-500,-32,1000,64)==(0d,"top"),"Top left endpoint reachable");
Check(RulerGeometry.PickPivot(500,32,1000,64)==(1d,"bottom"),"Bottom right endpoint reachable");
var session=new EditorSession();session.Open(new());session.Begin();
var image=session.Add(new BoardObject{Type="image",X=40,Y=60,Width=300,Height=150,ImageUrl="data:image/png;base64,fixture",Rotation=37});session.Commit();
session.Begin();ObjectHandles.Resize(image,DocumentCodec.Clone(image),4,new(500,450),true);image.Rotation=90;session.Commit();
var edited=DocumentCodec.Encode(session.Document);session.Undo();Near(session.Document.Objects[0].Rotation,37,"Undo restores image transform");
session.Redo();Check(DocumentCodec.Encode(session.Document)==edited,"Redo restores image data and transform");
var decoded=DocumentCodec.Decode(edited);Check(decoded.Objects[0].ImageUrl==image.ImageUrl,"Image source survives save/reopen");
Near(decoded.Objects[0].Rotation,90,"Rotation survives save/reopen");

// ScreenshotCaptureCoordinator lifecycle & deduplication tests
var coord = new ScreenshotCaptureCoordinator();
Check(coord.State == ScreenshotSessionState.Idle, "Initial coordinator state is Idle");
Check(!coord.IsCapturing, "Initial coordinator is not capturing");
Check(coord.ActiveRequest == null, "Initial active request is null");

var req1 = coord.BeginCapture("board_1", "page_1", new(120, 240), 1000);
Check(req1 != null, "BeginCapture returns valid request");
Check(coord.IsCapturing, "Coordinator is capturing after BeginCapture");
Check(coord.State == ScreenshotSessionState.Capturing, "State is Capturing");
Check(coord.ActiveRequest?.BoardId == "board_1", "Request boardId matches");
Check(coord.ActiveRequest?.PageId == "page_1", "Request pageId matches");
Point(coord.ActiveRequest!.TargetCenter, new(120, 240), "Target center matches");
Check(coord.ActiveRequest.BaselineClipboardSequence == 1000, "Baseline clipboard sequence matches");

// Duplicate capture prevention
var reqDuplicate = coord.BeginCapture("board_1", "page_1", new(300, 400), 1000);
Check(reqDuplicate == null, "BeginCapture returns null when already capturing");

// Stale clipboard rejection (sequence unchanged)
Check(!coord.CanAcceptResult(req1!.RequestId, "board_1", "page_1", 1000), "Reject result if clipboard sequence unchanged");

// Context mismatch rejection
Check(!coord.CanAcceptResult(req1.RequestId, "other_board", "page_1", 1001), "Reject result if boardId mismatch");
Check(!coord.CanAcceptResult(req1.RequestId, "board_1", "other_page", 1001), "Reject result if pageId mismatch");
Check(!coord.CanAcceptResult("wrong_req_id", "board_1", "page_1", 1001), "Reject result if requestId mismatch");

// Valid result acceptance
Check(coord.CanAcceptResult(req1.RequestId, "board_1", "page_1", 1001), "Accept result with new sequence and matching context");

// Complete session & deduplication
Check(coord.Complete(req1.RequestId), "Complete returns true for matching requestId");
Check(!coord.IsCapturing, "IsCapturing is false after Complete");
Check(coord.State == ScreenshotSessionState.Completed, "State is Completed");
Check(coord.ActiveRequest == null, "ActiveRequest is cleared after Complete");
Check(!coord.CanAcceptResult(req1.RequestId, "board_1", "page_1", 1001), "Cannot accept result after session completed");
Check(!coord.Complete(req1.RequestId), "Cannot complete twice");

// Cancellation
var req2 = coord.BeginCapture("board_2", "page_2", new(50, 50), 2000);
Check(req2 != null && coord.IsCapturing, "BeginCapture succeeds after previous completion");
Check(coord.Cancel("User pressed escape"), "Cancel returns true");
Check(!coord.IsCapturing, "IsCapturing is false after Cancel");
Check(coord.State == ScreenshotSessionState.Cancelled, "State is Cancelled");
Check(!coord.CanAcceptResult(req2!.RequestId, "board_2", "page_2", 2001), "Cancelled session cannot accept results");

// Context invalidation (page or board change during capture)
var req3 = coord.BeginCapture("board_3", "page_3", new(0, 0), 3000);
Check(req3 != null && coord.IsCapturing, "Session 3 started");
coord.InvalidateIfContextChanged("board_3", "page_3"); // same context
Check(coord.IsCapturing, "Same context does not invalidate session");
coord.InvalidateIfContextChanged("board_3", "page_new"); // page changed
Check(!coord.IsCapturing, "Page change invalidates screenshot session");
Check(coord.State == ScreenshotSessionState.Cancelled, "State became Cancelled on context change");

// Timeout expiration and CheckTimeout transition
var timeoutCoord = new ScreenshotCaptureCoordinator { Timeout = TimeSpan.FromMilliseconds(30) };
var reqTimeout = timeoutCoord.BeginCapture("board_t", "page_t", new(0, 0), 4000);
Check(reqTimeout != null, "Timeout coordinator started");
Thread.Sleep(50);
Check(timeoutCoord.IsExpired, "Session marked expired after timeout");
Check(timeoutCoord.CheckTimeout(), "CheckTimeout returns true when expired");
Check(timeoutCoord.State == ScreenshotSessionState.TimedOut, "State transitioned to TimedOut");
Check(!timeoutCoord.IsCapturing, "IsCapturing is false when expired");
Check(!timeoutCoord.CanAcceptResult(reqTimeout!.RequestId, "board_t", "page_t", 4001), "Cannot accept result when expired");

// Slow capture test (> 3 seconds valid capture)
var slowCoord = new ScreenshotCaptureCoordinator { Timeout = TimeSpan.FromSeconds(60) };
var reqSlow = slowCoord.BeginCapture("board_s", "page_s", new(10, 10), 5000);
Check(reqSlow != null && slowCoord.IsCapturing, "Slow capture session initiated");
// Simulate window deactivated (entering snipping tool)
slowCoord.NotifyWindowDeactivated();
Check(slowCoord.WindowWasDeactivated, "Window marked deactivated during snip");
// Even if multiple checks happen while snipping tool is active, capture remains valid
for(int i = 0; i < 20; i++)
{
    Check(!slowCoord.RecordReactivatedTickAndShouldCancel(4), "Still in overlay; reactivated tick does not trigger cancel prematurely");
    Check(slowCoord.IsCapturing, "Capturing remains true after multiple ticks (> 3 sec equivalent)");
}
// Now simulate window reactivated but user cancelled (no clipboard change)
slowCoord.NotifyWindowReactivated();
bool cancelledByReactivation = false;
for(int i = 0; i < 4; i++)
{
    cancelledByReactivation = slowCoord.RecordReactivatedTickAndShouldCancel(4);
}
Check(cancelledByReactivation, "User cancel detected after window restored without clipboard sequence change");
slowCoord.Cancel("Reactivation check detected cancellation");
Check(slowCoord.State == ScreenshotSessionState.Cancelled, "Slow session cleanly cancelled");

// Two-phase async validation: processing protects until commit
var asyncCoord = new ScreenshotCaptureCoordinator();
var reqAsync = asyncCoord.BeginCapture("board_a", "page_a", new(100, 100), 6000);
Check(reqAsync != null && asyncCoord.CanAcceptResult(reqAsync.RequestId, "board_a", "page_a", 6001), "Result accepted");
Check(asyncCoord.BeginProcessing(reqAsync!.RequestId), "BeginProcessing succeeded");
Check(asyncCoord.IsProcessing, "Coordinator in processing state");
// Context change occurs DURING async decoding
asyncCoord.InvalidateIfContextChanged("board_different", "page_a");
Check(asyncCoord.State == ScreenshotSessionState.Cancelled, "Context change cancelled processing session");
Check(!asyncCoord.ValidateAndComplete(reqAsync.RequestId, "board_different", "page_a"), "Cannot complete if context changed during decode");

// Successful two-phase async validation
var asyncSuccessCoord = new ScreenshotCaptureCoordinator();
var reqSuccess = asyncSuccessCoord.BeginCapture("board_ok", "page_ok", new(100, 100), 7000);
Check(asyncSuccessCoord.BeginProcessing(reqSuccess!.RequestId), "BeginProcessing succeeded for success test");
Check(asyncSuccessCoord.ValidateAndComplete(reqSuccess.RequestId, "board_ok", "page_ok"), "ValidateAndComplete succeeds when context matches");
Check(asyncSuccessCoord.State == ScreenshotSessionState.Completed, "State is Completed after ValidateAndComplete");

// ImagePlacementMath tests: aspect ratio preservation
// Thin horizontal image
var (thinW, thinH, thinX, thinY) = ImagePlacementMath.ComputePlacement(1200, 30, 800, 600, "infinite", null, null, new(400, 300), isCenter: true);
Near(thinW / thinH, 1200d / 30d, "Thin horizontal image preserves exact aspect ratio");
Check(thinW <= 800 * 0.75, "Width fits viewport constraint");

// Thin vertical image
var (tallW, tallH, tallX, tallY) = ImagePlacementMath.ComputePlacement(30, 1200, 800, 600, "infinite", null, null, new(400, 300), isCenter: true);
Near(tallW / tallH, 30d / 1200d, "Thin vertical image preserves exact aspect ratio");
Check(tallH <= 600 * 0.75, "Height fits viewport constraint");

// Fixed canvas clamping
var (fixW, fixH, fixX, fixY) = ImagePlacementMath.ComputePlacement(500, 500, 1000, 1000, "fixed", 595, 842, new(590, 840), isCenter: true);
Check(fixX + fixW <= 595, "Fixed canvas clamps X within board width");
Check(fixY + fixH <= 842, "Fixed canvas clamps Y within board height");

// W-V01: ToolbarPreferences tests
var defaultPrefs = ToolbarPreferences.CreateDefault();
Check(defaultPrefs.DockSide == "上方", "Default dock side is 上方");
Check(defaultPrefs.VisibleTools.Count == ToolbarPreferences.StreamlinedTools.Length, "Default visible tools are streamlined (8 tools)");
Check(defaultPrefs.HiddenTools.Count == ToolbarPreferences.AllDefaultTools.Length - ToolbarPreferences.StreamlinedTools.Length, "Additional tools in hidden by default");

// Normalization & corrupt settings handling
var corruptPrefs = new ToolbarPreferences
{
    DockSide = "invalid_dock",
    VisibleTools = ["pen", "invalid_tool", "pen"],
    HiddenTools = ["eraser", "pen"]
};
corruptPrefs.Normalize();
Check(corruptPrefs.DockSide == "上方", "Invalid dock side normalized to 上方");
Check(corruptPrefs.VisibleTools.Contains("pen"), "Valid tool kept");
Check(!corruptPrefs.VisibleTools.Contains("invalid_tool"), "Invalid tool removed");
Check(corruptPrefs.VisibleTools.Count(t => t == "pen") == 1, "Duplicate tool deduplicated");
Check(!corruptPrefs.HiddenTools.Contains("pen"), "Duplicate across visible/hidden deduplicated");
Check(corruptPrefs.VisibleTools.Count + corruptPrefs.HiddenTools.Count == ToolbarPreferences.AllDefaultTools.Length, "All missing tools recovered");

// Hide and Show operations
var customPrefs = ToolbarPreferences.CreateDefault();
customPrefs.HideTool("eraser");
Check(!customPrefs.VisibleTools.Contains("eraser"), "Eraser removed from visible");
Check(customPrefs.HiddenTools.Contains("eraser"), "Eraser added to hidden");
customPrefs.ShowTool("eraser");
Check(customPrefs.VisibleTools.Contains("eraser"), "Eraser restored to visible");
Check(!customPrefs.HiddenTools.Contains("eraser"), "Eraser removed from hidden");

// File persistence & atomic save/load in temp directory
var tempDir = Path.Combine(Path.GetTempPath(), "HeiBan_Test_" + Guid.NewGuid().ToString("N"));
Directory.CreateDirectory(Path.Combine(tempDir, "Settings"));
try
{
    var savePrefs = ToolbarPreferences.CreateDefault();
    savePrefs.DockSide = "左側";
    savePrefs.HideTool("eraser");
    await ToolbarPreferencesStore.SaveAsync(tempDir, savePrefs);

    var loadedPrefs = await ToolbarPreferencesStore.LoadAsync(tempDir);
    Check(loadedPrefs.DockSide == "左側", "Dock side preserved across save/load");
    Check(!loadedPrefs.VisibleTools.Contains("eraser"), "Hidden tool persisted");
    Check(loadedPrefs.HiddenTools.Contains("eraser"), "Hidden tool loaded");

    // Corrupt file handling
    var settingsPath = ToolbarPreferencesStore.GetPreferencesPath(tempDir);
    await File.WriteAllTextAsync(settingsPath, "{ corrupt json ... }}}");
    var fallbackPrefs = await ToolbarPreferencesStore.LoadAsync(tempDir);
    Check(fallbackPrefs.DockSide == "上方", "Corrupt file gracefully falls back to defaults");
    Check(fallbackPrefs.VisibleTools.Count == ToolbarPreferences.StreamlinedTools.Length, "Corrupt file restores streamlined tools");
}
finally
{
    if (Directory.Exists(tempDir)) Directory.Delete(tempDir, true);
}

// W-V02: SelectionQuickActionCoordinator tests
var strokeObj = new BoardObject { Type = "stroke" };
var strokeActions = SelectionQuickActionCoordinator.GetAvailableActions(strokeObj);
Check(strokeActions.Contains(QuickActionItem.StrokeColor), "Stroke has color action");
Check(!strokeActions.Contains(QuickActionItem.FillColor), "Stroke has no fill color action");

var rectObj = new BoardObject { Type = "rect" };
var rectActions = SelectionQuickActionCoordinator.GetAvailableActions(rectObj);
Check(rectActions.Contains(QuickActionItem.FillColor), "Rect has fill color action");
Check(rectActions.Contains(QuickActionItem.DashStyle), "Rect has dash style action");

var imgObj = new BoardObject { Type = "image" };
var imgActions = SelectionQuickActionCoordinator.GetAvailableActions(imgObj);
Check(!imgActions.Contains(QuickActionItem.StrokeWidth), "Image does not show stroke width");
Check(!imgActions.Contains(QuickActionItem.FillColor), "Image does not show fill color");
Check(imgActions.Contains(QuickActionItem.Opacity), "Image shows opacity");

var lockedObj = new BoardObject { Type = "rect", IsLocked = true };
var lockedActions = SelectionQuickActionCoordinator.GetAvailableActions(lockedObj);
Check(lockedActions.Contains(QuickActionItem.Unlock), "Locked object shows unlock");
Check(!lockedActions.Contains(QuickActionItem.Delete), "Locked object hides delete");
Check(!lockedActions.Contains(QuickActionItem.StrokeColor), "Locked object hides property edits");

// Bar position calculations
// Default: placed above selection
var normalPos = SelectionQuickActionCoordinator.ComputeBarPosition(200, 300, 100, 100, [new(190, 290), new(310, 410)], 1000, 800, 240, 36);
Check(normalPos.Y < 290, "Normal bar placed above selection envelope");
Near(normalPos.X + 120, 250, "Bar centered horizontally on selection");

// Near top edge of window: flips below
var topPos = SelectionQuickActionCoordinator.ComputeBarPosition(200, 40, 100, 100, [new(200, 40), new(300, 140)], 1000, 800, 240, 36);
Check(topPos.Y > 140, "Bar flips below selection when too close to top edge");

// W-V04: CanvasHUDFormatter tests
Check(CanvasHUDFormatter.FormatDimensions(320.44, 180.22) == "320.4 × 180.2 pt", "Dimensions formatted correctly in pt");
Check(CanvasHUDFormatter.FormatRotation(37.54) == "37.5°", "Rotation rounded to 0.1°");
Check(CanvasHUDFormatter.FormatRotation(-90.0) == "-90.0°", "Negative rotation formatted with 0.1°");
Check(CanvasHUDFormatter.FormatRotation(360.0) == "0.0°", "Full circle normalized to 0.0°");

var badgePos = CanvasHUDFormatter.ComputeBadgePosition(500, 400, 100, 30, 1200, 900);
Check(badgePos.X >= 516, "Badge placed to right of pointer");
Check(badgePos.Y < 400, "Badge placed above pointer");

// ========================================================
// W-N00 補修與可信基線斷言
// ========================================================
// 1. ScreenshotCaptureCoordinator: State getter 純淨性與 CancelIfMatching 隔離
var safeCoord = new ScreenshotCaptureCoordinator();
var sReq1 = safeCoord.BeginCapture("board_s1", "page_s1", new(50, 50), 8000);
Check(safeCoord.State == ScreenshotSessionState.Capturing, "State is capturing");
Check(!safeCoord.CancelIfMatching("wrong_req_id", "mismatch"), "CancelIfMatching rejects wrong requestId");
Check(safeCoord.IsCapturing, "Session still capturing after mismatched cancel");
Check(safeCoord.CancelIfMatching(sReq1!.RequestId, "matching"), "CancelIfMatching succeeds with matching requestId");
Check(safeCoord.State == ScreenshotSessionState.Cancelled, "State transitioned to Cancelled");

// 2. ToolbarPreferences: 精簡預設配置、移動工具排序、新工具收折於更多
var streamPrefs = ToolbarPreferences.CreateDefault();
Check(streamPrefs.VisibleTools.Count == ToolbarPreferences.StreamlinedTools.Length, "Streamlined default toolbar has 8 tools");
Check(streamPrefs.HiddenTools.Contains("calculator"), "Calculator placed in hidden/more by default");
Check(streamPrefs.HiddenTools.Contains("timer"), "Timer placed in hidden/more by default");
Check(streamPrefs.HiddenTools.Contains("compass"), "Compass placed in hidden/more by default");
Check(streamPrefs.MoveToolDown("select"), "Move select down succeeded");
Check(streamPrefs.VisibleTools[1] == "select", "Select moved to index 1");
Check(streamPrefs.MoveToolUp("select"), "Move select up succeeded");
Check(streamPrefs.VisibleTools[0] == "select", "Select restored to index 0");

// 3. SelectionQuickActionCoordinator: star 與 arc 納入幾何形狀
var starObj = new BoardObject { Type = "star" };
var starActions = SelectionQuickActionCoordinator.GetAvailableActions(starObj);
Check(starActions.Contains(QuickActionItem.FillColor), "Star object has fill color quick action");
Check(starActions.Contains(QuickActionItem.DashStyle), "Star object has dash style quick action");

var arcQuickObj = new BoardObject { Type = "arc" };
var arcActions = SelectionQuickActionCoordinator.GetAvailableActions(arcQuickObj);
Check(arcActions.Contains(QuickActionItem.FillColor), "Arc object has fill color quick action");
Check(arcActions.Contains(QuickActionItem.StrokeWidth), "Arc object has stroke width quick action");

// 4. VectorMath: 旋轉尺規屏幕包圍盒計算
var (rX, rY, rW, rH) = VectorMath.ComputeRotatedRulerBounds(new(500, 300), 90, 600, 72);
Near(rW, 72, "90-degree rotated ruler width matches thickness");
Near(rH, 600, "90-degree rotated ruler height matches length");

// ========================================================
// W-N03: 計算機 (CalculatorModel) 標靶驗收
// ========================================================
var calc = new CalculatorModel();
// 1. 89 * 63 = 5607
calc.InputDigit("8"); calc.InputDigit("9");
calc.InputOperator("×");
calc.InputDigit("6"); calc.InputDigit("3");
calc.CalculateResult();
Check(calc.Display == "5607", "89 × 63 = 5607");
Check(calc.History.Count == 1, "History has 1 item");
Check(calc.History[0].Result == "5607", "History result matches");

// 2. 0.1 + 0.2 = 0.3 (浮點精度優化驗收)
calc.Clear();
calc.InputDigit("0"); calc.InputDecimal(); calc.InputDigit("1");
calc.InputOperator("+");
calc.InputDigit("0"); calc.InputDecimal(); calc.InputDigit("2");
calc.CalculateResult();
Check(calc.Display == "0.3", "0.1 + 0.2 = 0.3 without floating point residue");

// 3. 直接運算式優先級與括號: (2 + 3) * 4 = 20
var exprVal1 = CalculatorModel.EvaluateExpressionString("(2+3)*4");
Near(exprVal1 ?? 0, 20.0, "(2 + 3) * 4 = 20");

var exprVal2 = CalculatorModel.EvaluateExpressionString("2+3*4");
Near(exprVal2 ?? 0, 14.0, "2 + 3 * 4 = 14");

// 4. 百分比運算: 200 + 10% = 220, 200 * 10% = 20
calc.Clear();
calc.InputDigit("2"); calc.InputDigit("0"); calc.InputDigit("0");
calc.InputOperator("+");
calc.InputDigit("1"); calc.InputDigit("0");
calc.InputPercentage();
calc.CalculateResult();
Check(calc.Display == "220", "200 + 10% = 220");

calc.Clear();
calc.InputDigit("2"); calc.InputDigit("0"); calc.InputDigit("0");
calc.InputOperator("×");
calc.InputDigit("1"); calc.InputDigit("0");
calc.InputPercentage();
calc.CalculateResult();
Check(calc.Display == "20", "200 × 10% = 20");

// 5. 科學計算: sin(30) = 0.5 (DEG 模式)
calc.Clear();
calc.IsDegreeMode = true;
calc.InputDigit("3"); calc.InputDigit("0");
calc.SinFunction();
Check(calc.Display == "0.5", "DEG sin(30) = 0.5");

// 6. 平方根、倒數、次方
calc.Clear();
calc.InputDigit("1"); calc.InputDigit("6");
calc.SquareRoot();
Check(calc.Display == "4", "√16 = 4");

calc.Clear();
calc.InputDigit("4");
calc.Reciprocal();
Check(calc.Display == "0.25", "1/4 = 0.25");

calc.Clear();
calc.InputDigit("2");
calc.InputOperator("^");
calc.InputDigit("3");
calc.CalculateResult();
Check(calc.Display == "8", "2^3 = 8");

// 7. 除以零安全恢復
calc.Clear();
calc.InputDigit("5");
calc.InputOperator("÷");
calc.InputDigit("0");
calc.CalculateResult();
Check(calc.HasError, "Divide by zero flags error");
Check(calc.Display == "錯誤", "Divide by zero displays 錯誤");
calc.Clear();
Check(!calc.HasError && calc.Display == "0", "Clear recovers from error safely");

// 8. 插入畫布文字物件
var calcObj = calc.CreateBoardObject(500, 300, "b_calc", "p_calc");
Check(calcObj.Type == "text", "Calculator board object is text type");
Check(calcObj.FontFamily?.Contains("Consolas") == true, "Calculator text uses monospace font");

// ========================================================
// W-N04: 圓規與圓弧 (CompassToolEngine & Arc) 標靶驗收
// ========================================================
var compass = new CompassToolEngine();
Check(!compass.IsArmed, "Compass initially unarmed");
Check(!compass.IsDrawingArc, "Compass initially not drawing arc");

// 1. 準備階段可移動圓心與調整半徑
compass.MoveCenter(new(350, 250));
Point(compass.Center, new(350, 250), "Compass center moved in preparation");
compass.AdjustRadius(180);
Near(compass.Radius, 180, "Compass radius adjusted in preparation");
compass.AdjustRadius(2); // clamped to min 5
Near(compass.Radius, 5, "Compass radius clamped to min 5");
compass.AdjustRadius(150);

// 2. 鎖定階段 (Armed)
compass.ToggleArmed();
Check(compass.IsArmed, "Compass is armed");
compass.MoveCenter(new(999, 999));
Point(compass.Center, new(350, 250), "Compass center locked while armed");

// 3. 沿圓周作畫與跨零度累計掃角
compass.SetStartAngle(350);
compass.StartArc(350);
Check(compass.IsDrawingArc, "Drawing arc started");
compass.UpdateSweep(20); // 跨過 0 度 (從 350 到 20 相當於順時針 +30 度)
Near(compass.SweepAngle, 30, "Continuous sweep across 0 degrees (+30 deg)");
compass.FinishArcDrawing();

// 4. 產生 arc 物件與契約相容性
var arcObj = compass.CreateArcObject("b_arc", "p_arc");
Check(arcObj.Type == "arc", "Object type is arc");
Near(arcObj.ArcRadius ?? 0, 150, "Arc radius matches compass radius");
Near(arcObj.ArcStartAngle ?? 0, 350, "Arc start angle matches");
Near(arcObj.ArcSweepAngle ?? 0, 30, "Arc sweep angle matches");
Near(arcObj.Width, 300, "Arc bounding box width is diameter");
Near(arcObj.Height, 300, "Arc bounding box height is diameter");

// 5. 整圓繪製
var fullCircleObj = compass.CreateArcObject("b_arc", "p_arc", fullCircle: true);
Near(fullCircleObj.ArcSweepAngle ?? 0, 360, "Full circle arc sweep angle is 360");

// 6. VectorMath: arc 幾何命中測試與角域跨度判定
Check(VectorMath.IsAngleInSpan(10, 350, 30), "10 deg is within 350..20 deg span");
Check(!VectorMath.IsAngleInSpan(180, 350, 30), "180 deg is not within 350..20 deg span");

// 命中弧線上的點 (Center 350, 250, Radius 150, start 350, sweep 30 -> 包含 0 度正右方點 500, 250)
Check(VectorMath.IsPointInObject(new(500, 250), arcObj, 4), "Point on arc circumference is hit");
// 反方向點 (200, 250) 落在同一圓周但不在該弧段跨度內，應不命中
Check(!VectorMath.IsPointInObject(new(200, 250), arcObj, 4), "Point on un-swept circle arc misses");

// 7. Arc 包圍盒計算
var arcBox = VectorMath.ComputeArcBoundingBox(new(300, 300), 100, 0, 90, 2);
Near(arcBox.MinX, 299, "Arc bounding box minX (contains center.X to center.X + R)");
Near(arcBox.MaxX, 401, "Arc bounding box maxX");

// 8. 序列化與反序列化往返一致性
var arcDoc = new HeiBanDocument { Board = new BoardMetadata { Id = "test_arc_doc" }, Objects = [arcObj] };
var encodedArcDoc = DocumentCodec.Encode(arcDoc);
var decodedArcDoc = DocumentCodec.Decode(encodedArcDoc);
var roundtripArc = decodedArcDoc.Objects[0];
Check(roundtripArc.Type == "arc", "Roundtrip arc type preserved");
Near(roundtripArc.ArcRadius ?? 0, 150, "Roundtrip arc radius preserved");
Near(roundtripArc.ArcStartAngle ?? 0, 350, "Roundtrip arc start angle preserved");
Near(roundtripArc.ArcSweepAngle ?? 0, 30, "Roundtrip arc sweep angle preserved");

// ========================================================
// W-N05: 計時器 (TimerCoordinator) 標靶驗收
// ========================================================
var timer = new TimerCoordinator();
Check(timer.Status == TimerStatus.Stopped, "Timer initial status is Stopped");
Check(timer.Mode == TimerMode.Stopwatch, "Timer initial mode is Stopwatch");

// 1. 正計時操作
timer.Start();
Check(timer.Status == TimerStatus.Running, "Timer running after start");
timer.Pause();
Check(timer.Status == TimerStatus.Paused, "Timer paused");
timer.Resume();
Check(timer.Status == TimerStatus.Running, "Timer resumed");
timer.Reset();
Check(timer.Status == TimerStatus.Stopped, "Timer stopped after reset");
Near(timer.ElapsedSeconds, 0, "Elapsed seconds reset to 0");

// 2. 倒數計時與預設時間
timer.SelectPresetMinutes(5);
Check(timer.Mode == TimerMode.Countdown, "Mode set to Countdown");
Near(timer.CountdownDuration, 300, "Countdown duration is 300s");
Near(timer.RemainingSeconds, 300, "Remaining seconds starts at 300s");
Check(timer.FormattedTimeString() == "05:00", "5 minutes formatted as 05:00");

// 模擬時間抵達 0
timer.Start();
timer.UpdateDisplayTimes(simulatedElapsed: 300.5);
Check(timer.Status == TimerStatus.TimesUp, "Timer status becomes TimesUp");
Check(timer.DidAlertTimesUp, "TimesUp alert triggered");
Near(timer.RemainingSeconds, 0, "Remaining seconds clamped to 0");

// 3. 插入畫布文字物件
var timerObj = timer.CreateBoardObject(600, 400, "b_timer", "p_timer");
// 4. 計算機表達式求值與結果設置
var calcTest = new CalculatorModel();
calcTest.EvaluateCurrentExpression("(2+3)*4");
Check(calcTest.Display == "20", "EvaluateCurrentExpression calculates (2+3)*4 = 20");
calcTest.SetResult("123.45");
Check(calcTest.Display == "123.45", "SetResult updates display value");

// 5. 工具列自訂排序 (ToolbarPreferences MoveToolUp / MoveToolDown)
var tpTest = ToolbarPreferences.CreateDefault();
var firstTool = tpTest.VisibleTools[0];
var secondTool = tpTest.VisibleTools[1];
Check(tpTest.MoveToolDown(firstTool), "MoveToolDown succeeds on first tool");
Check(tpTest.VisibleTools[0] == secondTool && tpTest.VisibleTools[1] == firstTool, "First and second tools swapped");
Check(tpTest.MoveToolUp(firstTool), "MoveToolUp restores order");
// 6. Arc 物件控制點、等比 Resize 與端點互動驗收 (W-N04)
var testArc = new BoardObject
{
    Type = "arc",
    X = 100,
    Y = 100,
    Width = 200,
    Height = 200,
    ArcRadius = 100,
    ArcStartAngle = 0,
    ArcSweepAngle = 90
};

var arcHandles = ObjectHandles.Get(testArc, 1.0);
Check(arcHandles.Any(h => h.Kind == "arc_start"), "Arc has arc_start handle");
Check(arcHandles.Any(h => h.Kind == "arc_end"), "Arc has arc_end handle");
Check(arcHandles.Count(h => h.Kind == "resize") == 8, "Arc has 8 resize handles");
Check(arcHandles.Any(h => h.Kind == "rotate"), "Arc has rotate handle");

var startH = arcHandles.First(h => h.Kind == "arc_start");
var endH = arcHandles.First(h => h.Kind == "arc_end");
Near(startH.Point.X, 300, "Start handle X is at 0 deg (300)");
Near(startH.Point.Y, 200, "Start handle Y is at 0 deg (200)");
Near(endH.Point.X, 200, "End handle X is at 90 deg (200)");
Near(endH.Point.Y, 300, "End handle Y is at 90 deg (300)");

// 等比 Resize 與 ArcRadius 同步驗收
var resizedArc = DocumentCodec.Clone(testArc);
ObjectHandles.Resize(resizedArc, testArc, 4, new InkPoint(400, 500), false);
Check(resizedArc.Width == resizedArc.Height, "Arc resize forces width == height");
Near(resizedArc.ArcRadius ?? 0, resizedArc.Width / 2.0, "ArcRadius synced to Width / 2");

// MoveArcEndpoint 起訖點互動驗收
ObjectHandles.MoveArcEndpoint(resizedArc, 0, new InkPoint(resizedArc.X + resizedArc.Width / 2, resizedArc.Y));
Check(resizedArc.ArcStartAngle.HasValue, "ArcStartAngle updated via MoveArcEndpoint");
ObjectHandles.MoveArcEndpoint(resizedArc, 1, new InkPoint(resizedArc.X + resizedArc.Width, resizedArc.Y + resizedArc.Height / 2));
Check(resizedArc.ArcSweepAngle.HasValue, "ArcSweepAngle updated via MoveArcEndpoint");

// 7. 截圖 Processing 階段逾時檢驗 (W-N00b/c)
var procCoord = new ScreenshotCaptureCoordinator { Timeout = TimeSpan.FromMilliseconds(50) };
var pReq = procCoord.BeginCapture("b_proc", null, new(100, 100), 10);
Check(pReq != null, "Capture session began");
Check(procCoord.BeginProcessing(pReq!.RequestId), "Transitioned to Processing");
Check(procCoord.IsProcessing, "Coordinator IsProcessing is true");
Thread.Sleep(65);
Check(procCoord.CheckTimeout(), "CheckTimeout detects expired Processing session");
Check(procCoord.State == ScreenshotSessionState.TimedOut, "Coordinator state is TimedOut");
Check(!procCoord.HasActiveSession, "Active session cleared on processing timeout");

// 8. 計算機括號鍵盤與表達式互動 (W-N03)
var parenCalc = new CalculatorModel();
parenCalc.InputParenthesis("(");
parenCalc.InputDigit("3");
parenCalc.InputOperator("+");
parenCalc.InputDigit("4");
parenCalc.InputParenthesis(")");
// 9. 驗證離線手冊 (W-N24)
var guideFile = Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "HeiBan.Windows", "Assets", "HeiBanUserGuide.html");
if (!File.Exists(guideFile))
{
    // 備用相對路徑檢查（依據測試工作目錄）
    guideFile = Path.GetFullPath("windows/HeiBan.Windows/Assets/HeiBanUserGuide.html");
}
Check(File.Exists(guideFile), "HeiBanUserGuide.html exists in Assets directory");
var guideHtml = File.ReadAllText(guideFile);
Check(guideHtml.Contains("黑板 · Windows 使用手冊"), "User guide contains Windows title");
Check(guideHtml.Contains("Win+Shift+S"), "User guide documents Win+Shift+S screenshot shortcut");
Check(guideHtml.Contains("Ctrl+S"), "User guide documents Ctrl+S shortcut");
Check(guideHtml.Contains("圓規：準備 → 鎖定 → 畫弧"), "User guide documents compass two-stage process");

// 10. 計算機浮點捨入與優先級驗證 (W-N03)
parenCalc.Clear();
parenCalc.InputDigit("0");
parenCalc.InputDecimal();
parenCalc.InputDigit("1");
parenCalc.InputOperator("+");
parenCalc.InputDigit("0");
parenCalc.InputDecimal();
parenCalc.InputDigit("2");
parenCalc.CalculateResult();
Check(parenCalc.Display == "0.3", "0.1 + 0.2 = 0.3 IEEE floating point rounding");

parenCalc.Clear();
parenCalc.InputParenthesis("(");
parenCalc.InputDigit("2");
parenCalc.InputOperator("+");
parenCalc.InputDigit("3");
parenCalc.InputParenthesis(")");
parenCalc.InputOperator("×");
parenCalc.InputDigit("4");
parenCalc.CalculateResult();
Check(parenCalc.Display == "20", "(2 + 3) × 4 = 20 via calculator model");

// preview.5: arc sides can shrink and endpoints remain continuous at 0 degrees.
foreach (var side in new[] { 1, 3, 5, 7 })
{
    var initialArc = new BoardObject { Type = "arc", X = 0, Y = 0, Width = 200, Height = 200, ArcRadius = 100, ArcStartAngle = 350, ArcSweepAngle = 40 };
    var nextArc = DocumentCodec.Clone(initialArc);
    var pointer = side switch { 1 => new InkPoint(100, 100), 3 => new InkPoint(100, 100), 5 => new InkPoint(100, 100), _ => new InkPoint(100, 100) };
    ObjectHandles.Resize(nextArc, initialArc, side, pointer, false);
    Near(nextArc.Width, 100, $"Arc side {side} shrinks");
    Near(nextArc.Height, nextArc.Width, $"Arc side {side} remains circular");
    Near(nextArc.ArcRadius ?? 0, nextArc.Width / 2, $"Arc side {side} radius matches size");
}
var crossingArc = new BoardObject { Type = "arc", X = 0, Y = 0, Width = 200, Height = 200, ArcRadius = 100, ArcStartAngle = 350, ArcSweepAngle = 40 };
ObjectHandles.MoveArcEndpoint(crossingArc, 0, new InkPoint(200, 100));
Near(crossingArc.ArcStartAngle ?? -1, 0, "Arc start crosses zero");
Near(crossingArc.ArcSweepAngle ?? 0, 30, "Arc start preserves short forward sweep at zero");
Check(ObjectHandles.Get(crossingArc, 1)[0].Kind == "arc_start", "Arc endpoint takes priority over box handle");
var backwardArc = new BoardObject { Type = "arc", X = 0, Y = 0, Width = 200, Height = 200, ArcRadius = 100, ArcStartAngle = 10, ArcSweepAngle = -40 };
ObjectHandles.MoveArcEndpoint(backwardArc, 0, new InkPoint(200, 100));
Near(backwardArc.ArcSweepAngle ?? 0, -30, "Arc start preserves backward sweep at zero");
ObjectHandles.MoveArcEndpoint(backwardArc, 1, new InkPoint(200, 100));
Near(backwardArc.ArcSweepAngle ?? 0, -.1, "Coincident backward endpoints do not become full circle");
ObjectHandles.MoveArcEndpoint(backwardArc, 1, new InkPoint(100, 100));
Near(backwardArc.ArcSweepAngle ?? 0, -.1, "Dragging endpoint at center is ignored");

// Layer identity is separate from localized presentation, including names imported from Mac.
var layerDocument=DocumentCodec.Decode("""{"board":{"id":"layers"},"objects":[{"id":"opaque-a","type":"rect","zIndex":1,"name":"課程重點","futureField":42},{"id":"opaque-b","type":"rect","zIndex":2},{"id":"opaque-c","type":"text","text":" 第一行\n第二行 | 保留分隔符 "}]}""");
var layerRows=LayerPresentation.Build(layerDocument.Objects);
Check(layerRows[0].ObjectId=="opaque-b"&&layerRows[0].Title=="矩形 2","Layers show Chinese numbered names in z order");
Check(layerRows[1].Title=="課程重點","Mac custom name is displayed");
Check(layerRows[2].Title=="文字：第一行 第二行 | 保留分隔符","Text is readable and not parsed as identity");
Check(layerDocument.Objects[0].ExtraFields!["futureField"].GetInt32()==42,"Known name preserves other unknown fields");
var layerRoundTrip=DocumentCodec.Decode(DocumentCodec.Encode(layerDocument));
Check(layerRoundTrip.Objects[0].Name=="課程重點","Custom name survives saving");
Check(!LayerPresentation.Build(layerRoundTrip.Objects).Any(row=>row.Title.Contains(row.ObjectId)),"UUID is not visible in default layer labels");
layerDocument.Objects[1].ZIndex=-2;
Check(LayerPresentation.Build(layerDocument.Objects).Single(row=>row.ObjectId=="opaque-b").Title=="矩形 2","Reordering keeps generated names stable");
var namedLayerSession=new EditorSession();namedLayerSession.Open(layerDocument);namedLayerSession.Begin();namedLayerSession.Document.Objects[1].Name="示範 | 中文";namedLayerSession.Commit();
Check(LayerPresentation.Build(namedLayerSession.VisibleObjects).Single(row=>row.ObjectId=="opaque-b").Title=="示範 | 中文","Renaming never changes identity");
namedLayerSession.Undo();Check(namedLayerSession.Document.Objects[1].Name is null,"Layer rename can undo");
namedLayerSession.Redo();Check(namedLayerSession.Document.Objects[1].Name=="示範 | 中文","Layer rename can redo");
var emojiLayer=LayerPresentation.Build(new[]{new BoardObject{Type="text",Text=string.Concat(Enumerable.Repeat("👩‍🏫",30))}})[0];
Check(emojiLayer.Title=="文字："+string.Concat(Enumerable.Repeat("👩‍🏫",28))+"…","Snippet truncates at grapheme boundaries");
Check(LayerPresentation.Build(new[]{new BoardObject{Type="unfamiliar",IsLocked=true}})[0].Description=="其他物件 · 已鎖定","Unknown types and lock state have readable descriptions");

Console.WriteLine($"PASS: {checks} Windows interaction geometry, screenshot coordinator, calculator, compass/arc, timer & offline guide checks");


