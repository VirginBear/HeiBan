using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.Graphics.Canvas.UI.Xaml;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;
using Microsoft.UI.Xaml.Media;
using global::Windows.ApplicationModel.DataTransfer;
using global::Windows.Foundation;
using global::Windows.UI;
using static HeiBan.Windows.Localization.Strings;
namespace HeiBan.Windows.Views;

// Non-modal: a ContentDialog would block the toolbar which supplies the drag source.
internal sealed class RadialWheelSettingsWindow : Window
{
    internal const string DragFormat="HeiBan.RadialToolKey.v1";
    private readonly RadialToolProfile _profile;
    private readonly bool _screen;
    private readonly Func<Task> _save;
    private readonly CanvasControl _canvas=new(){Width=320,Height=320,AllowDrop=true};
    private readonly Direct2DCanvasRenderer _renderer=new();
    private readonly TextBlock _status=new(){TextWrapping=TextWrapping.Wrap,MaxWidth=610,Foreground=new SolidColorBrush(Color.FromArgb(255,57,115,90))};
    private readonly List<Button> _slotButtons=[];
    private readonly Button _presetButton=new(){MinWidth=240,Height=36,HorizontalContentAlignment=HorizontalAlignment.Stretch,Padding=new Thickness(10,4,10,4)};
    private readonly TextBox _presetNameBox=new(){Width=168,PlaceholderText=T("輸入組合名稱…"),MaxLength=40};
    private readonly Button _deletePresetButton=new(){Height=34,Padding=new Thickness(10,4,10,4)};
    private bool _closed;
    private int _hover=-1;
    private readonly string[] _keys;
    internal nint Handle=>WinRT.Interop.WindowNative.GetWindowHandle(this);

    internal RadialWheelSettingsWindow(RadialToolProfile profile,bool screen,Func<Task> save)
    {
        _profile=profile;_screen=screen;_save=save;
        Title=T("右鍵工具輪盤")+" · "+T(screen?"螢幕畫布":"畫布");
        _keys=new[]{""}.Concat(ToolbarPreferences.AllDefaultTools).Concat(new[]{"line","arrow","rect","circle","triangle","quadrilateral","diamond","pentagon","star"}).Where(k=>k==""||RadialToolProfile.Allowed(k,screen)).Distinct().ToArray();

        var root=new StackPanel
        {
            FlowDirection=RightToLeft?FlowDirection.RightToLeft:FlowDirection.LeftToRight,
            Spacing=12,
            Padding=new Thickness(18),
            RequestedTheme=ElementTheme.Light,
            Background=new SolidColorBrush(Color.FromArgb(255,247,250,246))
        };
        root.Children.Add(new TextBlock{Text=T("右鍵工具輪盤"),FontSize=22,FontWeight=Microsoft.UI.Text.FontWeights.SemiBold});
        root.Children.Add(new TextBlock{Text=T("將上方工具列的圖示拖到輪盤格子，或點選格子／右側圖示選單挑選工具；亦可儲存與切換常用組合。"),TextWrapping=TextWrapping.Wrap,MaxWidth=610,Foreground=new SolidColorBrush(Color.FromArgb(255,82,102,91))});

        // Preset management card (select existing preset, save custom preset, delete preset)
        var presetCard=new Border
        {
            Background=new SolidColorBrush(Color.FromArgb(255,238,244,238)),
            BorderBrush=new SolidColorBrush(Color.FromArgb(90,116,156,141)),
            BorderThickness=new Thickness(1),
            CornerRadius=new CornerRadius(10),
            Padding=new Thickness(12,10,12,10)
        };
        var presetStack=new StackPanel{Spacing=8};

        var presetTopRow=new StackPanel{Orientation=Orientation.Horizontal,Spacing=8,VerticalAlignment=VerticalAlignment.Center};
        presetTopRow.Children.Add(new TextBlock{Text=T("輪盤組合"),FontWeight=Microsoft.UI.Text.FontWeights.SemiBold,VerticalAlignment=VerticalAlignment.Center,MinWidth=64});
        _presetButton.Click+=(_,_)=>ShowPresetPicker(_presetButton);
        presetTopRow.Children.Add(_presetButton);

        var resetBtn=CreateIconTextButton("radial",T("預設"));
        resetBtn.Click+=async(_,_)=>
        {
            _profile.Reset(screen);
            _presetNameBox.Text="";
            await SaveAsync(T("已還原預設輪盤組合"));
        };
        presetTopRow.Children.Add(resetBtn);
        presetStack.Children.Add(presetTopRow);

        var presetSaveRow=new StackPanel{Orientation=Orientation.Horizontal,Spacing=8,VerticalAlignment=VerticalAlignment.Center};
        presetSaveRow.Children.Add(new TextBlock{Text=T("儲存新組合"),VerticalAlignment=VerticalAlignment.Center,MinWidth=64,Foreground=new SolidColorBrush(Color.FromArgb(255,82,102,91))});
        presetSaveRow.Children.Add(_presetNameBox);

        var savePresetBtn=CreateIconTextButton("save",T("儲存組合"));
        savePresetBtn.Click+=async(_,_)=>
        {
            var name=_presetNameBox.Text.Trim();
            if(string.IsNullOrEmpty(name))
            {
                var idx=_profile.Presets.Count+1;
                while(_profile.Presets.Any(p=>string.Equals(p.Name,$"{T("自訂組合")} {idx}",StringComparison.OrdinalIgnoreCase)))idx++;
                name=$"{T("自訂組合")} {idx}";
                _presetNameBox.Text=name;
            }
            if(_profile.SavePreset(name,screen) is not null)
                await SaveAsync($"{T("已儲存輪盤組合")}：{name}");
        };
        presetSaveRow.Children.Add(savePresetBtn);

        _deletePresetButton.Content=CreateIconTextContent("delete",T("刪除組合"));
        _deletePresetButton.Click+=async(_,_)=>
        {
            var target=!string.IsNullOrWhiteSpace(_presetNameBox.Text)?_presetNameBox.Text.Trim():_profile.ActivePreset;
            if(_profile.DeletePreset(target))
            {
                _presetNameBox.Text="";
                await SaveAsync($"{T("已刪除輪盤組合")}：{target}");
            }
        };
        presetSaveRow.Children.Add(_deletePresetButton);
        presetStack.Children.Add(presetSaveRow);

        presetCard.Child=presetStack;
        root.Children.Add(presetCard);

        // Main body: left radial wheel preview + right 8 icon-picker slot buttons
        var body=new StackPanel{FlowDirection=FlowDirection.LeftToRight,Orientation=Orientation.Horizontal,Spacing=16,VerticalAlignment=VerticalAlignment.Top};
        body.Children.Add(_canvas);

        var options=new StackPanel{FlowDirection=RightToLeft?FlowDirection.RightToLeft:FlowDirection.LeftToRight,Spacing=6,Width=272};
        for(var i=0;i<RadialToolProfile.Count;i++)
        {
            var slot=i;
            var row=new StackPanel{Orientation=Orientation.Horizontal,Spacing=8,VerticalAlignment=VerticalAlignment.Center};
            var badge=new Border
            {
                Width=24,Height=24,CornerRadius=new CornerRadius(12),
                Background=new SolidColorBrush(Color.FromArgb(255,222,235,226)),
                Child=new TextBlock{Text=(i+1).ToString(),FontSize=12,FontWeight=Microsoft.UI.Text.FontWeights.SemiBold,HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center,Foreground=new SolidColorBrush(Color.FromArgb(255,40,84,63))}
            };
            row.Children.Add(badge);

            var slotBtn=new Button
            {
                Width=238,
                Height=36,
                IsEnabled=!(screen&&i==7),
                HorizontalContentAlignment=HorizontalAlignment.Stretch,
                Padding=new Thickness(10,4,10,4),
                CornerRadius=new CornerRadius(8)
            };
            slotBtn.Click+=(_,_)=>ShowSlotToolPicker(slot,slotBtn);
            slotBtn.PointerEntered+=(_,_)=>{if(_hover!=slot){_hover=slot;_canvas.Invalidate();}};
            slotBtn.PointerExited+=(_,_)=>{if(_hover==slot){_hover=-1;_canvas.Invalidate();}};
            row.Children.Add(slotBtn);
            options.Children.Add(row);
            _slotButtons.Add(slotBtn);
        }
        body.Children.Add(options);
        root.Children.Add(body);
        root.Children.Add(_status);

        Content=new ScrollViewer{Content=root,HorizontalScrollBarVisibility=ScrollBarVisibility.Auto,VerticalScrollBarVisibility=ScrollBarVisibility.Auto};
        var scale=ScreenAnnotation.NativeOverlayWindow.DpiScale(Handle);
        var area=Microsoft.UI.Windowing.DisplayArea.GetFromWindowId(AppWindow.Id,Microsoft.UI.Windowing.DisplayAreaFallback.Nearest).WorkArea;
        AppWindow.Resize(new global::Windows.Graphics.SizeInt32(Math.Min(area.Width-24,(int)(680*scale)),Math.Min(area.Height-24,(int)(660*scale))));
        if(AppWindow.Presenter is Microsoft.UI.Windowing.OverlappedPresenter presenter){presenter.IsAlwaysOnTop=true;presenter.IsResizable=false;presenter.IsMaximizable=false;}

        _canvas.Draw+=(_,args)=>_renderer.RenderRadialWheel(args.DrawingSession,_profile,new InkPoint(160,160),_hover);
        _canvas.CreateResources+=(_,_)=>_renderer.ClearCache();
        _canvas.PointerMoved+=(_,args)=>
        {
            var hit=HitSlot(args.GetCurrentPoint(_canvas).Position);
            if(hit!=_hover){_hover=hit;_canvas.Invalidate();}
        };
        _canvas.PointerExited+=(_,_)=>{if(_hover!=-1){_hover=-1;_canvas.Invalidate();}};
        _canvas.PointerPressed+=(_,args)=>
        {
            var hit=HitSlot(args.GetCurrentPoint(_canvas).Position);
            if(hit>=0&&!(screen&&hit==7)&&hit<_slotButtons.Count)
                ShowSlotToolPicker(hit,_slotButtons[hit]);
        };
        _canvas.DragOver+=(_,args)=>
        {
            var p=args.GetPosition(_canvas);_hover=HitSlot(p);
            var allowed=args.DataView.Contains(DragFormat)&&_hover>=0&&!(screen&&_hover==7);
            if(!allowed)_hover=-1;args.AcceptedOperation=allowed?DataPackageOperation.Copy:DataPackageOperation.None;_canvas.Invalidate();args.Handled=true;
        };
        _canvas.DragLeave+=(_,_)=>{_hover=-1;_canvas.Invalidate();};
        _canvas.Drop+=async(_,args)=>
        {
            args.Handled=true;var p=args.GetPosition(_canvas);var index=HitSlot(p);var deferral=args.GetDeferral();
            try
            {
                if(!args.DataView.Contains(DragFormat))return;
                if(await args.DataView.GetDataAsync(DragFormat) is string key&&_profile.Assign(index,key,screen))await SaveAsync();
                else _status.Text=T("這一格不能放入此工具。");
            }
            catch(Exception error){if(!_closed)_status.Text=T("輪盤設定尚未保存：")+error.Message;}
            finally{deferral.Complete();_hover=-1;if(!_closed)_canvas.Invalidate();}
        };
        Closed+=(_,_)=>{_closed=true;_canvas.RemoveFromVisualTree();_renderer.Dispose();};
        RefreshSlots();
    }

    private static Button CreateIconTextButton(string iconKey,string text)
    {
        return new Button
        {
            Height=34,
            Padding=new Thickness(10,4,10,4),
            Content=CreateIconTextContent(iconKey,text)
        };
    }

    private static StackPanel CreateIconTextContent(string iconKey,string text)
    {
        var row=new StackPanel{Orientation=Orientation.Horizontal,Spacing=6,VerticalAlignment=VerticalAlignment.Center};
        row.Children.Add(ToolIcons.Create(iconKey));
        row.Children.Add(new TextBlock{Text=text,FontSize=12,VerticalAlignment=VerticalAlignment.Center});
        return row;
    }

    private static UIElement CreateSlotButtonContent(string key,bool locked)
    {
        var grid=new Grid{ColumnSpacing=8,VerticalAlignment=VerticalAlignment.Center};
        grid.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(22)});
        grid.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(1,GridUnitType.Star)});
        grid.ColumnDefinitions.Add(new ColumnDefinition{Width=GridLength.Auto});

        var icon=ToolIcons.Create(key);
        if(string.IsNullOrEmpty(key))icon.Opacity=0.45;
        var iconHost=new Border{Width=22,Height=22,Child=icon,HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center};
        Grid.SetColumn(iconHost,0);
        grid.Children.Add(iconHost);

        var labelText=string.IsNullOrEmpty(key)?T("空"):Direct2DCanvasRenderer.RadialLabel(key);
        var label=new TextBlock
        {
            Text=labelText,
            FontSize=13,
            VerticalAlignment=VerticalAlignment.Center,
            TextTrimming=TextTrimming.CharacterEllipsis,
            Foreground=new SolidColorBrush(string.IsNullOrEmpty(key)?Color.FromArgb(160,90,105,96):Color.FromArgb(255,34,54,44))
        };
        Grid.SetColumn(label,1);
        grid.Children.Add(label);

        var arrow=new TextBlock
        {
            Text=locked?"":("▾"),
            FontSize=11,
            VerticalAlignment=VerticalAlignment.Center,
            Foreground=new SolidColorBrush(Color.FromArgb(180,82,102,91))
        };
        Grid.SetColumn(arrow,2);
        grid.Children.Add(arrow);
        return grid;
    }

    private void ShowSlotToolPicker(int slot,FrameworkElement anchor)
    {
        if(_screen&&slot==7)return;
        var flyout=new Flyout{ShouldConstrainToRootBounds=false};
        var panel=new StackPanel
        {
            Width=396,
            Spacing=10,
            RequestedTheme=ElementTheme.Light,
            FlowDirection=RightToLeft?FlowDirection.RightToLeft:FlowDirection.LeftToRight
        };
        panel.Children.Add(new TextBlock
        {
            Text=$"{T("第")} {slot+1} {T("格")} · {T("選擇工具")}",
            FontSize=14,
            FontWeight=Microsoft.UI.Text.FontWeights.SemiBold,
            Foreground=new SolidColorBrush(Color.FromArgb(255,40,84,63))
        });

        var grid=new Grid{ColumnSpacing=6,RowSpacing=6};
        for(var c=0;c<3;c++)grid.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(1,GridUnitType.Star)});

        var currentKey=slot<_profile.Slots.Count?_profile.Slots[slot]:"";
        for(var idx=0;idx<_keys.Length;idx++)
        {
            var key=_keys[idx];
            var r=idx/3;
            var col=idx%3;
            while(grid.RowDefinitions.Count<=r)grid.RowDefinitions.Add(new RowDefinition{Height=GridLength.Auto});

            var isCurrent=string.Equals(currentKey,key,StringComparison.Ordinal);
            var existingIndex=string.IsNullOrEmpty(key)?-1:_profile.Slots.IndexOf(key);
            var itemGrid=new Grid{ColumnSpacing=6,VerticalAlignment=VerticalAlignment.Center};
            itemGrid.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(20)});
            itemGrid.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(1,GridUnitType.Star)});
            itemGrid.ColumnDefinitions.Add(new ColumnDefinition{Width=GridLength.Auto});

            var icon=ToolIcons.Create(key);
            if(string.IsNullOrEmpty(key))icon.Opacity=0.45;
            var iconWrap=new Border{Width=20,Height=20,Child=icon,HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center};
            Grid.SetColumn(iconWrap,0);
            itemGrid.Children.Add(iconWrap);

            var nameBlock=new TextBlock
            {
                Text=string.IsNullOrEmpty(key)?T("空"):Direct2DCanvasRenderer.RadialLabel(key),
                FontSize=12,
                VerticalAlignment=VerticalAlignment.Center,
                TextTrimming=TextTrimming.CharacterEllipsis
            };
            Grid.SetColumn(nameBlock,1);
            itemGrid.Children.Add(nameBlock);

            if(existingIndex>=0&&existingIndex!=slot)
            {
                var slotHint=new TextBlock
                {
                    Text=$"({existingIndex+1})",
                    FontSize=10,
                    VerticalAlignment=VerticalAlignment.Center,
                    Foreground=new SolidColorBrush(Color.FromArgb(180,95,115,104))
                };
                Grid.SetColumn(slotHint,2);
                itemGrid.Children.Add(slotHint);
            }

            var btn=new Button
            {
                HorizontalAlignment=HorizontalAlignment.Stretch,
                HorizontalContentAlignment=HorizontalAlignment.Stretch,
                Height=36,
                Padding=new Thickness(8,4,8,4),
                CornerRadius=new CornerRadius(6),
                Background=new SolidColorBrush(isCurrent?Color.FromArgb(255,214,239,227):Color.FromArgb(255,248,251,248)),
                BorderBrush=new SolidColorBrush(isCurrent?Color.FromArgb(255,57,115,90):Color.FromArgb(90,160,180,168)),
                BorderThickness=new Thickness(isCurrent?1.5:1),
                Content=itemGrid
            };
            ToolTipService.SetToolTip(btn,string.IsNullOrEmpty(key)?T("清空此格"):Direct2DCanvasRenderer.RadialLabel(key));
            btn.Click+=async(_,_)=>
            {
                flyout.Hide();
                if(string.IsNullOrEmpty(key))_profile.Slots[slot]="";
                else _profile.Assign(slot,key,_screen);
                await SaveAsync();
            };
            Grid.SetRow(btn,r);
            Grid.SetColumn(btn,col);
            grid.Children.Add(btn);
        }

        panel.Children.Add(grid);
        flyout.Content=panel;
        flyout.ShowAt(anchor);
    }

    private void ShowPresetPicker(FrameworkElement anchor)
    {
        var flyout=new Flyout{ShouldConstrainToRootBounds=false};
        var panel=new StackPanel
        {
            Width=360,
            Spacing=6,
            RequestedTheme=ElementTheme.Light,
            FlowDirection=RightToLeft?FlowDirection.RightToLeft:FlowDirection.LeftToRight
        };
        panel.Children.Add(new TextBlock
        {
            Text=T("選擇輪盤組合"),
            FontSize=14,
            FontWeight=Microsoft.UI.Text.FontWeights.SemiBold,
            Foreground=new SolidColorBrush(Color.FromArgb(255,40,84,63)),
            Margin=new Thickness(0,0,0,4)
        });

        void AddPresetRow(string keyOrName,string displayName,IReadOnlyList<string> slots,bool custom)
        {
            var isMatch=SlotsMatch(_profile.Slots,slots);
            var rowGrid=new Grid{ColumnSpacing=8,VerticalAlignment=VerticalAlignment.Center};
            rowGrid.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(1,GridUnitType.Star)});
            rowGrid.ColumnDefinitions.Add(new ColumnDefinition{Width=GridLength.Auto});

            var contentStack=new StackPanel{Spacing=4};
            var titleRow=new StackPanel{Orientation=Orientation.Horizontal,Spacing=6};
            titleRow.Children.Add(new TextBlock
            {
                Text=(isMatch?"✓ ":"")+displayName,
                FontSize=13,
                FontWeight=isMatch?Microsoft.UI.Text.FontWeights.SemiBold:Microsoft.UI.Text.FontWeights.Normal,
                Foreground=new SolidColorBrush(Color.FromArgb(255,34,54,44))
            });
            if(custom)
            {
                titleRow.Children.Add(new TextBlock
                {
                    Text=$"({T("自訂")})",
                    FontSize=11,
                    VerticalAlignment=VerticalAlignment.Center,
                    Foreground=new SolidColorBrush(Color.FromArgb(255,85,135,113))
                });
            }
            contentStack.Children.Add(titleRow);

            var iconsRow=new StackPanel{Orientation=Orientation.Horizontal,Spacing=4};
            for(var i=0;i<Math.Min(RadialToolProfile.Count,slots.Count);i++)
            {
                var k=slots[i];
                var icon=ToolIcons.Create(k);
                if(string.IsNullOrEmpty(k))icon.Opacity=0.35;
                var box=new Border
                {
                    Width=22,Height=22,CornerRadius=new CornerRadius(4),
                    Background=new SolidColorBrush(Color.FromArgb(255,236,243,238)),
                    Child=icon
                };
                ToolTipService.SetToolTip(box,$"{i+1}. {(string.IsNullOrEmpty(k)?T("空"):Direct2DCanvasRenderer.RadialLabel(k))}");
                iconsRow.Children.Add(box);
            }
            contentStack.Children.Add(iconsRow);

            var applyBtn=new Button
            {
                HorizontalAlignment=HorizontalAlignment.Stretch,
                HorizontalContentAlignment=HorizontalAlignment.Stretch,
                Padding=new Thickness(10,6,10,6),
                CornerRadius=new CornerRadius(8),
                Background=new SolidColorBrush(isMatch?Color.FromArgb(255,214,239,227):Color.FromArgb(255,248,251,248)),
                BorderBrush=new SolidColorBrush(isMatch?Color.FromArgb(255,57,115,90):Color.FromArgb(90,160,180,168)),
                BorderThickness=new Thickness(isMatch?1.5:1),
                Content=contentStack
            };
            applyBtn.Click+=async(_,_)=>
            {
                flyout.Hide();
                if(_profile.ApplyPreset(keyOrName,_screen))
                {
                    _presetNameBox.Text=custom?displayName:"";
                    await SaveAsync($"{T("已套用輪盤組合")}：{displayName}");
                }
            };
            Grid.SetColumn(applyBtn,0);
            rowGrid.Children.Add(applyBtn);

            if(custom)
            {
                var delBtn=new Button
                {
                    Width=34,Height=34,Padding=new Thickness(4),
                    VerticalAlignment=VerticalAlignment.Center,
                    Content=ToolIcons.Create("delete")
                };
                ToolTipService.SetToolTip(delBtn,$"{T("刪除組合")}：{displayName}");
                delBtn.Click+=async(_,_)=>
                {
                    flyout.Hide();
                    if(_profile.DeletePreset(keyOrName))
                    {
                        if(string.Equals(_presetNameBox.Text.Trim(),displayName,StringComparison.OrdinalIgnoreCase))
                            _presetNameBox.Text="";
                        await SaveAsync($"{T("已刪除輪盤組合")}：{displayName}");
                    }
                };
                Grid.SetColumn(delBtn,1);
                rowGrid.Children.Add(delBtn);
            }
            panel.Children.Add(rowGrid);
        }

        foreach(var builtIn in RadialToolProfile.BuiltInPresets(_screen))
            AddPresetRow(builtIn.Key,T(builtIn.Name),builtIn.Slots,custom:false);

        if(_profile.Presets.Count>0)
        {
            panel.Children.Add(new TextBlock
            {
                Text=T("已儲存的自訂組合"),
                FontSize=12,
                Foreground=new SolidColorBrush(Color.FromArgb(255,95,115,104)),
                Margin=new Thickness(0,6,0,2)
            });
            foreach(var custom in _profile.Presets)
                AddPresetRow(custom.Name,custom.Name,custom.Slots,custom:true);
        }

        flyout.Content=new ScrollViewer{Content=panel,MaxHeight=420,VerticalScrollBarVisibility=ScrollBarVisibility.Auto};
        flyout.ShowAt(anchor);
    }

    private static bool SlotsMatch(IReadOnlyList<string> a,IReadOnlyList<string> b)
    {
        if(a.Count!=b.Count)return false;
        for(var i=0;i<a.Count;i++)if(!string.Equals(a[i],b[i],StringComparison.Ordinal))return false;
        return true;
    }

    private (string Label,bool IsCustom,string CustomName) CurrentPresetDisplay()
    {
        foreach(var custom in _profile.Presets)
            if(SlotsMatch(_profile.Slots,custom.Slots))
                return (custom.Name,true,custom.Name);
        foreach(var builtIn in RadialToolProfile.BuiltInPresets(_screen))
            if(SlotsMatch(_profile.Slots,builtIn.Slots))
                return (T(builtIn.Name),false,"");
        return (T("自訂配置（未存檔）"),false,"");
    }

    private static int HitSlot(Point point)=>Math.Pow(point.X-160,2)+Math.Pow(point.Y-160,2)>RadialGesture.Radius*RadialGesture.Radius?-1:RadialGesture.Hit(new(point.X,point.Y),new(160,160),1);

    private async Task SaveAsync(string? customStatus=null)
    {
        RefreshSlots();
        try{await _save();if(!_closed)_status.Text=customStatus??T("設定已儲存");}
        catch(Exception error){if(!_closed)_status.Text=T("輪盤設定尚未保存：")+error.Message;}
    }

    internal void RefreshSlots()
    {
        if(_closed)return;
        for(var i=0;i<_slotButtons.Count;i++)
        {
            var key=_screen&&i==7?"operate":(i<_profile.Slots.Count?_profile.Slots[i]:"");
            _slotButtons[i].Content=CreateSlotButtonContent(key,_screen&&i==7);
        }
        var (presetLabel,isCustom,customName)=CurrentPresetDisplay();
        var presetGrid=new Grid{ColumnSpacing=8,VerticalAlignment=VerticalAlignment.Center};
        presetGrid.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(20)});
        presetGrid.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(1,GridUnitType.Star)});
        presetGrid.ColumnDefinitions.Add(new ColumnDefinition{Width=GridLength.Auto});
        var icon=new Border{Width=20,Height=20,Child=ToolIcons.Create("radial"),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center};
        Grid.SetColumn(icon,0);presetGrid.Children.Add(icon);
        var txt=new TextBlock{Text=presetLabel,FontSize=13,VerticalAlignment=VerticalAlignment.Center,TextTrimming=TextTrimming.CharacterEllipsis};
        Grid.SetColumn(txt,1);presetGrid.Children.Add(txt);
        var chev=new TextBlock{Text="▾",FontSize=11,VerticalAlignment=VerticalAlignment.Center,Foreground=new SolidColorBrush(Color.FromArgb(180,82,102,91))};
        Grid.SetColumn(chev,2);presetGrid.Children.Add(chev);
        _presetButton.Content=presetGrid;
        _deletePresetButton.IsEnabled=isCustom||(!string.IsNullOrWhiteSpace(_presetNameBox.Text)&&_profile.Presets.Any(p=>string.Equals(p.Name,_presetNameBox.Text.Trim(),StringComparison.OrdinalIgnoreCase)));
        if(isCustom&&string.IsNullOrWhiteSpace(_presetNameBox.Text))_presetNameBox.Text=customName;
        _canvas.Invalidate();
    }
}
