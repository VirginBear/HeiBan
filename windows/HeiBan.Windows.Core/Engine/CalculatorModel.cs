using System.Globalization;
using HeiBan.Windows.Models;

namespace HeiBan.Windows.Engine;

public sealed record CalculatorHistoryItem(
    string Id,
    string Expression,
    string Result,
    string Timestamp
);

/// <summary>
/// W-N03: 畫布內建計算機引擎 (對齊 CalculatorModel.swift)
/// 支援基本四則運算、括號運算、小數、正負號、百分比、科學計算 (sin/cos/tan/log/ln/sqrt/pow/reciprocal)
/// 支援 DEG/RAD 模式、歷史紀錄、複製及單步 Undo 插入畫布。
/// </summary>
public sealed class CalculatorModel
{
    public string Display { get; set; } = "0";
    public string Expression { get; set; } = string.Empty;
    public List<CalculatorHistoryItem> History { get; } = [];
    public bool IsDegreeMode { get; set; } = true;
    public bool IsScientificMode { get; set; } = false;
    public bool HasError { get; set; } = false;
    public bool IsVisible { get; set; } = false;
    public bool IsCollapsed { get; set; } = false;
    public double OffsetX { get; set; } = 80;
    public double OffsetY { get; set; } = 80;

    private string _currentInput = "0";
    private string? _pendingOperator = null;
    private double? _previousOperand = null;
    private bool _isEnteringNewNumber = true;

    public void InputDigit(string digit)
    {
        if (HasError)
        {
            Clear();
            InputDigit(digit);
            return;
        }

        if (_isEnteringNewNumber)
        {
            _currentInput = digit;
            _isEnteringNewNumber = false;
        }
        else
        {
            _currentInput = _currentInput == "0" ? digit : _currentInput + digit;
        }
        Display = _currentInput;
    }

    public void InputDecimal()
    {
        if (HasError)
        {
            Clear();
            InputDecimal();
            return;
        }

        if (_isEnteringNewNumber)
        {
            _currentInput = "0.";
            _isEnteringNewNumber = false;
        }
        else if (!_currentInput.Contains('.'))
        {
            _currentInput += ".";
        }
        Display = _currentInput;
    }

    public void InputParenthesis(string paren)
    {
        if (HasError) Clear();
        if (paren == "(")
        {
            if (_isEnteringNewNumber || Expression.EndsWith("+") || Expression.EndsWith("-") || Expression.EndsWith("×") || Expression.EndsWith("÷") || Expression.EndsWith("^") || string.IsNullOrEmpty(Expression))
            {
                Expression += "(";
            }
            else
            {
                Expression += $"{Display}×(";
            }
            _isEnteringNewNumber = true;
            _currentInput = "0";
            Display = "0";
        }
        else if (paren == ")")
        {
            if (!_isEnteringNewNumber && !Expression.TrimEnd().EndsWith(")"))
            {
                Expression += Display + ")";
                _isEnteringNewNumber = true;
            }
            else
            {
                Expression += ")";
            }
            var eval = EvaluateExpressionString(Expression);
            if (eval.HasValue)
            {
                Display = FormatNumber(eval.Value);
            }
        }
    }

    public void InputOperator(string op)
    {
        if (HasError) return;

        string normalizedOp = op switch
        {
            "+" or "＋" => "+",
            "-" or "−" or "–" => "-",
            "*" or "×" or "x" or "X" => "×",
            "/" or "÷" => "÷",
            "^" => "^",
            _ => op
        };

        if (Expression.Contains('(') || Expression.Contains(')'))
        {
            if (!_isEnteringNewNumber && !Expression.TrimEnd().EndsWith(")"))
            {
                Expression += $"{Display} {normalizedOp} ";
                _isEnteringNewNumber = true;
            }
            else
            {
                Expression += $" {normalizedOp} ";
            }
            _pendingOperator = normalizedOp;
            return;
        }

        double currentValue = ParseDisplayValue();

        if (_previousOperand.HasValue && _pendingOperator != null && !_isEnteringNewNumber)
        {
            var res = ExecuteBinaryOp(_previousOperand.Value, currentValue, _pendingOperator);
            if (res.HasValue)
            {
                _previousOperand = res.Value;
                Display = FormatNumber(res.Value);
            }
            else
            {
                ShowError();
                return;
            }
        }
        else
        {
            _previousOperand = currentValue;
        }

        _pendingOperator = normalizedOp;
        Expression = $"{FormatNumber(_previousOperand.Value)} {normalizedOp}";
        _isEnteringNewNumber = true;
    }

    public void InputPercentage()
    {
        if (HasError) return;
        double current = ParseDisplayValue();

        if (_previousOperand.HasValue && _pendingOperator != null)
        {
            double percentValue = _pendingOperator switch
            {
                "+" or "-" => _previousOperand.Value * (current / 100.0), // 200 + 10% = 220
                "×" => current / 100.0,                                    // 200 × 10% = 20
                "÷" => current / 100.0,
                _ => current / 100.0
            };
            _currentInput = FormatNumber(percentValue);
            Display = _currentInput;
        }
        else
        {
            double result = current / 100.0;
            _currentInput = FormatNumber(result);
            Display = _currentInput;
        }
    }

    public void CalculateResult()
    {
        if (HasError) return;
        if (Expression.Contains('(') || Expression.Contains(')'))
        {
            string fullExpr = Expression;
            if (!_isEnteringNewNumber && !fullExpr.TrimEnd().EndsWith(")"))
            {
                fullExpr += Display;
            }
            var eval = EvaluateExpressionString(fullExpr);
            if (eval.HasValue)
            {
                string formattedResult = FormatNumber(eval.Value);
                Display = formattedResult;
                Expression = $"{fullExpr} =";
                History.Insert(0, new CalculatorHistoryItem(
                    Guid.NewGuid().ToString("N"),
                    fullExpr,
                    formattedResult,
                    DateTime.UtcNow.ToString("o")
                ));
                if (History.Count > 30) History.RemoveAt(History.Count - 1);
                _previousOperand = eval.Value;
                _pendingOperator = null;
                _isEnteringNewNumber = true;
                return;
            }
            else
            {
                ShowError();
                return;
            }
        }
        if (!_previousOperand.HasValue || _pendingOperator == null) return;

        double current = ParseDisplayValue();
        string simpleExpr = $"{FormatNumber(_previousOperand.Value)} {_pendingOperator} {FormatNumber(current)}";

        var result = ExecuteBinaryOp(_previousOperand.Value, current, _pendingOperator);
        if (!result.HasValue)
        {
            ShowError();
            return;
        }

        string simpleFormattedResult = FormatNumber(result.Value);
        Display = simpleFormattedResult;
        Expression = $"{simpleExpr} =";

        History.Insert(0, new CalculatorHistoryItem(
            Guid.NewGuid().ToString("N"),
            simpleExpr,
            simpleFormattedResult,
            DateTime.UtcNow.ToString("o")
        ));
        if (History.Count > 30) History.RemoveAt(History.Count - 1);

        _previousOperand = result.Value;
        _pendingOperator = null;
        _isEnteringNewNumber = true;
    }

    public void ToggleSign()
    {
        if (HasError) return;
        double val = ParseDisplayValue();
        _currentInput = FormatNumber(-val);
        Display = _currentInput;
    }

    public void Clear()
    {
        Display = "0";
        Expression = string.Empty;
        _currentInput = "0";
        _pendingOperator = null;
        _previousOperand = null;
        _isEnteringNewNumber = true;
        HasError = false;
    }

    public void ClearEntry()
    {
        if (HasError)
        {
            Clear();
            return;
        }
        _currentInput = "0";
        Display = "0";
        _isEnteringNewNumber = true;
    }

    public void Backspace()
    {
        if (HasError || _isEnteringNewNumber) return;
        if (_currentInput.Length > 1)
        {
            _currentInput = _currentInput[..^1];
            if (_currentInput == "-")
            {
                _currentInput = "0";
                _isEnteringNewNumber = true;
            }
        }
        else
        {
            _currentInput = "0";
            _isEnteringNewNumber = true;
        }
        Display = _currentInput;
    }

    public void SquareRoot()
    {
        if (HasError) return;
        double val = ParseDisplayValue();
        if (val < 0) { ShowError(); return; }
        RecordUnary("√", val, Math.Sqrt(val));
    }

    public void Square()
    {
        if (HasError) return;
        double val = ParseDisplayValue();
        RecordUnary("sqr", val, val * val);
    }

    public void Reciprocal()
    {
        if (HasError) return;
        double val = ParseDisplayValue();
        if (Math.Abs(val) < 1e-15) { ShowError(); return; }
        RecordUnary("1/", val, 1.0 / val);
    }

    public void SinFunction()
    {
        if (HasError) return;
        double val = ParseDisplayValue();
        double radians = IsDegreeMode ? (val * Math.PI / 180.0) : val;
        double res = Math.Sin(radians);
        if (Math.Abs(res) < 1e-15) res = 0.0;
        RecordUnary("sin", val, res);
    }

    public void CosFunction()
    {
        if (HasError) return;
        double val = ParseDisplayValue();
        double radians = IsDegreeMode ? (val * Math.PI / 180.0) : val;
        double res = Math.Cos(radians);
        if (Math.Abs(res) < 1e-15) res = 0.0;
        RecordUnary("cos", val, res);
    }

    public void TanFunction()
    {
        if (HasError) return;
        double val = ParseDisplayValue();
        double radians = IsDegreeMode ? (val * Math.PI / 180.0) : val;
        double c = Math.Cos(radians);
        if (Math.Abs(c) < 1e-15) { ShowError(); return; }
        double res = Math.Tan(radians);
        if (Math.Abs(res) < 1e-15) res = 0.0;
        RecordUnary("tan", val, res);
    }

    public void Log10Function()
    {
        if (HasError) return;
        double val = ParseDisplayValue();
        if (val <= 0) { ShowError(); return; }
        RecordUnary("log", val, Math.Log10(val));
    }

    public void LnFunction()
    {
        if (HasError) return;
        double val = ParseDisplayValue();
        if (val <= 0) { ShowError(); return; }
        RecordUnary("ln", val, Math.Log(val));
    }

    public void ToggleDegreeMode() => IsDegreeMode = !IsDegreeMode;

    public void SetResult(string res)
    {
        Display = res;
        _currentInput = res;
        _isEnteringNewNumber = true;
        HasError = false;
    }

    public void EvaluateCurrentExpression(string expr)
    {
        var res = EvaluateExpressionString(expr);
        if (res.HasValue)
        {
            Display = FormatNumber(res.Value);
            Expression = $"{expr} =";
            _currentInput = Display;
            _isEnteringNewNumber = true;
            History.Insert(0, new CalculatorHistoryItem(Guid.NewGuid().ToString("N"), expr, Display, DateTime.UtcNow.ToString("o")));
            if (History.Count > 30) History.RemoveAt(History.Count - 1);
        }
        else
        {
            ShowError();
        }
    }

    public BoardObject CreateBoardObject(double centerX, double centerY, string boardId, string? pageId, bool asExpression = false)
    {
        string text = asExpression && !string.IsNullOrEmpty(Expression) ? $"{Expression} {Display}" : Display;
        return new BoardObject
        {
            Id = Guid.NewGuid().ToString("N"),
            BoardId = boardId,
            PageId = pageId,
            Type = "text",
            X = centerX - 60,
            Y = centerY - 20,
            Width = 140,
            Height = 44,
            Text = text,
            FontSize = 22,
            FontFamily = "Segoe UI Variable, Consolas, monospace",
            IsBold = true,
            StrokeColor = "#24533D",
            FillColor = "none"
        };
    }

    public static double? EvaluateExpressionString(string inputExpr)
    {
        if (string.IsNullOrWhiteSpace(inputExpr)) return null;

        string clean = inputExpr
            .Replace("×", "*")
            .Replace("÷", "/")
            .Replace("＋", "+")
            .Replace("−", "-")
            .Replace(" ", "");

        try
        {
            var parser = new ExpressionParser(clean);
            return parser.Parse();
        }
        catch
        {
            return null;
        }
    }

    private double ParseDisplayValue()
    {
        if (double.TryParse(_currentInput, NumberStyles.Float, CultureInfo.InvariantCulture, out double d)) return d;
        if (double.TryParse(Display, NumberStyles.Float, CultureInfo.InvariantCulture, out double d2)) return d2;
        return 0.0;
    }

    private static double? ExecuteBinaryOp(double left, double right, string op)
    {
        return op switch
        {
            "+" => left + right,
            "-" => left - right,
            "×" or "*" => left * right,
            "÷" or "/" => Math.Abs(right) < 1e-15 ? null : left / right,
            "^" => Math.Pow(left, right),
            _ => null
        };
    }

    private void RecordUnary(string funcName, double operand, double result)
    {
        string formattedRes = FormatNumber(result);
        string exprStr = $"{funcName}({FormatNumber(operand)})";
        Display = formattedRes;
        _currentInput = formattedRes;
        Expression = $"{exprStr} =";

        History.Insert(0, new CalculatorHistoryItem(
            Guid.NewGuid().ToString("N"),
            exprStr,
            formattedRes,
            DateTime.UtcNow.ToString("o")
        ));
        if (History.Count > 30) History.RemoveAt(History.Count - 1);
        _isEnteringNewNumber = true;
    }

    private void ShowError()
    {
        HasError = true;
        Display = "錯誤";
        Expression = string.Empty;
    }

    public static string FormatNumber(double val)
    {
        if (double.IsNaN(val) || double.IsInfinity(val)) return "錯誤";

        // 四捨五入消除 IEEE 754 微小誤差 (如 0.30000000000000004 -> 0.3)
        double rounded = Math.Round(val, 10);
        if (rounded % 1.0 == 0 && Math.Abs(rounded) < 1e14)
        {
            return rounded.ToString("0", CultureInfo.InvariantCulture);
        }

        return rounded.ToString("0.##########", CultureInfo.InvariantCulture);
    }

    private sealed class ExpressionParser(string expr)
    {
        private int _pos = 0;

        public double Parse()
        {
            double result = ParseAddSubtract();
            if (_pos < expr.Length) throw new FormatException("未預期的符號");
            return result;
        }

        private double ParseAddSubtract()
        {
            double left = ParseMultiplyDivide();
            while (_pos < expr.Length)
            {
                char op = expr[_pos];
                if (op != '+' && op != '-') break;
                _pos++;
                double right = ParseMultiplyDivide();
                left = op == '+' ? left + right : left - right;
            }
            return left;
        }

        private double ParseMultiplyDivide()
        {
            double left = ParsePower();
            while (_pos < expr.Length)
            {
                char op = expr[_pos];
                if (op != '*' && op != '/') break;
                _pos++;
                double right = ParsePower();
                if (op == '/' && Math.Abs(right) < 1e-15) throw new DivideByZeroException();
                left = op == '*' ? left * right : left / right;
            }
            return left;
        }

        private double ParsePower()
        {
            double left = ParseFactor();
            if (_pos < expr.Length && expr[_pos] == '^')
            {
                _pos++;
                double right = ParsePower();
                return Math.Pow(left, right);
            }
            return left;
        }

        private double ParseFactor()
        {
            if (_pos < expr.Length && expr[_pos] == '+')
            {
                _pos++;
                return ParseFactor();
            }
            if (_pos < expr.Length && expr[_pos] == '-')
            {
                _pos++;
                return -ParseFactor();
            }

            if (_pos < expr.Length && expr[_pos] == '(')
            {
                _pos++;
                double val = ParseAddSubtract();
                if (_pos < expr.Length && expr[_pos] == ')')
                {
                    _pos++;
                    return val;
                }
                throw new FormatException("缺少閉括號");
            }

            int start = _pos;
            while (_pos < expr.Length && (char.IsDigit(expr[_pos]) || expr[_pos] == '.'))
            {
                _pos++;
            }

            if (start == _pos) throw new FormatException("預期為數字");
            return double.Parse(expr[start.._pos], CultureInfo.InvariantCulture);
        }
    }
}
