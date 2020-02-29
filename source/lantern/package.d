///
module lantern;

public import lantern.describe;
public import lantern.table;

///
unittest
{
	import std;
	import lantern;

	struct Test
	{
		double value;
	}

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

	// print as table
	printTable(result);
}

unittest
{
	import std;
	import lantern;

	struct Test
	{
		double value;
	}

	// make 10 records
	auto dataset = iota(10).map!(n => Test(uniform01()));

	auto result = describe(dataset);

    auto table = TablePrinter!(typeof(result))(result);
    auto buffer = appender!string();
    table.writeTo(buffer);
    const _text = buffer.data;
}