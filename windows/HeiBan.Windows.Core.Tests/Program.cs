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

// Mac 1.0.8 teaching and shared document behavior.
var multi=new EditorSession();multi.Open(new HeiBanDocument{Objects=[new BoardObject{Id="one",Type="rect",X=10,Y=20,Width=40,Height=50},new BoardObject{Id="two",Type="text",X=100,Y=20,Text="資料",IsLocked=true},new BoardObject{Id="three",Type="rect",X=200,Y=20,IsVisible=false}]});
multi.SetSelection(new[]{"one","two","missing"});Check(multi.SelectedIds.Count==2,"Selection validates document identities");
multi.Begin();multi.MoveSelection(10,15);multi.Commit();Check(multi.Document.Objects[0].X==20&&multi.Document.Objects[0].Y==35,"Multiple selection moves unlocked object");Check(multi.Document.Objects[1].X==100,"Multiple move protects locked objects");
multi.Undo();Check(multi.Document.Objects[0].X==10,"Batch move uses one undo");multi.Redo();Check(multi.Document.Objects[0].X==20,"Batch move redo restores movement");
multi.SetSelection(new[]{"one","two"});multi.DeleteSelected();Check(multi.Document.Objects.Count==2&&multi.Document.Objects.Any(o=>o.Id=="two"),"Batch delete protects locked objects");multi.Undo();Check(multi.Document.Objects.Count==3,"Batch deletion undo restores all objects");
Check(multi.PageObjects.Count()==3&&multi.VisibleObjects.Count()==2,"Hidden objects remain in layer inventory");
var primaryStyle=new BoardObject{Id="primary",Type="rect",X=13};var beforeStyle=DocumentCodec.Clone(primaryStyle);primaryStyle.StrokeColor="#EF4444";primaryStyle.FontSize=30;
var otherStyle=new BoardObject{Id="other",Type="rect",X=90};var lockedStyle=new BoardObject{Id="locked",Type="text",IsLocked=true};var textStyle=new BoardObject{Id="label",Type="text"};
SelectionStyle.ApplyChanged(beforeStyle,primaryStyle,new[]{otherStyle,lockedStyle,textStyle});Check(otherStyle.StrokeColor=="#EF4444"&&otherStyle.X==90&&otherStyle.Id=="other","Batch styles do not copy geometry or identity");Check(otherStyle.FontSize!=30&&textStyle.FontSize==30,"Text styles only target text types");Check(lockedStyle.StrokeColor!="#EF4444","Batch styles preserve locks");
var lassoPolygon=new[]{new InkPoint(0,0),new InkPoint(100,0),new InkPoint(100,100),new InkPoint(0,100)};
Check(LassoSelection.Contains(new InkPoint(50,50),lassoPolygon),"Lasso contains interior point");Check(!LassoSelection.Contains(new InkPoint(150,50),lassoPolygon),"Lasso excludes exterior point");Check(!LassoSelection.Contains(new InkPoint(50,50),lassoPolygon.Take(2).ToArray()),"Incomplete lasso selects nothing");
Check(LassoSelection.Intersects(new BoardObject{Type="rect",X=90,Y=40,Width=30,Height=20},lassoPolygon),"Lasso supports partial boundary overlap");Check(!LassoSelection.Intersects(new BoardObject{Type="rect",X=10,Y=10,Width=20,Height=20,IsVisible=false},lassoPolygon),"Lasso ignores hidden objects");
var laserTransient=new LaserPointerEngine{FadeDuration=.5};var lp=new InkPoint(1,2);laserTransient.Add(lp,0);lp.X=100;Check(laserTransient.Samples[0].Point.X==1,"Laser clones samples");laserTransient.Add(new InkPoint(2,3),.1);laserTransient.EndTrail();laserTransient.Add(new InkPoint(3,4),.2);Check(laserTransient.Samples[2].StartsTrail,"Laser separates gesture trails");laserTransient.Prune(.61);Check(laserTransient.Samples.Count==1,"Laser prunes faded samples");
for(var i=0;i<1000;i++)laserTransient.Add(new InkPoint(i,i),1+i*.0001);Check(laserTransient.Samples.Count==500,"Laser bounds live sample memory");laserTransient.Clear();Check(laserTransient.Samples.Count==0,"Laser clear leaves no persistent object");
var exportDoc=new HeiBanDocument{Board=new BoardMetadata{Title="<script>中文 & 標題</script>",CanvasMode="infinite",GridStyle="grid"},Objects=[new BoardObject{Id="e1",Name="主圖層",Type="arrow",X=10,Y=10,Width=100,Height=80,X1=110,Y1=10,X2=10,Y2=90,StrokeColor="#EF4444",Extension="end"},new BoardObject{Id="e2",Type="text",X=20,Y=120,Width=300,Height=50,Text="中文 <b>文字</b>",RichTextSpans=[new TextSpan{Text="中文 ",IsBold=true,Color="#16A34A"},new TextSpan{Text="<b>文字</b>",IsUnderline=true}]},new BoardObject{Id="e3",Type="tape",X=30,Y=200,Width=120,Height=40,IsRevealed=true,StrokeColor="#F59E0B"},new BoardObject{Id="e4",Type="circle",X=400,Y=30,Width=80,Height=60}]};
var exportArea=BoardExporter.Bounds(exportDoc.Board,exportDoc.Objects);Check(exportArea.Width>450&&exportArea.Height>200,"Full export bounds include content outside viewport");
var svg=BoardExporter.Svg(exportDoc,exportDoc.Objects,exportArea);var xml=System.Xml.Linq.XDocument.Parse(svg);Check(xml.Root?.Name.LocalName=="svg","SVG is well formed XML");Check(svg.Contains("&lt;script&gt;中文 &amp; 標題&lt;/script&gt;")&&!svg.Contains("<script>中文"),"Export titles escape markup");Check(svg.Contains("&lt;b&gt;文字&lt;/b&gt;"),"Rich text remains literal, not HTML injection");Check(svg.Contains("foreignObject")&&svg.Contains("font-weight:bold"),"SVG contains rich text formatting");Check(svg.Contains(".12")&&svg.Contains("5 4"),"Revealed tape exports faint fill and outline");
var html=BoardExporter.Html(exportDoc,exportDoc.Objects,exportArea);Check(html.Contains("id=\"heiban-data\"")&&html.Contains("\\u003cscript\\u003e",StringComparison.OrdinalIgnoreCase),"HTML preserves editable JSON without closing script injection");Check(html.Contains("Content-Security-Policy")&&html.Contains("img-src data:"),"HTML uses embedded media and no remote resources");
Check(BoardExporter.Bounds(new BoardMetadata{CanvasMode="fixed",CanvasWidth=595,CanvasHeight=842},exportDoc.Objects).Width==595,"Fixed canvas exports paper dimensions");
var cropped=new BoardObject{Type="image",OriginalWidth=800,OriginalHeight=600,Width=100,Height=150,CropX=200,CropY=100,CropWidth=200,CropHeight=300,ImageUrl="data:image/png;base64,AA=="};var croppedSvg=BoardExporter.Svg(exportDoc,new[]{cropped},new(0,0,300,300));Check(croppedSvg.Contains("viewBox=\"200 100 200 300\""),"SVG uses original-pixel crop rectangle");
var teachingDoc=new HeiBanDocument{Objects=[new BoardObject{Type="stroke",BrushKind="calligraphy",Name="鋼筆"},new BoardObject{Type="tape",IsRevealed=true,TapeStyle="striped"}]};var teachingRoundTrip=DocumentCodec.Decode(DocumentCodec.Encode(teachingDoc));Check(teachingRoundTrip.Objects[0].BrushKind=="calligraphy"&&teachingRoundTrip.Objects[1].IsRevealed==true,"Mac brush and tape fields round trip");
var upgradedToolbar=new ToolbarPreferences{VisibleTools=["select","pen"],HiddenTools=[]};upgradedToolbar.Normalize();Check(new[]{"laser","tape","lasso","extension","clearAll","viewLock"}.All(upgradedToolbar.HiddenTools.Contains),"Existing toolbar preferences receive new tools in More");
var customTimer=new TimerCoordinator();customTimer.SetCountdownDuration(73);customTimer.Mode=TimerMode.Countdown;customTimer.Start();customTimer.UpdateDisplayTimes(73);Check(customTimer.Status==TimerStatus.TimesUp,"Custom countdown reaches requested duration");
var minimumPdf=System.Text.Encoding.ASCII.GetBytes("%PDF-1.7\n1 0 obj\n<< /Type /Catalog >>\nendobj\nxref\n0 2\n0000000000 65535 f \n0000000009 00000 n \ntrailer\n<< /Size 2 /Root 1 0 R >>\nstartxref\n50\n%%EOF\n");
var attached=PdfDocumentAttachment.Append(minimumPdf,exportDoc);var attachmentText=System.Text.Encoding.ASCII.GetString(attached);
Check(attached.Take(minimumPdf.Length).SequenceEqual(minimumPdf),"PDF attachment preserves original vector payload");
Check(attachmentText.EndsWith("%%EOF\n",StringComparison.Ordinal)&&attachmentText.Contains("/Prev 50"),"PDF attachment finishes a valid incremental trailer");
var marker=attachmentText.Split("%HeiBanDocumentJSON-START%\n")[1].Split("\n%HeiBanDocumentJSON-END%")[0];Check(DocumentCodec.Decode(System.Text.Encoding.UTF8.GetString(Convert.FromBase64String(marker))).Objects.Count==4,"PDF attachment uses Mac editable payload contract");
var lastXref=long.Parse(System.Text.RegularExpressions.Regex.Matches(attachmentText,@"startxref\s+(\d+)")[^1].Groups[1].Value);Check(attachmentText[(int)lastXref..].StartsWith("xref\n",StringComparison.Ordinal),"PDF incremental xref uses exact byte offsets");
var ray=new BoardObject{Type="line",X1=0,Y1=0,X2=100,Y2=0,X=0,Y=0,Width=100,Height=0,Extension="end",StrokeWidth=2};Check(VectorMath.IsPointInObject(new InkPoint(300,0),ray,2)&&!VectorMath.IsPointInObject(new InkPoint(-300,0),ray,2),"Ray hit testing respects allowed extension direction");
Check(LayerPresentation.Build(new[]{new BoardObject{Type="rect",IsVisible=false}})[0].Description.Contains("已隱藏"),"Hidden layers have a readable visibility indicator");
// Mac 1.0.12 text-only batch commands must preserve mixed values and future-format data.
var batchText=new EditorSession();var future=System.Text.Json.JsonSerializer.SerializeToElement(new{revision="future"});
var textOne=new BoardObject{Id="t1",Type="text",Text="中文\n多行",FontSize=24,StrokeColor="#ef4444",Opacity=.4,IsItalic=true,PageId="p1",ExtraFields=new(){["futureText"]=future},RichTextSpans=[new TextSpan{Text="中文",Color="#22c55e",IsItalic=true,HighlightColor="#ff00ff",ExtraFields=new(){["futureSpan"]=future}}]};
var textTwo=new BoardObject{Id="t2",Type="sticky",FontSize=48,StrokeColor="#3b82f6",Opacity=.8,PageId="p1"};
var textLocked=new BoardObject{Id="tl",Type="text",IsLocked=true,PageId="p1"};var textShape=new BoardObject{Id="ts",Type="rect",PageId="p1"};var textOtherPage=new BoardObject{Id="tp",Type="text",PageId="p2"};
batchText.Open(new HeiBanDocument{Board=new BoardMetadata{CanvasMode="notebook",ActivePageId="p1"},Objects=[textOne,textTwo,textLocked,textShape,textOtherPage]});batchText.SetSelection(new[]{"t1","t2","tl","ts","tp"});
Check(TextStyles.ApplySelection(batchText,new(Bold:true)),"Text batch changes commit");
Check(textOne.IsBold==true&&textTwo.IsBold==true,"Text and sticky receive batch bold");
Check(textLocked.IsBold!=true&&textShape.IsBold!=true&&textOtherPage.IsBold!=true,"Text command protects locks, non-text and other pages");
Check(textOne.FontSize==24&&textTwo.FontSize==48&&textOne.Opacity==.4&&textTwo.Opacity==.8,"Only requested fields change; mixed sizes and opacity survive");
Check(textOne.RichTextSpans![0].IsBold==true&&textOne.RichTextSpans[0].IsItalic==true&&textOne.RichTextSpans[0].HighlightColor=="#ff00ff","Rich text formatting updates without losing unrelated attributes");
Check(textOne.ExtraFields!["futureText"].GetProperty("revision").GetString()=="future"&&textOne.RichTextSpans[0].ExtraFields!["futureSpan"].GetProperty("revision").GetString()=="future","Text and span unknown fields survive");
batchText.Undo();Check(batchText.Document.Objects.Where(o=>o.Id is "t1" or "t2").All(o=>o.IsBold!=true)&&!batchText.CanUndo,"Entire text batch is one undo");
batchText.SetSelection(new[]{"t1","t2","tl","ts"});TextStyles.ApplySelection(batchText,new(Color:"#a855f7",Size:144,Align:"center"));
var changedText=batchText.Document.Objects.First(o=>o.Id=="t1");Check(changedText.StrokeColor=="#a855f7"&&changedText.RichTextSpans![0].Color=="#a855f7","Base and rich text colors agree");
Check(changedText.Height>=144*1.35*2&&changedText.Align=="center","Large multiline text expands conservatively");
Check(batchText.Document.Objects.First(o=>o.Id=="ts").StrokeColor!="#a855f7","Mixed shape selection remains untouched by text colors");
var generationBefore=batchText.Generation;TextStyles.ApplySelection(batchText,new());Check(batchText.Generation==generationBefore,"Empty delta adds no history");
var invalidBefore=DocumentCodec.Encode(batchText.Document);TextStyles.ApplySelection(batchText,new(Size:double.NaN,Bold:true));Check(DocumentCodec.Encode(batchText.Document)==invalidBefore,"Invalid numeric style is rejected atomically");
var scaledText=new BoardObject{Type="text",Text="Hi",FontSize=48};TextStyles.Apply(scaledText,new(Size:12),2);Near(scaledText.FontSize!.Value,24,"Screen text menu uses logical points at 200 percent DPI");
TextStyles.Apply(scaledText,new(Size:500,Opacity:0));Check(scaledText.FontSize==144&&scaledText.Opacity==.05,"Text style values clamp to Mac limits");
TextStyles.Apply(scaledText,new(Color:"invalid",Family:"",Align:"other"));Check(scaledText.StrokeColor!="invalid"&&scaledText.Align=="left","Malformed custom fields cannot corrupt styles");
Check(TextStyles.ValidColor("#Aa03fF")&&!TextStyles.ValidColor("#123")&&!TextStyles.ValidColor("#1234567"),"Custom text color validates exact hexadecimal form");

// Snapshot isolation and transient drags protect serialized artwork and undo while removing JSON from pointer updates.
var fullSnapshot=new HeiBanDocument{ExtraFields=new(){["rootFuture"]=future},Board=new BoardMetadata{Pages=[new BoardPage{Title="one",ExtraFields=new(){["pageFuture"]=future}}],Pins=[new BoardPin{Name="pin",ExtraFields=new(){["pinFuture"]=future}}],CollaboratorIds=["owner"],MemberRoles=new(){["owner"]="editor"},ExtraFields=new(){["boardFuture"]=future}},Objects=[new BoardObject{Type="text",Text="中文",ImageUrl=new string('A',100000),RichTextSpans=[new TextSpan{Text="中文",IsBold=true,ExtraFields=new(){["spanFuture"]=future}}],ExtraFields=new(){["objectFuture"]=future}}]};
var snapshotCopy=DocumentCodec.Clone(fullSnapshot);Check(DocumentCodec.Encode(fullSnapshot)==DocumentCodec.Encode(snapshotCopy)&&DocumentSnapshot.Same(fullSnapshot,snapshotCopy),"Fast snapshots preserve every serialized field");
Check(ReferenceEquals(fullSnapshot.Objects[0].ImageUrl,snapshotCopy.Objects[0].ImageUrl),"Immutable image payload is shared without copying bytes");
snapshotCopy.Board.Pages![0].Title="changed";snapshotCopy.Board.Pins![0].X=45;snapshotCopy.Board.CollaboratorIds![0]="other";snapshotCopy.Board.MemberRoles!["owner"]="viewer";snapshotCopy.Objects[0].RichTextSpans![0].IsBold=false;snapshotCopy.Objects[0].ExtraFields!.Remove("objectFuture");snapshotCopy.ExtraFields!.Clear();
Check(fullSnapshot.Board.Pages![0].Title=="one"&&fullSnapshot.Board.Pins![0].X==0&&fullSnapshot.Board.CollaboratorIds![0]=="owner"&&fullSnapshot.Board.MemberRoles!["owner"]=="editor","Snapshot collections and child models cannot mutate the original board");
Check(fullSnapshot.Objects[0].RichTextSpans![0].IsBold==true&&fullSnapshot.Objects[0].ExtraFields!.ContainsKey("objectFuture")&&fullSnapshot.ExtraFields!.Count==1,"Snapshot rich text and unknown dictionaries are isolated");
Check(!DocumentSnapshot.Same(fullSnapshot,snapshotCopy),"Structural comparison sees nested mutations");
var previewPoints=new[]{new InkPoint(0,0,.8){TiltX=12,TiltY=-3,ExtraFields=new(){["pointFuture"]=future}},new InkPoint(100,50,.9)};
var previewStroke=new BoardObject{Id="drag-stroke",Type="stroke",X=0,Y=0,Width=100,Height=50,Rotation=37,Points=System.Text.Json.JsonSerializer.Serialize(previewPoints,DocumentCodec.Options),PageId="p1"};
var lockedPreview=new BoardObject{Id="drag-locked",Type="rect",X=20,IsLocked=true,PageId="p1"};
var outsidePreview=new BoardObject{Id="drag-other",Type="rect",X=30,PageId="p2"};
var dragSession=new EditorSession();dragSession.Open(new(){Board=new BoardMetadata{CanvasMode="notebook",ActivePageId="p1",Revision=5},Objects=[previewStroke,lockedPreview,outsidePreview]});dragSession.SetSelection(new[]{"drag-stroke","drag-locked","drag-other"});var storedPoints=previewStroke.Points;var timestamp=previewStroke.UpdatedAt;
for(var i=0;i<80;i++)dragSession.PreviewMoveSelection(1,.5);
Check(ReferenceEquals(storedPoints,previewStroke.Points)&&previewStroke.UpdatedAt==timestamp,"Pointer drag does not rewrite points or timestamps");Near(previewStroke.X,80,"Drag bounds move immediately");Near(previewStroke.PreviewOffsetX,80,"Render uses the accumulated transient offset");
Near(lockedPreview.X,20,"Preview protects locked objects");Near(outsidePreview.X,30,"Preview protects other pages");
Check(VectorMath.IsPointInObject(ObjectHandles.ToWorld(previewStroke,new(80,40)),previewStroke,2),"Rotated stroke remains hittable during transient movement");
Check(!DocumentCodec.Encode(dragSession.Document).Contains("previewOffset",StringComparison.Ordinal),"Transient offsets never enter the file schema");
dragSession.Commit();Near(previewStroke.ParsedPoints[0].X,80,"Point coordinates commit only at pointer release");Near(previewStroke.ParsedPoints[0].Y,40,"Committed Y offset is exact");
Check(previewStroke.PreviewOffsetX==0&&previewStroke.ParsedPoints[0].Pressure==.8&&previewStroke.ParsedPoints[0].TiltX==12&&previewStroke.ParsedPoints[0].ExtraFields!.ContainsKey("pointFuture"),"Committed points retain pressure, tilt and future fields");
dragSession.Undo();Check(dragSession.Document.Objects[0].Points==storedPoints&&!dragSession.CanUndo,"An entire drag is one undo");dragSession.Redo();Near(dragSession.Document.Objects[0].ParsedPoints[0].X,80,"Redo restores committed absolute points");
dragSession.SelectedId="drag-stroke";var originalDrag=DocumentCodec.Encode(dragSession.Document);dragSession.PreviewMoveSelection(40,20);dragSession.MarkSaved(dragSession.Generation,8);dragSession.Cancel();Check(dragSession.Document.Objects[0].X==80&&dragSession.Document.Objects[0].PreviewOffsetX==0&&dragSession.Document.Board.Revision==8,"Cancel restores geometry without discarding a completed save revision");
var unchangedGeneration=dragSession.Generation;dragSession.Begin();dragSession.Commit();dragSession.PreviewMoveSelection(0,0);dragSession.PreviewMoveSelection(double.NaN,0);Check(dragSession.Generation==unchangedGeneration&&!dragSession.HasTransaction,"No-op and nonfinite movement add no transaction");
var snapshotSession=new EditorSession();snapshotSession.Open(DocumentCodec.Clone(fullSnapshot));snapshotSession.Begin();snapshotSession.Document.Objects[0].RichTextSpans![0].IsBold=false;snapshotSession.Commit();snapshotSession.Undo();Check(snapshotSession.Document.Objects[0].RichTextSpans![0].IsBold==true&&snapshotSession.Document.ExtraFields!.ContainsKey("rootFuture"),"Snapshot undo restores rich text and future root fields");snapshotSession.Redo();Check(snapshotSession.Document.Objects[0].RichTextSpans![0].IsBold==false,"Snapshot redo is isolated from subsequent edits");
var cappedHistory=new EditorSession();cappedHistory.Open(new());for(var i=0;i<70;i++){cappedHistory.Begin();cappedHistory.Document.Board.Title=i.ToString();cappedHistory.Commit();}var undoCount=0;while(cappedHistory.CanUndo){cappedHistory.Undo();undoCount++;}Check(undoCount==64,"Fast snapshot history retains the transaction-count cap");
var epochBefore=cappedHistory.DocumentEpoch;cappedHistory.Open(new());Check(cappedHistory.DocumentEpoch>epochBefore,"Open invalidates pending saves and thumbnails by epoch");
var saveRace=new EditorSession();saveRace.Open(new());saveRace.Begin();saveRace.MarkSaved(0,7);saveRace.Commit();Check(saveRace.Generation==0&&!saveRace.CanUndo,"Completed background save revision does not create a fake undo");
var pointCacheOriginal=new BoardObject{Points=storedPoints};_ = pointCacheOriginal.ParsedPoints;var pointCacheCopy=DocumentCodec.Clone(pointCacheOriginal);pointCacheCopy.ParsedPoints[0].X=999;Check(pointCacheOriginal.ParsedPoints[0].X==0,"Snapshots do not share mutable parsed-point caches");
// Cursor-anchored zoom is independent of the modifier keys and obeys zoom limits.
foreach(var zoom in new[]{.05,.4,1d,7.9,8d})
foreach(var delta in new[]{-240d,-120d,15d,120d,240d})
{
    var view=new ViewportTransform{X=-430,Y=123,Zoom=zoom};var cursor=new InkPoint(619,377);var anchor=view.ScreenToWorld(cursor.X,cursor.Y);
    view.ZoomAt(cursor.X,cursor.Y,delta);Point(view.WorldToScreen(anchor.X,anchor.Y),cursor,"Wheel zoom keeps the world point under the cursor");Check(view.Zoom>=.05&&view.Zoom<=8,"Wheel respects zoom limits");
}
var enclosed=new BoardObject{Type="rect",X=2,Y=2,Width=6,Height=6,StrokeWidth=1};
Check(WindowSelection.Matches(enclosed,new(0,0),new(10,10)),"Left-to-right window includes an enclosed object");
Check(!WindowSelection.Matches(enclosed,new(0,0),new(5,10)),"Left-to-right window excludes a partial object");
Check(WindowSelection.Matches(enclosed,new(5,0),new(0,10)),"Right-to-left crossing includes a touched object");
Check(!WindowSelection.Matches(enclosed,new(20,0),new(15,10)),"Crossing excludes a distant object");
var longLine=new BoardObject{Type="line",StrokeWidth=0};ObjectHandles.SetEndpoints(longLine,new(-100,5),new(100,5));
Check(WindowSelection.Matches(longLine,new(10,0),new(0,10)),"Crossing finds a line whose endpoints are both outside");
Check(!WindowSelection.Matches(longLine,new(0,0),new(10,10)),"Window excludes a line whose endpoints are outside");
ObjectHandles.SetEndpoints(longLine,new(-100,10),new(100,10));Check(WindowSelection.Matches(longLine,new(10,0),new(0,10)),"Boundary tangency counts as touching");
ObjectHandles.SetEndpoints(longLine,new(0,0),new(100,100));Check(!WindowSelection.Matches(longLine,new(100,0),new(80,20)),"Empty diagonal bounding-box area does not select a line");
var shapeImage=new BoardObject{Type="image",X=0,Y=0,Width=100,Height=100,StrokeWidth=0};
Check(WindowSelection.Matches(shapeImage,new(60,40),new(40,60)),"Crossing inside an image selects its surface");
Check(!WindowSelection.Matches(shapeImage,new(40,40),new(60,60)),"Window inside an image does not select the larger image");
var hollow=new BoardObject{Type="rect",X=0,Y=0,Width=100,Height=100,StrokeWidth=1,FillColor="none"};
Check(!WindowSelection.Matches(hollow,new(60,40),new(40,60)),"Crossing entirely inside an unfilled rectangle misses the outline");
hollow.FillColor="#FF0000";Check(WindowSelection.Matches(hollow,new(60,40),new(40,60)),"Filled rectangle selects its occupied surface");
var circleSelection=new BoardObject{Type="circle",X=0,Y=0,Width=100,Height=100,StrokeWidth=0,FillColor="none"};
Check(!WindowSelection.Matches(circleSelection,new(5,0),new(0,5)),"Ellipse bounding-box corner remains unselected");
Check(WindowSelection.Matches(circleSelection,new(55,-1),new(45,1)),"Crossing detects the top of an ellipse");
var selectionArrow=new BoardObject{Type="arrow",StrokeWidth=0,ArrowHeadLength=20,ArrowHeadWidth=30};ObjectHandles.SetEndpoints(selectionArrow,new(0,50),new(100,50));
Check(WindowSelection.Matches(selectionArrow,new(86,62),new(78,68)),"Crossing includes arrow-head branches");
Check(!WindowSelection.Matches(selectionArrow,new(-1,49),new(101,51)),"Window must include the arrow head as well as its shaft");
var selectionRay=new BoardObject{Type="line",StrokeWidth=0,Extension="end"};ObjectHandles.SetEndpoints(selectionRay,new(0,5),new(10,5));
Check(WindowSelection.Matches(selectionRay,new(200,0),new(100,10)),"Crossing reaches the visible extension beyond A/B");
Check(!WindowSelection.Matches(selectionRay,new(-10,-10),new(300,300)),"An unbounded ray cannot be fully enclosed");
var hiddenSelection=DocumentCodec.Clone(enclosed);hiddenSelection.IsVisible=false;Check(!WindowSelection.Matches(hiddenSelection,new(0,0),new(10,10)),"Hidden objects cannot be window-selected");
var rotatedSelection=new BoardObject{Type="image",X=0,Y=0,Width=100,Height=10,Rotation=90};
Check(WindowSelection.Matches(rotatedSelection,new(40,-46),new(60,56)),"Containment uses the rotated image footprint");
Check(!WindowSelection.Matches(rotatedSelection,new(-1,-1),new(101,11)),"Unrotated bounds do not fully contain a rotated image");
var anchors=new List<InkPoint>{new(0,0)};var possible=CurvePreview.Points(anchors,new(100,100));Check(possible.Count==2&&anchors.Count==1,"First click provides a separate cursor preview without committing an anchor");
anchors.Add(new(100,100));possible=CurvePreview.Points(anchors,new(200,0));var flattened=CurvePreview.Flatten(possible);
Check(flattened.Count>3&&flattened.Any(p=>p.Y>95),"Second-click preview exposes the same Catmull-Rom curve as the final path");Point(flattened[0],anchors[0],"Curve preview starts at the first anchor");Point(flattened[^1],new(200,0),"Curve preview ends at the cursor");
var overshoot=CurvePreview.Flatten(new[]{new InkPoint(0,0),new InkPoint(100,0),new InkPoint(101,0)});Check(overshoot.Any(p=>p.X>101.1),"Collinear cubic overshoot is retained in selection geometry");
var curveSelection=new BoardObject{Type="curve",StrokeWidth=0,Points=System.Text.Json.JsonSerializer.Serialize(possible,DocumentCodec.Options)};
Check(WindowSelection.Matches(curveSelection,new(106,95),new(94,105)),"Crossing selects the actual cubic arc");
Check(!WindowSelection.Matches(curveSelection,new(110,-5),new(90,5)),"Crossing does not select empty space in a curve bounding box");
Check(!VectorMath.IsPointInObject(new(50,50),circleSelection,0),"Hollow ellipse center is blank space for starting a selection frame");
Check(!VectorMath.IsPointInObject(new(1,1),circleSelection,0),"Hollow ellipse bounding-box corner does not intercept selection");
Check(VectorMath.IsPointInObject(new(50,0),circleSelection,1),"Ellipse outline remains selectable");
hollow.FillColor="none";Check(!VectorMath.IsPointInObject(new(50,50),hollow,0),"Hollow rectangle center is blank space for a frame");
Check(VectorMath.IsPointInObject(new(0,50),hollow,0),"Hollow rectangle outline remains selectable");
Check(VectorMath.IsPointInObject(new(100,100),curveSelection,2),"Smoothed curve is selectable on its actual path");
Check(!VectorMath.IsPointInObject(new(100,50),curveSelection,0),"Curve control bounding box does not intercept empty-area selection");
foreach(var offset in new[]{new InkPoint(90,20),new InkPoint(-90,20),new InkPoint(20,90),new InkPoint(20,-90),new InkPoint(40,40)})
{
 var anchor=new InkPoint(-30,70);var cursor=new InkPoint(anchor.X+offset.X,anchor.Y+offset.Y,.8){TiltX=12,TiltY=-3};var constrained=ObjectHandles.ConstrainOrthogonal(anchor,cursor);
 Check(constrained.X==anchor.X||constrained.Y==anchor.Y,"Shift constrains the line to an orthogonal axis");
 Near(constrained.Pressure,.8,"Constraint keeps sample pressure");Near(constrained.TiltX!.Value,12,"Constraint keeps tilt");
 Check(cursor.X==anchor.X+offset.X&&cursor.Y==anchor.Y+offset.Y,"Constraint does not mutate the mouse sample");
}
// Order views must observe direct edits before a transaction commits, without changing stable ties.
var orderCache=new ObjectOrderCache();
var orderDoc=new HeiBanDocument{Board=new BoardMetadata{CanvasMode="notebook",ActivePageId="p1"},Objects=Enumerable.Range(0,80).Select(i=>new BoardObject{Id="order-"+i,Type="rect",Width=40,Height=40,FillColor="#39735A",ZIndex=i%7,PageId=i%5==0?"p2":i%3==0?null:"p1",IsVisible=i%11==0?false:null,IsLocked=i%4==0}).ToList()};
void CheckOrder(string reason)
{
 var visible=orderDoc.Objects.Where(o=>o.IsVisible!=false&&(orderDoc.Board.CanvasMode!="notebook"||o.PageId is null||o.PageId==orderDoc.Board.ActivePageId));
 Check(orderCache.Ascending(orderDoc).SequenceEqual(visible.OrderBy(o=>o.ZIndex)),"Cached drawing matches stable LINQ: "+reason);
 Check(orderCache.Descending(orderDoc).SequenceEqual(visible.OrderByDescending(o=>o.ZIndex)),"Cached hits match stable LINQ: "+reason);
}
CheckOrder("initial page");var orderBuilds=orderCache.Rebuilds;CheckOrder("warm reuse");Check(orderCache.Rebuilds==orderBuilds,"Unchanged order does not rebuild");
orderDoc.Objects[1].ZIndex=999;CheckOrder("direct ZIndex before commit");
orderDoc.Objects.Reverse();CheckOrder("same-size source reorder and ties");
orderDoc.Objects[1]=DocumentCodec.Clone(orderDoc.Objects[1]);CheckOrder("same-size object replacement");
orderDoc.Objects.Add(new BoardObject{Id="order-added",ZIndex=-10});CheckOrder("add");orderDoc.Objects.RemoveAt(2);CheckOrder("delete");
orderBuilds=orderCache.Rebuilds;orderDoc.Board.ActivePageId="p2";orderDoc.Objects[0].IsVisible=true;orderDoc.Objects[1].PageId="p2";CheckOrder("live page and visibility edits");Check(orderCache.Rebuilds==orderBuilds,"Page and visibility filtering do not allocate a new sorted view");
orderDoc.Board.CanvasMode="infinite";CheckOrder("mode switch");orderDoc.Objects=[..orderDoc.Objects];CheckOrder("list replacement");
orderDoc=DocumentCodec.Clone(orderDoc);CheckOrder("document replacement");orderCache.Clear();CheckOrder("clear");
var orderedSession=new EditorSession();orderedSession.Open(orderDoc);
void CheckOrderedSession(string reason)
{
 Check(orderedSession.DrawingObjects.SequenceEqual(orderedSession.VisibleObjects.OrderBy(o=>o.ZIndex)),"Session drawing: "+reason);
 Check(ReferenceEquals(orderedSession.Hit(new(10,10),8),orderedSession.VisibleObjects.OrderByDescending(o=>o.ZIndex).FirstOrDefault(o=>VectorMath.IsPointInObject(new(10,10),o))),"Session hit preserves locked objects and stable ties: "+reason);
}
CheckOrderedSession("open");orderedSession.Begin();orderedSession.Document.Objects[0].ZIndex=2000;CheckOrderedSession("transaction");orderedSession.Cancel();CheckOrderedSession("cancel");
orderedSession.Begin();orderedSession.Document.Objects[0].ZIndex=2000;orderedSession.Commit();CheckOrderedSession("commit");orderedSession.Undo();CheckOrderedSession("undo");orderedSession.Redo();CheckOrderedSession("redo");orderedSession.Open(new());CheckOrderedSession("empty switch");
var readonlySample=new InkPoint(10,10,.75){TiltX=12,TiltY=-3,ExtraFields=new(){["future"]=future}};
Check(VectorMath.IsPointInObject(readonlySample,new BoardObject{Type="rect",Width=20,Height=20,FillColor="#39735A"}),"Unrotated filled hit");
Check(readonlySample.X==10&&readonlySample.Y==10&&readonlySample.Pressure==.75&&readonlySample.TiltX==12&&readonlySample.ExtraFields!.ContainsKey("future"),"Hit does not mutate input or future sample fields");
foreach(var rotation in new[]{-180d,-90d,0d,25d,90d,180d})
{
 var rotatedHit=new BoardObject{Type="rect",X=10,Y=30,Width=40,Height=20,FillColor="#39735A",Rotation=rotation};
 Check(VectorMath.IsPointInObject(ObjectHandles.ToWorld(rotatedHit,new(30,40)),rotatedHit,0),"Rotated center hit "+rotation);
 Check(!VectorMath.IsPointInObject(ObjectHandles.ToWorld(rotatedHit,new(200,200)),rotatedHit,0),"Rotated distant miss "+rotation);
}
// Rendering broad phase must never reject a candidate that the original radius scan would draw.
var viewportCache=new ObjectViewportCache();var spatialOrder=new ObjectOrderCache();
var spatialDoc=new HeiBanDocument{Objects=Enumerable.Range(0,1000).Select(i=>new BoardObject
 {Id="spatial-test-"+i,Type="rect",X=i%40*180-3600,Y=i/40*180-2200,Width=20,Height=30,ZIndex=i%13}).ToList()};
var spatialRandom=new Random(107);
void CheckSpatial(VectorMath.RectBounds world,string reason)
{
 var ordered=spatialOrder.Ascending(spatialDoc);var candidates=viewportCache.Query(ordered,world).ToArray();var set=candidates.ToHashSet();
 Check(candidates.Distinct().Count()==candidates.Length,"No duplicated viewport candidate: "+reason);
 Check(candidates.SequenceEqual(ordered.Where(set.Contains)),"Viewport preserves stable global Z/page/visibility: "+reason);
 foreach(var item in ordered)
 {
  var radius=Math.Sqrt(item.Width*item.Width+item.Height*item.Height)/2+item.StrokeWidth+32;
  var cx=item.X+item.Width/2;var cy=item.Y+item.Height/2;
  if(item.Extension is "start" or "end" or "both"||world.Intersects(new(cx-radius,cy-radius,cx+radius,cy+radius)))
   Check(set.Contains(item),"Viewport contains legacy render candidate: "+reason);
 }
}
for(var i=0;i<160;i++)
{
 var x=spatialRandom.Next(-6000,6000);var y=spatialRandom.Next(-5000,5000);
 CheckSpatial(new(x,y,x+spatialRandom.Next(1,1500),y+spatialRandom.Next(1,1000)),"random "+i);
}
var spatialWorld=new VectorMath.RectBounds(-150,-150,650,550);
var spatialBuilds=viewportCache.Rebuilds;CheckSpatial(spatialWorld,"warm");Check(viewportCache.Rebuilds==spatialBuilds,"Unchanged geometry reuses grid");
spatialDoc.Objects[0].X=0;spatialDoc.Objects[0].Y=0;CheckSpatial(spatialWorld,"direct move before commit");
Check(viewportCache.Rebuilds==spatialBuilds&&viewportCache.Updates>0,"Direct geometry edits update memberships without a full rebuild");
spatialDoc.Objects[1].Width=900;spatialDoc.Objects[1].Height=300;spatialDoc.Objects[1].Rotation=75;CheckSpatial(spatialWorld,"resize rotation");
spatialDoc.Objects[2].StrokeWidth=500;CheckSpatial(spatialWorld,"stroke extent");
spatialDoc.Objects[3].Type="curve";spatialDoc.Objects[3].Points="[{\"x\":10,\"y\":10},{\"x\":80,\"y\":200}]";
spatialDoc.Objects[4].Type="text";spatialDoc.Objects[5].Extension="both";spatialDoc.Objects[6].Type="future-unknown";
spatialDoc.Objects[7].Width=100000;spatialDoc.Objects[8].X=double.NaN;spatialDoc.Objects[9].X=1e20;
CheckSpatial(spatialWorld,"global complex/oversized/nonfinite/huge");
spatialBuilds=viewportCache.Rebuilds;var spatialUpdates=viewportCache.Updates;CheckSpatial(spatialWorld,"stable NaN global");
Check(viewportCache.Rebuilds==spatialBuilds&&viewportCache.Updates==spatialUpdates,"Malformed NaN candidates do not invalidate each query");
var globals=viewportCache.Query(spatialOrder.Ascending(spatialDoc),spatialWorld).ToHashSet();
foreach(var i in new[]{3,4,5,6,7,8,9})Check(globals.Contains(spatialDoc.Objects[i]),"Unsafe bounds remain global "+i);
Check(viewportCache.MembershipCount<=spatialDoc.Objects.Count*16,"Membership budget is bounded per object");
spatialBuilds=viewportCache.Rebuilds;spatialDoc.Board.CanvasMode="notebook";spatialDoc.Board.ActivePageId="p1";
foreach(var item in spatialDoc.Objects){item.PageId=item.ZIndex%2==0?"p1":"p2";item.IsVisible=item.ZIndex%3==0?false:null;}
CheckSpatial(spatialWorld,"page visibility");spatialDoc.Board.ActivePageId="p2";CheckSpatial(spatialWorld,"page switch");
Check(viewportCache.Rebuilds==spatialBuilds,"Page/visibility changes use live filtering without grid rebuild");
spatialDoc.Objects[0].ZIndex=999;CheckSpatial(spatialWorld,"direct Z");spatialDoc.Objects.Reverse();CheckSpatial(spatialWorld,"reverse ties");
spatialDoc.Objects[1]=DocumentCodec.Clone(spatialDoc.Objects[2]);CheckSpatial(spatialWorld,"same-size replacement");
spatialDoc.Objects.Add(new(){Type="circle",X=150,Y=150,Width=100,Height=50});CheckSpatial(spatialWorld,"add");
spatialDoc.Objects.RemoveAt(20);CheckSpatial(spatialWorld,"remove");spatialDoc.Objects=[..spatialDoc.Objects];CheckSpatial(spatialWorld,"list replacement");
var spatialSession=new EditorSession();spatialSession.Open(spatialDoc);spatialSession.Begin();
spatialSession.Document.Objects[1].X=700;spatialDoc=spatialSession.Document;CheckSpatial(spatialWorld,"transaction move");
spatialSession.Cancel();spatialDoc=spatialSession.Document;CheckSpatial(spatialWorld,"cancel");
spatialSession.Begin();spatialSession.Document.Objects[1].X=0;spatialSession.Commit();CheckSpatial(spatialWorld,"commit");
spatialSession.Undo();spatialDoc=spatialSession.Document;CheckSpatial(spatialWorld,"undo");
spatialSession.Redo();spatialDoc=spatialSession.Document;CheckSpatial(spatialWorld,"redo");
spatialSession.Begin();spatialSession.SetSelection(new[]{spatialDoc.Objects[1].Id});spatialSession.PreviewMoveSelection(-200,-100);
CheckSpatial(spatialWorld,"preview selection move");spatialSession.Cancel();spatialDoc=spatialSession.Document;CheckSpatial(spatialWorld,"preview cancel");
CheckSpatial(new(double.NegativeInfinity,0,double.PositiveInfinity,500),"nonfinite query fallback");
var descendingSpatial=spatialOrder.Descending(spatialDoc);Check(ReferenceEquals(viewportCache.Query(descendingSpatial,spatialWorld),descendingSpatial),"Descending views use original scan");
spatialDoc=new(){Objects=[new(){Type="rect",Width=30,Height=20}]};CheckSpatial(spatialWorld,"small new document");
Check(viewportCache.CellCount==0&&viewportCache.MembershipCount==0,"Small document releases prior grid");
viewportCache.Clear();CheckSpatial(spatialWorld,"clear");
spatialDoc=new(){Objects=Enumerable.Range(0,600).Select(i=>new BoardObject{Type="rect",X=i*500+10000,Y=10000,Width=20,Height=30}).ToList()};
foreach(var type in new[]{"rect","circle","image","tape"})
{
 var item=spatialDoc.Objects[0];item.Type=type;item.Extension=null;item.X=20;item.Y=20;CheckSpatial(spatialWorld,"indexed type "+type);
 Check(viewportCache.Query(spatialOrder.Ascending(spatialDoc),spatialWorld).Contains(item),"Indexed type is admitted in viewport "+type);
 item.X=10000;item.Y=10000;CheckSpatial(spatialWorld,"indexed type moved out "+type);
 Check(!viewportCache.Query(spatialOrder.Ascending(spatialDoc),spatialWorld).Contains(item),"Indexed type is removed outside viewport "+type);
 item.Extension="both";CheckSpatial(spatialWorld,"indexed type becomes global "+type);
 Check(viewportCache.Query(spatialOrder.Ascending(spatialDoc),spatialWorld).Contains(item),"Extension mutation updates global candidates "+type);
}
var counterDoc=new HeiBanDocument{Objects=[new(){Type="rect",X=2,Y=3,Width=20,Height=30,ExtraFields=new(){["future"]=future}}]};
var beforeCounter=DocumentCodec.Clone(counterDoc);counterDoc.Objects[0].X=99;counterDoc.Objects[0].X=2;
Check(DocumentSnapshot.Same(beforeCounter,counterDoc),"Transient invalidation does not change document equality or undo contract");
var counterJson=DocumentCodec.Encode(counterDoc);
Check(!counterJson.Contains("RenderBoundsVersion",StringComparison.OrdinalIgnoreCase),"Render counter is absent from persisted JSON");
Check(DocumentCodec.Decode(counterJson).Objects[0].ExtraFields!.ContainsKey("future"),"Bounds tracking preserves future fields after reopen");
counterDoc.Objects[0].X=-0d;Check(double.IsNegative(counterDoc.Objects[0].X),"Tracked setter preserves supplied signed zero");
if(args.Contains("--performance"))Console.WriteLine(System.Text.Json.JsonSerializer.Serialize(InteractionBenchmark.Run(),new System.Text.Json.JsonSerializerOptions{WriteIndented=true}));

if(args.Length==2&&args[0]=="--export-fixtures")
{
    Directory.CreateDirectory(args[1]);File.WriteAllText(Path.Combine(args[1],"parity-demo.heiban"),DocumentCodec.Encode(exportDoc));File.WriteAllText(Path.Combine(args[1],"parity-demo.svg"),svg);File.WriteAllText(Path.Combine(args[1],"parity-demo.html"),html);
}

Console.WriteLine($"PASS: {checks} Windows interaction geometry, screenshot coordinator, calculator, compass/arc, timer & offline guide checks");


