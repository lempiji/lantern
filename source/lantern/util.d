module lantern.util;

import core.time;

import std.typecons;

template MemberTypeOf(T)
{
    alias MemberTypeOf(string name) = typeof(__traits(getMember, T.init, name));
}

template FieldTypeOf(T)
{
    alias FieldTypeOf(string name) = typeof({
        auto value = __traits(getMember, T.init, name);
        return value;
    }());
}

unittest
{
    struct Test
    {
        int n;

        float test()
        {
            return 1.0f;
        }
    }

    alias MemberType = MemberTypeOf!Test;
    alias FieldType = FieldTypeOf!Test;

    static assert(is(MemberType!"n" == int));
    static assert(is(FieldType!"n" == int));

    alias F = float();
    static assert(is(MemberType!"test" == F));
    static assert(is(FieldType!"test" == float));
}

Nullable!Duration toDuration()(Nullable!long d)
{
    if (d.isNull)
        return Nullable!Duration.init;

    return nullable(d.get().hnsecs);
}

unittest
{
    Nullable!long a;
    Nullable!long b = 1.hnsecs.total!"hnsecs";
    Nullable!long c = 10.seconds.total!"hnsecs";

    assert(a.toDuration().isNull);
    assert(b.toDuration() == nullable(1.hnsecs));
    assert(c.toDuration() == nullable(10.seconds));
}

Nullable!Duration toDuration()(Nullable!real d)
{
    if (d.isNull)
        return Nullable!Duration.init;

    import std.math : round;

    return nullable((cast(long) round(d.get())).hnsecs);
}

unittest
{
    Nullable!real a;
    Nullable!real b = 1.hnsecs.total!"hnsecs";
    Nullable!real c = 10.seconds.total!"hnsecs";

    assert(a.toDuration().isNull);
    assert(b.toDuration() == nullable(1.hnsecs));
    assert(c.toDuration() == nullable(10.seconds));
}
