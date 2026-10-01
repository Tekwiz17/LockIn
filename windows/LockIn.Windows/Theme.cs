using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
namespace LockIn;
public static class Theme {
 public static readonly Brush Purple=new SolidColorBrush(Color.FromRgb(108,99,255));
 public static readonly Brush Background=new SolidColorBrush(Color.FromRgb(20,17,29));
 public static readonly Brush Ink=new SolidColorBrush(Color.FromRgb(242,238,255));
 public static readonly Brush Muted=new SolidColorBrush(Color.FromRgb(180,169,202));
 public static TextBlock Text(string value,double size=14,Brush? color=null)=>new(){Text=value,FontSize=size,Foreground=color??Ink,TextWrapping=TextWrapping.Wrap,Margin=new Thickness(0,4,0,8)};
 public static StackPanel Stack()=>new(){Margin=new Thickness(24)};
 public static Button Button(string title,Action action,bool enabled=true){var b=new Button{Content=title,Padding=new Thickness(14,9,14,9),Margin=new Thickness(0,4,8,4),Background=Purple,Foreground=Brushes.White,BorderThickness=new Thickness(0),IsEnabled=enabled};b.Click+=(_,_)=>Run(action);return b;}
 public static void Run(Action action){try{action();}catch(Exception e){MessageBox.Show(e.Message,"LockIn",MessageBoxButton.OK,MessageBoxImage.Warning);}}
 public static void Window(Window w,string title,double width=540,double height=640){w.Icon=new System.Windows.Media.Imaging.BitmapImage(new Uri("pack://application:,,,/Assets/LockIn.ico"));w.Title=title;w.Width=width;w.Height=height;w.MinWidth=Math.Min(width,420);w.MinHeight=Math.Min(height,300);w.Background=Background;w.Foreground=Ink;w.WindowStartupLocation=WindowStartupLocation.CenterOwner;}
 public static string Clock(double seconds){var t=TimeSpan.FromSeconds(Math.Max(0,seconds));return t.TotalHours>=1?$"{(int)t.TotalHours}:{t.Minutes:00}:{t.Seconds:00}":$"{t.Minutes:00}:{t.Seconds:00}";}
 public static string? Prompt(Window owner,string title,string initial=""){var w=new Window{Owner=owner};Window(w,title,440,240);var p=Stack();p.Children.Add(Text(title,18));var input=new TextBox{Text=initial,Margin=new Thickness(0,8,0,12)};p.Children.Add(input);string? result=null;p.Children.Add(Button("Save",()=>{if(string.IsNullOrWhiteSpace(input.Text))return;result=input.Text.Trim();w.DialogResult=true;}));w.Content=p;w.Loaded+=(_,_)=>input.Focus();w.ShowDialog();return result;}
 public static CheckBox Check(string title,bool value){return new(){Content=title,IsChecked=value,Foreground=Ink,Margin=new Thickness(0,8,0,8)};}
 public static TextBox Input(string value)=>new(){Text=value,Padding=new Thickness(8),Margin=new Thickness(0,4,0,8)};
 public static ComboBox Select(params string[] items){var c=new ComboBox{Margin=new Thickness(0,4,0,12),Padding=new Thickness(5)};foreach(var item in items)c.Items.Add(item);c.SelectedIndex=0;return c;}
}
