# lantern

任意の構造体配列をテーブルとみなし、要約統計量を取得するためのライブラリです。

PythonにおけるPandasのDataFrameにある `describe` のような機能を持ちます。

- Pandas DataFrame.describe
  - [https://pandas.pydata.org/pandas-docs/stable/reference/api/pandas.DataFrame.describe.html](https://pandas.pydata.org/pandas-docs/stable/reference/api/pandas.DataFrame.describe.html)

# Examples

## Example (30 secs)

##### source
```d
import std;
import lantern;

void main()
{
    // make 10 records
    auto dataset = iota(10).map!(n => Test(uniform01()));

    auto result = describe(dataset);

    // get stats
    writeln(result.value.min);
    writeln(result.value.max);
    writeln(result.value.mean);
    writeln(result.value.std);
    writeln(result.value.p25);
    writeln(result.value.p50);
    writeln(result.value.p75);

    writeln();

    // print as table
    printTable(result);
}

struct Test
{
    double value;
}
```

##### output

```console
0.079207
0.865132
0.391348
0.237936
0.235163
0.376355
0.53751

|       | value    |
|-------|----------|
| count | 10       |
| min   | 0.079207 |
| max   | 0.865132 |
| p25   | 0.235163 |
| p50   | 0.376355 |
| p75   | 0.53751  |
| mean  | 0.391348 |
| std   | 0.237936 |
```


# 基本機能

## 対応する型

数値や文字列、真偽値やenumに対応します。

変数の種類によって以下の統計量が取得できます。

- 数値変数 (int, float, double, Duration, ...)
  - count, min, max, p25, p50, p75, mean, std
- 順序変数 (SysTime, DateTime, Date, TimeOfDay, ...)
  - count, uniq, top, freq, first, last
- カテゴリ変数 (string, bool, enum)
  - count, uniq, top, freq
