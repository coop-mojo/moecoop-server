/**
 * Copyright: Copyright 2016 Mojo
 * Authors: Mojo
 * License: $(LINK2 https://github.com/coop-mojo/moecoop-server/blob/master/LICENSE, MIT License)
 */
module coop.util;

import std.range;
import std.string;
import std.traits;

/// 各種データファイルが置いてあるディレクトリ
immutable SystemResourceBase = "resource";

/// プログラム名
immutable AppName = "生協の知恵袋"d;

/// バージョン番号
immutable Version = import("version").chomp;

/// 公式サイト URL
enum MoeCoopURL = "http://docs.fukuro.coop.moe/";

/**
 * バージョン番号 `var` がリリース版を表しているかを返す。
 * リリース版の番号は、`va.b.c` となっている (`a`, `b`, `c` は数字)。
 * Returns: `var` がリリース版を表していれば `true`、それ以外は `false`
 */
@property auto isRelease(in string ver) @safe pure nothrow
{
    import std.algorithm;
    return !ver.canFind("-");
}

///
@safe pure nothrow unittest
{
    assert(!"v1.0.2-2-norelease".isRelease);
    assert("v1.0.2".isRelease);
}

auto toReleaseArray(in string ver) @safe pure
{
    import std.algorithm;
    import std.conv;
    if (ver.isRelease)
    {
        return ver[1..$].split(".").to!(int[])~0;
    }
    else
    {
        auto vers = ver[1..$].split("-");
        return vers[0].split(".").to!(int[])~vers[1].to!int;
    }
}

@safe pure unittest
{
    assert("v1.2.0".toReleaseArray == [1, 2, 0, 0]);
    assert("v1.2.0-39-g591278a".toReleaseArray == [1, 2, 0, 39]);
}

auto versionLT(in string rhs, in string lhs) @safe pure
{
    return rhs.toReleaseArray < lhs.toReleaseArray;
}

@safe pure unittest
{
    assert("v1.2.0".versionLT("v1.2.0-39-g591278a"));
    assert("v1.2.0".versionLT("v1.2.1"));
}

///
auto indexOf(Range, Elem)(Range r, Elem e)
    if (isInputRange!Range && is(Elem: ElementType!Range) && !isSomeChar!(ElementType!Range))
{
    import std.algorithm;
    auto elm = r.enumerate.find!"a[1] == b"(e);
    return elm.empty ? -1 : elm.front[0];
}

///
@safe pure nothrow unittest
{
    assert([1, 2, 3, 4].indexOf(2) == 1);
    assert([1, 2, 3, 4].indexOf(5) == -1);
}

/**
 * デバッグビルド時に、key の重複時にエラー出力にその旨を表示する std.array.assocArray
 * リリースビルド時には std.array.assocArray をそのまま呼び出す。
 */
auto checkedAssocArray(Range)(Range r) if (isInputRange!Range)
{
    debug
    {
        import std.algorithm;
        import std.traits;
        import std.typecons;
        alias E = ElementType!Range;
        static assert(isTuple!E, "assocArray: argument must be a range of tuples");
        static assert(E.length == 2, "assocArray: tuple dimension must be 2");
        alias KeyType = E.Types[0];
        alias ValueType = E.Types[1];

        ValueType[KeyType] ret;
        return r.fold!((r, kv) {
                auto key = kv[0];
                auto val = kv[1];
                if (auto it = key in r)
                {
                    import std.stdio;
                    writef("キーが重複しています: %s", key);
                    static if (hasMember!(ValueType, "file") && is(typeof(ValueType.init.file) == string))
                    {
                        writefln(" (%s, %s)", (*it).file, val.file);
                    }
                    else
                    {
                        writeln;
                    }
                }
                r[key] = val;
                return r;
            })(ret);
    }
    else
    {
        return r.assocArray;
    }
}
