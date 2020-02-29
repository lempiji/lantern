module lantern.table;

import std.meta;
import std.traits;

///
void printTable(Results)(Results results)
{
    import std.array : appender;
    import std.stdio : writeln;

    auto table = TablePrinter!Results(results);
    auto buffer = appender!string;
    table.writeTo(buffer);

    writeln(buffer.data);
}

unittest
{
    struct X
    {
        int a;
        int b;
    }

    struct Y
    {
        int a;
        int c;
    }

    struct Z
    {
        int d;
    }

    static assert(MergeFieldNames!(X, Y) == AliasSeq!("a", "b", "c"));
    static assert(MergeFieldNames!(X, Y, Z) == AliasSeq!("a", "b", "c", "d"));
}

private alias MergeFieldNames(Ts...) = NoDuplicates!(staticMap!(FieldNameTuple, Ts));

unittest
{
    struct NumericResult
    {
        size_t count;
        double min;
        double max;
    }

    struct CategoricalResult
    {
        size_t count;
        string top;
        size_t freq;
    }

    struct Results
    {
        NumericResult num;
        CategoricalResult text;
    }

    alias B = MergeFieldNames!(Fields!Results);
    static assert(B == AliasSeq!("count", "min", "max", "top", "freq"));
}

struct TablePrinter(T)
{
    T result;

    alias ColumnNames = FieldNameTuple!T;
    alias RowNames = MergeFieldNames!(Fields!T);

    void writeTo(R)(R buffer)
    {
        import std.array : array;
        import std.algorithm : map, max, joiner, reduce;
        import std.range : put;
        import std.range : repeat;
        import eastasianwidth : displayWidth;

        enum rowNameLength = [RowNames].map!(name => displayWidth(name)).array();
        enum maxNameLength = rowNameLength.reduce!max;
        enum paddingHeaderText = "|" ~ repeatText(maxNameLength + 2, ' ');
        enum splitHeaderText = "|" ~ repeatText(maxNameLength + 2, '-');

        put(buffer, paddingHeaderText);

        import std.conv;

        string[][string] cells;
        static foreach (colName; ColumnNames)
        {
            static foreach (rowName; RowNames)
            {
                static if (__traits(compiles, {
                        auto s = __traits(getMember, __traits(getMember,
                        result, colName), rowName);
                    }))
                {
                    cells[colName] ~= to!string(__traits(getMember,
                            __traits(getMember, result, colName), rowName));
                }
                else
                {
                    cells[colName] ~= "";
                }
            }
        }

        size_t[string] columnWidths;
        static foreach (colName; ColumnNames)
        {
            columnWidths[colName] = max(cells[colName].map!(c => displayWidth(c))
                    .reduce!max(), displayWidth(colName));
        }

        static foreach (colName; ColumnNames)
        {
            put(buffer, "| ");
            put(buffer, colName);
            put(buffer, repeatText(columnWidths[colName] - displayWidth(colName) + 1));
        }
        put(buffer, "|\n");

        put(buffer, splitHeaderText);
        static foreach (colName; ColumnNames)
        {
            put(buffer, '|');
            put(buffer, repeatText(columnWidths[colName] + 2, '-'));
        }
        put(buffer, "|\n");

        static foreach (j, rowName; RowNames)
        {
            put(buffer, "| ");
            put(buffer, rowName);
            put(buffer, repeatText(maxNameLength - displayWidth(rowName) + 1));

            static foreach (i, colName; ColumnNames)
            {
                put(buffer, '|');
                put(buffer, ' ');
                put(buffer, cells[colName][j]);
                put(buffer, repeatText(columnWidths[colName] - displayWidth(cells[colName][j]) + 1));
            }
            put(buffer, "|\n");
        }
    }
}

unittest
{
    struct NumericResult
    {
        size_t count;
        double min;
        double max;
    }

    struct CategoricalResult
    {
        size_t count;
        string top;
        size_t freq;
        size_t サイズ;
    }

    struct Results
    {
        NumericResult num;
        CategoricalResult text;
    }

    TablePrinter!Results table;
    table.result.num.min = -1000;
    table.result.text.top = "lempiji";

    import std.array : appender;

    auto buffer = appender!string();
    table.writeTo(buffer);

    // import std.stdio : writeln;

    // writeln(buffer.data);
}

private string[] tablePadRight(string[] texts)
{
    import std.algorithm : map, max, reduce;
    import eastasianwidth : displayWidth;

    auto displayWidthList = texts.map!(s => displayWidth(s));
    const maxDisplayWidth = displayWidthList.reduce!max();

    auto results = new string[texts.length];
    foreach (i, ref result; results)
    {
        result = ' ' ~ texts[i] ~ repeatText(maxDisplayWidth - displayWidthList[i] + 1);
    }
    return results;
}

unittest
{
    enum texts = tablePadRight(["text", "value", "a", "b"]);
    assert(texts[0] == " text  ");
    assert(texts[1] == " value ");
    assert(texts[2] == " a     ");
    assert(texts[3] == " b     ");
}

private string repeatText(size_t n, char c = ' ')
in(n > 0)
in(n < 1000)
{
    auto text = new char[n];
    text[] = c;
    import std : assumeUnique;

    return text.assumeUnique();
}

unittest
{
    enum a = repeatText(4);
    assert(a == "    ");
}

private size_t calculateColumnWidth(size_t dataWidth, size_t columnNameLength)
{
    if (dataWidth > columnNameLength)
    {
        return dataWidth + 2;
    }
    return columnNameLength + 2;
}
