module lantern.describe;

import core.math;
import core.time;

import std.algorithm;
import std.array : Appender, appender;
import std.meta;
import std.range : put;
import std.traits;
import std.typecons;

import mir.math.sum;

import lantern.util;

enum isAggregator(T) = is(typeof({
            T aggregator;

            static assert(is(T.DataType));

            T.DataType value = void;
            .put(aggregator, value);

            auto result = aggregator.result();
            size_t count = result.count;
        }));

struct NumericAggregator(T)
{
    alias DataType = T;

    struct Result
    {
        size_t count;
        Nullable!DataType min;
        Nullable!DataType max;
        Nullable!real p25;
        Nullable!real p50;
        Nullable!real p75;
        Nullable!real mean;
        Nullable!real std;
    }

    size_t count = 0;
    Appender!(T[]) buffer;

    Result result()
    {
        if (count > 0)
        {
            import std.math : floor;

            auto data = buffer.data;
            immutable size = data.length;
            data.sort();

            Summator!(real, Summation.fast) summator = 0;
            .put(summator, data);
            real mean = summator.sum() / size;
            summator = 0;
            .put(summator, data.map!(a => (a - mean) ^^ 2));
            real std = sqrt(summator.sum() / (size - 1));

            real pos25_ = (size - 1) * 0.25;
            size_t pos25 = cast(size_t) floor(pos25_);
            real pos50_ = (size - 1) * 0.5;
            size_t pos50 = cast(size_t) floor(pos50_);
            real pos75_ = (size - 1) * 0.75;
            size_t pos75 = cast(size_t) floor(pos75_);

            Nullable!real p25 = ({
                if (pos25 == pos25_)
                    return data[pos25];

                auto a = pos25_ - pos25;
                return (1 - a) * data[pos25] + a * data[pos25 + 1];
            })();

            Nullable!real p50 = ({
                if (pos50 == pos50_)
                    return data[pos50];

                auto a = pos50_ - pos50;
                return (1 - a) * data[pos50] + a * data[pos50 + 1];
            })();

            Nullable!real p75 = ({
                if (pos75 == pos75_)
                    return data[pos75];

                auto a = pos75_ - pos75;
                return (1 - a) * data[pos75] + a * data[pos75 + 1];
            })();

            return Result(count, nullable(data[0]), nullable(data[$ - 1]), p25,
                    p50, p75, nullable(mean), nullable(std));
        }

        enum noneData = Nullable!DataType.init;
        enum none = Nullable!real.init;
        return Result(count, noneData, noneData, none, none, none, none, none);
    }

    void put(T value)
    {
        count++;
        .put(buffer, value);
    }
}

unittest
{
    static assert(isAggregator!(NumericAggregator!int));
    static assert(isAggregator!(NumericAggregator!float));
}

unittest
{
    NumericAggregator!int aggregator;
    auto result = aggregator.result();
    assert(result.count == 0);
    assert(result.mean.isNull);
    assert(result.std.isNull);
    assert(result.min.isNull);
    assert(result.p25.isNull);
    assert(result.p50.isNull);
    assert(result.p75.isNull);
    assert(result.max.isNull);
}

unittest
{
    import std.math : approxEqual;
    import std.conv : to;

    NumericAggregator!int aggregator;

    .put(aggregator, [1, 2, 3, 4, 5]);

    auto result = aggregator.result();
    static assert(is(typeof(result) == typeof(aggregator).Result));
    assert(result.count == 5);
    assert(result.mean == 3);
    assert(approxEqual(result.std.get, 1.581139), result.std.get.to!string);
    assert(result.min == 1, result.min.to!string());
    assert(result.p25 == 2, result.p25.to!string());
    assert(result.p50 == 3, result.p50.to!string());
    assert(result.p75 == 4, result.p75.to!string());
    assert(result.max == 5, result.min.to!string());
}

unittest
{
    import std.math : approxEqual;
    import std.conv : to;

    NumericAggregator!int aggregator;

    .put(aggregator, [1, 2, 3, 4, 5, 6]);

    auto result = aggregator.result();
    static assert(is(typeof(result) == typeof(aggregator).Result));
    assert(result.count == 6);
    assert(result.mean == 3.5);
    assert(approxEqual(result.std.get, 1.870829));
    assert(result.min == 1, result.min.to!string());
    assert(result.p25 == 2.25, result.p25.to!string());
    assert(result.p50 == 3.5, result.p50.to!string());
    assert(result.p75 == 4.75, result.p75.to!string());
    assert(result.max == 6, result.max.to!string());
}

struct DurationAggregator(T)
{
    alias DataType = T;

    struct Result
    {
        size_t count;
        Nullable!DataType min;
        Nullable!DataType max;
        Nullable!DataType p25;
        Nullable!DataType p50;
        Nullable!DataType p75;
        Nullable!DataType mean;
        Nullable!DataType std;
    }

    NumericAggregator!long aggregator;

    Result result()
    {
        auto inner = aggregator.result();

        return Result(inner.count, inner.min.toDuration(),
                inner.max.toDuration(), inner.p25.toDuration(),
                inner.p50.toDuration(), inner.p75.toDuration(),
                inner.mean.toDuration(), inner.std.toDuration());
    }

    void put(T value)
    {
        .put(aggregator, value.total!"hnsecs");
    }
}

unittest
{
    import core.time : Duration;

    static assert(isAggregator!(DurationAggregator!Duration));
}

unittest
{
    import core.time;
    import std.math : approxEqual;

    DurationAggregator!Duration aggregator;

    .put(aggregator, [1.seconds, 2.seconds, 3.seconds]);

    auto result = aggregator.result();

    assert(result.count == 3);
    assert(result.min == 1.seconds);
    assert(result.max == 3.seconds);
    assert(result.mean == 2.seconds);
    assert(result.std == 1.seconds);
}

struct CategoricalAggregator(T)
{
    alias DataType = T;

    struct Result
    {
        size_t count;
        size_t unique;
        Nullable!T top;
        size_t freq;
    }

    size_t count;
    size_t[T] counts;

    Result result()
    {
        size_t keyCount;
        size_t topCount;
        Nullable!T topKey;
        foreach (key, count; counts)
        {
            keyCount++;

            if (count > topCount)
            {
                topCount = count;
                topKey = key;
            }
        }

        return Result(count, keyCount, topKey, topCount);
    }

    void put(T value)
    {
        count++;
        counts[value]++;
    }
}

unittest
{
    enum Test
    {
        A,
        B,
        C
    }

    CategoricalAggregator!Test aggregator;

    auto result = aggregator.result();
    assert(result.count == 0);
    assert(result.unique == 0);
    assert(result.top.isNull);
    assert(result.freq == 0);
}

unittest
{
    enum Test
    {
        A,
        B,
        C
    }

    CategoricalAggregator!Test aggregator;

    .put(aggregator, [Test.A, Test.A, Test.A, Test.B]);

    auto result = aggregator.result();
    assert(result.count == 4);
    assert(result.unique == 2);
    assert(result.top == Test.A);
    assert(result.freq == 3);
}

unittest
{
    CategoricalAggregator!string aggregator;

    .put(aggregator, ["A", "A", "B", "B", "C", "C"]);

    auto result = aggregator.result();
    assert(result.count == 6);
    assert(result.unique == 3);
    assert(result.top == "A");
    assert(result.freq == 2);
}

struct SeriesAggregator(T)
{
    alias DataType = T;

    struct Result
    {
        size_t count;
        size_t unique;
        Nullable!DataType top;
        size_t freq;
        Nullable!DataType first;
        Nullable!DataType last;
    }

    size_t count;
    size_t[DataType] counts;

    Result result()
    {
        size_t keyCount;
        size_t topCount;
        Nullable!DataType topKey;
        Nullable!DataType first;
        Nullable!DataType last;
        foreach (key, count; counts)
        {
            keyCount++;
            if (count > topCount)
            {
                topCount = count;
                topKey = key;
            }
            if (first.isNull || key < first.get())
            {
                first = key;
            }
            if (last.isNull || key > last.get())
            {
                last = key;
            }
        }

        return Result(count, keyCount, topKey, topCount, first, last);
    }

    void put(DataType value)
    {
        count++;
        counts[value]++;
    }
}

unittest
{
    import core.time : MonoTime;
    import std.datetime : DateTime, Date, TimeOfDay, SysTime;

    static assert(isAggregator!(SeriesAggregator!MonoTime));
    static assert(isAggregator!(SeriesAggregator!DateTime));
    static assert(isAggregator!(SeriesAggregator!Date));
    static assert(isAggregator!(SeriesAggregator!TimeOfDay));
    static assert(isAggregator!(SeriesAggregator!SysTime));
}

unittest
{
    import std.datetime : SysTime, Date, UTC;

    SeriesAggregator!SysTime aggregator;

    .put(aggregator, [
            SysTime(Date(1990, 1, 1), UTC()), SysTime(Date(1990, 1, 1), UTC()),
            SysTime(Date(2000, 1, 1), UTC()), SysTime(Date(2010, 1, 1), UTC()),
            SysTime(Date(2020, 1, 1), UTC()),
            ]);

    auto result = aggregator.result();
    assert(result.count == 5);
}


struct DescribeConfig
{
    alias AggregatorResolver = DefaultResolver;
}

private template GetResolver(Config)
{
    static if (__traits(compiles, {
            static struct Test
            {
                int n;
            }

            alias ResolverOf = Config.AggregatorResolver;
            alias Resolver = ResolverOf!Test;
            alias Aggregator = Resolver!"n";
            static assert(isAggregator!Aggregator);
        }))
    {
        alias GetResolver = Config.AggregatorResolver;
    }
    else
    {
        alias GetResolver = DefaultResolver;
    }
}

unittest
{
    alias SimpleResolver = GetResolver!DescribeConfig;

}

///
auto describe(R, Config = DescribeConfig)(auto ref R datalist)
{
    import std.range : ElementType;

    alias RecordType = Unqual!(ElementType!R);

    alias ResolverOf = GetResolver!Config;
    alias Resolver = ResolverOf!RecordType;
    enum canAggregate(string name) = __traits(compiles, {
            alias T = Resolver!name;
            static assert(isAggregator!T);
        });

    alias AggregateNames = Filter!(canAggregate, __traits(allMembers, RecordType));
    alias RecordAggregators = staticMap!(Resolver, AggregateNames);

    RecordAggregators aggregators;
    foreach (data; datalist)
    {
        static foreach (i, name; AggregateNames)
        {
            .put(aggregators[i], __traits(getMember, data, name));
        }
    }

    static struct Results
    {
        static foreach (i, name; AggregateNames)
        {
            mixin(`RecordAggregators[i].Result ` ~ name ~ ";");
        }
    }

    Results results;
    static foreach (i, name; AggregateNames)
    {
        __traits(getMember, results, name) = aggregators[i].result();
    }
    return results;
}

///
unittest
{
    enum State
    {
        Uninitialized,
        Running,
        Finish,
    }

    struct Test
    {
        Object obj;
        string text;
        int number;
        Duration span;
        bool flag;
        State state;
    }

    auto result = describe([
            Test(null, "A", 10, 10.msecs, true, State.Uninitialized),
            Test(null, "A", 20, 20.msecs, true, State.Running),
            Test(null, "B", 30, 30.msecs, false, State.Uninitialized),
            Test(null, "B", 40, 40.msecs, false, State.Finish),
            Test(null, "B", 50, 50.msecs, true, State.Uninitialized),
            Test(null, "B", 60, 60.msecs, false, State.Running),
            ]);

    assert(result.text.count == 6);
    assert(result.text.unique == 2);
    assert(result.number.count == 6);
    assert(result.number.min == 10);
    assert(result.number.max == 60);
    assert(result.span.count == 6);
    assert(result.span.min == 10.msecs);
    assert(result.span.max == 60.msecs);
    assert(result.flag.count == 6);
    assert(result.flag.unique == 2);
    assert(result.flag.top == false);
    assert(result.flag.freq == 3);
    assert(result.state.count == 6);
    assert(result.state.top == State.Uninitialized);
    assert(result.state.freq == 3);
}

import std.datetime;

template DefaultResolver(T)
{
    alias MemberType = MemberTypeOf!T;

    template DefaultResolver(string name)
    {
        alias DataType = Unqual!(MemberType!name);

        static if (is(DataType == enum) || is(DataType == bool) || isSomeString!DataType)
        {
            alias DefaultResolver = CategoricalAggregator!DataType;
        }
        else static if (is(DataType == Duration))
        {
            alias DefaultResolver = DurationAggregator!DataType;
        }
        else static if (is(DataType == SysTime) || is(DataType == DateTime)
                || is(DataType == Date) || is(DataType == TimeOfDay))
        {
            alias DefaultResolver = SeriesAggregator!DataType;
        }
        else static if (isNumeric!DataType)
        {
            alias DefaultResolver = NumericAggregator!DataType;
        }
        else
        {
            static assert(false);
        }
    }
}

unittest
{
    import std.datetime : SysTime, DateTime, Date, TimeOfDay;

    enum State
    {
        A,
        B,
        C
    }

    struct Test
    {
        bool flag;
        State state;
        byte n1;
        ubyte n2;
        int n3;
        long n4;
        float f1;
        double f2;
        real f3;
        Duration d;
        SysTime t1;
        DateTime t2;
        Date t3;
        TimeOfDay t4;
        string s1;
        wstring s2;
        dstring s3;
    }

    static assert(isSomeString!dstring);

    alias Resolver = DefaultResolver!Test;
    static assert(is(Resolver!"flag" == CategoricalAggregator!bool));
    static assert(is(Resolver!"state" == CategoricalAggregator!State));
    static assert(is(Resolver!"n1" == NumericAggregator!byte));
    static assert(is(Resolver!"n2" == NumericAggregator!ubyte));
    static assert(is(Resolver!"n3" == NumericAggregator!int));
    static assert(is(Resolver!"n4" == NumericAggregator!long));
    static assert(is(Resolver!"f1" == NumericAggregator!float));
    static assert(is(Resolver!"f2" == NumericAggregator!double));
    static assert(is(Resolver!"f3" == NumericAggregator!real));
    static assert(is(Resolver!"d" == DurationAggregator!Duration));
    static assert(is(Resolver!"t1" == SeriesAggregator!SysTime));
    static assert(is(Resolver!"t2" == SeriesAggregator!DateTime));
    static assert(is(Resolver!"t3" == SeriesAggregator!Date));
    static assert(is(Resolver!"t4" == SeriesAggregator!TimeOfDay));
    static assert(is(Resolver!"s1" == CategoricalAggregator!string));
    static assert(is(Resolver!"s2" == CategoricalAggregator!wstring));
    static assert(is(Resolver!"s3" == CategoricalAggregator!dstring));
}

struct DescribeResult
{
    NumericAggregator!double result;

    string toString() const
    {
        return "";
    }
}
